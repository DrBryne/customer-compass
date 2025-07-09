import os
import requests
from bs4 import BeautifulSoup
from googleapiclient.discovery import build
import vertexai
from vertexai.generative_models import GenerativeModel
from database import get_conn
import json

# --- Configuration ---
CUSTOM_SEARCH_API_KEY = os.environ.get('CUSTOM_SEARCH_API_KEY')
CUSTOM_SEARCH_ENGINE_ID = os.environ.get('CUSTOM_SEARCH_ENGINE_ID')
VERTEXAI_PROJECT_ID = os.environ.get('VERTEXAI_PROJECT_ID')
VERTEXAI_LOCATION = os.environ.get('VERTEXAI_LOCATION')

# --- Intelligence Pipeline ---

def run_intelligence_pipeline(monitor_id):
    """Runs the full intelligence pipeline for a given monitor."""
    conn = get_conn()
    cursor = conn.cursor()

    # 1. Get monitor configuration
    cursor.execute("SELECT recency_days FROM monitors WHERE id = %s", (monitor_id,))
    recency_days = cursor.fetchone()[0]

    cursor.execute("SELECT o.name FROM organizations o JOIN monitor_organizations mo ON o.id = mo.organization_id WHERE mo.monitor_id = %s", (monitor_id,))
    organizations = [row[0] for row in cursor.fetchall()]

    cursor.execute("SELECT a.name FROM areas_of_interest a JOIN monitor_areas_of_interest ma ON a.id = ma.area_of_interest_id WHERE ma.monitor_id = %s", (monitor_id,))
    areas_of_interest = [row[0] for row in cursor.fetchall()]

    cursor.close()
    conn.close()

    # 2. Information Gathering
    search_results = _google_search(organizations, areas_of_interest, recency_days)
    scraped_content = _scrape_articles(search_results)

    # 3. AI Summarization
    summary = _summarize_with_gemini(organizations, areas_of_interest, scraped_content)

    # 4. Format sources
    sources = json.dumps([{"title": r['title'], "url": r['link']} for r in search_results])

    return summary, sources

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
                num=5, # Limit to 5 results per query
                sort=f'date:r:d:{recency_days}' # Sort by date, recency in days
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
            # A simple way to get the main text content
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
