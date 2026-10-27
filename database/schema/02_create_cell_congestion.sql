USE capstone_db;

CREATE TABLE IF NOT EXISTS cell_congestion (
    congestion_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cell_id VARCHAR(50) NOT NULL,
    day_type VARCHAR(20) NOT NULL,
    hour TINYINT UNSIGNED NOT NULL,
    avg_pop DOUBLE,
    pct_same_time DOUBLE,
    level_same_time VARCHAR(10),
    pct_all_day DOUBLE,
    level_all_day VARCHAR(10),

    CONSTRAINT fk_congestion_cell
        FOREIGN KEY (cell_id)
        REFERENCES cell(cell_id),

    CONSTRAINT uq_cell_congestion_time
        UNIQUE (cell_id, day_type, hour),

    INDEX idx_congestion_lookup (cell_id, day_type, hour)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4;

DESCRIBE cell_congestion;
