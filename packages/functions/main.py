import os
import json
import base64
import requests
from bs4 import BeautifulSoup
from googleapiclient.discovery import build
import vertexai
from vertexai.generative_models import GenerativeModel
from google.cloud.sql.connector import Connector
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

# --- Environment Variables ---
CUSTOM_SEARCH_API_KEY = os.environ.get('CUSTOM_SEARCH_API_KEY')
CUSTOM_SEARCH_ENGINE_ID = os.environ.get('CUSTOM_SEARCH_ENGINE_ID')
VERTEXAI_PROJECT_ID = os.environ.get('VERTEXAI_PROJECT_ID')
VERTEXAI_LOCATION = os.environ.get('VERTEXAI_LOCATION')
SENDGRID_API_KEY = os.environ.get('SENDGRID_API_KEY')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL')
DB_USER = os.environ.get("DB_USER")
DB_PASS = os.environ.get("DB_PASS")
DB_NAME = os.environ.get("DB_NAME")
SQL_INSTANCE = os.environ.get("SQL_INSTANCE")
PROJECT_ID = os.environ.get("PROJECT_ID")
REGION = os.environ.get("REGION")

# --- Cloud SQL Connector ---
connector = Connector()

def get_conn():
    """Returns a database connection object."""
    conn = connector.connect(
        f"{PROJECT_ID}:{REGION}:{SQL_INSTANCE}",
        "pg8000",
        user=DB_USER,
        password=DB_PASS,
        db=DB_NAME
    )
    return conn

# --- Main Cloud Function ---

def run_intelligence_pipeline(event, context):
    """
    Triggered from a message on a Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_data = json.loads(pubsub_message)
    monitor_id = message_data['monitor_id']
    
    conn = get_conn()
    cursor = conn.cursor()

    # 1. Get monitor configuration
    cursor.execute("SELECT user_id, recency_days, schedule FROM monitors WHERE id = %s", (monitor_id,))
    user_id, recency_days, schedule = cursor.fetchone()

    cursor.execute("SELECT email FROM users WHERE id = %s", (user_id,))
    user_email = cursor.fetchone()[0]

    cursor.execute("SELECT o.name FROM organizations o JOIN monitor_organizations mo ON o.id = mo.organization_id WHERE mo.monitor_id = %s", (monitor_id,))
    organizations = [row[0] for row in cursor.fetchall()]

    cursor.execute("SELECT a.name FROM areas_of_interest a JOIN monitor_areas_of_interest ma ON a.id = ma.area_of_interest_id WHERE ma.monitor_id = %s", (monitor_id,))
    areas_of_interest = [row[0] for row in cursor.fetchall()]

    # 2. Information Gathering
    search_results = _google_search(organizations, areas_of_interest, recency_days)
    if not search_results:
        print(f"No search results found for monitor {monitor_id}. Exiting.")
        return

    scraped_content = _scrape_articles(search_results)

    # 3. AI Summarization
    summary = _summarize_with_gemini(organizations, areas_of_interest, scraped_content)

    # 4. Store results
    sources = json.dumps([{"title": r['title'], "url": r['link']} for r in search_results])
    cursor.execute(
        "INSERT INTO reports (monitor_id, summary, sources) VALUES (%s, %s, %s) RETURNING id",
        (monitor_id, summary, sources)
    )
    report_id = cursor.fetchone()[0]
    conn.commit()

    # 5. Send email if scheduled
    if schedule: # If a schedule is set, we assume an email is desired.
        _send_email_notification(user_email, summary, report_id)

    cursor.close()
    conn.close()
    print(f"Successfully generated report {report_id} for monitor {monitor_id}.")


def _google_search(organizations, areas_of_interest, recency_days):
    """Performs targeted Google searches."""
    service = build("customsearch", "v1", developerKey=CUSTOM_SEARCH_API_KEY)
    results = []
    for org in organizations:
        for area in areas_of_interest:
            query = f'"{org}" "{area}"'
            res = service.cse().list(
                q=query,
                cx=CUSTOM_SEARCH_ENGINE_ID,
                num=5,
                sort=f'date:r:d:{recency_days}'
            ).execute()
            if 'items' in res:
                results.extend(res['items'])
    return results

def _scrape_articles(search_results):
    """Scrapes the content of articles from a list of URLs."""
    content = []
    for i, result in enumerate(search_results):
        try:
            response = requests.get(result['link'], timeout=10)
            soup = BeautifulSoup(response.content, 'html.parser')
            paragraphs = soup.find_all('p')
            article_text = '\n'.join([p.get_text() for p in paragraphs])
            content.append({
                "source_num": i + 1,
                "url": result['link'],
                "text": article_text
            })
        except requests.RequestException as e:
            print(f"Error scraping {result['link']}: {e}")
    return content

def _summarize_with_gemini(organizations, areas_of_interest, scraped_content):
    """Summarizes content using Gemini 1.5 Pro."""
    vertexai.init(project=VERTEXAI_PROJECT_ID, location=VERTEXAI_LOCATION)
    model = GenerativeModel('gemini-1.5-pro-preview-0409')

    source_articles = "\n---\n".join([
        f"[Source {item['source_num']}: {item['url']}]\n{item['text']}"
        for item in scraped_content
    ])

    prompt = f"""CONTEXT:
    You are a sales intelligence analyst for Google Cloud. Your task is to summarize the following articles based on the user's areas of interest. For EVERY statement you make, you MUST provide a citation in the format [Source N], where N is the number of the source article. Do not invent any information.

    AREAS OF INTEREST:
    - {", ".join(areas_of_interest)}

    SOURCE ARTICLES:
    {source_articles}

    SUMMARY:
    """

    response = model.generate_content(prompt)
    return response.text

def _send_email_notification(recipient_email, summary, report_id):
    """Sends an email notification with the report summary."""
    message = Mail(
        from_email=SENDER_EMAIL,
        to_emails=recipient_email,
        subject='Your New Customer Compass Report is Ready',
        html_content=f"""
        <h2>Your scheduled report is here!</h2>
        <p>Here is the latest summary:</p>
        <blockquote>{summary.replace('\n', '<br>')}</blockquote>
        <p>
            <a href="[YOUR_FRONTEND_URL]/report/{report_id}">View the full report</a>
        </p>
        """
    )
    try:
        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(message)
        print(f"Email sent to {recipient_email}, status code: {response.status_code}")
    except Exception as e:
        print(f"Error sending email: {e}")