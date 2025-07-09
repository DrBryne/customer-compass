# 1. Executive Summary

Project "Customer Compass" is a web-based intelligence tool designed to empower Google Cloud sales professionals. It provides proactive, curated, and timely public information about their customers. By specifying organizations and areas of interest (e.g., AI strategy, cloud adoption, financial health), salespeople receive AI-generated summaries with pinpoint, statement-level citations. The platform supports both on-demand searches and scheduled email subscriptions, ensuring the sales team is always equipped with the latest, most relevant customer insights. The entire solution is designed to be secure, scalable, and run exclusively on Google Cloud.

# 2. Data Flow & Logic

The system operates based on two primary workflows that both leverage the same core intelligence pipeline: an on-demand search and a scheduled search.

### Workflow 1: On-Demand Search

*   **User Interaction:** A salesperson logs into the web app and defines a "Monitor" by specifying:
    *   **Organizations:** "Acme Corp," "Global Tech Inc."
    *   **Areas of Interest:** "AI adoption, sustainability initiatives, Q2 financial results."
    *   **Recency:** "Last 14 days."
*   **API Request & Trigger:** The frontend sends this configuration to the backend API on Cloud Run. The backend saves the monitor configuration to Cloud SQL and immediately publishes a message to a Pub/Sub topic to trigger the intelligence pipeline. This message contains the ID of the newly created "Monitor."
*   **Pipeline Execution:** A Cloud Function, subscribed to this Pub/Sub topic, is triggered. It retrieves the "Monitor" configuration from Cloud SQL.
*   **Information Gathering:**
    *   The pipeline uses the Google Custom Search JSON API to perform targeted queries. Example queries could be:
        *   `"Acme Corp" "AI adoption" after:YYYY-MM-DD`
        *   `"Global Tech Inc." "sustainability report" after:YYYY-MM-DD`
    *   For each search result (URL), a separate function scrapes the primary text content from the page. All results are aggregated.
*   **AI Summarization & Citation Engine (Vertex AI):** The aggregated text is passed to the Gemini 1.5 Pro model with a meticulously crafted prompt to generate a summary with citations.
*   **Store & Display:** The backend function stores the summary and the source-to-URL mapping in the Cloud SQL database and returns the formatted result to the frontend for immediate display.

### Workflow 2: Scheduled Search & Email

*   **User Subscription:** The user creates a "Monitor" as above but also specifies a schedule (e.g., "Weekly on Mondays") and opts-in for email notifications. This schedule is saved as a Cloud Scheduler job.
*   **Scheduled Trigger:** At the specified time, Cloud Scheduler publishes a message to the same Pub/Sub topic used by the on-demand flow. The message payload contains the ID of the "Monitor" to be executed.
*   **Pipeline Execution:** The same Cloud Function is triggered, retrieving the monitor's configuration from Cloud SQL.
*   **Processing:** The same information gathering and AI summarization steps (4-5 from the on-demand flow) are executed.
*   **Store & Notify:**
    *   The new summary is stored in Cloud SQL.
    *   The orchestrator function then uses a service like SendGrid to format the summary into a clean HTML email and send it to the subscribed user. The email contains the summary and links back to the full report within the web application.

# 3. User Interface & Experience (UI/UX) Concepts

### Dashboard
Upon logging in, the user sees a dashboard of their existing "Monitors." Each card shows the organization, key interests, and the timestamp of the last run, with a "View Latest" button.

### Create/Edit Monitor Page
A user-friendly form to:
*   Add/remove organizations.
*   Add/remove areas of interest (using a tag-based input field).
*   Set the recency period with a slider or dropdown (e.g., 7, 14, 30, 90 days).
*   Configure the email subscription schedule using simple presets (Daily, Weekly, Monthly).

### Results Page
*   Displays the organization name and the date range of the search.
*   Presents the summary in a clean, readable format.
*   Each citation `[Source N]` is an interactive, clickable link that opens the source article in a new tab.
*   A "Sources" section at the bottom lists all referenced articles with their titles and URLs.

# 4. High-Level Architecture

The Customer Compass application is designed as a cloud-native, serverless web application running entirely on Google Cloud. The architecture is split into a frontend, a backend API, and a serverless intelligence pipeline.

**Frontend:**
*   **Framework:** React with React Router.
*   **Hosting:** Deployed as a containerized application on Cloud Run.
*   **Authentication:** Secured using Identity-Aware Proxy (IAP).

**Backend API:**
*   **Framework:** Python with Flask, providing a RESTful API.
*   **Hosting:** Deployed as a containerized application on Cloud Run.
*   **Database:** Cloud SQL for PostgreSQL to store monitor configurations, generated reports, and user data.

**Intelligence Pipeline:**
*   **Orchestration:** A single Pub/Sub topic receives messages to trigger report generation. Cloud Scheduler pushes messages to this topic for scheduled runs, and the Backend API pushes messages for on-demand runs.
*   **Core Logic:** A Cloud Function (Python) is subscribed to the Pub/Sub topic. This function is responsible for:
    *   Fetching data from the Google Custom Search API.
    *   Scraping and parsing web content.
    *   Using the Vertex AI Gemini API to generate summaries.
    *   Storing results in Cloud SQL.
*   **Email Notifications:** The Cloud Function uses SendGrid to send email notifications to users with the generated reports.
