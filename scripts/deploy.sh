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

# --- 3. Backend Deployment ---
echo "
🚀 Deploying backend service..."

# The audience for the backend is the OAuth Client ID of the client that IAP uses.
gcloud beta run deploy $BACKEND_SERVICE \
  --project=$PROJECT_ID \
  --source=./packages/backend \
  --region=$REGION \
  --ingress=all \
  --vpc-connector=$VPC_CONNECTOR \
  --add-cloudsql-instances="$PROJECT_ID:$REGION:$SQL_INSTANCE" \
  --set-env-vars="IAP_AUDIENCE=$IAP_CLIENT_ID,PROJECT_ID=$PROJECT_ID,REGION=$REGION,SQL_INSTANCE=$SQL_INSTANCE,DB_USER=$DB_USER,DB_NAME=$DB_NAME,DB_PASS=f4So2HFUXzgVO2GTZgdabg==" \
  --iap # Replace with your DB password

# --- 4. Frontend Deployment ---
echo "
🚀 Deploying frontend service..."

gcloud run deploy $FRONTEND_SERVICE \
  --project=$PROJECT_ID \
  --source=. \
  --region=$REGION \
  --ingress=all \
  --vpc-connector=$VPC_CONNECTOR \
  --port=80 \
  --no-allow-unauthenticated

# Enable IAP for the frontend service.
gcloud beta run services update $FRONTEND_SERVICE \
  --project=$PROJECT_ID \
  --region=$REGION \
  --iap

# Grant the user permission to access the IAP-secured application.
USER_EMAIL=$(gcloud config get-value account)
gcloud run services add-iam-policy-binding $FRONTEND_SERVICE \
    --project=$PROJECT_ID \
    --region=$REGION \
    --member="user:$USER_EMAIL" \
    --role="roles/run.invoker" \
    --quiet

gcloud beta iap web add-iam-policy-binding     --project=$PROJECT_ID     --resource-type=cloud-run     --service=$FRONTEND_SERVICE     --region=$REGION     --member="user:$USER_EMAIL"     --role="roles/iap.httpsResourceAccessor"

echo "✅ Access granted to $USER_EMAIL."


echo "
🎉 Deployment complete!"

echo "
Frontend URL: $(gcloud run services describe $FRONTEND_SERVICE --project=$PROJECT_ID --region=$REGION --format='value(status.url)')"
echo "Backend URL: $(gcloud run services describe $BACKEND_SERVICE --project=$PROJECT_ID --region=$REGION --format='value(status.url)')"