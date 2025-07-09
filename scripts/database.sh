#!/bin/bash

# This script provisions the Cloud SQL database and is idempotent.

set -e

# Source the central configuration
source "$(dirname "$0")/config.sh"

# --- 1. Enable APIs ---
echo "Enabling Cloud SQL Admin API..."
gcloud services enable sqladmin.googleapis.com --project=$PROJECT_ID

# --- 2. Provision Cloud SQL Instance ---
echo "Checking for Cloud SQL instance: $SQL_INSTANCE..."
if ! gcloud sql instances describe $SQL_INSTANCE --project=$PROJECT_ID &>/dev/null; then
  echo "Creating Cloud SQL instance: $SQL_INSTANCE..."
  gcloud sql instances create $SQL_INSTANCE \
    --database-version=POSTGRES_15 \
    --region=$REGION \
    --cpu=1 \
    --memory=4GiB \
    --project=$PROJECT_ID
else
  echo "Cloud SQL instance already exists."
fi

# --- 3. Assign Public IP ---
echo "Assigning public IP to Cloud SQL instance..."
gcloud sql instances patch $SQL_INSTANCE --assign-ip --project=$PROJECT_ID

# --- 4. Create Database User ---
echo "Checking for database user: $DB_USER..."
if ! gcloud sql users list --instance=$SQL_INSTANCE --project=$PROJECT_ID | grep -q "^$DB_USER "; then
  echo "Creating database user: $DB_USER..."
  # In a production environment, use a strong, randomly generated password from a secret store.
  DB_PASSWORD=$(openssl rand -base64 16)
  echo $DB_PASSWORD > /home/bryne/customer_compass/db_password.txt
  gcloud sql users create $DB_USER \
    --instance=$SQL_INSTANCE \
    --password="$DB_PASSWORD" \
    --project=$PROJECT_ID
  echo "NOTE: The user password should be stored securely (e.g., in Secret Manager)."
else
  echo "Database user already exists."
fi

# --- 5. Create Database ---
echo "Checking for database: $DB_NAME..."
if ! gcloud sql databases describe $DB_NAME --instance=$SQL_INSTANCE --project=$PROJECT_ID &>/dev/null; then
  echo "Creating database: $DB_NAME..."
  gcloud sql databases create $DB_NAME \
    --instance=$SQL_INSTANCE \
    --project=$PROJECT_ID
else
  echo "Database already exists."
fi

echo "
✅ Database setup complete."
