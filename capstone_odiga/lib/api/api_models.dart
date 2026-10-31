/// DTOs preserve the wire fields; UI-specific defaults belong in api_mappers.dart.
typedef Json = Map<String, dynamic>;

abstract class ApiDto {
  ApiDto(Json json) : json = Map.unmodifiable(json);
  final Json json;
  Json toJson() => Map.of(json);
}

class SearchRequestDto {
  const SearchRequestDto({
    required this.query,
    this.date,
    this.startTime,
    this.region,
    this.conditions,
  });
  final String query;
  final String? date, startTime, region;

  /// Explicit filters from the editable conditions screen (API spec v0.3).
  final Json? conditions;
  Json toJson() => {
    'query': query,
    if (date != null) 'date': date,
    if (startTime != null) 'startTime': startTime,
    if (region != null) 'region': region,
    if (conditions != null) 'conditions': conditions,
  };
}

class ConditionsDto extends ApiDto {
  ConditionsDto.fromJson(super.json);
  String get region => json['region'];
  String get date => json['date'];
  String get dayType => json['dayType'];
  String get startTime => json['startTime'];
  int get partySize => json['partySize'];
  List<String> get atmospheres => List<String>.from(json['atmospheres'] ?? []);
  List<String> get allergies => List<String>.from(json['allergies'] ?? []);
  List<String> get categories => List<String>.from(json['categories'] ?? []);
  String? get crowdPreference => json['crowdPreference'];
  String? get extractedBy => json['extractedBy'];
}

class SearchResultDto extends ApiDto {
  SearchResultDto.fromJson(super.json);
  String get searchId => json['searchId'];
  String get query => json['query'];
  ConditionsDto get conditions => ConditionsDto.fromJson(json['conditions']);
  List<PlaceDto> get places => [
    for (final p in json['places']) PlaceDto.fromJson(p),
  ];
  List<CourseDto> get courses => [
    for (final c in json['courses']) CourseDto.fromJson(c),
  ];
  String? get notice => json['notice'];
}

class ScoreDto extends ApiDto {
  ScoreDto.fromJson(super.json);
  double get total => (json['total'] as num).toDouble();
  double? value(String key) => (json[key] as num?)?.toDouble();
  double? get request => value('request');
  double? get target => value('target');
  double? get congestion => value('congestion');
  double? get placeAvg => value('placeAvg');
  double? get moveEfficiency => value('moveEfficiency');
  double? get timeFit => value('timeFit');
}

class CongestionDto extends ApiDto {
  CongestionDto.fromJson(super.json);
  String get level => json['level'];
  int? get hour => json['hour'];
  double get percentile => (json['percentile'] as num).toDouble();
}

class TagDto extends ApiDto {
  TagDto.fromJson(super.json);
  String get tag => json['tag'];
  int get mentions => json['mentions'];
}

class PlaceDto extends ApiDto {
  PlaceDto.fromJson(super.json);
  String get placeId => json['placeId'];
  String get name => json['name'];
  String get category => json['category'];
  String? get region => json['region'];
  String? get address => json['address'];
  String? get phone => json['phone'];
  String? get placeUrl => json['placeUrl'];
  double get lat => (json['lat'] as num).toDouble();
  double get lng => (json['lng'] as num).toDouble();
  List<TagDto> get tags => [
    for (final t in json['tags'] ?? []) TagDto.fromJson(t),
  ];
  String? get reason => json['reason'];
  ScoreDto? get score =>
      json['score'] == null ? null : ScoreDto.fromJson(json['score']);
  CongestionDto? get congestion => json['congestion'] == null
      ? null
      : CongestionDto.fromJson(json['congestion']);
}

class HourlyCongestionDto extends ApiDto {
  HourlyCongestionDto.fromJson(super.json);
  String get date => json['date'];
  String get dayType => json['dayType'];
  String get basis => json['basis'];
  List<CongestionDto> get hours => [
    for (final h in json['hours']) CongestionDto.fromJson(h),
  ];
}

class PlaceDetailDto extends PlaceDto {
  PlaceDetailDto.fromJson(super.json) : super.fromJson();
  String? get roadAddress => json['roadAddress'];
  String? get kakaoCategory => json['kakaoCategory'];
  String? get openingHours => json['openingHours'];
  HourlyCongestionDto get congestionByHour =>
      HourlyCongestionDto.fromJson(json['congestionByHour']);
}

