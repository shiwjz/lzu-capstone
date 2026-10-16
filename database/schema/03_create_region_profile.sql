USE capstone_db;

CREATE TABLE IF NOT EXISTS region_profile (
    region VARCHAR(20) NOT NULL,
    day_type VARCHAR(20) NOT NULL,
    hour TINYINT UNSIGNED NOT NULL,
    avg_pop DOUBLE,

    PRIMARY KEY (region, day_type, hour)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4;

DESCRIBE region_profile;
