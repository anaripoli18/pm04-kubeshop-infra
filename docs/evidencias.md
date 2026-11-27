# Evidências Técnicas - KubeShop PM04

## 1. Objetivo

Este documento consolida as evidências de implementação,
implantação, automação, backup e restauração do projeto
KubeShop.

As evidências são organizadas de acordo com o ambiente
em que foram produzidas.

## 2. Repositório

- [Código-fonte](https://github.com/anaripoli18/pm04-kubeshop-infra)
- [GitHub Actions](https://github.com/anaripoli18/pm04-kubeshop-infra/actions)

## 3. Evidências de infraestrutura AWS

| Evidência | Status |
|---|---|
| Duas instâncias EC2 | Aguardando captura |
| VPC e sub-redes | Aguardando captura |
| Internet Gateway | Aguardando captura |
| NAT Gateway | Aguardando captura |
| Security Groups | Aguardando captura |
| Volume EBS criptografado | Aguardando captura |
| Aplicação funcionando | Aguardando captura |
| MongoDB em rede privada | Aguardando captura |

As evidências de implantação deverão ser fornecidas
pela equipe responsável pela infraestrutura AWS.

## 4. Evidências da pipeline

| Execução | Finalidade | Link | Status |
|---|---|---|---|
| #3 | Implantação inicial | Pendente | A verificar |
| #6 | Atualização da aplicação | Pendente | A verificar |
| #4 | Validação de idempotência | Pendente | A verificar |

### 4.1. Implantação inicial

A evidência deverá demonstrar a execução das etapas
de provisionamento, configuração e implantação.

### 4.2. Atualização da aplicação

A evidência deverá demonstrar a atualização da
aplicação por meio da automação do projeto.

### 4.3. Idempotência

A evidência deverá demonstrar a reexecução da
automação sem alterações desnecessárias.

A conclusão deverá considerar os resultados do
Terraform e do Ansible, e não apenas o status
de sucesso do workflow.

## 5. Evidências de backup e restauração

### 5.1. Ambiente de validação

- Data: 27/11/2026.
- Sistema operacional: Windows.
- Terminal: PowerShell e Git Bash.
- Containerização: Docker Desktop.
- Banco de dados: MongoDB 8.0.17.
- Container: kubeshop-mongo-test.
- Banco: kubeshop.
- Coleção: orders.
- Dados utilizados: pedidos fictícios.

### 5.2. Backup manual

O primeiro teste foi realizado com 10 pedidos.

Após a geração do backup, um décimo primeiro
pedido foi inserido no banco original.

A restauração foi realizada em um banco temporário.

Resultado:

```
BANCO_ORIGINAL=kubeshop
PEDIDOS_ORIGINAIS=11
BANCO_TEMPORARIO=kubeshop_restore_20261127T230035Z
PEDIDOS_RESTAURADOS=10
PEDIDOS_ESPERADOS=10
PEDIDO_11_PRESERVADO=true
RESULTADO=APROVADO
```

### 5.3. Backup automatizado

Script utilizado:

`scripts/backup/backup-mongodb.sh`

Resultado:

```
[2026-11-27 20:05:31] Iniciando backup de kubeshop...
done dumping kubeshop.orders (11 documents)
[2026-11-27 20:05:31] Gerando manifesto JSON...
[2026-11-27 20:05:32] BACKUP=APROVADO
```

O script gerou um arquivo compactado contendo
11 pedidos e seu respectivo manifesto JSON.

### 5.4. Manifesto JSON

Manifesto real produzido durante o teste:

```json
{
  "database": "kubeshop",
  "collection": "orders",
  "documentCount": 11,
  "timestamp": "20261127T230530Z",
  "backupFile": "kubeshop_20261127T230530Z_1366.archive.gz",
  "sha256": "4d426e29961c9548a182d0ba57e33bd8536a618a1b9f2fed3d2ebd2b14153de3"
}
```

O hash SHA-256 foi utilizado para verificar
a integridade do arquivo antes da restauração.

### 5.5. Restauração automatizada

Script utilizado:

`scripts/backup/restore-mongodb.sh`

Após o backup automatizado, um décimo segundo
pedido foi inserido no banco original.

Resultado:

```
[2026-11-27 20:06:03] Validando pedidos restaurados...
PEDIDOS_ORIGINAIS=12
PEDIDOS_ESPERADOS=11
PEDIDOS_RESTAURADOS=11
RESULTADO=APROVADO
[2026-11-27 20:06:04] Restauracao temporaria validada.
```

Banco temporário:

`kubeshop_restore_20261127T230602Z_1694`

### 5.6. Validação integral dos documentos

Foi realizada uma comparação complementar entre
os documentos originais e os documentos restaurados.

Resultado:

```
PEDIDOS_ORIGINAIS=12
PEDIDOS_RESTAURADOS=11
DOCUMENTOS_IDENTICOS=true
PEDIDO_12_PRESERVADO=true
PEDIDO_12_AUSENTE_NO_RESTORE=true
VALIDACAO_FINAL=APROVADO
```

Os 11 pedidos recuperados apresentaram conteúdo
idêntico aos documentos originais comparados.

O décimo segundo pedido permaneceu no banco
original e não foi incluído no banco restaurado.

### 5.7. Resumo das validações

| Teste | Resultado |
|---|---|
| Conexão com MongoDB | Aprovado |
| Inserção de pedidos | Aprovado |
| Backup manual | Aprovado |
| Restauração manual | Aprovado |
| Sintaxe dos scripts | Aprovado |
| Backup automatizado | Aprovado |
| Manifesto JSON | Aprovado |
| Verificação SHA-256 | Aprovado |
| Restauração automatizada | Aprovado |
| Comparação integral dos documentos | Aprovado |
| Preservação do pedido adicional | Aprovado |
| Rejeição de backup corrompido | Pendente |
| Integração Amazon S3 | Pendente |
| Backup automatizado na AWS | Pendente |
| Agendamento pela pipeline | Pendente |

## 6. Evidências documentais

- [Arquitetura](arquitetura.md)
- [Tecnologias e requisitos](tecnologias-e-requisitos.md)
- [Backup e restauração](backup-e-restauracao.md)
- [Estimativa de custos AWS](estimativa-custos-aws.md)
- [Diagrama Mermaid](assets/diagrama-infraestrutura.mmd)
- [Diagrama Draw.io](assets/diagrama-infraestrutura.drawio)

## 7. Capturas de tela

As capturas serão organizadas nos seguintes diretórios:

- evidencias/backup/
- evidencias/infraestrutura/
- evidencias/pipeline/

Os arquivos serão incorporados após conferência
de sua existência, conteúdo e legibilidade.

Nenhuma captura deverá expor senhas, tokens,
chaves privadas ou credenciais de acesso.

## 8. Limitações

Os testes de backup e restauração foram realizados
em ambiente local.

A comparação integral dos documentos foi executada
como validação complementar.

A integração com Amazon S3, as permissões IAM,
o agendamento e a recuperação efetiva na AWS
ainda precisam ser validados.

Os resultados locais não representam uma medição
do RPO ou RTO em ambiente de produção.

## 9. Responsabilidade técnica

Responsável pela rotina de backup, restauração,
testes locais e documentação técnica:

**João Pedro Foster Ruiz**

Projeto KubeShop - PM04.
