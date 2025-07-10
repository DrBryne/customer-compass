#!/bin/bash

# This script deploys the entire Customer Compass application and is idempotent.

set -e

# Source the central configuration
source "$(dirname "$0")/config.sh"

# --- 1. Infrastructure Setup ---
echo "Setting up infrastructure..."
"$(dirname "$0")/networking.sh"
"$(dirname "$0")/database.sh"

# --- 2. IAP Configuration ---
echo "
🔒 Configuring IAP..."

# Enable the IAP API
gcloud services enable iap.googleapis.com --project=$PROJECT_ID

# Get the OAuth brand. If it doesn't exist, create one.
BRAND=$(gcloud alpha iap oauth-brands list --project=$PROJECT_ID --format='value(name)' | head -n 1)
if [ -z "$BRAND" ]; then
  echo "Creating a new OAuth brand..."
  SUPPORT_EMAIL=$(gcloud config get-value account)
  gcloud alpha iap oauth-brands create --application_title="Customer Compass" --support_email=$SUPPORT_EMAIL --project=$PROJECT_ID
  BRAND=$(gcloud alpha iap oauth-brands list --project=$PROJECT_ID --format='value(name)' | head -n 1)
fi

# Create a new OAuth 2.0 client ID for IAP.
echo "Creating a new OAuth client..."
CLIENT_NAME=$(gcloud alpha iap oauth-clients create "$BRAND" --display_name="Customer Compass IAP" --format='value(name)')
export IAP_CLIENT_ID=$(basename $CLIENT_NAME)

echo "✅ IAP OAuth Client created with ID: $IAP_CLIENT_ID"

# --- 3. Create Pub/Sub Topic ---
echo "
Pub/Sub Topic..."
if ! gcloud pubsub topics describe $PUBSUB_TOPIC --project=$PROJECT_ID &>/dev/null; then
  echo "Creating Pub/Sub topic: $PUBSUB_TOPIC..."
  gcloud pubsub topics create $PUBSUB_TOPIC --project=$PROJECT_ID
else
  echo "Pub/Sub topic already exists."
fi

# --- 4. Backend Deployment ---
echo "
🚀 Deploying backend service..."

DB_PASSWORD=$(cat /home/bryne/customer_compass/db_password.txt)

(cd /home/bryne/customer_compass/packages/backend && gcloud beta run deploy $BACKEND_SERVICE \
  --project=$PROJECT_ID \
  --source=. \
  --region=$REGION \
  --ingress=internal \
  --vpc-connector=$VPC_CONNECTOR \
  --add-cloudsql-instances="$PROJECT_ID:$REGION:$SQL_INSTANCE" \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION,SQL_INSTANCE=$SQL_INSTANCE,DB_USER=$DB_USER,DB_NAME=$DB_NAME,DB_PASS=$DB_PASSWORD,TOPIC_ID=$PUBSUB_TOPIC" \
  --no-allow-unauthenticated)

# --- 5. Frontend Deployment ---
echo "
🚀 Deploying frontend service..."

BACKEND_URL=$(gcloud run services describe $BACKEND_SERVICE --project=$PROJECT_ID --region=$REGION --format='value(status.url)')
sed -i "s|__BACKEND_URL__|$BACKEND_URL|g" /home/bryne/customer_compass/packages/frontend/nginx.conf

(cd /home/bryne/customer_compass/packages/frontend && gcloud run deploy $FRONTEND_SERVICE \
  --project=$PROJECT_ID \
  --source=. \
  --region=$REGION \
  --ingress=all \
  --port=80 \
  --no-allow-unauthenticated)

# Enable IAP for the frontend service.
if [ -z "$IAP_OAUTH_SECRET" ]; then
  read -p "Enter your IAP OAuth Client Secret: " IAP_OAUTH_SECRET
fi
gcloud beta run services update $FRONTEND_SERVICE \
  --project=$PROJECT_ID \
  --region=$REGION \
  --iap=oauth2-client-id=$IAP_CLIENT_ID,oauth2-client-secret=$IAP_OAUTH_SECRET

# Grant the user permission to access the IAP-secured application.
USER_EMAIL=$(gcloud config get-value account)
gcloud run services add-iam-policy-binding $FRONTEND_SERVICE \
    --project=$PROJECT_ID \
    --region=$REGION \
    --member="user:$USER_EMAIL" \
    --role="roles/run.invoker" \
    --quiet

gcloud beta iap web add-iam-policy-binding \
    --project=$PROJECT_ID \
    --resource-type=cloud-run \
    --service=$FRONTEND_SERVICE \
    --region=$REGION \
    --member="user:$USER_EMAIL" \
    --role="roles/iap.httpsResourceAccessor"

echo "✅ Access granted to $USER_EMAIL."

# --- 6. Functions Deployment ---
echo "
🚀 Deploying functions..."

if [ -z "$SENDGRID_API_KEY" ]; then
  read -p "Enter your SendGrid API Key: " SENDGRID_API_KEY
fi

FRONTEND_URL_FOR_FUNCTION=$(gcloud run services describe $FRONTEND_SERVICE --project=$PROJECT_ID --region=$REGION --format='value(status.url)')

(cd /home/bryne/customer_compass/packages/functions && gcloud functions deploy $FUNCTION_NAME \
  --gen2 \
  --runtime=python312 \
  --project=$PROJECT_ID \
  --region=$REGION \
  --source=. \
  --entry-point=run_intelligence_pipeline \
  --trigger-topic=$PUBSUB_TOPIC \
  --vpc-connector=$VPC_CONNECTOR \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION,SQL_INSTANCE=$SQL_INSTANCE,DB_USER=$DB_USER,DB_NAME=$DB_NAME,DB_PASS=$DB_PASSWORD,SENDER_EMAIL=$SENDER_EMAIL,SENDGRID_API_KEY=$SENDGRID_API_KEY,FRONTEND_URL=$FRONTEND_URL_FOR_FUNCTION")

echo "
🎉 Deployment complete!"

FRONTEND_URL=$(gcloud run services describe $FRONTEND_SERVICE --project=$PROJECT_ID --region=$REGION --format='value(status.url)')
BACKEND_URL=$(gcloud run services describe $BACKEND_SERVICE --project=$PROJECT_ID --region=$REGION --format='value(status.url)')

echo "
Frontend URL: $FRONTEND_URL"
echo "Backend URL: $BACKEND_URL"
