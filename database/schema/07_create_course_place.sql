USE capstone_db;

CREATE TABLE IF NOT EXISTS course_place (
    course_place_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    course_id BIGINT NOT NULL,
    place_id VARCHAR(50) NOT NULL,
    visit_order INT NOT NULL,
    stay_minutes INT,

    CONSTRAINT fk_course_place_course
        FOREIGN KEY (course_id)
        REFERENCES course(course_id),

    CONSTRAINT fk_course_place_place
        FOREIGN KEY (place_id)
        REFERENCES place(place_id),

    CONSTRAINT uq_course_visit_order
        UNIQUE (course_id, visit_order)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4;

DESCRIBE course_place;
