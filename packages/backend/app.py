
import os
import json
from flask import Flask, request, jsonify, g
from functools import wraps
from google.auth.transport import requests as grequests
from google.oauth2 import id_token
from google.cloud import pubsub_v1

from database import get_conn, init_db_command
import scheduler

app = Flask(__name__)

# --- Configuration ---
IAP_AUDIENCE = os.environ.get('IAP_AUDIENCE')
PROJECT_ID = os.environ.get('PROJECT_ID')
TOPIC_ID = os.environ.get('TOPIC_ID')

# --- IAP Authentication ---

def verify_iap_jwt(f):
    """Decorator to verify IAP JWT token."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        iap_jwt = request.headers.get('x-goog-iap-jwt-assertion')
        if not iap_jwt:
            return jsonify({'error': 'Missing IAP JWT'}), 401

        try:
            decoded_token = id_token.verify_oauth2_token(
                iap_jwt, grequests.Request(), audience=IAP_AUDIENCE
            )
            g.user_email = decoded_token['email']
            g.user_id = decoded_token['sub']
        except Exception as e:
            return jsonify({'error': f'Invalid IAP JWT: {e}'}), 401

        return f(*args, **kwargs)
    return decorated_function

# --- API Routes ---

@app.route("/api/monitors", methods=["POST"])
@verify_iap_jwt
def create_monitor():
    """Creates a new monitor and triggers the intelligence pipeline."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    try:
        conn = get_conn()
        cursor = conn.cursor()

        # Get or create user
        cursor.execute("SELECT id FROM users WHERE email = %s", (g.user_email,))
        user = cursor.fetchone()
        if user:
            user_id = user[0]
        else:
            cursor.execute("INSERT INTO users (email) VALUES (%s) RETURNING id", (g.user_email,))
            user_id = cursor.fetchone()[0]

        # Create monitor
        cursor.execute(
            "INSERT INTO monitors (user_id, recency_days, schedule) VALUES (%s, %s, %s) RETURNING id",
            (user_id, data.get('recency_days', 14), data.get('schedule'))
        )
        monitor_id = cursor.fetchone()[0]

        # Add organizations
        for org_name in data.get('organizations', []):
            cursor.execute("SELECT id FROM organizations WHERE name = %s", (org_name,))
            org = cursor.fetchone()
            if org:
                org_id = org[0]
            else:
                cursor.execute("INSERT INTO organizations (name) VALUES (%s) RETURNING id", (org_name,))
                org_id = cursor.fetchone()[0]
            cursor.execute("INSERT INTO monitor_organizations (monitor_id, organization_id) VALUES (%s, %s)", (monitor_id, org_id))

        # Add areas of interest
        for area_name in data.get('areas_of_interest', []):
            cursor.execute("SELECT id FROM areas_of_interest WHERE name = %s", (area_name,))
            area = cursor.fetchone()
            if area:
                area_id = area[0]
            else:
                cursor.execute("INSERT INTO areas_of_interest (name) VALUES (%s) RETURNING id", (area_name,))
                area_id = cursor.fetchone()[0]
            cursor.execute("INSERT INTO monitor_areas_of_interest (monitor_id, area_of_interest_id) VALUES (%s, %s)", (monitor_id, area_id))

        conn.commit()

        # Trigger pipeline
        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)
        message_data = {"monitor_id": monitor_id}
        publisher.publish(topic_path, json.dumps(message_data).encode('utf-8'))

        # Create schedule if provided
        if data.get('schedule'):
            scheduler.create_schedule(monitor_id, data['schedule'])

        cursor.close()
        conn.close()

        return jsonify({"monitor_id": monitor_id}), 201

    except Exception as e:
        app.logger.error(f"Database error: {e}")
        return jsonify({"error": "Could not create monitor"}), 500

@app.route("/api/monitors/<int:monitor_id>", methods=["DELETE"])
@verify_iap_jwt
def delete_monitor(monitor_id):
    """Deletes a monitor."""
    try:
        conn = get_conn()
        cursor = conn.cursor()

        cursor.execute("SELECT user_id, schedule FROM monitors WHERE id = %s", (monitor_id,))
        result = cursor.fetchone()
        if not result or result[0] != g.user_id:
            return jsonify({"error": "Monitor not found or access denied"}), 404

        schedule = result[1]
        if schedule:
            scheduler.delete_schedule(monitor_id)

        cursor.execute("DELETE FROM monitor_organizations WHERE monitor_id = %s", (monitor_id,))
        cursor.execute("DELETE FROM monitor_areas_of_interest WHERE monitor_id = %s", (monitor_id,))
        cursor.execute("DELETE FROM reports WHERE monitor_id = %s", (monitor_id,))
        cursor.execute("DELETE FROM monitors WHERE id = %s", (monitor_id,))

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"message": "Monitor deleted"}), 200
    except Exception as e:
        app.logger.error(f"Database error: {e}")
        return jsonify({"error": "Could not delete monitor"}), 500

@app.cli.command("init-db")
def init_db():
    init_db_command()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