class StopDto extends PlaceDto {
  StopDto.fromJson(super.json) : super.fromJson();
  int get order => json['order'];
  String get slot => json['slot'];
  String get arriveAt => json['arriveAt'];
  String get leaveAt => json['leaveAt'];
  int get stayMinutes => json['stayMinutes'];
  int? get walkMinutesFromPrev => json['walkMinutesFromPrev'];
  double? get distanceMetersFromPrev =>
      (json['distanceMetersFromPrev'] as num?)?.toDouble();
  double get placeScore => (json['placeScore'] as num).toDouble();
}

class WarningDto extends ApiDto {
  WarningDto.fromJson(super.json);
  String get code => json['code'];
  String get message => json['message'];
}

class CourseDto extends ApiDto {
  CourseDto.fromJson(super.json);
  String get courseId => json['courseId'];
  int? get rank => json['rank'];
  String? get title => json['title'];
  String? get reason => json['reason'];
  String get startAt => json['startAt'];
  String get endAt => json['endAt'];
  int get totalMinutes => json['totalMinutes'];
  int get totalWalkMinutes => json['totalWalkMinutes'];
  double get totalDistanceMeters =>
      (json['totalDistanceMeters'] as num).toDouble();
  ScoreDto get score => ScoreDto.fromJson(json['score']);
  List<StopDto> get stops => [
    for (final s in json['stops']) StopDto.fromJson(s),
  ];
  List<WarningDto> get warnings => [
    for (final w in json['warnings'] ?? []) WarningDto.fromJson(w),
  ];
}

class StopInputDto {
  const StopInputDto({required this.placeId, required this.stayMinutes});
  final String placeId;
  final int stayMinutes;
  Json toJson() => {'placeId': placeId, 'stayMinutes': stayMinutes};
}

class CourseUpdateRequestDto {
  const CourseUpdateRequestDto({required this.stops, this.startTime});
  final List<StopInputDto> stops;
  final String? startTime;
  Json toJson() => {
    if (startTime != null) 'startTime': startTime,
    'stops': stops.map((s) => s.toJson()).toList(),
  };
}

class ShareCreateDto extends ApiDto {
  ShareCreateDto.fromJson(super.json);
  String get shareCode => json['shareCode'];
  String get shareUrl => json['shareUrl'];
  String get shareText => json['shareText'];
}

class ShareViewDto extends ApiDto {
  ShareViewDto.fromJson(super.json);
  String get shareCode => json['shareCode'];
  DateTime get createdAt => DateTime.parse(json['createdAt']);
  ConditionsDto get conditions => ConditionsDto.fromJson(json['conditions']);
  CourseDto get course => CourseDto.fromJson(json['course']);
}

class SignupRequestDto {
  const SignupRequestDto({
    required this.email,
    required this.password,
    required this.region,
  });
  final String email, password, region;
  Json toJson() => {'email': email, 'password': password, 'region': region};
}

class LoginRequestDto {
  const LoginRequestDto({required this.email, required this.password});
  final String email, password;
  Json toJson() => {'email': email, 'password': password};
}

class UserDto extends ApiDto {
  UserDto.fromJson(super.json);
  int get userId => json['userId'];
  String get email => json['email'];
  String get region => json['region'];
}

class LoginResultDto extends ApiDto {
  LoginResultDto.fromJson(super.json);
  String get accessToken => json['accessToken'];
  String get tokenType => json['tokenType'];
  int get expiresIn => json['expiresIn'];
  UserDto get user => UserDto.fromJson(json['user']);
}

class PreferencesDto extends ApiDto {
  PreferencesDto({
    required String region,
    required List<String> atmospheres,
    required List<String> allergies,
  }) : super({
         'region': region,
         'atmospheres': List<String>.unmodifiable(atmospheres),
         'allergies': List<String>.unmodifiable(allergies),
       });
  PreferencesDto.fromJson(super.json);
  String get region => json['region'];
  List<String> get atmospheres => List<String>.from(json['atmospheres']);
  List<String> get allergies => List<String>.from(json['allergies']);
}
