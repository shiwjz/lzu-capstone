package com.capstone.backend.course;

/**
 * 코스에 넣을 장소 하나와 체류 시간(분). 코스 수정(PUT)에서 받은 목록도 이 형태로 바꿔서 계산
 */
public record StopInput(CoursePlace place, int stayMinutes) {
}
