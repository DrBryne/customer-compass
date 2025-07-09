
import os
from google.cloud import scheduler_v1
from google.cloud import pubsub_v1

PROJECT_ID = os.environ.get('PROJECT_ID')
LOCATION = os.environ.get('LOCATION')
TOPIC_NAME = os.environ.get('TOPIC_NAME')

def create_schedule(monitor_id, schedule):
    """Creates a Cloud Scheduler job for a given monitor."""
    scheduler_client = scheduler_v1.CloudSchedulerClient()
    pubsub_client = pubsub_v1.PublisherClient()

    job_name = f'projects/{PROJECT_ID}/locations/{LOCATION}/jobs/monitor-{monitor_id}'
    topic_path = pubsub_client.topic_path(PROJECT_ID, TOPIC_NAME)

    job = {
        'name': job_name,
        'pubsub_target': {
            'topic_name': topic_path,
            'data': f'{{"monitor_id": {monitor_id}}}'.encode('utf-8'),
        },
        'schedule': schedule,
        'time_zone': 'Etc/UTC',
    }

    try:
        scheduler_client.create_job(parent=f'projects/{PROJECT_ID}/locations/{LOCATION}', job=job)
        print(f"Created scheduler job: {job_name}")
    except Exception as e:
        print(f"Error creating scheduler job: {e}")

def delete_schedule(monitor_id):
    """Deletes a Cloud Scheduler job."""
    scheduler_client = scheduler_v1.CloudSchedulerClient()
    job_name = f'projects/{PROJECT_ID}/locations/{LOCATION}/jobs/monitor-{monitor_id}'

    try:
        scheduler_client.delete_job(name=job_name)
        print(f"Deleted scheduler job: {job_name}")
    except Exception as e:
        print(f"Error deleting scheduler job: {e}")
