#!/usr/bin/env bash
set -Eeuo pipefail

export MSYS_NO_PATHCONV=1
umask 077

PROJECT_DIR="${PROJECT_DIR:-/opt/kubeshop}"
MONGO_DB="kubeshop"
S3_BUCKET="${S3_BUCKET:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
BACKUP_MODE="${BACKUP_MODE:-s3}"
MONGO_CONTAINER="${MONGO_CONTAINER:-}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

fail() {
  log "ERRO: $*"
  exit 1
}

BACKUP_SOURCE="${1:-}"

[[ -n "$BACKUP_SOURCE" ]] ||
  fail "Informe o arquivo local ou a chave S3."

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
RESTORE_DB="${MONGO_DB}_restore_${TIMESTAMP}_$$"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

BACKUP_NAME="$(basename "$BACKUP_SOURCE")"
BACKUP_FILE="$TEMP_DIR/$BACKUP_NAME"
MANIFEST_FILE="$BACKUP_FILE.manifest.json"

case "$BACKUP_MODE" in
  local)
    cp "$BACKUP_SOURCE" "$BACKUP_FILE"
    cp "$BACKUP_SOURCE.manifest.json" "$MANIFEST_FILE"
    ;;
  s3)
    command -v aws >/dev/null 2>&1 ||
      fail "AWS CLI nao encontrada."

    [[ -n "$S3_BUCKET" ]] ||
      fail "Configure S3_BUCKET."

    aws s3 cp \
      "s3://$S3_BUCKET/$BACKUP_SOURCE" \
      "$BACKUP_FILE" \
      --region "$AWS_REGION" \
      --only-show-errors

    aws s3 cp \
      "s3://$S3_BUCKET/$BACKUP_SOURCE.manifest.json" \
      "$MANIFEST_FILE" \
      --region "$AWS_REGION" \
      --only-show-errors
    ;;
  *)
    fail "BACKUP_MODE invalido."
    ;;
esac

[[ -s "$BACKUP_FILE" ]] ||
  fail "Arquivo de backup vazio."

gzip -t "$BACKUP_FILE" ||
  fail "Arquivo gzip invalido."

log "Validando manifesto e SHA-256..."

EXPECTED_COUNT="$(run_python - "$BACKUP_FILE" \
  "$MANIFEST_FILE" <<'PY'
import hashlib
import json
import pathlib
import sys

backup = pathlib.Path(sys.argv[1])

with open(sys.argv[2], encoding="utf-8-sig") as file:
    manifest = json.load(file)

if manifest.get("database") != "kubeshop":
    raise SystemExit("Banco incorreto no manifesto.")

if manifest.get("collection") != "orders":
    raise SystemExit("Colecao incorreta no manifesto.")

if manifest.get("backupFile") != backup.name:
    raise SystemExit("Nome do backup divergente.")

count = manifest.get("documentCount")

if type(count) is not int or count < 0:
    raise SystemExit("Contagem invalida no manifesto.")

digest = hashlib.sha256()

with backup.open("rb") as file:
    for chunk in iter(lambda: file.read(1048576), b""):
        digest.update(chunk)

if digest.hexdigest() != manifest.get("sha256"):
    raise SystemExit("ERRO: SHA-256 divergente.")

print(count)
PY
)"

log "SHA-256=APROVADO"
log "PEDIDOS_ESPERADOS=$EXPECTED_COUNT"
log "BANCO_ORIGINAL=$MONGO_DB"
log "BANCO_TEMPORARIO=$RESTORE_DB"

log "Restaurando em banco temporario..."

mongo_exec sh -c '
  set -eu
  umask 077

  config="$(mktemp)"
  trap "rm -f \"$config\"" EXIT

  mongosh --nodb --quiet --eval "
    const fs = require(\"fs\");
    const password =
      process.env.MONGO_INITDB_ROOT_PASSWORD ||
      fs.readFileSync(
        \"/run/secrets/mongo_root_password\", \"utf8\"
      ).trim();

    print(JSON.stringify({
      uri: \"mongodb://admin:\" +
        encodeURIComponent(password) +
        \"@127.0.0.1:27017/?authSource=admin\"
    }));
  " > "$config"

  mongorestore \
    --config="$config" \
    --archive \
    --gzip \
    --nsInclude="kubeshop.*" \
    --nsFrom="kubeshop.*" \
    --nsTo="$1.*" \
    --stopOnError
' sh "$RESTORE_DB" < "$BACKUP_FILE"

log "Validando pedidos restaurados..."

mongo_exec env \
  "RESTORE_DB=$RESTORE_DB" \
  "EXPECTED_COUNT=$EXPECTED_COUNT" \
  mongosh --nodb --quiet --eval '
    const fs = require("fs");

    const password =
      process.env.MONGO_INITDB_ROOT_PASSWORD ||
      fs.readFileSync(
        "/run/secrets/mongo_root_password", "utf8"
      ).trim();

    const connection = new Mongo(
      "mongodb://admin:" +
      encodeURIComponent(password) +
      "@127.0.0.1:27017/?authSource=admin"
    );

    const original = connection.getDB("kubeshop");
    const restored = connection.getDB(
      process.env.RESTORE_DB
    );

    const expected = Number(process.env.EXPECTED_COUNT);
    const actual = restored.orders.countDocuments({});
    const originalCount = original.orders.countDocuments({});

    print("PEDIDOS_ORIGINAIS=" + originalCount);
    print("PEDIDOS_ESPERADOS=" + expected);
    print("PEDIDOS_RESTAURADOS=" + actual);

    if (actual !== expected) {
      print("RESULTADO=REPROVADO");
      quit(1);
    }

    print("RESULTADO=APROVADO");
  '

log "Restauracao temporaria validada."
log "Banco disponivel para inspecao: $RESTORE_DB"
