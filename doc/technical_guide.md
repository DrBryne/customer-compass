# Customer Compass: Technical Guide

## 1. Introduction

This document provides a detailed technical guide for developers working on the Customer Compass project. It covers the local development setup, architecture of each service, API specifications, database schema, and the deployment process. For a higher-level overview of the project's goals and data flow, please refer to the [design.md](./design.md) document.

## 2. High-Level Architecture

The application consists of three main components:

*   **Frontend:** A containerized React single-page application served by Nginx. It is deployed on Cloud Run and secured with Identity-Aware Proxy (IAP).
*   **Backend:** A containerized Python Flask API that provides data to the frontend. It runs on Cloud Run with internal-only ingress, accessible via the frontend.
*   **Intelligence Pipeline:** A Gen2 Cloud Function triggered by Pub/Sub messages. It orchestrates the data gathering, AI summarization, and notification process.

## 3. Local Development Setup

### Prerequisites

*   Google Cloud SDK (`gcloud`)
*   Docker & Docker Compose
*   Node.js (v18 or later)
*   Python (v3.11 or later) & `pip`

### Backend Setup

1.  **Navigate to the backend directory:**
    ```bash
    cd packages/backend
    ```
2.  **Create and activate a virtual environment:**
    ```bash
    python -m venv venv
    source venv/bin/activate
    ```
3.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
4.  **Set up environment variables:**
    Create a `.env` file in the `packages/backend` directory. You will need to set up local database credentials and point to your Google Cloud project. For full functionality, you will also need to configure Application Default Credentials for the Google Cloud libraries.
    ```
    # .env example
    FLASK_APP=app.py
    FLASK_DEBUG=1
    # Add local DB connection string if not using Cloud SQL Proxy
    ```
5.  **Run the Flask development server:**
    ```bash
    flask run --port 8080
    ```

### Frontend Setup

1.  **Navigate to the frontend directory:**
    ```bash
    cd packages/frontend
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Run the React development server:**
    ```bash
    npm start
    ```
    The frontend will start on `http://localhost:3000`. The `package.json` includes a proxy configuration (`"proxy": "http://localhost:8080"`) to forward API requests to the local backend server, avoiding CORS issues during development.

## 4. Backend (Python/Flask)

The backend is a Flask application responsible for user interactions, managing monitors, and initiating pipeline runs.

### Authentication

The backend is deployed as an internal Cloud Run service. It is protected by Identity-Aware Proxy (IAP), which is configured on the frontend. Every request to a protected endpoint must contain a JWT in the `x-goog-iap-jwt-assertion` header. The `@verify_iap_jwt` decorator in `app.py` handles the validation of this token.

### API Endpoints

| Method | Path                       | Description                                                                                             | Request Body (JSON)                                                                                                                                                           |
| :----- | :------------------------- | :------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST` | `/api/monitors`            | Creates a new monitor, saves it to the database, and publishes a message to Pub/Sub to trigger a run. | `{ "name": "string", "organizations": ["string"], "areas_of_interest": ["string"], "recency_days": integer, "schedule": "string" }`                                             |
| `GET`  | `/api/monitors`            | Retrieves a list of all monitors for the authenticated user.                                            | (None)                                                                                                                                                                        |
| `GET`  | `/api/monitors/<id>/report` | Retrieves the most recent report for a specific monitor.                                                | (None)                                                                                                                                                                        |
| `POST` | `/api/monitors/<id>/run`   | Triggers a new, on-demand run of the intelligence pipeline for a specific monitor.                      | (None)                                                                                                                                                                        |
| `DELETE`| `/api/monitors/<id>`       | Deletes a monitor and all associated data (reports, schedules, etc.).                                   | (None)                                                                                                                                                                        |

### Database Schema

The application uses a PostgreSQL database on Cloud SQL. The schema is defined in `packages/backend/schema.sql`:

```sql
-- Database schema for the Customer Compass application

-- Users are managed by IAP, but we can store their email for subscriptions
-- We don't need a full users table for now.

