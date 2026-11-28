# Backup e teste de restauracao MongoDB — AWS

## Pre-requisitos

- EC2 privada `pm04-kubeshop-db-dev` ligada e conectada ao Systems Manager.
- Bucket privado `pm04-kubeshop-backups-251783195076` em `us-east-1`, criptografia SSE-S3, acesso publico bloqueado e expiracao de objetos apos 30 dias.
- IAM Role da EC2 `pm04-kubeshop-database-ssm-dev` com `s3:ListBucket`, `s3:GetBucketLocation` no bucket e `s3:GetObject`, `s3:PutObject` no prefixo `kubeshop/mongodb/*`.
- Role do GitHub `PM04GitHubActionsDeploy` com acesso SSM e ao bucket temporario `pm04-kubeshop-ansible-251783195076`, como na pipeline de deploy.
- **Nunca usar o bucket temporario do Ansible nem o bucket Terraform State para os backups.**

## Backup manual pela pipeline

1. GitHub > Actions > **Backup e restauracao MongoDB AWS** > **Run workflow**.
2. Branch `main`, operacao `backup` e campo `backup_key` vazio.
3. Nos logs, localizar `BACKUP=APROVADO` e `Destino: s3://...`.
4. No S3, abrir `pm04-kubeshop-backups-251783195076/kubeshop/mongodb/` e verificar o arquivo `.archive.gz` e seu manifesto `.manifest.json`.

## Teste de restauracao (sem substituir o banco da loja)

1. Copiar a chave S3 exata do arquivo de backup, por exemplo `kubeshop/mongodb/kubeshop_20261127T230530Z_1366.archive.gz`.
2. No mesmo workflow, selecionar `restore-test` e preencher `backup_key` com essa chave.
3. Nos logs, verificar `SHA-256=APROVADO`, `PEDIDOS_RESTAURADOS` e `RESULTADO=APROVADO`.
4. Verificar que os pedidos do MongoDB original continuam aparecendo na loja.

O teste restaura os documentos em um **banco temporario**. Nao remove nem substitui `kubeshop`. A remocao posterior do banco temporario requer revisao separada.

## Agendamento automatico

A pipeline programa backup diario **03:17 UTC**. Se a VM estiver parada, o backup agendado sera ignorado; ele nao liga as VMs. Apos finalizar os testes do projeto e desligar a infraestrutura, **desabilitar o workflow agendado** para evitar tentativas recorrentes.

## Limites

A rotina nao executa `terraform apply`, nao faz restore por cima do banco da aplicacao e nao inicia ou para EC2. Um backup logico por `mongodump` nao equivale a um snapshot consistente do banco com escritas concorrentes. A infraestrutura do bucket e permissoes devem ser versionadas futuramente no Terraform para garantir reproducibilidade completa.
