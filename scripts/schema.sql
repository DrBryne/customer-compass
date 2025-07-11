CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS monitors (
    id SERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    organizations TEXT[] NOT NULL,
    areas_of_interest TEXT[] NOT NULL,
    recency_days INTEGER NOT NULL,
    schedule VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reports (
    id SERIAL PRIMARY KEY,
    monitor_id INTEGER NOT NULL REFERENCES monitors(id),
    summary TEXT NOT NULL,
    sources JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);