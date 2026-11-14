import '../models/domain.dart';
import 'api_models.dart';

/// Converts API-shaped fixtures to the presentation models.
class ApiMappers {
  static Course toCourse(CourseDto dto, ConditionsDto conditions) =>
      course(dto.json, conditions.json);
  static Place toPlace(PlaceDto dto, String regionCode) =>
      place(dto.json, regionCode);
  static String region(String code) =>
      const {'SEONGSU': '성수', 'HONGDAE': '홍대', 'GANGNAM': '강남'}[code] ?? code;

  static Place place(Map<String, dynamic> json, String regionCode) {
    final category =
        const {
          'FOOD': '음식점',
          'CAFE': '카페',
          'SNACK': '간식',
          'CULTURE': '문화시설',
          'ACTIVITY': '놀거리',
          'EXPERIENCE': '체험',
          'SHOPPING': '쇼핑',
          'TOUR': '관광',
          'NATURE': '자연/휴식',
        }[json['category']] ??
        json['category'] as String;
    // 호프·이자카야 같은 술집은 카카오 분류상 음식점이라 "술집"으로 따로 표시 (예민 11/14)
    final cuisine = json['cuisine'] as String?;
    final shownCategory =
        json['bar'] == true || (category == '음식점' && cuisine == 'BAR')
        ? '술집'
        : category;
    final id = json['placeId'] as String;
    return Place(
      id: id,
      kakaoPlaceId: id,
      name: json['name'] as String,
      category: shownCategory,
      region: region(json['region'] ?? regionCode),
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      // Fixtures expose no grid cell ID; this key only groups local snapshots.
      cellId: 'fixture-place-$id',
      tags: [
        for (final tag in json['tags'] as List? ?? []) tag['tag'] as String,
      ],
      openingHours: json['openingHours'] as String? ?? '영업시간 정보 없음',
      imageAsset: _placeImage(shownCategory, json),
      rating: null,
      description:
          json['reason'] as String? ?? json['address'] as String? ?? '',
      address: (json['roadAddress'] as String?)?.trim().isNotEmpty == true
          ? json['roadAddress'] as String
          : json['address'] as String?,
      cuisine: cuisine,
      cuisineDetail: json['cuisineDetail'] as String?,
    );
  }

  static String? _placeImage(String category, Map<String, dynamic> json) {
    final details = [json['cuisineDetail'], json['kakaoCategory'], json['name']]
        .whereType<String>()
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');

    bool has(String pattern) => RegExp(pattern).hasMatch(details);

    final asset = switch (category) {
      '음식점' =>
        const {
              'KOREAN': 'food_korean',
              'JAPANESE': 'food_japanese',
              'WESTERN': 'food_western',
              'CHINESE': 'food_chinese',
              'BUNSIK': 'food_bunsik',
              'ASIAN': 'food_asian',
              'CHICKEN': 'food_chicken',
            }[json['cuisine']] ??
            'food_etc',
      '술집' when has('이자카야|일본식주점') => 'bar_izakaya',
      '술집' when has('칵테일|cocktail') => 'bar_cocktail',
      '술집' when has('포장마차|포차') => 'bar_pocha',
      '술집' when has('와인|wine') => 'bar_wine',
      '술집' when has('호프|요리주점|맥주') => 'bar_hof',
      '술집' => 'bar_etc',
      '카페' when has('찻집|전통차|차·음료|생과일|공차|티하우스') => 'cafe_tea',
      '카페' when has('테마카페|갤러리·북카페|갤러리카페|북카페|고양이카페') => 'cafe_theme',
      '카페' => 'cafe',
      '간식' when has('베이커리|제과|도넛|도너츠|빵|베이글|bakery|donut') => 'dessert_bakery',
      '간식' when has('아이스크림|젤라또|젤라토|배스킨라빈스') => 'dessert_icecream',
      '간식' => 'dessert_etc',
      '놀거리' when has('노래방|노래연습장|노래연습실|코인노래') => 'play_karaoke',
      '놀거리' when has('방탈출') => 'play_escape',
      '놀거리' when has('보드카페|보드게임|레드버튼|데블다이스') => 'play_board',
      '놀거리' when has('만화카페|만화방|벌툰|놀숲') => 'play_manga',
      '놀거리' when has('오락실|아케이드') => 'play_arcade',
      '놀거리' when has('볼링|사격|클라이밍|탁구|당구|스포츠시설') => 'play_sports',
      '놀거리' when has('테마카페|고양이카페|사주카페') => 'cafe_theme',
      '놀거리' => 'play_theme',
      '문화시설' when has('영화관|시네마|메가박스|cgv') => 'culture_movie',
      '문화시설' when has('공연장|연극극장|연극|뮤지컬|소극장') => 'culture_performance',
      '문화시설' => 'culture_gallery',
      '체험' when has('공예|공방|도자기|자수|원데이클래스') => 'experience_workshop',
      '체험' => 'experience_etc',
      '쇼핑' when has('의류|양복|옷가게') => 'shop_cloth',
      '쇼핑' when has('패션잡화|편집숍|편집샵|액세서리') => 'shop_select',
      '쇼핑' when has('소품|문구|생활용품|인테리어장식|아트박스') => 'shop_gift',
      '쇼핑' when has('서점|문고|책방') => 'shop_book',
      '쇼핑' => 'shop_etc',
      '관광' => 'tour_theme',
      '자연/휴식' => 'nature_park',
      _ => null,
    };
    return asset == null ? null : 'assets/places/$asset.png';
  }

