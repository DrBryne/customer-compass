import os
import pg8000.dbapi
from google.cloud.sql.connector import Connector
from dotenv import load_dotenv

# Load environment variables from .env file for local development
load_dotenv()

# Initialize the Connector
connector = Connector()

def get_conn():
    """
    Function to get a database connection.
    Uses the Cloud SQL Python Connector to safely connect to the database.
    """
    conn = connector.connect(
        f"{os.environ.get('PROJECT_ID')}:{os.environ.get('REGION')}:{os.environ.get('SQL_INSTANCE')}", # Cloud SQL instance connection name
        "pg8000",
        user=os.environ.get('DB_USER'),
        password=os.environ.get('DB_PASS'), # This should be securely managed
        db=os.environ.get('DB_NAME')
    )
    return conn

def init_db_command():
    """
    A CLI command to create the database schema.
    This can be run from the command line by executing `flask init-db`.
    """
    conn = get_conn()
    cursor = conn.cursor()
    # Read the schema.sql file and execute it
    with open(os.path.join(os.path.dirname(__file__), 'schema.sql'), 'r') as f:
        cursor.execute(f.read())
    conn.commit()
    conn.close()
    print("Database schema initialized.")