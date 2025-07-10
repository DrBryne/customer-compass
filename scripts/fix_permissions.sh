#!/bin/bash

# This script grants the necessary IAM permissions for deploying from source to Cloud Run.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
PROJECT_ID="customer-compass-20250709"
USER_ACCOUNT="bryne@bryne.altostrat.com"

# 1. Get the Project Number from the Project ID
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

if [ -z "$PROJECT_NUMBER" ]; then
    echo "Error: Could not retrieve Project Number for Project ID: $PROJECT_ID" >&2
    exit 1
fi

# 2. Construct the full email of the service accounts
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
RUN_SA="service-${PROJECT_NUMBER}@gcp-sa-run.iam.gserviceaccount.com"


# --- Grant Permissions ---

echo "Granting permissions to Cloud Build Service Account (${CLOUD_BUILD_SA})..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${CLOUD_BUILD_SA}" --role="roles/run.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${CLOUD_BUILD_SA}" --role="roles/iam.serviceAccountUser"

# --- FIX: Grant Storage Object Admin role for GCR access ---
echo "Granting permissions to push to Google Container Registry..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${CLOUD_BUILD_SA}" --role="roles/storage.objectAdmin"


echo "Granting permissions to Compute Default Service Account (${COMPUTE_SA})..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${COMPUTE_SA}" --role="roles/storage.objectViewer"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${COMPUTE_SA}" --role="roles/logging.logWriter"



echo "Granting permissions to User Account (${USER_ACCOUNT})..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="user:${USER_ACCOUNT}" --role="roles/logging.viewer"

echo "
✅ All necessary permissions have been granted."