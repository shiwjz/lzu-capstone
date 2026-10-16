import 'package:flutter/foundation.dart';

import '../data/mock_repository.dart';
import '../models/domain.dart';

class AppState extends ChangeNotifier {
  AppState({MockRepository? repository})
    : repository = repository ?? MockRepository() {
    savedCourses.add(
      this.repository
          .recommend(conditions, preference)
          .first
          .copyWith(id: 'saved-seed'),
    );
  }
  final MockRepository repository;
  int tab = 0;
  String userName = '윤경';
  String groupName = '이번 주말 성수 모임';
  SearchConditions conditions = SearchConditions();
  UserPreference preference = UserPreference();
  final savedPlaceIds = <String>{'성수-1', '홍대-0'};
  final savedCourses = <Course>[];
  final friends = <FriendProfile>[
    const FriendProfile('friend-1', '예민', '오늘은 감성 카페가 좋아요', ['카페', '디저트']),
    const FriendProfile('friend-2', '예령', '사진 찍기 좋은 곳을 찾아요', ['사진', '산책']),
    const FriendProfile('friend-3', '정헌', '맛있는 한식과 산책', ['한식', '산책']),
  ];
  final messages = <ChatMessage>[
    ChatMessage(author: '예민', text: '점심 먹고 조용한 카페 가면 어때?'),
    ChatMessage(author: '정헌', text: '좋아! 서울숲도 걷자'),
  ];
  void selectTab(int value) {
    tab = value;
    notifyListeners();
  }

  void setConditions(SearchConditions value) {
    conditions = value.copy();
    notifyListeners();
  }

  void setPreference(UserPreference value) {
    preference = value.copy();
    notifyListeners();
  }

  void rename(String name) {
    userName = name;
    notifyListeners();
  }

  void createGroup(String name) {
    groupName = name;
    notifyListeners();
  }

  void togglePlace(String id) {
    if (!savedPlaceIds.remove(id)) savedPlaceIds.add(id);
    notifyListeners();
  }

  void saveCourse(Course course) {
    final index = savedCourses.indexWhere((c) => c.id == course.id);
    if (index < 0) {
      savedCourses.add(course.copyWith());
    } else {
      savedCourses[index] = course.copyWith();
    }
    notifyListeners();
  }

  void deleteCourse(String id) {
    savedCourses.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void sendMessage(String text, {Course? course}) {
    if (text.trim().isEmpty && course == null) return;
    messages.add(
      ChatMessage(
        author: userName,
        text: text.trim(),
        course: course?.copyWith(),
      ),
    );
    notifyListeners();
  }

  bool addDemoFriend(String code) {
    if (code.trim().toUpperCase() != 'ODIGA-DEMO' ||
        friends.any((f) => f.id == 'friend-demo')) {
      return false;
    }
    friends.add(
      const FriendProfile('friend-demo', '민수', '새로운 전시를 좋아해요', ['문화시설', '사진']),
    );
    notifyListeners();
    return true;
  }
}
