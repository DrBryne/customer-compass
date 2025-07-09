#!/bin/bash

# Set the newly created project as the active project for gcloud commands
gcloud config set project customer-compass-20250709

# Enable the Compute Engine API for the project
gcloud services enable compute.googleapis.com --project=customer-compass-20250709

# 1. Create the VPC
gcloud compute networks create cc-vpc \
  --project=customer-compass-20250709 \
  --subnet-mode=custom

# 2. Create the subnet
gcloud compute networks subnets create cc-subnet-us-central1 \
  --project=customer-compass-20250709 \
  --network=cc-vpc \
  --region=us-central1 \
  --range=10.0.1.0/24

# 3. Create the internal traffic firewall rule
gcloud compute firewall-rules create cc-allow-internal \
  --project=customer-compass-20250709 \
  --network=cc-vpc \
  --allow=tcp,udp,icmp \
  --source-ranges=10.0.1.0/24

# 4. Create the IAP firewall rule
gcloud compute firewall-rules create cc-allow-iap \
  --project=customer-compass-20250709 \
  --network=cc-vpc \
  --allow=tcp \
  --source-ranges=35.235.240.0/20

# 5. Create the Cloud Router
gcloud compute routers create cc-router \
  --project=customer-compass-20250709 \
  --network=cc-vpc \
  --region=us-central1

# 6. Create the Cloud NAT configuration
gcloud compute routers nats create cc-nat \
  --project=customer-compass-20250709 \
  --router=cc-router \
  --region=us-central1 \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips

# 7. Enable Service Networking API for VPC Peering
gcloud services enable servicenetworking.googleapis.com \
  --project=customer-compass-20250709

# 8. Create a reserved IP range for the Google services connection
gcloud compute addresses create google-managed-services-cc-vpc \
  --global \
  --purpose=VPC_PEERING \
  --addresses=10.0.2.0 \
  --prefix-length=24 \
  --network=cc-vpc \
  --project=customer-compass-20250709

# 9. Create the VPC peering connection to Google services
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-cc-vpc \
  --network=cc-vpc \
  --project=customer-compass-20250709

# 10. Enable the Serverless VPC Access API
echo "Enabling Serverless VPC Access API..."
gcloud services enable vpcaccess.googleapis.com --project=customer-compass-20250709

# 11. Create a Serverless VPC Access connector
echo "Creating VPC Access Connector..."
gcloud compute networks vpc-access connectors create cc-connector \
  --network=cc-vpc \
  --region=us-central1 \
  --range=10.8.0.0/28