CREATE TABLE IF NOT EXISTS monitors (
    id SERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL, -- Email of the user who created the monitor
    name VARCHAR(255) NOT NULL,
    recency_days INTEGER NOT NULL DEFAULT 14,
    schedule VARCHAR(255), -- e.g., 'daily', 'weekly', 'monthly' or a cron expression
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_run_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS areas_of_interest (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS monitor_organizations (
    monitor_id INTEGER NOT NULL REFERENCES monitors(id) ON DELETE CASCADE,
    organization_id INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    PRIMARY KEY (monitor_id, organization_id)
);

CREATE TABLE IF NOT EXISTS monitor_areas_of_interest (
    monitor_id INTEGER NOT NULL REFERENCES monitors(id) ON DELETE CASCADE,
    area_of_interest_id INTEGER NOT NULL REFERENCES areas_of_interest(id) ON DELETE CASCADE,
    PRIMARY KEY (monitor_id, area_of_interest_id)
);

CREATE TABLE IF NOT EXISTS reports (
    id SERIAL PRIMARY KEY,
    monitor_id INTEGER NOT NULL REFERENCES monitors(id) ON DELETE CASCADE,
    summary TEXT NOT NULL,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    sources JSONB -- Store sources as a JSON array of objects, e.g., [{"title": "...", "url": "..."}]
);
```

## 5. Frontend (React)

The frontend is a standard React application created with `create-react-app`.

### Component Structure

*   `App.js`: The root component that sets up routing using `react-router-dom`.
*   `Dashboard.js`: The main landing page. It fetches and displays a list of the user's monitors.
*   `CreateMonitor.js`: A form for creating and editing monitors. It uses `rc-slider` for the recency slider and `@eidellev/react-tag-input` for tag-based input.
*   `Report.js`: Displays a generated report. It includes logic to render citations `[Source N]` as clickable links to the source articles.

## 6. Intelligence Pipeline (Cloud Function)

The core logic of the application resides in a single Python Cloud Function located in `packages/functions`.

### Trigger

The function is triggered by messages published to the `customer-compass-topic` Pub/Sub topic. The message payload is a JSON object containing the `monitor_id`.

### Execution Flow

The `run_intelligence_pipeline` function in `main.py` executes the following steps:

1.  **Get Monitor Config:** Retrieves the monitor's configuration (organizations, areas of interest, etc.) from the Cloud SQL database using the `monitor_id`.
2.  **Google Search:** Performs targeted searches using the Google Custom Search JSON API. It constructs queries by combining organizations and areas of interest.
3.  **Scrape Content:** For each search result URL, it fetches the webpage and uses `BeautifulSoup4` to parse and extract the primary text content (paragraphs).
4.  **AI Summarization:** The aggregated text from all sources is passed to the Vertex AI Gemini 1.5 Pro model. A detailed prompt instructs the model to generate a summary and provide statement-level citations for every claim.
5.  **Store Report:** The generated summary and a JSON object of the sources are stored in the `reports` table in Cloud SQL.
6.  **Send Email:** If the monitor has a schedule configured, the function uses SendGrid to send an HTML email to the user containing the summary and a link back to the full report in the web app.

## 7. Deployment

The entire application is deployed via the `scripts/deploy.sh` script.

### Deployment Script (`deploy.sh`)

The script is idempotent and automates the following processes:

1.  **Infrastructure Setup:** Calls `networking.sh` and `database.sh` to ensure the VPC, VPC Connector, and Cloud SQL instance are configured.
2.  **IAP Configuration:** Enables the IAP API and creates the necessary OAuth brand and client credentials for securing the frontend.
3.  **Pub/Sub Topic:** Creates the Pub/Sub topic used to trigger the intelligence pipeline.
4.  **Backend Deployment:** Deploys the Flask application from `packages/backend` as a containerized Cloud Run service. It injects necessary environment variables, including database credentials and the Pub/Sub topic name.
5.  **Frontend Deployment:** Deploys the React application from `packages/frontend` as a containerized Cloud Run service. It enables IAP on this service and grants the deploying user access.
6.  **Function Deployment:** Deploys the intelligence pipeline from `packages/functions` as a Gen2 Cloud Function, setting the Pub/Sub topic as the trigger and injecting required environment variables (database credentials, API keys, etc.).

### Required Secrets & Variables

The deployment script will prompt for the following secrets if they are not already set as environment variables:

*   `IAP_OAUTH_SECRET`: The secret for the IAP OAuth client.
*   `SENDGRID_API_KEY`: Your API key for SendGrid.
*   `DB_PASSWORD`: The password for the Cloud SQL database user. This is expected to be in a file at `/home/bryne/customer_compass/db_password.txt`.