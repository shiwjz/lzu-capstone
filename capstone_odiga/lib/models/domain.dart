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
  });
  final String id, kakaoPlaceId, name, category, region, cellId, openingHours;
  final double latitude, longitude;
  final List<String> tags;
  // UI-only mock fields; these are not an agreed backend response contract.
  final String imageAsset, description;
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
    this.travelMinutesToNext = 0,
    this.distanceMetersToNext = 0,
  });
  final String id, placeId;
  final int order, stayMinutes, travelMinutesToNext;
  final DateTime arrival;
  final double distanceMetersToNext;
  CourseStop withStay(int minutes) => CourseStop(
    id: id,
    placeId: placeId,
    order: order,
    arrival: arrival,
    stayMinutes: minutes,
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
  }) : stops = List.unmodifiable(stops);
  final String id, title, region, reason;
  final int matchScore;
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
      );
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'region': region,
    'stops': stops.map((s) => s.toJson()).toList(),
    'totalMinutes': totalMinutes,
  };
}

class SearchConditions {
  SearchConditions({
    this.query = '',
    this.region = '성수',
    DateTime? start,
    this.people = 2,
    this.mood = '조용한',
    this.excluded = '',
    this.useSelectedRegion = true,
  }) : start = start ?? DateTime(2026, 10, 17, 12);
  String query, region, mood, excluded;
  DateTime start;
  int people;
  bool useSelectedRegion;
  SearchConditions copy() => SearchConditions(
    query: query,
    region: region,
    start: start,
    people: people,
    mood: mood,
    excluded: excluded,
    useSelectedRegion: useSelectedRegion,
  );
}

class UserPreference {
  UserPreference({
    Set<String>? categories,
    Set<String>? moods,
    this.allergies = '',
    this.dislikedFood = '',
  }) : categories = categories ?? {'카페'},
       moods = moods ?? {'조용한', '사진'};
  final Set<String> categories, moods;
  String allergies, dislikedFood;
  UserPreference copy() => UserPreference(
    categories: {...categories},
    moods: {...moods},
    allergies: allergies,
    dislikedFood: dislikedFood,
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
