# Estimativa mensal de custos AWS — KubeShop PM04

**Data de referência:** 27/11/2026  
**Responsável:** João Pedro Foster Ruiz  
**Região:** us-east-1 (Norte da Virgínia)

## 1. Objetivo e escopo

Estimar o custo recorrente da arquitetura definida em Terraform e da integração prevista de backup MongoDB em Amazon S3. Este documento não representa uma fatura nem comprovação de implantação. A estimativa do colega, de US$ 74/mês, é utilizada como referência comparativa.

## 2. Premissas

- 730 horas mensais, duas EC2 t3.small Linux On-Demand, Ubuntu 24.04, tenancy compartilhada.
- Uma zona de disponibilidade (us-east-1a), aplicação pública e MongoDB privado.
- Três volumes gp3: 12 + 12 + 20 = 44 GiB, com desempenho básico incluído.
- Um NAT Gateway público e dois IPv4 públicos: aplicação e Elastic IP do NAT.
- 10 GB/mês de processamento NAT total, incluindo tráfego de backup, recuperação e manutenção.
- S3 Standard na mesma região, 10 GB-mês de armazenamento médio, incluindo versões retidas; 30 backups diários por mês, com manifesto separado.
- 60 objetos enviados, 60 consultas HEAD, 20 GET adicionais e margem de 1000 requisições PUT/COPY/POST/LIST e 8300 GET/HEAD no total para estimativa conservadora de tráfego de API, conforme detalhado abaixo.
- Tráfego para internet de até 100 GB/mês, supondo franquia agregada da conta integralmente disponível.
- Sem créditos promocionais, contratos de desconto, impostos, conversão cambial ou cobrança extra por CPU, IOPS ou throughput.

## 3. Recursos e memória de cálculo

| Recurso | Cálculo | US$/mês |
|---|---|---:|
| EC2 aplicação | 730 × 0,0208 | 15,184 |
| EC2 banco | 730 × 0,0208 | 15,184 |
| EBS raiz aplicação | 12 × 0,08 | 0,96 |
| EBS raiz banco | 12 × 0,08 | 0,96 |
| EBS dados MongoDB | 20 × 0,08 | 1,60 |
| NAT Gateway | 730 × 0,045 | 32,85 |
| IPv4 aplicação | 730 × 0,005 | 3,65 |
| Elastic IP NAT | 730 × 0,005 | 3,65 |
| **Subtotal fixo** | | **74,038** |
| Processamento NAT | 10 × 0,045 | 0,45 |
| S3 Standard | 10 × 0,023 | 0,23 |
| Requisições S3 | 1000 × 0,005/1000 + 8300 × 0,0004/1000 | 0,00832 |
| Transferência internet | Dentro da franquia disponível | 0,00 |
| **Total mensal** | | **74,72632** |

Total arredondado: **US$ 74,73/mês**. Total anual, mantendo o cenário constante: **US$ 896,72** (calculado sem arredondamentos intermediários).

## 4. Computação e armazenamento

Cada t3.small possui 2 vCPUs e 2 GiB de RAM. As duas instâncias somam US$ 30,368/mês. O volume de dados MongoDB é dedicado e criptografado. Os 44 GiB de EBS somam US$ 3,52/mês, supondo gp3 e desempenho básico de 3000 IOPS e 125 MiB/s por volume. Volumes continuam cobrados enquanto provisionados, mesmo com EC2 desligadas. Snapshots EBS não estão incluídos. Créditos excedentes de CPU T3 Unlimited para Linux podem custar US$ 0,05 por vCPU-hora.

## 5. Rede e transferência

O NAT Gateway custa US$ 32,85/mês apenas por disponibilidade, mais US$ 0,045 por GB processado. Seu Elastic IP custa outros US$ 3,65/mês. O segundo IPv4 corresponde à EC2 pública; o banco não possui IPv4 público. VPC, sub-redes, tabelas de rota, Security Groups e Internet Gateway não recebem cobrança fixa própria neste cenário.

A comunicação aplicação–banco por IP privado na mesma AZ não gera tarifa de transferência EC2 inter-AZ. Transferência direta EC2–S3 na mesma região não tem tarifa de transferência própria, mas o caminho pelo NAT gera cobrança de processamento. A entrada de dados da internet é gratuita no cenário usual; saída acima da franquia agregada disponível de 100 GB/mês custa US$ 0,09/GB na primeira faixa paga. O NAT contabiliza bytes processados em ambos os sentidos. Não confundir processamento NAT com transferência para internet.

## 6. Backup S3

O S3 é uma integração prevista, não um recurso provisionado e validado. A política proposta é backup lógico diário, retenção de 30 dias, bucket privado e SSE-S3. Cada execução gera um archive gzip e um manifesto JSON com SHA-256. A restauração isolada foi validada localmente; consultar [Backup e restauração](backup-e-restauracao.md).

