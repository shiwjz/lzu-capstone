/// 서버랑 주고받는 코드값 ↔ 화면 표시 한글 (docs/api-spec.md 공통 규칙 표와 같음)
/// - 서버에는 항상 code(영어 대문자)로 보내고, 화면에는 label로 보여주기
/// - 모르는 코드가 오면 FormatException → 명세랑 서버가 어긋난 거니까 바로 알려주기
library;

Never _unknown(String field, Object? raw) =>
    throw FormatException('알 수 없는 $field 코드: $raw');

enum RegionCode {
  seongsu('SEONGSU', '성수'),
  hongdae('HONGDAE', '홍대'),
  gangnam('GANGNAM', '강남');

  const RegionCode(this.code, this.label);
  final String code, label;
  static RegionCode fromCode(Object? raw) => values.firstWhere(
    (e) => e.code == raw,
    orElse: () => _unknown('region', raw),
  );
}

enum CategoryCode {
  food('FOOD', '음식'),
  cafe('CAFE', '카페'),
  culture('CULTURE', '문화'),
  activity('ACTIVITY', '액티비티'),
  experience('EXPERIENCE', '체험'),
  shopping('SHOPPING', '쇼핑'),
  tour('TOUR', '관광'),
  nature('NATURE', '자연/휴식');

  const CategoryCode(this.code, this.label);
  final String code, label;
  static CategoryCode fromCode(Object? raw) => values.firstWhere(
    (e) => e.code == raw,
    orElse: () => _unknown('category', raw),
  );
}

/// 코스 칸: 식사(FOOD) · 카페(CAFE) · 놀거리(나머지 6개)
enum SlotCode {
  meal('MEAL', '식사'),
  cafe('CAFE', '카페'),
  play('PLAY', '놀거리');

  const SlotCode(this.code, this.label);
  final String code, label;
  static SlotCode fromCode(Object? raw) => values.firstWhere(
    (e) => e.code == raw,
    orElse: () => _unknown('slot', raw),
  );
}

/// 혼잡도: 한산(하위 30%) · 보통 · 혼잡(상위 30%)
enum LevelCode {
  quiet('QUIET', '한산'),
  normal('NORMAL', '보통'),
  busy('BUSY', '혼잡');

  const LevelCode(this.code, this.label);
  final String code, label;
  static LevelCode fromCode(Object? raw) => values.firstWhere(
    (e) => e.code == raw,
    orElse: () => _unknown('level', raw),
  );
}

/// 혼잡 선호: 따로 저장 안 함, 분위기 태그('조용함', '활기')나 검색 문장에서 나옴
/// - DEFAULT는 Dart 예약어라 이름만 any로
enum CrowdCode {
  quiet('QUIET', '조용한 곳'),
  any('DEFAULT', '상관없음'),
  lively('LIVELY', '활기찬 곳');

  const CrowdCode(this.code, this.label);
  final String code, label;
  static CrowdCode fromCode(Object? raw) => values.firstWhere(
    (e) => e.code == raw,
    orElse: () => _unknown('crowdPreference', raw),
  );
}

enum DayTypeCode {
  weekday('WEEKDAY', '주중'),
  weekend('WEEKEND', '주말');

  const DayTypeCode(this.code, this.label);
  final String code, label;
  static DayTypeCode fromCode(Object? raw) => values.firstWhere(
    (e) => e.code == raw,
    orElse: () => _unknown('dayType', raw),
  );
}

/// 알레르기: 갑각류·해산물만 음식점 종류로 거르고, 나머지는 블로그 메뉴 경고
enum AllergyCode {
  shellfish('SHELLFISH', '갑각류'),
  seafood('SEAFOOD', '해산물·생선'),
  peanut('PEANUT', '땅콩·견과류'),
  milk('MILK', '우유·유제품'),
  egg('EGG', '달걀'),
  wheat('WHEAT', '밀·글루텐');

  const AllergyCode(this.code, this.label);
  final String code, label;
  static AllergyCode fromCode(Object? raw) => values.firstWhere(
    (e) => e.code == raw,
    orElse: () => _unknown('allergy', raw),
  );
}
