#!/usr/bin/env bash
set -Eeuo pipefail

export MSYS_NO_PATHCONV=1
umask 077

PROJECT_DIR="${PROJECT_DIR:-/opt/kubeshop}"
MONGO_DB="kubeshop"
S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-kubeshop/mongodb}"
AWS_REGION="${AWS_REGION:-us-east-1}"
BACKUP_MODE="${BACKUP_MODE:-s3}"
LOCAL_BACKUP_DIR="${LOCAL_BACKUP_DIR:-}"
MONGO_CONTAINER="${MONGO_CONTAINER:-}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

fail() {
  log "ERRO: $*"
  exit 1
}

if python3 --version >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif python --version >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  fail "Python 3 nao encontrado."
fi

run_python() {
  (
    unset MSYS_NO_PATHCONV
    unset MSYS2_ARG_CONV_EXCL
    "$PYTHON_BIN" "$@"
  )
}

for cmd in docker gzip; do
  command -v "$cmd" >/dev/null 2>&1 ||
    fail "Comando nao encontrado: $cmd"
done

case "$BACKUP_MODE" in
  s3)
    command -v aws >/dev/null 2>&1 ||
      fail "AWS CLI nao encontrada."
    [[ -n "$S3_BUCKET" ]] ||
      fail "Configure S3_BUCKET."
    ;;
  local)
    [[ -n "$LOCAL_BACKUP_DIR" ]] ||
      fail "Configure LOCAL_BACKUP_DIR."
    ;;
  *)
    fail "BACKUP_MODE invalido."
    ;;
esac

mongo_exec() {
  if [[ -n "$MONGO_CONTAINER" ]]; then
    docker exec -i "$MONGO_CONTAINER" "$@"
  else
    docker compose \
      --project-directory "$PROJECT_DIR" \
      -f "$PROJECT_DIR/compose.db.yaml" \
      exec -T mongodb "$@"
  fi
}

TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
BACKUP_NAME="${MONGO_DB}_${TIMESTAMP}_$$.archive.gz"
S3_KEY="${S3_PREFIX%/}/${BACKUP_NAME}"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

BACKUP_FILE="$TEMP_DIR/$BACKUP_NAME"
MANIFEST_FILE="$BACKUP_FILE.manifest.json"
DUMP_LOG="$TEMP_DIR/mongodump.log"

log "Iniciando backup de $MONGO_DB..."

if ! mongo_exec sh -c '
  set -eu
  umask 077

  config="$(mktemp)"
  trap "rm -f \"$config\"" EXIT

  mongosh --nodb --quiet --eval "
    const fs = require(\"fs\");
    const local = process.env.MONGO_INITDB_ROOT_PASSWORD;
    const password = local ||
      fs.readFileSync(
        \"/run/secrets/mongo_app_password\", \"utf8\"
      ).trim();

    const user = local ? \"admin\" : \"kubeshop\";
    const auth = local ? \"admin\" : \"kubeshop\";

    print(JSON.stringify({
      uri: \"mongodb://\" + user + \":\" +
        encodeURIComponent(password) +
        \"@127.0.0.1:27017/?authSource=\" + auth
    }));
  " > "$config"

  mongodump \
    --config="$config" \
    --db=kubeshop \
    --archive \
    --gzip
' > "$BACKUP_FILE" 2> "$DUMP_LOG"; then
  cat "$DUMP_LOG"
  fail "Falha no mongodump."
fi

cat "$DUMP_LOG"

[[ -s "$BACKUP_FILE" ]] ||
  fail "Arquivo de backup vazio."

gzip -t "$BACKUP_FILE" ||
  fail "Arquivo gzip invalido."

log "Gerando manifesto JSON..."

run_python - "$BACKUP_FILE" "$MANIFEST_FILE" \
  "$DUMP_LOG" "$TIMESTAMP" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

backup = pathlib.Path(sys.argv[1])
manifest = pathlib.Path(sys.argv[2])
dump_log = pathlib.Path(sys.argv[3]).read_text(
    encoding="utf-8", errors="replace"
)

counts = re.findall(
    r"done dumping kubeshop\.orders \((\d+) documents?\)",
    dump_log
)

if len(counts) != 1:
    raise SystemExit(
        "ERRO: nao foi possivel identificar "
        "a quantidade de pedidos no dump."
    )

digest = hashlib.sha256()

with backup.open("rb") as file:
    for chunk in iter(lambda: file.read(1048576), b""):
        digest.update(chunk)

data = {
    "database": "kubeshop",
    "collection": "orders",
    "documentCount": int(counts[0]),
    "timestamp": sys.argv[4],
    "backupFile": backup.name,
    "sha256": digest.hexdigest()
}

manifest.write_text(
    json.dumps(data, indent=2) + "\n",
    encoding="utf-8"
)

print(json.dumps(data, indent=2))
PY

if [[ "$BACKUP_MODE" == "local" ]]; then
  mkdir -p "$LOCAL_BACKUP_DIR"

  cp "$BACKUP_FILE" "$LOCAL_BACKUP_DIR/"
  cp "$MANIFEST_FILE" "$LOCAL_BACKUP_DIR/"

  log "Destino: $LOCAL_BACKUP_DIR/$BACKUP_NAME"
else
  log "Enviando backup para Amazon S3..."

  aws s3 cp "$BACKUP_FILE" \
    "s3://$S3_BUCKET/$S3_KEY" \
    --region "$AWS_REGION" \
    --sse AES256 \
    --only-show-errors

  aws s3 cp "$MANIFEST_FILE" \
    "s3://$S3_BUCKET/$S3_KEY.manifest.json" \
    --region "$AWS_REGION" \
    --sse AES256 \
    --only-show-errors

  for key in "$S3_KEY" "$S3_KEY.manifest.json"; do
    aws s3api head-object \
      --bucket "$S3_BUCKET" \
      --key "$key" \
      --region "$AWS_REGION" >/dev/null
  done

  log "Destino: s3://$S3_BUCKET/$S3_KEY"
fi

log "BACKUP=APROVADO"