A capacidade de 10 GB-mês é uma hipótese orçamentária, não tamanho medido. Com 30 arquivos diários de aproximadamente 333 MB e retenção efetiva de 30 dias, o armazenamento em regime estável seria próximo de 10 GB, sem contar versões adicionais. O custo depende do tamanho compactado real, retenção, versões não atuais e requisições. A margem de requisições adotada excede o mínimo de 60 PUT e 60 HEAD mensais: 1000 operações da classe PUT e 8300 da classe GET/HEAD, totalizando US$ 0,00832. Uploads multipart podem elevar o número de operações. SSE-S3 não acrescenta cobrança KMS. A política lifecycle deverá expirar também versões não atuais quando aplicável.

## 7. Comparação e cenários

A diferença em relação aos US$ 74 informados pelo colega é de US$ 0,73 (aproximadamente 0,98%, ou 0,99% com o total mensal arredondado). O subtotal fixo de US$ 74,04 explica a proximidade; não se conhece a memória de cálculo original do colega.

| Cenário | NAT GB | S3 GB-mês | Saída internet GB | Total US$/mês |
|---|---:|---:|---:|---:|
| Fixo, sem backups/tráfego | 0 | 0 | 0 | 74,04 |
| Referência | 10 | 10 | 20 | 74,73 |
| Crescimento | 50 | 30 | 200 | 86,99 |
| Uso elevado | 200 | 100 | 500 | 121,35 |

Cenários com S3 incluem a margem de requisições de US$ 0,00832; assumem 100 GB de franquia de saída disponíveis. Valores calculados com o subtotal não arredondado.

## 8. Otimização

- O NAT Gateway é o maior item isolado: aproximadamente 44% do total de referência. Um S3 Gateway VPC Endpoint não tem cobrança adicional própria e pode evitar processamento NAT para tráfego S3; não elimina sozinho o custo fixo do NAT utilizado por outros destinos.
- Ajustar retenção S3 e acompanhar o tamanho dos backups; usar métricas de faturamento para confirmar os volumes reais.
- Avaliar desligamento das EC2 fora dos horários acadêmicos, sem comprometer a disponibilidade e os backups. EBS, Elastic IP do NAT e NAT Gateway continuam cobrados enquanto provisionados; um IPv4 público automático da EC2 normalmente é liberado ao parar a instância.
- Configurar AWS Budgets e alertas de custo. Avaliar dimensionamento após medir CPU e memória. Não alterar a arquitetura sem aprovação da equipe.

## 9. Limitações

Não foram incluídos impostos, câmbio, snapshots EBS, créditos excedentes de CPU, desempenho adicional EBS, logs/monitoramento pagos, serviços adicionais, custos de pipeline, recuperação de desastre ou tráfego fora das hipóteses. SSM básico e IAM não receberam custo adicional neste modelo; funcionalidades avançadas podem gerar cobranças. Não há redundância multi-AZ no cenário. O custo real depende da duração do mês e do consumo. Confirmar os preços e a configuração efetivamente implantada no AWS Pricing Calculator e na fatura.

## 10. Referências

Consultadas em 27/11/2026:

- [AWS EC2 On-Demand](https://aws.amazon.com/ec2/pricing/on-demand/) — computação, transferência e créditos CPU.
- [CloudRoute — tabela EC2 baseada no AWS Price List, novembro de 2026](https://www.cloudroutehq.com/aws/ec2-pricing) — preço t3.small Linux us-east-1.
- [AWS EBS Pricing](https://aws.amazon.com/ebs/pricing/) e [tipos EBS](https://aws.amazon.com/ebs/volume-types/) — gp3.
- [AWS VPC Pricing](https://aws.amazon.com/vpc/pricing/) e [documentação EC2 sobre IPv4](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-instance-addressing.html) — NAT e IPv4.
- [AWS S3 Pricing](https://aws.amazon.com/s3/pricing/) — armazenamento e requisições; valores de referência também publicados em [Cloud Cost Calculator](https://cloudcostcalc.vercel.app/regions/us-east-1) e [Loams](https://greenhouse.loams.dev/cost).
- [AWS Pricing Calculator](https://calculator.aws/).

## 11. Conclusão

O orçamento mensal de referência é US$ 74,73, próximo dos US$ 74 estimados pelo colega. O custo fixo é US$ 74,04 e o restante corresponde a hipóteses de uso de NAT e S3. Recomenda-se validar o orçamento com os recursos realmente implantados e monitorar o consumo após a integração de backup. Nenhum recurso da infraestrutura foi alterado para elaborar esta estimativa.
