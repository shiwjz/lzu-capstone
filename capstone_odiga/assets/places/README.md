# 코스 썸네일 픽셀 사진 (예민)

장소 종류에 따라 아래 사진을 쓰면 됨. 192px PNG, 배경 투명.
앱에서 쓰려면 pubspec.yaml의 assets에 `- assets/places/` 추가 필요.

| 사진 | 언제 쓰는지 |
|---|---|
| food_korean / food_japanese / food_western / food_chinese | 음식점: 한식 / 일식 / 양식 / 중식 |
| food_bunsik / food_asian / food_chicken | 음식점: 분식 / 아시안 / 치킨 |
| food_etc | 음식점: 그 외 |
| bar_hof / bar_izakaya / bar_cocktail | 술집: 호프 / 일본식주점 / 칵테일바 |
| bar_pocha / bar_wine / bar_etc | 술집: 포장마차 / 와인바 / 그 외 |
| cafe / cafe_tea / cafe_theme | 카페 / 찻집·생과일·공차 / 테마카페 |
| dessert_bakery / dessert_icecream / dessert_etc | 디저트: 베이커리·도넛 / 아이스크림 / 그 외 |
| play_karaoke / play_escape / play_board / play_manga / play_arcade | 놀거리: 노래방 / 방탈출 / 보드카페 / 만화방 / 오락실 |
| play_sports / play_theme | 놀거리: 볼링·사격·클라이밍·탁구 등 / 그 외 |
| culture_performance / culture_movie / culture_gallery | 문화: 공연장 / 영화관 / 전시·미술관 등 |
| experience_workshop / experience_etc | 체험: 공예·도자기·자수 / 그 외 |
| shop_cloth / shop_select / shop_gift / shop_book / shop_etc | 쇼핑: 의류 / 패션잡화(편집숍) / 소품·문구·생활용품 / 서점 / 그 외 |
| tour_theme / nature_park | 관광 / 자연·공원 |

종류 구분은 DB 장소의 category, cuisine, 카카오 카테고리 이름 기준.
