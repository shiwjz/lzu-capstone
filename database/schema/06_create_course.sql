USE capstone_db;

CREATE TABLE IF NOT EXISTS course (
    course_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NULL,
    region VARCHAR(20) NOT NULL,
    course_date DATE,
    start_time TIME,
    share_code VARCHAR(100) UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_course_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4;

DESCRIBE course;
