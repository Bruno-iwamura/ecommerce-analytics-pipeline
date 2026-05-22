# E-commerce Analytics Pipeline

Pipeline de dados end-to-end para análise de e-commerce brasileiro, construído com o Modern Data Stack. Utiliza o dataset público da Olist com +100k pedidos reais.

![dbt CI](https://github.com/Bruno-iwamura/ecommerce-analytics-pipeline/actions/workflows/dbt_ci.yml/badge.svg)

## Dashboard

🔗 [Acessar dashboard no Looker Studio](https://datastudio.google.com/reporting/8cd10c01-3713-4e05-8d14-fadd3fa5d58c)

Métricas disponíveis:
- Receita bruta diária e volume de pedidos
- Taxa de entrega no prazo ao longo do tempo
- Top 10 categorias de produto por receita
- Segmentação de clientes por LTV (high / mid / low)
- KPIs: total de pedidos, receita total, ticket médio

## Arquitetura

Olist CSV → Python ingest.py → BigQuery (raw) → dbt (staging → marts) → Looker Studio

## Stack

| Camada | Tecnologia |
|---|---|
| Ingestão | Python + google-cloud-bigquery |
| Data Warehouse | Google BigQuery |
| Transformação | dbt Core + dbt-bigquery |
| Visualização | Looker Studio |
| CI/CD | GitHub Actions + Workload Identity Federation |
| Autenticação | Application Default Credentials (ADC) |

## Estrutura do projeto

ecommerce-analytics-pipeline/
├── .github/workflows/
│   └── dbt_ci.yml          # CI/CD — roda dbt build em todo PR
├── ingestion/
│   ├── ingest.py            # Carga dos CSVs da Olist no BigQuery
│   └── requirements.txt
├── dbt/ecommerce/
│   ├── models/
│   │   ├── staging/         # 7 modelos — limpeza e padronização
│   │   └── marts/           # 4 modelos — métricas de negócio
│   └── dbt_project.yml
└── README.md

## Modelos dbt

### Staging (views)
| Modelo | Fonte | Descrição |
|---|---|---|
| stg_orders | raw.orders | Pedidos com timestamps padronizados |
| stg_customers | raw.customers | Clientes com colunas renomeadas |
| stg_order_items | raw.order_items | Itens de pedido com preços |
| stg_order_payments | raw.order_payments | Pagamentos por pedido |
| stg_order_reviews | raw.order_reviews | Avaliações dos clientes |
| stg_products | raw.products | Catálogo de produtos |
| stg_sellers | raw.sellers | Vendedores cadastrados |

### Marts (tables)
| Modelo | Descrição |
|---|---|
| mart_orders_daily | Volume e receita de pedidos por dia |
| mart_customer_ltv | Lifetime value e segmentação de clientes |
| mart_delivery_performance | Taxa de entrega no prazo por dia |
| mart_product_revenue | Receita e volume de vendas por categoria |

## Qualidade de dados

44 testes automatizados cobrindo:
- Unicidade e not_null em todas as chaves primárias
- Valores aceitos em campos categóricos (order_status, review_score, ltv_segment)
- Integridade referencial entre modelos

## CI/CD

Todo Pull Request para `main` dispara automaticamente:
1. Instalação do dbt no ambiente Ubuntu
2. Autenticação no GCP via Workload Identity Federation (sem chave JSON)
3. `dbt build` — compila, executa e testa todos os modelos
4. PR bloqueado se qualquer teste falhar

## Como rodar localmente

### Pré-requisitos
- Python 3.11+
- gcloud CLI autenticado (`gcloud auth application-default login`)
- Acesso ao projeto GCP `ecommerce-analytics-497016`

### Instalação

```bash
python -m venv .venv
.venv\Scripts\activate  # Windows
pip install -r ingestion/requirements.txt
pip install dbt-core dbt-bigquery
```

### Ingestão

```bash
python ingestion/ingest.py
```

### Transformação

```bash
cd dbt/ecommerce
dbt build
```

### Documentação

```bash
dbt docs generate
dbt docs serve
```

## Dataset

[Brazilian E-Commerce (Olist)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — dataset público com +100k pedidos reais de e-commerce brasileiro (2016-2018).

## Próximos passos

- [ ] Fase 7 — Airbyte conectando PostgreSQL ou Salesforce como fonte real
- [ ] Camada intermediate no dbt para lógica de negócio reutilizável
- [ ] Orquestração com Airflow ou BigQuery Scheduled Queries

## Decisões técnicas e desafios

### Autenticação sem chave JSON
A organização Google associada à conta bloqueava a criação de chaves JSON para service accounts — uma política de segurança corporativa comum. A solução foi usar **Application Default Credentials (ADC)** localmente via `gcloud auth application-default login`, e **Workload Identity Federation** no CI/CD. Essa abordagem é inclusive a recomendada pelo Google: sem arquivos de credencial estáticos, sem risco de vazamento. O que começou como uma restrição virou uma escolha de segurança melhor.

### Workload Identity Federation no CI/CD
Em vez de guardar uma chave JSON como secret no GitHub, configuramos o GCP para aceitar tokens OIDC temporários gerados pelo GitHub Actions. O token é válido apenas para aquela execução específica, do repositório específico. Mais seguro e sem segredos de longa duração para gerenciar.

### Python 3.13 + dbt
O dbt historicamente tinha problemas de compatibilidade com versões muito recentes do Python. Optamos por instalar e validar antes de prosseguir — a versão 1.11.1 do dbt-bigquery se mostrou compatível com Python 3.13 sem erros.

### ADC no terminal do VS Code vs PATH do sistema
O gcloud CLI é instalado no PATH do sistema operacional, não dentro do virtualenv do projeto. Por isso comandos como `gcloud` e `bq` funcionam no CMD/PowerShell do Windows mas não no terminal integrado do VS Code com o venv ativo. Solução adotada: comandos de infraestrutura (`gcloud`, `bq`) rodam no CMD, comandos do projeto (`python`, `dbt`) rodam no terminal do VS Code com venv ativo.

### PowerShell vs CMD para comandos gcloud
O PowerShell interpreta parênteses em argumentos como expressões de código, causando erros em comandos como `--format="value(name)"` e redirecionando outputs para arquivos. Todos os comandos `gcloud` com parênteses foram executados no CMD para evitar esse problema.

### Dados nulos em gross_revenue
Durante os testes do `mart_orders_daily`, o dbt identificou uma linha com `gross_revenue` nulo — pedidos sem pagamento associado no dataset, o que ocorre com pedidos nos status `created` ou `processing`. A decisão foi usar `coalesce(sum(amount), 0)` para tratar esses casos como receita zero, documentando explicitamente no código que a ausência de pagamento é um estado válido, não um dado faltante.

### Looker Studio vs Tableau/Power BI
O Looker Studio foi escolhido por ser gratuito e ter conector nativo com BigQuery — sem exportar dados, sem configuração de gateway. A limitação real é a flexibilidade de layout e interatividade, inferior ao Tableau e Power BI. Para um projeto de portfólio demonstrando o pipeline de dados, o Looker Studio cumpre o papel. Em produção com budget disponível, Looker (pago) ou Metabase self-hosted seriam opções mais robustas.

### Filtro de data global no Looker Studio
Tentamos adicionar um controle de intervalo de datas global conectado a todas as fontes. O Looker Studio apresentou conflitos quando múltiplas fontes de dados com campos de data diferentes estavam no mesmo relatório. A solução foi remover o filtro global e deixar cada gráfico com seu próprio período padrão configurado — tradeoff entre simplicidade e interatividade.