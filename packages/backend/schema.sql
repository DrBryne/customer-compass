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