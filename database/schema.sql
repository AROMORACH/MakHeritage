-- Initial Schema for MakHeritage

-- Landmarks table stores the core historical nodes
CREATE TABLE landmarks (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) CHECK (category IN ('College', 'Hall', 'Spiritual', 'Infrastructure', 'Gate')),
    foundation_year INTEGER NOT NULL,
    description TEXT NOT NULL,
    image_url VARCHAR(255),
    latitude DECIMAL,
    longitude DECIMAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Events table handles specific milestones linked to landmarks
CREATE TABLE events (
    id UUID PRIMARY KEY,
    landmark_id UUID REFERENCES landmarks(id) ON DELETE CASCADE,
    event_date DATE NOT NULL,
    event_type VARCHAR(50),
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexing for performance in filtering/search
CREATE INDEX idx_category ON landmarks(category);
CREATE INDEX idx_foundation_year ON landmarks(foundation_year);