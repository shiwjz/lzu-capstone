USE capstone_db;

CREATE TABLE IF NOT EXISTS cell (
    cell_id VARCHAR(50) PRIMARY KEY,
    region VARCHAR(20) NOT NULL,
    region_name VARCHAR(50),
    center_lat DECIMAL(10,7) NOT NULL,
    center_lon DECIMAL(10,7) NOT NULL,
    dist_m DECIMAL(10,2),

    INDEX idx_cell_region (region)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4;

DESCRIBE cell;
