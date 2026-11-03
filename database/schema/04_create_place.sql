USE capstone_db;

CREATE TABLE IF NOT EXISTS place (
    place_id VARCHAR(50) PRIMARY KEY,
    cell_id VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(255),
    address VARCHAR(500),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),

    CONSTRAINT fk_place_cell
        FOREIGN KEY (cell_id)
        REFERENCES cell(cell_id),

    INDEX idx_place_cell (cell_id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4;

DESCRIBE place;
