# Arquitetura do KubeShop

## 1. Visão geral

O KubeShop é uma aplicação web composta por frontend, backend e banco de dados MongoDB. A aplicação utiliza containers Docker para padronizar a execução e permitir implantação em ambiente local ou infraestrutura AWS.

Na implantação AWS, os componentes são distribuídos em duas instâncias EC2: uma para a aplicação e outra para o banco de dados.

## 2. Componentes e tecnologias

| Componente | Tecnologia | Versão |
|---|---|---|
| Frontend | React | 19.3.1 |
| Build do frontend | Vite | 8.3.4 |
| Servidor web e proxy reverso | Nginx | 1.28.0-alpine |
| Backend | Node.js | 24.15.0 |
| Framework backend | Express | 5.3.0 |
| Driver MongoDB | MongoDB Node.js Driver | 7.7.0 |
| Banco de dados | MongoDB | 8.0.17 |
| Containers | Docker | Conforme ambiente |
| Orquestração dos containers | Docker Compose | Conforme ambiente |

## 3. Arquitetura da aplicação

A aplicação é dividida em três componentes principais:

- **Frontend:** interface web desenvolvida em React e compilada com Vite. Os arquivos gerados são servidos pelo Nginx.
- **Backend:** API desenvolvida em Node.js e Express, responsável pela lógica da aplicação e comunicação com o banco de dados.
- **Banco de dados:** MongoDB, responsável pela persistência das informações da aplicação.

O Nginx atua como servidor web e proxy reverso. Ele disponibiliza a interface React e encaminha as requisições destinadas a `/api` para o serviço backend na porta 3000.

## 4. Execução local

O arquivo `compose.yaml` define os três serviços:

| Serviço | Função | Porta |
|---|---|---|
| frontend | Interface React servida pelo Nginx | 8080 (publicada) |
| api | API Node.js e Express | 3000 (interna) |
| mongodb | Banco de dados MongoDB | 27017 (interna) |

A comunicação entre frontend e API ocorre pela rede Docker `web`. A API e o MongoDB se comunicam pela rede `data`, configurada como interna.

O MongoDB utiliza volumes Docker para persistir os dados e arquivos de configuração.

O serviço frontend depende da API saudável, enquanto a API depende do MongoDB saudável.

## 5. Arquitetura AWS

Na implantação AWS, os serviços são distribuídos em duas instâncias EC2 na região `us-east-1`.

### 5.1. Instância de aplicação

A instância pública executa o Docker Compose definido em `compose.app.yaml`, contendo:

- Frontend React servido pelo Nginx.
- Backend Node.js e Express.
- Comunicação com o banco de dados pelo endereço IP privado.

A porta TCP 8080 é publicada na instância para disponibilizar a aplicação. A API utiliza a porta 3000 internamente no ambiente Docker, sem publicação direta dessa porta no host.

O Nginx encaminha as requisições `/api` para o backend.

### 5.2. Instância de banco de dados

A instância privada executa o Docker Compose definido em `compose.db.yaml`, contendo:

- MongoDB 8.0.17.
- Volume EBS dedicado de 20 GiB para persistência dos dados.
- Diretório separado para os arquivos de configuração do MongoDB.

A porta TCP 27017 é vinculada ao endereço privado da instância. O Security Group do banco permite acesso nessa porta somente a partir do Security Group da aplicação.

### 5.3. Rede AWS

A infraestrutura utiliza:

- VPC `10.40.0.0/16`.
- Sub-rede pública `10.40.1.0/24`.
- Sub-rede privada `10.40.2.0/24`.
- Internet Gateway para conectividade da sub-rede pública.
- NAT Gateway para saída da sub-rede privada.
- Security Groups para controlar o tráfego entre os componentes.

A instância de aplicação possui acesso público. A instância de banco de dados não possui IP público.

## 6. Persistência e armazenamento

No ambiente local, o MongoDB utiliza volumes Docker.

