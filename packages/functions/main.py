
import base64
import json
import os
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
import intelligence
from database import get_conn

SENDGRID_API_KEY = os.environ.get('SENDGRID_API_KEY')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL')

def run_monitor_pubsub(event, context):
    """Cloud Function triggered by Pub/Sub to run a monitor."""
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)
    monitor_id = message_json['monitor_id']

    summary, sources = intelligence.run_intelligence_pipeline(monitor_id)

    # Store the report
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO reports (monitor_id, summary, sources) VALUES (%s, %s, %s)",
        (monitor_id, summary, sources)
    )
    cursor.execute(
        "UPDATE monitors SET last_run_at = CURRENT_TIMESTAMP WHERE id = %s",
        (monitor_id,)
    )
    conn.commit()

    # Send email notification
    cursor.execute("SELECT user_email FROM monitors WHERE id = %s", (monitor_id,))
    user_email = cursor.fetchone()[0]
    cursor.close()
    conn.close()

    _send_email_notification(user_email, monitor_id, summary)

def _send_email_notification(recipient_email, monitor_id, summary):
    """Sends an email notification with the report summary."""
    message = Mail(
        from_email=SENDER_EMAIL,
        to_emails=recipient_email,
        subject=f'Customer Compass Report for Monitor {monitor_id}',
        html_content=f'<h2>Latest Report Summary</h2><p>{summary}</p><p><a href="#">View full report in the app</a></p>'
    )
    try:
        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(message)
        print(response.status_code)
        print(response.body)
        print(response.headers)
    except Exception as e:
        print(e)
