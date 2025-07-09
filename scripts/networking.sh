#!/bin/bash

# This script provisions the necessary networking resources and is idempotent.

set -e

# Source the central configuration
source "$(dirname "$0")/config.sh"

# --- 1. Enable APIs ---
echo "Enabling required networking APIs..."
gcloud services enable compute.googleapis.com servicenetworking.googleapis.com vpcaccess.googleapis.com --project=$PROJECT_ID

# --- 2. Create VPC Network ---
echo "Checking for VPC network: default..."
if ! gcloud compute networks describe default --project=$PROJECT_ID &>/dev/null; then
  echo "Creating default VPC network..."
  gcloud compute networks create default --subnet-mode=auto --project=$PROJECT_ID
else
  echo "Default VPC network already exists."
fi

# --- 3. Create VPC Connector ---
echo "Checking for VPC Connector: $VPC_CONNECTOR..."
if ! gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR --region=$REGION --project=$PROJECT_ID &>/dev/null; then
  echo "Creating VPC Connector: $VPC_CONNECTOR..."
  gcloud compute networks vpc-access connectors create $VPC_CONNECTOR \
    --network=default \
    --region=$REGION \
    --range=10.8.0.0/28 \
    --project=$PROJECT_ID
else
  echo "VPC Connector already exists."
fi

echo "
✅ Networking setup complete."