  static DateTime time(String date, String clock) =>
      DateTime.parse('${date}T$clock:00');

  static Course course(
    Map<String, dynamic> json,
    Map<String, dynamic> conditions,
  ) {
    final stops = json['stops'] as List;
    final date = conditions['date'] as String;
    var previous = time(date, json['startAt']);
    final result = <CourseStop>[];
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      var arrival = time(date, stop['arriveAt']);
      while (arrival.isBefore(previous)) {
        arrival = arrival.add(const Duration(days: 1));
      }
      previous = arrival;
      final next = i + 1 < stops.length ? stops[i + 1] : null;
      result.add(
        CourseStop(
          id: '${json['courseId']}-stop-$i',
          placeId: stop['placeId'],
          name: stop['name'],
          order: stop['order'],
          arrival: arrival,
          stayMinutes: stop['stayMinutes'],
          travelMinutesToNext:
              (next?['walkMinutesFromPrev'] as num?)?.toInt() ?? 0,
          distanceMetersToNext:
              (next?['distanceMetersFromPrev'] as num?)?.toDouble() ?? 0,
          congestionBand: switch (stop['congestion']?['level']) {
            'QUIET' => CongestionBand.quiet,
            'BUSY' => CongestionBand.busy,
            'NORMAL' => CongestionBand.moderate,
            _ => null,
          },
          congestionPercentile: (stop['congestion']?['percentile'] as num?)
              ?.toDouble(),
        ),
      );
    }
    final label = region(conditions['region']);
    return Course(
      id: json['courseId'],
      title: json['title'] as String? ?? '$label 추천 코스 ${json['rank']}',
      region: label,
      stops: result,
      reason:
          json['reason'] as String? ??
          '지역별 예시 코스 · ${conditions['date']} ${json['startAt']} 기준',
      matchScore: ((json['score']['total'] as num) * 100).round(),
      score: {
        for (final entry in (json['score'] as Map).entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toDouble(),
      },
      keywords: List<String>.from(json['keywords'] ?? const []),
    );
  }

  static Congestion congestion(
    String id,
    Map<String, dynamic> json,
    DateTime visit,
  ) => Congestion(
    cellId: 'fixture-place-$id',
    weekend: visit.weekday >= DateTime.saturday,
    hour: visit.hour,
    value: (json['percentile'] as num).toDouble(),
    percentile: (json['percentile'] as num).toDouble(),
    reportedBand: switch (json['level']) {
      'QUIET' => CongestionBand.quiet,
      'BUSY' => CongestionBand.busy,
      _ => CongestionBand.moderate,
    },
  );
}
