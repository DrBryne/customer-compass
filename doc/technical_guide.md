# Technical Implementation Guide

This document provides a more detailed technical overview of the Customer Compass application.

## Backend (Python + Flask)

The backend is a containerized Flask application that serves a REST API. It is responsible for managing monitors, users, and reports.

### Key Libraries

*   **Flask:** The core web framework.
*   **cloud-sql-python-connector:** For secure connections to the Cloud SQL database.
*   **google-api-python-client:** To interact with Google Cloud APIs, such as Custom Search.
*   **google-cloud-aiplatform:** To interact with Vertex AI.
*   **psycopg2-binary:** PostgreSQL adapter for Python.
*   **sendgrid:** For sending email notifications.
*   **beautifulsoup4:** For web scraping.

### API Endpoints

*   `POST /api/monitors`: Creates a new monitor.
*   `GET /api/monitors`: Lists all monitors for the current user.
*   `POST /api/monitors/<monitor_id>/run`: Triggers an on-demand run of the intelligence pipeline.
*   `GET /api/monitors/<monitor_id>/report`: Retrieves the latest report for a monitor.
*   `DELETE /api/monitors/<monitor_id>`: Deletes a monitor.

## Frontend (React)

The frontend is a single-page application built with React.

### Key Libraries

*   **React:** The core UI library.
*   **React Router:** For client-side routing.
*   **axios:** For making HTTP requests to the backend API.

### Component Structure

*   **App.js:** The main component that sets up the router.
*   **Dashboard.js:** Displays a list of monitors and allows users to create new ones.
*   **CreateMonitor.js:** A form for creating a new monitor.
*   **Report.js:** Displays the latest report for a monitor.

## Deployment

The application is deployed using a set of shell scripts that automate the process of setting up the necessary infrastructure and deploying the services.

### Scripts

*   `config.sh`: Contains the project configuration.
*   `networking.sh`: Sets up the VPC and VPC Connector.
*   `database.sh`: Provisions the Cloud SQL instance.
*   `deploy.sh`: Deploys the frontend and backend services and configures IAP.
