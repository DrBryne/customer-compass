# Customer Compass Application

This repository contains the source code for the Customer Compass application, a tool for monitoring and analyzing public information about organizations.

## Project Structure

The repository is organized as a monorepo with the following structure:

```
customer_compass/
├── packages/
│   ├── backend/      # Flask API and backend services
│   └── frontend/     # React user interface
├── scripts/
│   ├── config.sh     # Centralized configuration
│   ├── database.sh   # Scripts for provisioning the Cloud SQL database
│   ├── networking.sh # Scripts for provisioning GCP networking resources
│   └── deploy.sh     # Deployment script
└── README.md         # This file
```

- **`/packages`**: Contains the individual, deployable applications.
  - **`backend`**: A Python Flask application that serves the API.
  - **`frontend`**: A React application for the user interface.

- **`/scripts`**: Contains shell scripts for setting up the necessary Google Cloud infrastructure and deploying the application.

## Getting Started

### Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and configured.
- [Docker](https://docs.docker.com/get-docker/) installed.
- An active Google Cloud project.

### Configuration

1.  Open the `scripts/config.sh` file and update the `PROJECT_ID` and other variables to match your environment.
2.  **Important:** The `deploy.sh` script will prompt you to set a database password. For production environments, it is highly recommended to use [Google Secret Manager](https://cloud.google.com/secret-manager) to manage the database password.

### Deployment

To deploy the application, run the following command from the root of the `customer_compass` directory:

```bash
./scripts/deploy.sh
```

This script will:

1.  Provision the necessary networking resources (VPC, VPC Connector).
2.  Provision the Cloud SQL instance, database, and user.
3.  Deploy the backend and frontend services to Cloud Run.
4.  Configure Identity-Aware Proxy (IAP) to secure the application.
5.  Grant your user account access to the application.

### Database Initialization

After the initial deployment, you need to initialize the database schema. You can do this by running the following command:

```bash
flask --app packages/backend/app.py init-db
```