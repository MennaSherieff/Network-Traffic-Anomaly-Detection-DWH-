DROP SCHEMA IF EXISTS dwh CASCADE;

-- CREATE SCHEMA


CREATE SCHEMA IF NOT EXISTS dwh;
SET search_path TO dwh;


-- DIMENSION TABLES


CREATE TABLE dim_time (
    time_key            INTEGER PRIMARY KEY,
    year                SMALLINT NOT NULL,
    month               SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    day                 SMALLINT NOT NULL CHECK (day BETWEEN 1 AND 31),
    hour                SMALLINT NOT NULL CHECK (hour BETWEEN 0 AND 23),
    day_of_week         VARCHAR(20) NOT NULL,
    week                SMALLINT NOT NULL,
    is_business_hours   SMALLINT NOT NULL CHECK (is_business_hours IN (0,1)),
    is_weekend          SMALLINT NOT NULL CHECK (is_weekend IN (0,1)),
    time_bucket         VARCHAR(20) NOT NULL
);



CREATE TABLE dim_endpoint (
	endpoint_key        INTEGER PRIMARY KEY,
    dst_port 			DOUBLE PRECISION,
    port_range_label    VARCHAR(20) NOT NULL,
    is_well_known_port  SMALLINT NOT NULL CHECK (is_well_known_port IN (0,1)),
    is_valid_port       VARCHAR(20) NOT NULL
);

CREATE TABLE dim_service (
    service_key         INTEGER PRIMARY KEY,
    service             VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dim_protocol_flag (
    protocol_key        INTEGER PRIMARY KEY,
    protocol            VARCHAR(20) NOT NULL,
    conn_state          VARCHAR(20),
    flag_combo_label    VARCHAR(50),
    is_handshake        SMALLINT NOT NULL CHECK (is_handshake IN (0,1)),
    is_teardown         SMALLINT NOT NULL CHECK (is_teardown IN (0,1))
);

CREATE TABLE dim_attack_label (
    label_key           INTEGER PRIMARY KEY,
    attack_label_raw    VARCHAR(100) NOT NULL,
    attack_family       VARCHAR(50) NOT NULL,
    binary_label        SMALLINT NOT NULL CHECK (binary_label IN (0,1)),
    severity_tier       SMALLINT NOT NULL CHECK (severity_tier BETWEEN 0 AND 4)
);


CREATE TABLE dwh.dim_capture_session (
    session_key         INTEGER PRIMARY KEY,
    source_dataset      VARCHAR(50) NOT NULL,
    session_name        VARCHAR(100) NOT NULL,
    collection_tool     VARCHAR(50),
    network_scenario    VARCHAR(100)
);


-- FACT TABLE


CREATE TABLE fact_network_flow (
    flow_id             INTEGER PRIMARY KEY,

    -- Foreign Keys
    time_key            INTEGER NOT NULL REFERENCES dim_time(time_key),
    endpoint_key        INTEGER NOT NULL REFERENCES dim_endpoint(endpoint_key),
    service_key         INTEGER NOT NULL REFERENCES dim_service(service_key),
    protocol_key        INTEGER NOT NULL REFERENCES dim_protocol_flag(protocol_key),
    label_key           INTEGER NOT NULL REFERENCES dim_attack_label(label_key),
    session_key         INTEGER NOT NULL REFERENCES dim_capture_session(session_key),

    -- Core Measures
    flow_duration_sec   DOUBLE PRECISION,
    flow_pkts_per_sec   DOUBLE PRECISION,
    flow_bytes_per_sec  DOUBLE PRECISION,
    total_bytes         DOUBLE PRECISION,
    iat_asymmetry       DOUBLE PRECISION,

    -- Binary anomaly indicator
    large_pkt_flag      SMALLINT CHECK (large_pkt_flag IN (0,1))
);


-- INDEXES


CREATE INDEX idx_fact_time_key
ON fact_network_flow(time_key);

CREATE INDEX idx_fact_endpoint_key
ON fact_network_flow(endpoint_key);

CREATE INDEX idx_fact_service_key
ON fact_network_flow(service_key);

CREATE INDEX idx_fact_protocol_key
ON fact_network_flow(protocol_key);

CREATE INDEX idx_fact_label_key
ON fact_network_flow(label_key);

CREATE INDEX idx_fact_session_key
ON fact_network_flow(session_key);

CREATE INDEX idx_fact_label_time
ON fact_network_flow(label_key, time_key);



-- Copy section
SET search_path TO dwh;

COPY dwh.dim_time
    FROM 'C:/pgdata/dim_time.csv'
    WITH (FORMAT csv, HEADER true, NULL '');

COPY dwh.dim_endpoint
    FROM 'C:/pgdata/dim_endpoint.csv'
    WITH (FORMAT csv, HEADER true, NULL '');

COPY dwh.dim_service
    FROM 'C:/pgdata/dim_service.csv'
    WITH (FORMAT csv, HEADER true, NULL '');

COPY dwh.dim_protocol_flag
    FROM 'C:/pgdata/dim_protocol_flag.csv'
    WITH (FORMAT csv, HEADER true, NULL '');

COPY dwh.dim_attack_label
    FROM 'C:/pgdata/dim_attack_label.csv'
    WITH (FORMAT csv, HEADER true, NULL '');

COPY dwh.dim_capture_session
    FROM 'C:/pgdata/dim_capture_session.csv'
    WITH (FORMAT csv, HEADER true, NULL '');

COPY dwh.fact_network_flow
	FROM 'C:/pgdata/fact_network_flow.csv'
	WITH (FORMAT csv, HEADER true, NULL '');