Na AWS, os dados do MongoDB são armazenados em um volume EBS separado da instância EC2, com capacidade de 20 GiB, tipo gp3 e criptografia habilitada.

A infraestrutura também utiliza discos raiz EBS para as instâncias EC2.

A separação do volume de dados permite preservar os dados do MongoDB independentemente do ciclo de vida da instância, desde que o volume não seja removido manualmente.

## 7. Segurança

A arquitetura contempla as seguintes medidas:

- Senhas do MongoDB disponibilizadas por Docker Secrets.
- Usuário específico da aplicação para acesso ao banco.
- Autenticação do MongoDB habilitada.
- Porta do MongoDB restrita ao tráfego privado autorizado.
- Instância de banco de dados sem exposição direta à internet.
- Volumes EBS criptografados.
- Sistema de arquivos somente leitura nos serviços frontend e API.
- Remoção de capabilities Linux desnecessárias nos serviços frontend e API.
- Opção `no-new-privileges` nos containers.
- Cabeçalhos de segurança configurados no Nginx.
- IMDSv2 obrigatório nas instâncias EC2.
- Role IAM das instâncias preparada para acesso ao AWS Systems Manager por meio da política `AmazonSSMManagedInstanceCore`.

As permissões necessárias para operações no Amazon S3 ainda dependem de configuração específica na role IAM.

## 8. Healthchecks e logs

Os serviços possuem verificações de saúde para acompanhar sua disponibilidade:

- Frontend: endpoint `/healthz`.
- Backend: endpoint `/api/health/ready`.
- MongoDB: verificação executada pelo `mongosh`.

No Compose local, os logs dos containers utilizam o driver `json-file`, com limite de 10 MB por arquivo e retenção de até três arquivos.

O Nginx encaminha os logs de acesso e erro para stdout e stderr.

## 9. Backup e recuperação

A estratégia planejada contempla a utilização de `mongodump` e `mongorestore` para gerar e recuperar backups do MongoDB.

Os arquivos de backup serão armazenados em um bucket privado do Amazon S3, utilizando criptografia SSE-S3 no envio e permissões IAM associadas à instância de banco de dados.

A implementação ainda depende de:

- Criação do bucket S3.
- Configuração das permissões necessárias na role IAM.
- Disponibilidade do AWS CLI e das ferramentas MongoDB Database Tools na instância.
- Validação da conectividade entre a instância de banco de dados e o MongoDB.

O bucket e as permissões específicas para backup ainda não estão configurados.

Os procedimentos operacionais serão detalhados em `backup-e-restauracao.md`.

## 10. Diagramas

Diagrama de infraestrutura:

[`assets/diagrama-infraestrutura.mmd`](assets/diagrama-infraestrutura.mmd)

Fluxo da aplicação:

[`assets/fluxo-aplicacao.pdf`](assets/fluxo-aplicacao.pdf)

## 11. Referências de configuração

- `compose.yaml`: execução integrada local.
- `compose.app.yaml`: serviços da aplicação na AWS.
- `compose.db.yaml`: serviço MongoDB na AWS.
- `apps/backend/Dockerfile`: construção da imagem do backend.
- `apps/frontend/Dockerfile`: construção da imagem do frontend.
- `apps/frontend/nginx.conf`: configuração do Nginx.
- `docker/mongodb/init.js`: inicialização do usuário da aplicação.
- `terraform/`: definição da infraestrutura AWS.

## 12. Limitações e escopo

Este documento descreve a arquitetura definida nos arquivos de configuração do projeto e o desenho planejado para a infraestrutura AWS.

A documentação não representa, por si só, comprovação de implantação ou validação operacional de todos os componentes.

Até o momento, não estão contempladas nesta documentação comprovações de:

- Alta disponibilidade e tolerância a falhas.
- Testes de carga e desempenho em ambiente AWS.
- Recuperação de desastre validada por restauração real.
- Execução automatizada de backups em produção.
- Configuração efetiva do bucket S3 e das permissões IAM específicas para backup.
- Validação operacional do acesso administrativo via AWS Systems Manager.