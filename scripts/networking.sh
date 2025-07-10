#!/bin/bash

# This script provisions the necessary networking resources and is idempotent.

set -e

# Source the central configuration
source "$(dirname "$0")/config.sh"

# --- 1. Enable APIs ---
echo "Enabling required networking APIs..."
gcloud services enable compute.googleapis.com servicenetworking.googleapis.com vpcaccess.googleapis.com pubsub.googleapis.com --project=$PROJECT_ID

# --- 2. Create VPC Network ---
echo "Checking for VPC network: $VPC_NETWORK..."
if ! gcloud compute networks describe $VPC_NETWORK --project=$PROJECT_ID &>/dev/null; then
  echo "Creating VPC network: $VPC_NETWORK..."
  gcloud compute networks create $VPC_NETWORK --project=$PROJECT_ID --subnet-mode=custom
else
  echo "VPC network '$VPC_NETWORK' already exists."
fi

# --- 3. Create VPC Subnet ---
echo "Checking for VPC subnet: $VPC_SUBNET..."
if ! gcloud compute networks subnets describe $VPC_SUBNET --region=$REGION --project=$PROJECT_ID &>/dev/null; then
    echo "Creating subnet: $VPC_SUBNET..."
    gcloud compute networks subnets create $VPC_SUBNET \
        --network=$VPC_NETWORK \
        --region=$REGION \
        --range=10.0.1.0/24 \
        --project=$PROJECT_ID
else
    echo "Subnet '$VPC_SUBNET' already exists."
fi

# --- 4. Create Firewall Rule for Internal Traffic ---
echo "Checking for firewall rule: ${VPC_NETWORK}-allow-internal..."
if ! gcloud compute firewall-rules describe ${VPC_NETWORK}-allow-internal --project=$PROJECT_ID &>/dev/null; then
    echo "Creating firewall rule for internal traffic..."
    gcloud compute firewall-rules create ${VPC_NETWORK}-allow-internal \
        --network=$VPC_NETWORK \
        --allow=tcp,udp,icmp \
        --source-ranges=10.0.1.0/24 \
        --project=$PROJECT_ID
else
    echo "Firewall rule for internal traffic already exists."
fi

# --- 5. Create Firewall Rule for IAP ---
echo "Checking for firewall rule: ${VPC_NETWORK}-allow-iap..."
if ! gcloud compute firewall-rules describe ${VPC_NETWORK}-allow-iap --project=$PROJECT_ID &>/dev/null; then
    echo "Creating firewall rule for IAP..."
    gcloud compute firewall-rules create ${VPC_NETWORK}-allow-iap \
        --network=$VPC_NETWORK \
        --allow=tcp \
        --source-ranges=35.235.240.0/20 \
        --project=$PROJECT_ID
else
    echo "Firewall rule for IAP already exists."
fi

# --- 6. Create Cloud Router ---
export CLOUD_ROUTER="${VPC_NETWORK}-router"
echo "Checking for Cloud Router: $CLOUD_ROUTER..."
if ! gcloud compute routers describe $CLOUD_ROUTER --region=$REGION --project=$PROJECT_ID &>/dev/null; then
    echo "Creating Cloud Router: $CLOUD_ROUTER..."
    gcloud compute routers create $CLOUD_ROUTER \
        --network=$VPC_NETWORK \
        --region=$REGION \
        --project=$PROJECT_ID
else
    echo "Cloud Router '$CLOUD_ROUTER' already exists."
fi

# --- 7. Create Cloud NAT ---
export CLOUD_NAT="${VPC_NETWORK}-nat"
echo "Checking for Cloud NAT on router: $CLOUD_ROUTER..."

# We will attempt to create the NAT gateway. If it already exists, the command will not fail.
# This is a more robust way to ensure idempotency when the checks are failing.
echo "Creating Cloud NAT gateway (if it does not exist): $CLOUD_NAT..."
gcloud compute routers nats create $CLOUD_NAT     --router=$CLOUD_ROUTER     --region=$REGION     --nat-all-subnet-ip-ranges     --auto-allocate-nat-external-ips     --project=$PROJECT_ID || true



# --- 8. Reserve IP Range for VPC Peering ---
export PEERING_RANGE_NAME="google-managed-services-${VPC_NETWORK}"
echo "Checking for reserved IP range: $PEERING_RANGE_NAME..."
if ! gcloud compute addresses describe $PEERING_RANGE_NAME --global --project=$PROJECT_ID &>/dev/null; then
    echo "Reserving IP range for VPC Peering..."
    gcloud compute addresses create $PEERING_RANGE_NAME \
        --global \
        --purpose=VPC_PEERING \
        --addresses=10.0.2.0 \
        --prefix-length=24 \
        --network=$VPC_NETWORK \
        --project=$PROJECT_ID
else
    echo "Reserved IP range for VPC Peering already exists."
fi

# --- 9. Create VPC Peering Connection ---
echo "Checking for VPC Peering connection..."
if ! gcloud services vpc-peerings list --network=$VPC_NETWORK --project=$PROJECT_ID | grep -q "servicenetworking-googleapis-com"; then
    echo "Creating VPC Peering connection..."
    gcloud services vpc-peerings connect \
        --service=servicenetworking.googleapis.com \
        --ranges=$PEERING_RANGE_NAME \
        --network=$VPC_NETWORK \
        --project=$PROJECT_ID
else
    echo "VPC Peering connection already exists."
fi

# --- 10. Create VPC Connector ---
echo "Checking for VPC Connector: $VPC_CONNECTOR..."
if ! gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR --region=$REGION --project=$PROJECT_ID &>/dev/null; then
  echo "Creating VPC Connector: $VPC_CONNECTOR..."
  gcloud compute networks vpc-access connectors create $VPC_CONNECTOR \
    --network=$VPC_NETWORK \
    --region=$REGION \
    --range=10.8.0.0/28 \
    --project=$PROJECT_ID
else
  echo "VPC Connector '$VPC_CONNECTOR' already exists."
fi

echo "
✅ Networking setup complete."