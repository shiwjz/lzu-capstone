USE capstone_db;

CREATE TABLE IF NOT EXISTS place_tag (
    place_tag_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    place_id VARCHAR(50) NOT NULL,
    tag VARCHAR(100) NOT NULL,

    CONSTRAINT fk_place_tag_place
        FOREIGN KEY (place_id)
        REFERENCES place(place_id),

    CONSTRAINT uq_place_tag
        UNIQUE (place_id, tag)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4;

DESCRIBE place_tag;
