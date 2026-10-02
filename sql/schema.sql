-- =========================================================================
-- schema.sql - the tables your database is made of
--
-- Project 1 | SQL: From Data to Insight
-- Team:
-- Dataset:
--
-- This is a DELIVERABLE: it is how someone rebuilds your database from
-- nothing, and the tables here must match the ERD you drew.
--
-- Written for SQLite. On MySQL, add a CREATE DATABASE / USE at the top and
-- swap the types (TEXT -> VARCHAR(n), REAL -> DECIMAL, INTEGER PRIMARY KEY
-- -> INT PRIMARY KEY AUTO_INCREMENT).
-- =========================================================================

-- SQLite does not enforce foreign keys unless you ask it to, once per
-- connection. Without this line a broken key is accepted in silence.
PRAGMA foreign_keys = ON;
-- Start from nothing: drop children before parents, so no foreign key
-- blocks the drop. This makes the file safe to run more than once.
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS listings;
DROP TABLE IF EXISTS licence_status;
DROP TABLE IF EXISTS hosts;
DROP TABLE IF EXISTS neighbourhoods;
DROP TABLE IF EXISTS districts;

-- --- Lookup tables -------------------------------------------------------
-- The categorical columns you pulled out: an id and the value it stands for.
-- These have no foreign keys of their own, so they are created and loaded
-- FIRST.

CREATE TABLE districts (
    district_id   INTEGER PRIMARY KEY,
    district_name TEXT    NOT NULL UNIQUE
);

CREATE TABLE licence_status (
    licence_status_id INTEGER PRIMARY KEY,
    status_code       TEXT    NOT NULL UNIQUE,
    description       TEXT    NOT NULL
);

-- Hosts: not a label but a real entity, with attributes that depend only
-- on host_id (checked in notebook 01, section 5.4).
CREATE TABLE hosts (
    host_id             INTEGER PRIMARY KEY,
    host_name           TEXT,     -- null for 42 hosts whose profile was not scraped
    is_superhost        INTEGER CHECK (is_superhost IN (0, 1)),
    identity_verified   INTEGER CHECK (identity_verified IN (0, 1)),
    host_listings_count INTEGER
);

-- --- Second level of the location hierarchy -------------------------
-- Each neighbourhood belongs to exactly one district, so it references
-- districts and must be created after it.

CREATE TABLE neighbourhoods (
    neighbourhood_id   INTEGER PRIMARY KEY,
    neighbourhood_name TEXT    NOT NULL UNIQUE,
    district_id        INTEGER NOT NULL REFERENCES districts (district_id)
);

-- --- Your main table -----------------------------------------------------
-- The rows you are actually analysing: the numbers you care about, plus one
-- foreign key pointing at each lookup table above. Created and loaded LAST,
-- because every key it carries has to already exist somewhere else.

CREATE TABLE listings (
    listing_id                INTEGER PRIMARY KEY,
    host_id                   INTEGER NOT NULL REFERENCES hosts (host_id),
    neighbourhood_id          INTEGER NOT NULL REFERENCES neighbourhoods (neighbourhood_id),
    licence_status_id         INTEGER NOT NULL REFERENCES licence_status (licence_status_id),
    licence_number            TEXT,     -- null unless a HUTB licence is shown
    room_type                 TEXT    NOT NULL,
    accommodates              INTEGER NOT NULL CHECK (accommodates > 0),
    price_eur                 REAL    CHECK (price_eur > 0),  -- null if not live in this scrape
    minimum_nights            INTEGER,  -- null for 1 listing (previous scrape)
    availability_365          INTEGER NOT NULL,
    number_of_reviews         INTEGER NOT NULL,
    number_of_reviews_ltm     INTEGER NOT NULL,
    estimated_occupancy_l365d INTEGER NOT NULL,
    review_scores_rating      REAL,     -- null = never reviewed
    is_current_scrape         INTEGER NOT NULL CHECK (is_current_scrape IN (0, 1))
);

-- --- Second table of records ----------------------------------------
-- One row per review, pointing at the listing it was left on. A child of
-- listings, so it is created and loaded after it.

CREATE TABLE reviews (
    review_id   INTEGER PRIMARY KEY,
    listing_id  INTEGER NOT NULL REFERENCES listings (listing_id),
    review_date TEXT    NOT NULL,   -- ISO format YYYY-MM-DD (SQLite has no DATE type)
    reviewer_id INTEGER NOT NULL
);
-- --- Indexes (optional) --------------------------------------------------
-- Worth adding on your foreign keys if a query starts to feel slow.
CREATE INDEX idx_reviews_listing_id      ON reviews (listing_id);
CREATE INDEX idx_reviews_review_date     ON reviews (review_date);
CREATE INDEX idx_listings_neighbourhood  ON listings (neighbourhood_id);
CREATE INDEX idx_listings_licence_status ON listings (licence_status_id);
CREATE INDEX idx_listings_host           ON listings (host_id);
