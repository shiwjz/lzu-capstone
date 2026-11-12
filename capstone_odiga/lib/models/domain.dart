const supportedCongestionRegions = ['성수', '홍대', '강남'];

/// Prototype contracts, separated from presentation and the future API client.
class Place {
  const Place({
    required this.id,
    required this.kakaoPlaceId,
    required this.name,
    required this.category,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.cellId,
    required this.tags,
    required this.openingHours,
    required this.imageAsset,
    required this.rating,
    required this.description,
    this.address,
    this.cuisine,
    this.cuisineDetail,
  });
  final String id, kakaoPlaceId, name, category, region, cellId, openingHours;
  final double latitude, longitude;
  final List<String> tags;
  // UI-only mock fields; these are not an agreed backend response contract.
  final String imageAsset, description;
  final String? address, cuisine, cuisineDetail;
  final double? rating;
  Map<String, Object> toJson() => {
    'id': id,
    'kakaoPlaceId': kakaoPlaceId,
    'name': name,
    'category': category,
    'region': region,
    'latitude': latitude,
    'longitude': longitude,
    'cellId': cellId,
    'tags': tags,
    'openingHours': openingHours,
    'address': ?address,
  };
}

enum CongestionBand { quiet, moderate, busy }

class Congestion {
  const Congestion({
    required this.cellId,
    required this.weekend,
    required this.hour,
    required this.value,
    required this.percentile,
    this.reportedBand,
  });
  final String cellId;
  final bool weekend;
  final int hour;

  /// Chart height (0–100); API fixtures use their percentile here.
  final double value;

  /// Relative percentile, not an occupancy percentage.
  final double percentile;
  final CongestionBand? reportedBand;
  CongestionBand get band =>
      reportedBand ??
      (value < 40
          ? CongestionBand.quiet
          : value < 70
          ? CongestionBand.moderate
          : CongestionBand.busy);
}

class CourseStop {
  const CourseStop({
    required this.id,
    required this.placeId,
    required this.order,
    required this.arrival,
    required this.stayMinutes,
    this.name,
    this.travelMinutesToNext = 0,
    this.distanceMetersToNext = 0,
    this.congestionBand,
    this.congestionPercentile,
  });
  final String id, placeId;
  final String? name;
  final int order, stayMinutes, travelMinutesToNext;
  final DateTime arrival;
  final double distanceMetersToNext;
  final CongestionBand? congestionBand;
  final double? congestionPercentile;
  CourseStop withStay(int minutes) => CourseStop(
    id: id,
    placeId: placeId,
    name: name,
    order: order,
    arrival: arrival,
    stayMinutes: minutes,
    travelMinutesToNext: travelMinutesToNext,
    distanceMetersToNext: distanceMetersToNext,
    congestionBand: congestionBand,
    congestionPercentile: congestionPercentile,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'placeId': placeId,
    'order': order,
    'arrival': arrival.toIso8601String(),
    'stayMinutes': stayMinutes,
    'travelMinutesToNext': travelMinutesToNext,
  };
}

class Course {
  Course({
    required this.id,
    required this.title,
    required this.region,
    required List<CourseStop> stops,
    this.reason = '',
    this.matchScore = 0,
    this.score = const {},
    this.keywords = const [],
  }) : stops = List.unmodifiable(stops);
  final String id, title, region, reason;
  final int matchScore;
  final Map<String, double> score;
  final List<String> keywords;
  final List<CourseStop> stops;
  int get totalMinutes =>
      stops.fold(0, (sum, s) => sum + s.stayMinutes + s.travelMinutesToNext);
  double get distanceKm =>
      stops.fold(0.0, (sum, s) => sum + s.distanceMetersToNext) / 1000;
  Course copyWith({List<CourseStop>? stops, String? title, String? id}) =>
      Course(
        id: id ?? this.id,
        title: title ?? this.title,
        region: region,
        stops: stops ?? this.stops,
        reason: reason,
        matchScore: matchScore,
        score: score,
        keywords: keywords,
      );
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'region': region,
    'stops': stops.map((s) => s.toJson()).toList(),
    'totalMinutes': totalMinutes,
  };
}

enum CourseType {
  basic('BASIC', '기본', ['식사 → 카페 → 놀거리', '카페 → 놀거리 → 식사']),
  drink('DRINK', '술', ['식사 → 술집', '식사 → 술집 → 술집', '놀거리 → 식사 → 술집']),
  culture('CULTURE', '문화', ['전시·공연 → 카페 → 식사']),
  walk('WALK', '산책', ['공원·자연 → 카페 → 식사']),
  shopping('SHOPPING', '쇼핑', ['쇼핑 → 카페 → 식사']);

  const CourseType(this.code, this.label, this.routes);
  final String code, label;
  final List<String> routes;
}

class SearchConditions {
  SearchConditions({
    this.query = '',
    this.region = '성수',
    DateTime? start,
    this.people = 2,
    this.gender = '무관',
    this.ageGroup = '무관',
    this.companionType = '친구',
    this.mood = '',
    this.useSelectedRegion = true,
    this.courseType,
    this.playDetails = const [],
    this.excludedCategories = const [],
    this.includedCategories = const [],
  }) : start = start ?? DateTime(2026, 10, 17, 12);
  String query, region, gender, ageGroup, companionType, mood;
  DateTime start;
  int people;
  bool useSelectedRegion;
  CourseType? courseType;
  List<String> playDetails, excludedCategories, includedCategories;
  SearchConditions copy() => SearchConditions(
    query: query,
    region: region,
    start: start,
    people: people,
    gender: gender,
    ageGroup: ageGroup,
    companionType: companionType,
    mood: mood,
    useSelectedRegion: useSelectedRegion,
    courseType: courseType,
    playDetails: playDetails,
    excludedCategories: excludedCategories,
    includedCategories: includedCategories,
  );
}

class UserPreference {
  UserPreference({
    Set<String>? categories,
    Set<String>? moods,
    this.allergies = '',
    this.dislikedFood = '',
    this.crowdPreference = 'DEFAULT',
    Set<String>? cuisines,
    Set<String>? cuisineDetails,
  }) : categories = categories ?? {'카페'},
       moods = moods ?? {'조용한', '감성적인'},
       cuisines = cuisines ?? <String>{},
       cuisineDetails = cuisineDetails ?? <String>{};
  final Set<String> categories, moods;
  final Set<String> cuisines, cuisineDetails;
  String allergies, dislikedFood;
  String crowdPreference;
  UserPreference copy() => UserPreference(
    categories: {...categories},
    moods: {...moods},
    allergies: allergies,
    dislikedFood: dislikedFood,
    crowdPreference: crowdPreference,
    cuisines: {...cuisines},
    cuisineDetails: {...cuisineDetails},
  );
}

class FriendProfile {
  const FriendProfile(this.id, this.name, this.status, this.tags);
  final String id, name, status;
  final List<String> tags;
}

class ChatMessage {
  ChatMessage({
    required this.author,
    required this.text,
    this.course,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();
  final String author, text;
  final Course? course;
  final DateTime sentAt;
}
