#!/bin/bash

# --- Project Configuration ---
# This file contains the central configuration for the Customer Compass application.
# All scripts in this project will source this file to ensure consistency.

# GCP Project Settings
export PROJECT_ID="customer-compass-20250709"
export REGION="us-central1"

# Cloud SQL Database Settings
export SQL_INSTANCE="cc-db-instance"
export DB_USER="customer_compass_user"
export DB_NAME="customer_compass_db"
# Note: The database password should be managed securely, for example, using Secret Manager.
# For this example, we'll generate a random password during setup.

# Cloud Run Service Names
export FRONTEND_SERVICE="cc-frontend"
export BACKEND_SERVICE="cc-backend"

# VPC Connector for Serverless
export VPC_CONNECTOR="cc-connector"

# IAP OAuth Client (will be created during deployment)
export IAP_CLIENT_ID=""
