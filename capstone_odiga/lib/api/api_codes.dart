enum RegionCode {
  seongsu('SEONGSU', '성수'),
  hongdae('HONGDAE', '홍대'),
  gangnam('GANGNAM', '강남');

  const RegionCode(this.code, this.label);
  final String code, label;
  static RegionCode parse(String value) =>
      values.firstWhere((v) => v.code == value || v.label == value);
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
  static CategoryCode parse(String value) =>
      values.firstWhere((v) => v.code == value);
}

enum CongestionCode {
  quiet('QUIET', '한산'),
  normal('NORMAL', '보통'),
  busy('BUSY', '혼잡');

  const CongestionCode(this.code, this.label);
  final String code, label;
  static CongestionCode parse(String value) =>
      values.firstWhere((v) => v.code == value);
}

enum AllergyCode {
  shellfish('SHELLFISH', '갑각류'),
  seafood('SEAFOOD', '해산물·생선'),
  peanut('PEANUT', '땅콩·견과류'),
  milk('MILK', '우유·유제품'),
  egg('EGG', '달걀'),
  wheat('WHEAT', '밀·글루텐');

  const AllergyCode(this.code, this.label);
  final String code, label;
}

String formatDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String formatTime(DateTime day) =>
    '${day.hour.toString().padLeft(2, '0')}:${day.minute.toString().padLeft(2, '0')}';
