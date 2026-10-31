import 'package:flutter/foundation.dart';

import '../data/mock_repository.dart';
import '../models/domain.dart';
import '../api/odiga_api.dart';
import '../api/api_codes.dart';

class AppState extends ChangeNotifier {
  AppState({required this.repository}) {
    preference = repository.initialPreference.copy();
    final courses = repository.initialCourses;
    if (courses.isNotEmpty) {
      savedCourses.add(courses.first.copyWith(id: 'saved-seed'));
      savedPlaceIds.addAll(courses.first.stops.take(2).map((s) => s.placeId));
      conditions.start = courses.first.stops.first.arrival;
    }
  }
  static Future<AppState> load({OdigaApi? api}) async =>
      AppState(repository: await MockRepository.load(api: api));
  final MockRepository repository;
  int tab = 0;
  String userName = '윤경';
  String? accountEmail;
  String? accessToken;
  String groupName = '이번 주말 성수 모임';
  SearchConditions conditions = SearchConditions();
  UserPreference preference = UserPreference();
  final savedPlaceIds = <String>{};
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

  Future<void> savePreference(UserPreference value) async {
    final saved = await repository.api.updatePreferences(
      PreferencesDto(
        region: RegionCode.parse(conditions.region).code,
        atmospheres: value.moods.toList(),
        allergies: value.allergies
            .split(RegExp(r'[,\s]+'))
            .where((s) => s.isNotEmpty)
            .toList(),
      ),
    );
    setPreference(
      UserPreference(
        categories: value.categories,
        moods: saved.atmospheres.toSet(),
        allergies: saved.allergies.join(', '),
        dislikedFood: value.dislikedFood,
      ),
    );
  }

  void rename(String name) {
    userName = name;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await repository.api.login(
      LoginRequestDto(email: email, password: password),
    );
    accountEmail = result.user.email;
    accessToken = result.accessToken;
    userName = result.user.email.split('@').first;
    notifyListeners();
  }

  void logout() {
    repository.api.clearSession();
    accountEmail = null;
    accessToken = null;
    userName = '윤경';
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
