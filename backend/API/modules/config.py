import os 
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

SENDGRID_API_KEY = os.getenv('SENDGRID_API_KEY')
MAIL_FROM_ADDRESS = os.getenv('MAIL_FROM_ADDRESS')

if SENDGRID_API_KEY is None:
    raise ValueError("La API Key de SendGrid no está definida en el archivo .env.")

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    LOCAL_USER = os.getenv("DB_USER", "admin")
    LOCAL_PASSWORD = os.getenv("DB_PASSWORD", "admin123")
    LOCAL_HOST = os.getenv("DB_HOST", "db")
    LOCAL_PORT = os.getenv("DB_PORT", "5432")
    LOCAL_NAME = os.getenv("DB_NAME", "placas_db")

    DATABASE_URL = f"postgresql+psycopg2://{LOCAL_USER}:{LOCAL_PASSWORD}@{LOCAL_HOST}:{LOCAL_PORT}/{LOCAL_NAME}"
else:
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg2://", 1)

engine = create_engine(DATABASE_URL, echo=False, future=True)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

Base = declarative_base()