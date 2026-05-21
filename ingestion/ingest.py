import os
import pandas as pd
from google.cloud import bigquery
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

PROJECT_ID = os.getenv("GCP_PROJECT_ID","ecommerce-analytics-497016")
DATASET = os.getenv("BQ_DATASET_RAW","raw")
DATA_DIR = Path(__file__).parent.parent / "data"

client = bigquery.Client(project=PROJECT_ID)

TABLES = {
    "customers":     "olist_customers_dataset.csv",
    "orders":        "olist_orders_dataset.csv",
    "order_items":   "olist_order_items_dataset.csv",
    "order_payments":"olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "products":      "olist_products_dataset.csv",
    "sellers":       "olist_sellers_dataset.csv",
    "geolocation":   "olist_geolocation_dataset.csv"
}

def load_table(table_name: str, filename: str):
    filepath = DATA_DIR / filename
    print(f"Lendo {filename}")

    df = pd.read_csv(filepath)

    print(f"{len(df):,} linhas | {list(df.columns)}")

    destination = f"{PROJECT_ID}.{DATASET}.{table_name}"

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect=True
    )

    job = client.load_table_from_dataframe(df, destination, job_config=job_config)
    job.result()

    print(f"  ✓ {table_name} carregada em {destination}\n")

def main():
    print(f"\n{'='*50}")
    print(f"Ingestão Olist → BigQuery")
    print(f"Projeto: {PROJECT_ID} | Dataset: {DATASET}")
    print(f"{'='*50}\n")
    
    for table_name, filename in TABLES.items():
        try:
            load_table(table_name, filename)
        except Exception as e:
            print(f"  ✗ Erro em {table_name}: {e}\n")
    
    print("✓ Ingestão concluída!")

if __name__ == "__main__":
    main()