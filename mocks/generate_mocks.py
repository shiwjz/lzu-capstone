"""오디가 가짜 응답 JSON + 서버 데이터 생성 (API 명세 v0.5 기준) - 김예민

실행: 저장소 맨 위 폴더에서  python mocks/generate_mocks.py
(장소·셀·혼잡도 파일이 바뀌면 다시 실행)

입력 파일
- output/places.csv      최예린  카카오 장소 (분류 보정·영어 코드 끝난 것 그대로 사용)
- grid_cells.csv         이윤경  50m 셀 목록
- cell_congestion.csv    이윤경  셀·요일·시간별 혼잡도 (가짜 유동인구 기반)
    · 검색·코스 혼잡도: pct_same_time / level_same_time (같은 시간끼리 비교)
    · 장소 상세 시간대 그래프: pct_all_day / level_all_day (하루 전체 비교)
- cell_congestion_seoul.csv 이윤경  서울시 생활인구 버전 혼잡도 (서버용 congestion_seoul.tsv로만 만듦)
- blog_tag/place_tag.csv  최예린  장소별 블로그 태그·언급 수 (태그 7개)
- cell_gender_age_fake.csv, cell_cluster.csv  이윤경  셀 성·연령 구성(가짜), 셀 유형(군집)
- place_score.py          이윤경  장소 점수 계산식 (import 해서 그대로 씀 → 서버 Java랑 결과 비교용)
- 셀 번호는 윤경 match_places.py랑 같은 방식(EPSG:5179 좌표 ÷ 50m)으로 직접 계산
  → places_with_cell.csv가 예전 장소 기준이어도 새 장소까지 전부 셀 붙음 (윤경 파일이랑 1,784곳 일치 확인)

- v0.4: 가짜 태그·임시 점수 → 예린 태그 + 윤경 장소 점수 모듈 (사용자 요구·타깃 특성·혼잡도 적합도 전부 계산)
- v0.5 (11/2):
    · 음식 취향: 장소마다 큰 종류(cuisine)·세부(detail) → place_cuisine.csv(예린 확정본) 있으면 그걸, 없으면 임시 분류
      (카카오 분류 → 없으면 가게 이름 → 그것도 없으면 큰 종류만) → 저장소 맨 위 place_cuisine_draft.csv로도 저장
    · 음식 큰 종류 고르면 식사 칸은 그 종류만, 세부 고르면 사용자 요구 점수에 가점 (딱 맞음 1.0 / 세부 없음 0.5 / 다른 세부 0.2)
    · 동행·인원 → 상황 태그 자동 (데이트: 연인 / 단체: 4명 이상·회사 / 혼자: 1명 / 아이: 가족) - 예린 태그 v3
    · 코스 최대 10개, 코스마다 keywords
- 거리·도보 시간·도착 시각·코스 조합: 코스 생성 규칙대로 실제 계산
- SNACK(베이커리·아이스크림 등)은 코스 칸에 안 넣음. 장소 추천·코스에 직접 추가만 가능

출력
- mocks/*.json                                   가짜 응답 JSON 15개
- capstone-backend/src/main/resources/data/      서버가 읽는 장소·혼잡도·셀 정보
    (places.tsv, congestion.tsv, congestion_seoul.tsv, cell_profile.tsv)
"""
import csv
import datetime
import itertools
import json
import math
import os
import sys

# ---------------- 코드표 (명세 '공통 규칙'과 동일) ----------------
REGION_CODE = {'성수': 'SEONGSU', '홍대': 'HONGDAE', '강남': 'GANGNAM'}
REGION_LABEL = {v: k for k, v in REGION_CODE.items()}
PLAY_CATS = ['CULTURE', 'ACTIVITY', 'EXPERIENCE', 'SHOPPING', 'TOUR', 'NATURE']
LEVEL_LABEL = {'QUIET': '한산해요', 'NORMAL': '보통이에요', 'BUSY': '붐벼요'}
LEVEL_CODE = {'한산': 'QUIET', '보통': 'NORMAL', '혼잡': 'BUSY',
              'QUIET': 'QUIET', 'NORMAL': 'NORMAL', 'BUSY': 'BUSY'}      # 예전 한글 값도 읽히게
GRID_REGION = {'SS': 'SEONGSU', 'HD': 'HONGDAE', 'GN': 'GANGNAM',
               'SEONGSU': 'SEONGSU', 'HONGDAE': 'HONGDAE', 'GANGNAM': 'GANGNAM'}
CONG = {}       # (cell_id, 'WEEKDAY'/'WEEKEND', hour) → 혼잡도 행 (가짜 유동인구, LG 데이터 모양)
CONG_SEOUL = {} # 같은 모양, 서울시 생활인구 버전 (서버 congestion_seoul.tsv용)
CELLS = []      # (cell_id, region, lat, lng)
CELL_IDS = set()

# ---------------- 코스 생성 규칙 v0.1 (초기값) ----------------
STAY_MIN = {'FOOD': 60, 'CAFE': 50, 'CULTURE': 60, 'ACTIVITY': 60, 'EXPERIENCE': 90,
            'SHOPPING': 40, 'TOUR': 40, 'NATURE': 40, 'SNACK': 30}
WALK_M_PER_MIN = 67          # 걷는 속도 4km/h
DETOUR = 1.3                 # 직선거리 → 실제 걷는 거리 보정
TARGET_MIN, TOL_MIN = 180, 30  # 총 3시간 ±30분 (3곳 기준)


def target_min(n):
    """장소 수별 목표 시간 (서버 CourseRules.targetMinutes): 2곳 135 / 3곳 180 / 4곳 245"""
    return 135 if n <= 2 else TARGET_MIN if n == 3 else 245


def tol_min(n):
    return 35 if n <= 2 else TOL_MIN if n == 3 else 45


def duration_text(m):
    return f'{m // 60}시간' if m % 60 == 0 else f'{m // 60}시간 {m % 60}분'
WALK_ZERO_MIN = 40           # 총 도보 40분이면 이동 효율 0
TOP_K = 10                   # 칸별 후보 수
W_PLACE = {'request': 0.45, 'target': 0.30, 'congestion': 0.25}
W_COURSE = {'placeAvg': 0.70, 'moveEfficiency': 0.20, 'timeFit': 0.10}
BAR_FROM_HOUR = 18           # 술집은 18시 이후 도착일 때만
# 11주차: 종류별 기본 영업시간 (여는 시, 닫는 시) - 서버 CourseRules.DEFAULT_HOURS랑 같게, 24 넘으면 다음날
DEFAULT_HOURS = {'FOOD': (11, 22), 'CAFE': (9, 22), 'SNACK': (9, 21), 'CULTURE': (10, 19), 'EXPERIENCE': (10, 21),
                 'ACTIVITY': (10, 24), 'SHOPPING': (11, 21), 'TOUR': (0, 24), 'NATURE': (0, 24)}
BAR_HOURS = (17, 26)
LATE_CULTURE_HOURS = (10, 24)  # 영화관·공연장
THEME_PLAY = ['CULTURE', 'NATURE', 'SHOPPING', 'TOUR']   # 놀거리 종류 하나만 말하면 놀거리 → 카페 → 식사
NOMINAL_STAY = {'MEAL': 60, 'CAFE': 50, 'PLAY': 60, 'BAR': 60}
BAR_LABEL = {'호프,요리주점': '호프', '일본식주점': '이자카야', '실내포장마차': '포차'}   # 경로 이름용
BETTER_START_MIN_GAIN = 8    # 덜 붐비는 출발 시간: 평균 혼잡도가 8%p 이상 낮아질 때만
# 조용한 곳 원하면 놀거리 칸에서 빼는 시끄러운 곳 (노래방 문제 대책, 카카오 카테고리·이름 기준)
NOISY_PLAY = ['노래방', '노래연습장', '코인노래', '멀티방', '오락실', 'PC방', '볼링', '당구', '클럽', 'VR', '사격']
PLAY_LABEL = {'미술,공예': '공방', '화랑': '전시', '보드카페': '보드게임', '방탈출카페': '방탈출', '만화방': '만화카페'}   # 코스 제목용
ALLERGY_EXCLUDE = {          # 알레르기 → 제외할 카카오 카테고리 단어 (초안)
    'SHELLFISH': ['해물', '조개', '게,대게', '랍스터'],
    'SEAFOOD': ['해물', '생선', '회', '초밥'],
}
CONGESTION_FIT = {           # 혼잡 선호별 구간 점수 (초안)
    'QUIET':   {'QUIET': 1.0, 'NORMAL': 0.5, 'BUSY': 0.1},
    'DEFAULT': {'QUIET': 0.8, 'NORMAL': 1.0, 'BUSY': 0.5},
    'LIVELY':  {'QUIET': 0.2, 'NORMAL': 0.6, 'BUSY': 1.0},
}
COURSE_COUNT = 10            # 추천 코스 최대 수 (v0.5, 예령 추천 리스트용)
TAGS = {}         # place_id → [{'tag', 'mentions'}] (예린 place_tag.csv, 언급 많은 순)
CUISINE = {}      # place_id → (cuisine, detail, source) 예린 place_cuisine.csv 확정본 (없으면 임시 분류)
TARGET = {}       # 윤경 load_target_data 결과: cells, cell_cluster, cluster_avg, region_avg
ps = None         # 윤경 place_score 모듈 (load_team_data에서 import)


def slot_of(cat):
    # SNACK은 코스 생성엔 안 쓰지만, 코스에 직접 추가하면 카페 칸으로 표시
    return {'FOOD': 'MEAL', 'CAFE': 'CAFE', 'SNACK': 'CAFE'}.get(cat, 'PLAY')


def hm(minutes):
    return f'{(minutes // 60) % 24:02d}:{minutes % 60:02d}'   # 자정 넘으면 00:xx (서버 CourseRules.hhmm이랑 같게)


def to_min(hhmm):
    a, b = hhmm.split(':')
    return int(a) * 60 + int(b)


def dist_m(p, q):
    R = 6371000
    lat1, lat2 = math.radians(p['lat']), math.radians(q['lat'])
    dlat = lat2 - lat1
    dlng = math.radians(q['lng'] - p['lng'])
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def walk_min(meters):
    return max(1, math.ceil(meters * DETOUR / WALK_M_PER_MIN))


def is_bar(p):
    return p.get('cuisine') == 'BAR' or '술집' in p['kakaoCategory']


def slot_of_place(p):
    """술집이면 BAR (11주차), 아니면 카테고리대로"""
    return 'BAR' if is_bar(p) else slot_of(p['category'])


def open_at(p, hour):
    """종류별 기본 영업시간 안에 도착하는지 (서버 CourseRules.openAt)"""
    if is_bar(p):
        o, c = BAR_HOURS
    elif '영화관' in p['kakaoCategory'] or '공연장' in p['kakaoCategory']:
        o, c = LATE_CULTURE_HOURS
    else:
        o, c = DEFAULT_HOURS.get(p['category'], (0, 24))
    h = hour % 24
    return (o <= h < c) or (o <= h + 24 < c)


def drinking(cond):
    """술 코스인지: 제외 음식에 술 → False, 음식 취향에 술집 → True, 말 없으면 None"""
    if '술' in (cond.get('excludedFoods') or []):
        return False
    if 'BAR' in (cond.get('cuisines') or []):
        return True
    if any(DETAIL_FAMILY.get(d) == 'BAR' for d in (cond.get('cuisineDetails') or [])):
        return True
    return None


def course_order(cond, start):
    """코스 틀 (서버 CourseRules.slotOrder(start, drinking, playCategories))"""
    hh = start // 60
    d = drinking(cond)
    picked = [c for c in cond['categories'] if c in PLAY_CATS]
    if d is True:
        if hh >= 17:
            return ['MEAL', 'BAR', 'BAR']
        return ['PLAY', 'CAFE', 'MEAL', 'BAR'] if hh == 15 else ['PLAY', 'MEAL', 'BAR']
    if hh < 17 and len(picked) == 1 and picked[0] in THEME_PLAY:
        return ['PLAY', 'CAFE', 'MEAL']
    if hh >= 20 and d is None:
        return ['MEAL', 'PLAY', 'BAR']
    return slot_order(start)


def slot_order(start):
    """시작 시각별 기본 순서"""
    hh = start // 60
    if hh < 11:
        return ['CAFE', 'PLAY', 'MEAL']
    if hh < 14:
        return ['MEAL', 'CAFE', 'PLAY']
    if hh < 17:
        return ['PLAY', 'CAFE', 'MEAL']
    return ['MEAL', 'CAFE', 'PLAY']


# ---------------- 장소 속성 ----------------
def tags_of(p):
    return TAGS.get(p['placeId'], [])


# ---------------- 음식 취향 (v0.5, 임시 분류 → 예린 place_cuisine.csv 오면 그걸 씀) ----------------
CUISINE_LABEL = {'KOREAN': '한식', 'JAPANESE': '일식', 'WESTERN': '양식', 'CHINESE': '중식', 'BUNSIK': '분식',
                 'ASIAN': '아시아', 'CHICKEN': '치킨', 'BAR': '술집', 'CAFE': '카페', 'ETC': '기타'}
# 카카오 두 번째 칸 → 큰 종류 (음식점)
KAKAO_BIG = {'한식': 'KOREAN', '일식': 'JAPANESE', '양식': 'WESTERN', '패밀리레스토랑': 'WESTERN', '패스트푸드': 'WESTERN',
             '중식': 'CHINESE', '분식': 'BUNSIK', '아시아음식': 'ASIAN', '치킨': 'CHICKEN', '술집': 'BAR'}
# 카카오 세 번째 칸 → 세부
KAKAO_DETAIL = {'육류,고기': '고기', '해물,생선': '해물·생선', '국밥': '국밥', '찌개,전골': '찌개·전골', '국수': '국수',
                '초밥,롤': '초밥·롤', '일본식라면': '라멘', '돈까스,우동': '돈까스·우동', '참치회': '초밥·롤',
                '이탈리안': '이탈리안', '피자': '피자', '햄버거': '햄버거', '스테이크,립': '스테이크', '멕시칸,브라질': '멕시칸',
                '중국요리': '중국요리', '양꼬치': '양꼬치', '떡볶이': '떡볶이', '동남아음식': '동남아', '인도음식': '인도',
                '호프,요리주점': '호프·요리주점', '일본식주점': '이자카야', '칵테일바': '칵테일바', '와인바': '와인바',
                '실내포장마차': '포장마차', '디저트카페': '디저트카페', '갤러리카페': '갤러리·북카페', '북카페': '갤러리·북카페'}
# 세부 없을 때 가게 이름으로 추정 (큰 종류 안에서만)
NAME_DETAIL = {
    'KOREAN': [('고기', ['고기', '삼겹', '갈비', '한우', '정육']), ('국밥', ['국밥', '곰탕', '설렁탕']),
               ('찌개·전골', ['찌개', '전골', '부대']), ('국수', ['국수', '칼국수', '냉면'])],
    'JAPANESE': [('초밥·롤', ['스시', '초밥', '오마카세']), ('라멘', ['라멘', '라면']),
                 ('돈까스·우동', ['돈까스', '돈카츠', '카츠', '우동', '소바']), ('덮밥', ['덮밥', '텐동', '규동', '카이센동', '히츠마부시'])],
    'WESTERN': [('이탈리안', ['파스타', '이탈리', '트라토리아']), ('피자', ['피자', '피제리아']), ('햄버거', ['버거']),
                ('스테이크', ['스테이크']), ('멕시칸', ['타코', '멕시'])],
    'CHINESE': [('양꼬치', ['양꼬치']), ('중국요리', ['마라', '짬뽕', '짜장', '반점'])],
    'BUNSIK': [('떡볶이', ['떡볶이']), ('김밥', ['김밥'])],
    'CAFE': [('디저트카페', ['디저트', '케이크', '베이커리', '구움과자'])],
}
CAFE_DRINK = ['전통찻집', '생과일전문점', '공차', '차백도', '흑화당', '홍콩다방', '차지', '다방']
CUISINE_COLS = ['place_id', 'name', 'region', 'category', 'kakao_category', 'cuisine', 'detail', 'source']


def classify_cuisine(p):
    """임시 분류 → (cuisine, detail, source). 음식점·카페만, 나머지는 (None, None, None)"""
    parts = [x.strip() for x in p['kakaoCategory'].split('>')]
    name = p['name']
    if p['category'] == 'FOOD':
        l2 = parts[1] if len(parts) > 1 else ''
        l3 = parts[2] if len(parts) > 2 else ''
        big = KAKAO_BIG.get(l2)
        if l2 == '퓨전요리':
            big = 'JAPANESE' if l3 == '퓨전일식' else 'KOREAN' if l3 == '퓨전한식' else None
        big = big or 'ETC'
        if l3 in KAKAO_DETAIL:
            return big, KAKAO_DETAIL[l3], 'KAKAO'
        if l2 == '분식' and '김밥' in l3:
            return big, '김밥', 'KAKAO'
        if l2 == '패스트푸드' and '버거' in (l3 + name):
            return big, '햄버거', 'KAKAO'
    elif p['category'] == 'CAFE':
        big = 'CAFE'
        l2 = parts[2] if len(parts) > 2 else ''     # 음식점 > 카페 > (커피전문점 / 테마카페 …)
        l3 = parts[3] if len(parts) > 3 else ''
        if l3 in KAKAO_DETAIL:
            return big, KAKAO_DETAIL[l3], 'KAKAO'
        if l2 in CAFE_DRINK:
            return big, '차·음료', 'KAKAO'
        if l2 == '바나프레소' or (l2 == '커피전문점' and l3):
            return big, '프랜차이즈', 'KAKAO'
    else:
        return None, None, None
    for detail, words in NAME_DETAIL.get(big, []):
        if any(w in name for w in words):
            return big, detail, 'NAME'
    if big == 'CAFE':
        return big, '개인카페', 'KAKAO'                # 카카오에 세부 없는 일반 카페
    return big, None, 'NONE'


def cuisine_of(p):
    if CUISINE:
        return CUISINE.get(p['placeId'], (None, None, None))
    return classify_cuisine(p)


def wants_cuisine(p, cond):
    """음식 큰 종류 골랐으면 식사 칸은 그 종류만 (카페·놀거리는 상관없음)
    11주차: 술집(BAR)은 술 코스 틀 술집 칸용 → 식사 거르기엔 안 씀"""
    cu = cond.get('cuisines') or []
    if not cu or p['category'] != 'FOOD':
        return True
    if is_bar(p):
        return 'BAR' in cu
    meal = [c for c in cu if c != 'BAR']
    return not meal or p['cuisine'] in meal




DETAIL_FAMILY = {}   # 세부 → 큰 종류 (아래에서 채움)
for _big, _pairs in NAME_DETAIL.items():
    for _d, _ in _pairs:
        DETAIL_FAMILY[_d] = _big
DETAIL_FAMILY.update({'해물·생선': 'KOREAN', '중국요리': 'CHINESE', '동남아': 'ASIAN', '인도': 'ASIAN',
                      '호프·요리주점': 'BAR', '이자카야': 'BAR', '칵테일바': 'BAR', '와인바': 'BAR', '포장마차': 'BAR',
                      '개인카페': 'CAFE', '프랜차이즈': 'CAFE', '갤러리·북카페': 'CAFE', '차·음료': 'CAFE'})


def party_moods(cond):
    """동행·인원 → 상황 태그 자동 (예린 tag_dictionary.py v3 SITUATION_RULES, 11/4, 서버 withPartyMoods랑 같게)
    데이트: COUPLE / 단체: 4명 이상 또는 COWORKER / 혼자: 1명 또는 SOLO / 아이: FAMILY"""
    n, comp = cond.get('partySize'), cond.get('companionType')
    moods = list(cond['moods'])
    for tag, ok in (('데이트', comp == 'COUPLE'),
                    ('단체', (n is not None and n >= 4) or comp == 'COWORKER'),
                    ('혼자', n == 1 or comp == 'SOLO'),
                    ('아이', comp == 'FAMILY')):
        if ok and tag not in moods:
            moods.append(tag)
    return {**cond, 'moods': moods}


def congestion(p, day_type, hour, basis='same_time'):
    """혼잡도 조회. basis = same_time(추천 점수용) / all_day(시간대 그래프용)"""
    row = CONG[(p['cellId'], day_type.upper(), hour % 24)]
    return {'hour': hour % 24, 'level': LEVEL_CODE[row[f'level_{basis}']],
            'percentile': round(float(row[f'pct_{basis}']))}


def place_score(p, cond, hour):
    """윤경 place_score.py 그대로 (혼잡 등급은 도착 시각 level_same_time)"""
    cong = congestion(p, cond['dayType'], hour)
    cell = p['cellId']
    cluster = TARGET['cluster_avg'].get(TARGET['cell_cluster'].get(cell))
    req = ps.request_score(cond['moods'], {t['tag']: t['mentions'] for t in p['tags']},   # 윤경 11/4: 세부 음식 포함
                           cond.get('cuisineDetails'), p['cuisine'], p['cuisineDetail'])
    tgt = ps.target_score(TARGET['cells'].get(cell), cluster, TARGET['region_avg'][p['region']],
                          cond.get('gender'), cond.get('ageGroup'))
    fit = ps.congestion_fit(cond['crowdPreference'], cong['level'])
    total = ps.W_REQUEST * req + ps.W_TARGET * tgt + ps.W_FIT * fit
    return {'total': round(total, 2), 'request': round(req, 2),
            'target': round(tgt, 2), 'congestion': round(fit, 2)}, cong


def reason(p, cond, cong):
    tags = sorted(p['tags'], key=lambda t: -t['mentions'])
    top = next((t['tag'] for t in tags if t['tag'] in cond['moods']), tags[0]['tag'] if tags else None)
    day = '주말' if cond['dayType'] == 'WEEKEND' else '평일'
    where = f"{day} {cong['hour']}시 주변이 {LEVEL_LABEL[cong['level']]}"
    return f"블로그 후기에서 '{top}' 언급이 많고, {where}" if top else where   # 태그 없는 곳은 혼잡도만


def summary(p, cond, hour):
    score, cong = place_score(p, cond, hour)
    return {
        'placeId': p['placeId'], 'name': p['name'], 'category': p['category'],
        'region': p['region'], 'address': p['roadAddress'] or p['address'],
        'lat': p['lat'], 'lng': p['lng'], 'phone': p['phone'], 'placeUrl': p['placeUrl'],
        'tags': p['tags'], 'cuisine': p['cuisine'], 'cuisineDetail': p['cuisineDetail'],
        'congestion': cong, 'score': score, 'reason': reason(p, cond, cong),
    }


# ---------------- 데이터 읽기 ----------------
def load(csv_path):
    rows = []
    with open(csv_path, encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            p = {'placeId': r['place_id'], 'region': r['region'], 'category': r['category'],
                 'name': r['name'], 'address': r['address'], 'roadAddress': r['road_address'] or None,
                 'phone': r['phone'] or None, 'lat': round(float(r['latitude']), 7),
                 'lng': round(float(r['longitude']), 7), 'kakaoCategory': r['kakao_category'],
                 'placeUrl': r['place_url'], 'searchKeyword': r['search_keyword'] or None}
            p['cellId'] = cell_of(float(r['latitude']), float(r['longitude'])) or nearest_cell(p)
            p['tags'] = tags_of(p)
            p['cuisine'], p['cuisineDetail'], p['cuisineSource'] = cuisine_of(p)
            rows.append(p)
    return rows


def tm5179(lat, lng):
    """위경도 → EPSG:5179(UTM-K) 좌표(m). 윤경 match_places.py의 pyproj 변환이랑 같은 값"""
    a, f = 6378137.0, 1 / 298.257222101
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    k0, lat0, lng0, fe, fn = 0.9996, math.radians(38), math.radians(127.5), 1000000, 2000000

    def arc(phi):
        return a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
                    - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
                    + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
                    - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))
    phi, lam = math.radians(lat), math.radians(lng)
    n = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    t, c = math.tan(phi) ** 2, ep2 * math.cos(phi) ** 2
    A = (lam - lng0) * math.cos(phi)
    x = fe + k0 * n * (A + (1 - t + c) * A ** 3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * A ** 5 / 120)
    y = fn + k0 * (arc(phi) - arc(lat0) + n * math.tan(phi) * (
        A * A / 2 + (5 - t + 9 * c + 4 * c * c) * A ** 4 / 24 + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * A ** 6 / 720))
    return x, y


def cell_of(lat, lng):
    x, y = tm5179(lat, lng)
    cid = f"{math.floor(x / 50)}_{math.floor(y / 50)}"
    return cid if cid in CELL_IDS else None


def nearest_cell(p):
    """셀 목록 밖(500m 경계)이면 같은 지역에서 가장 가까운 셀로 대체"""
    same = [c for c in CELLS if c[1] == p['region']]
    return min(same, key=lambda c: dist_m(p, {'lat': c[2], 'lng': c[3]}))[0]


def load_team_data(root):
    global ps
    sys.path.insert(0, root)
    import place_score as yk          # 윤경 모듈 (저장소 맨 위 place_score.py)
    ps = yk
    cells, cell_cluster, cluster_avg, region_avg = ps.load_target_data(
        os.path.join(root, 'cell_gender_age_fake.csv'), os.path.join(root, 'cell_cluster.csv'))
    TARGET.update(cells=cells, cell_cluster=cell_cluster, cluster_avg=cluster_avg, region_avg=region_avg)
    with open(os.path.join(root, 'blog_tag', 'place_tag.csv'), encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            TAGS.setdefault(r['place_id'], []).append({'tag': r['tag'], 'mentions': int(r['mentions'])})
    for tags in TAGS.values():
        tags.sort(key=lambda t: -t['mentions'])       # 언급 많은 순 (같으면 파일 순서)
    final = os.path.join(root, 'blog_tag', 'place_cuisine.csv')  # 예린 확정본 (place_id, cuisine, detail, source)
    if os.path.exists(final):
        with open(final, encoding='utf-8-sig', newline='') as f:
            for r in csv.DictReader(f):
                CUISINE[r['place_id']] = (r['cuisine'] or None, r['detail'] or None, r['source'] or None)
    with open(os.path.join(root, 'grid_cells.csv'), encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            CELLS.append((r['cell_id'], GRID_REGION[r['region']], float(r['center_lat']), float(r['center_lon'])))
            CELL_IDS.add(r['cell_id'])
    for name, target in (('cell_congestion.csv', CONG), ('cell_congestion_seoul.csv', CONG_SEOUL)):
        path = os.path.join(root, name)
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8-sig', newline='') as f:
            for r in csv.DictReader(f):
                target[(r['cell_id'], r['day_type'].upper(), int(r['hour']))] = r


def allowed(p, cond, arrive_hour):
    if p['region'] != cond['region']:
        return False
    if '술집' in p['kakaoCategory'] and arrive_hour < BAR_FROM_HOUR:
        return False
    if not open_at(p, arrive_hour):
        return False                                   # 종류별 기본 영업시간 (11주차)
    if p['category'] == 'FOOD' and ('간식' in p['kakaoCategory'] or '구내식당' in p['kakaoCategory']):
        return False                                   # 혹시 남은 간식·구내식당은 식사 칸 제외
    if wants_quiet(cond) and slot_of(p['category']) == 'PLAY' and is_noisy(p):
        return False                                   # 조용한 곳 원하면 노래방·오락실 등 제외
    if not wants_cuisine(p, cond):
        return False                                   # 음식 큰 종류 고르면 식사 칸은 그 종류만
    for code in cond['allergies']:
        if any(w in p['kakaoCategory'] for w in ALLERGY_EXCLUDE.get(code, [])):
            return False
    return True


def wants_quiet(cond):
    return cond['crowdPreference'] == 'QUIET' or '조용한' in cond['moods']


def is_noisy(p):
    text = p['kakaoCategory'] + ' ' + p['name']
    return any(w in text for w in NOISY_PLAY)


# ---------------- 코스 계산 ----------------
def build_course(stops_in, cond, start):
    """stops_in: [(place, stayMinutes)] → 시각·이동·점수가 계산된 코스"""
    t, stops, walk_total, dist_total, prev = start, [], 0, 0, None
    for i, (p, stay) in enumerate(stops_in, 1):
        d = w = None
        if prev is not None:
            d = round(dist_m(prev, p))
            w = walk_min(d)
            t += w
            walk_total += w
            dist_total += d
        score, cong = place_score(p, cond, t // 60)   # 도착 시각 기준 혼잡도 재반영
        stops.append({'order': i, 'slot': slot_of_place(p), 'placeId': p['placeId'],
                      'name': p['name'], 'category': p['category'], 'lat': p['lat'], 'lng': p['lng'],
                      'arriveAt': hm(t), 'leaveAt': hm(t + stay), 'stayMinutes': stay,
                      'walkMinutesFromPrev': w, 'distanceMetersFromPrev': d,
                      'congestion': {'level': cong['level'], 'percentile': cong['percentile']},
                      'placeScore': score['total']})
        t += stay
        prev = p
    total = t - start
    acc = 0.0
    for s in stops:                 # sum() 대신 하나씩 더하기: 파이썬 3.12 sum()은 보정 덧셈이라 Java(+=)랑 끝자리가 달라짐
        acc += s['placeScore']
    place_avg = acc / len(stops)
    move_eff = max(0.0, 1 - walk_total / WALK_ZERO_MIN)
    time_fit = max(0.0, 1 - abs(total - target_min(len(stops_in))) / tol_min(len(stops_in)))
    course_total = (W_COURSE['placeAvg'] * place_avg + W_COURSE['moveEfficiency'] * move_eff
                    + W_COURSE['timeFit'] * time_fit)
    return {'startAt': hm(start), 'endAt': hm(t), 'totalMinutes': total,
            'totalWalkMinutes': walk_total, 'totalDistanceMeters': dist_total,
            'score': {'total': round(course_total, 2), 'placeAvg': round(place_avg, 2),
                      'moveEfficiency': round(move_eff, 2), 'timeFit': round(time_fit, 2)},
            'stops': stops}


def time_word(start):
    hh = start // 60
    return '오전' if hh < 11 else '점심' if hh < 14 else '오후' if hh < 17 else '저녁' if hh < 21 else '밤'


def play_label(p):
    """카카오 카테고리에서 놀거리 종류 이름 (예: 노래방, 방탈출카페, 화랑)"""
    parts = p['kakaoCategory'].split(' > ')
    i = min(2, len(parts) - 1)
    if parts[i] == '테마카페' and len(parts) > i + 1:
        i += 1
    return PLAY_LABEL.get(parts[i], parts[i].replace(',', '·'))


def stop_label(p):
    """경로 이름용 장소 종류 (서버 CourseText.stopLabel)"""
    parts = p['kakaoCategory'].split(' > ')
    if is_bar(p):
        return BAR_LABEL.get(parts[2], parts[2].replace(',', '·')) if len(parts) > 2 else '술집'
    cat = p['category']
    if cat == 'FOOD':
        if p['cuisineDetail']:
            return p['cuisineDetail']
        if p['cuisine'] and p['cuisine'] != 'ETC':
            return CUISINE_LABEL[p['cuisine']]
        return parts[1].replace(',', '·') if len(parts) > 1 else '식당'
    if cat == 'CAFE':
        return play_label(p) if '테마카페' in p['kakaoCategory'] else '카페'
    if cat == 'SNACK':
        return '디저트'
    return play_label(p)


def course_route(course, by_id):
    """코스 경로 이름 (11주차): 칵테일바 → 카페 → 방탈출"""
    return ' → '.join(stop_label(by_id[s['placeId']]) for s in course['stops'])


def jround(x):
    """Java Math.round (반올림, .5는 올림)"""
    return int(math.floor(x + 0.5))


def avg_all_day(course, cond, shift, by_id):
    total = 0
    for s in course['stops']:
        hour = math.trunc((to_min(s['arriveAt']) + shift) / 60)   # Java 정수 나눗셈
        if shift != 0 and not open_at(by_id[s['placeId']], hour):
            return None
        total += congestion(by_id[s['placeId']], cond['dayType'], hour, 'all_day')['percentile']
    return total / len(course['stops'])


def better_start(course, cond, by_id):
    """덜 붐비는 출발 시간 (11주차, 서버 SearchService.betterStart)"""
    if cond['crowdPreference'] == 'LIVELY':
        return None
    start = to_min(course['startAt'])
    current = avg_all_day(course, cond, 0, by_id)
    best, best_shift = current, None
    for shift in (-120, -60, 60, 120):
        st = start + shift
        if st < 9 * 60 or st > 22 * 60:
            continue
        avg = avg_all_day(course, cond, shift, by_id)
        if avg is not None and avg < best:
            best, best_shift = avg, shift
    if best_shift is None or current - best < BETTER_START_MIN_GAIN:
        return None
    cur, now = jround(current), jround(best)
    word = '일찍' if best_shift < 0 else '늦게'
    return {'startTime': hm(start + best_shift), 'shiftMinutes': best_shift,
            'avgPercentile': now, 'currentAvgPercentile': cur,
            'message': f"{abs(best_shift) // 60}시간 {word} 출발하면 덜 붐벼요 (혼잡 {cur}% → {now}%)"}


def course_text(course, cond, by_id):
    """코스 제목·추천 이유 (규칙 기반)"""
    stops = course['stops']
    play = next((by_id[s['placeId']] for s in stops if s['slot'] == 'PLAY'), None)
    region = REGION_LABEL[cond['region']]
    when = time_word(to_min(course['startAt']))
    title = f"{region} {when} {play_label(play)} 코스" if play else f"{region} {when} 코스"
    parts = []
    if cond['moods']:
        mood = cond['moods'][0]
        n = sum(1 for s in stops if mood in [t['tag'] for t in by_id[s['placeId']]['tags']])
        if n:
            parts.append(f"'{mood}' 후기 많은 곳 {n}곳")
    levels = [s['congestion']['level'] for s in stops]
    if cond['crowdPreference'] == 'QUIET':
        parts.append(f"{len(stops)}곳 중 {levels.count('QUIET')}곳이 도착 시간에 한산")
    elif cond['crowdPreference'] == 'LIVELY':
        parts.append(f"{len(stops)}곳 중 {levels.count('BUSY')}곳이 도착 시간에 북적")
    parts.append(f"총 도보 {course['totalWalkMinutes']}분")
    return title, ' · '.join(parts)


def course_keywords(course, cond, by_id):
    """코스 키워드 태그 (최대 4개): 원하는 분위기 중 2곳 이상 태그 있는 것 → 한산/북적(2곳 이상) → 식사 음식 종류 → 도보 5분 이내"""
    stops = course['stops']
    out = []
    for mood in cond['moods']:
        if sum(1 for s in stops if mood in [t['tag'] for t in by_id[s['placeId']]['tags']]) >= 2:
            out.append(mood)
    levels = [s['congestion']['level'] for s in stops]
    if levels.count('QUIET') >= 2:
        out.append('한산')
    elif levels.count('BUSY') >= 2:
        out.append('북적')
    meal = next((by_id[s['placeId']] for s in stops if s['slot'] == 'MEAL'), None)
    if meal and meal['cuisine'] not in (None, 'ETC'):
        out.append(meal['cuisineDetail'] or CUISINE_LABEL[meal['cuisine']])
    if course['totalWalkMinutes'] <= 5:
        out.append('도보 5분 이내')
    return out[:4]


def warnings_of(course, cond, by_id=None):
    out = []
    n = len(course['stops'])
    hi, lo = target_min(n) + tol_min(n), target_min(n) - tol_min(n)
    if course['totalMinutes'] > hi:
        out.append({'code': 'TOTAL_TIME_OVER', 'message': f"총 {course['totalMinutes']}분으로 {duration_text(hi)}을 넘어요"})
    if course['totalMinutes'] < lo:
        out.append({'code': 'TOTAL_TIME_UNDER', 'message': f"총 {course['totalMinutes']}분으로 {duration_text(lo)}보다 짧아요"})
    for s in course['stops']:
        if s['walkMinutesFromPrev'] and s['walkMinutesFromPrev'] > 15:
            out.append({'code': 'LONG_WALK', 'message': f"{s['name']}까지 걸어서 {s['walkMinutesFromPrev']}분 걸려요"})
        if cond['crowdPreference'] == 'QUIET' and s['congestion']['level'] == 'BUSY':
            out.append({'code': 'BUSY_AT_ARRIVAL', 'message': f"{s['arriveAt']}에 {s['name']} 주변이 붐벼요"})
    for s in course['stops'] if by_id else []:      # 11주차: 기본 영업시간 밖 도착
        if not open_at(by_id[s['placeId']], int(s['arriveAt'][:2])):
            out.append({'code': 'MAYBE_CLOSED',
                        'message': f"{s['arriveAt']}에는 {s['name']} 영업이 끝났을 수 있어요 (종류별 기본 영업시간 기준)"})
    return out


def tie_break(p, cond):
    """점수 같을 때 순서 (11/4): 원하는 분위기 태그 언급 수 합 큰 곳 먼저 (서버 PlaceScorer.tieBreak랑 같게)"""
    return sum(t['mentions'] for t in p['tags'] if t['tag'] in cond['moods'])


def recommend(places, cond):
    start = to_min(cond['startTime'])
    order = course_order(cond, start)
    # 칸별 대략 도착 시각 (후보 순위용), 이동은 칸마다 10분으로 가정 - 술집 2번처럼 같은 칸 두 번 → 칸 순서대로 목록
    nominal, t = [], start
    for slot in order:
        nominal.append(t // 60)
        t += NOMINAL_STAY[slot] + 10
    bar_slot = 'BAR' in order
    play_cats = [c for c in cond['categories'] if c in PLAY_CATS] or PLAY_CATS

    def fits(p, slot):
        if slot == 'MEAL':
            return p['category'] == 'FOOD' and not (bar_slot and is_bar(p))
        if slot == 'BAR':
            return p['category'] == 'FOOD' and is_bar(p)
        return p['category'] in {'CAFE': ['CAFE'], 'PLAY': play_cats}[slot]

    cands = []
    for k, slot in enumerate(order):
        pool = [p for p in places if fits(p, slot) and allowed(p, cond, nominal[k])]
        pool.sort(key=lambda p: (-place_score(p, cond, nominal[k])[0]['total'], -tie_break(p, cond)))
        cands.append(pool[:TOP_K])
    combos, passed = [], 0
    for combo in itertools.product(*cands):
        if len({p['placeId'] for p in combo}) < len(combo):
            continue                                   # 술집 → 술집: 같은 곳 두 번은 안 됨
        c = build_course([(p, STAY_MIN[p['category']]) for p in combo], cond, start)
        if abs(c['totalMinutes'] - target_min(len(combo))) <= tol_min(len(combo)):
            passed += 1
            combos.append(c)
    combos.sort(key=lambda c: -c['score']['total'])
    chosen, used = [], set()
    for c in combos:
        ids = {s['placeId'] for s in c['stops']}
        if ids & used:
            continue
        chosen.append(c)
        used |= ids
        if len(chosen) == COURSE_COUNT:
            break
    by_id = {p['placeId']: p for p in places}
    for i, c in enumerate(chosen, 1):
        c['courseId'] = f"c_{cond['region'].lower()}_{i}"
        c['rank'] = i
        c['title'], c['reason'] = course_text(c, cond, by_id)
        c['keywords'] = course_keywords(c, cond, by_id)
        c['route'] = course_route(c, by_id)
    # 추천 장소 목록: 후보 전체에서 점수 상위 10곳
    seen, plist = set(), []
    for k in range(len(order)):
        for p in cands[k]:
            if p['placeId'] not in seen:
                seen.add(p['placeId'])
                plist.append(summary(p, cond, nominal[k]))
    plist.sort(key=lambda x: (-x['score']['total'], -tie_break(by_id[x['placeId']], cond)))
    stats = {'order': order, 'candidates': [len(v) for v in cands],
             'combos': math.prod(len(v) for v in cands), 'passedTimeRule': passed}
    return plist[:10], [ {k: c[k] for k in ['courseId', 'rank', 'title', 'reason', 'keywords', 'route', 'startAt', 'endAt', 'totalMinutes',
                          'totalWalkMinutes', 'totalDistanceMeters', 'score', 'stops']} for c in chosen], stats


def wrap(data):
    # 백엔드 ApiResponse(success, code, message, data)와 같은 모양
    return {'success': True, 'code': 'SUCCESS', 'message': '요청 성공', 'data': data}


def error(code, message):
    return {'success': False, 'code': code, 'message': message, 'data': None}


def dump(out_dir, name, obj):
    with open(os.path.join(out_dir, name), 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def dump_server_data(root, places):
    """서버가 읽는 파일 → capstone-backend/src/main/resources/data/
    - places.tsv: 장소 + 셀 번호 + 예린 태그 (이 파일 순서 그대로 써야 가짜 JSON이랑 결과 같음)
    - congestion_seoul.tsv: 같은 모양, 서울시 생활인구 버전 (서버 설정 odiga.congestion-file로 골라 씀)
    - cell_profile.tsv: 셀별 성·연령 구성 + 유형 (타깃 특성 점수용)
    - congestion.tsv: 셀·요일별 0~23시 혼잡도 두 줄 (sameTime = 같은 시간끼리 비교, allDay = 하루 전체 비교)
      값 형식: Q25 = 한산 25%, N = 보통, B = 혼잡, - = 없음
    - 정헌 ERD 확정되면 이 파일 대신 DB 테이블에서 읽기로 교체
    """
    out = os.path.join(root, 'capstone-backend', 'src', 'main', 'resources', 'data')
    if not os.path.isdir(os.path.dirname(out)):
        return
    os.makedirs(out, exist_ok=True)
    cols = ['placeId', 'name', 'region', 'category', 'kakaoCategory', 'lat', 'lng', 'cellId', 'tags',
            'address', 'roadAddress', 'phone', 'placeUrl', 'cuisine', 'cuisineDetail']
    with open(os.path.join(out, 'places.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\t'.join(cols) + '\n')
        for p in places:
            row = [p['placeId'], p['name'], p['region'], p['category'], p['kakaoCategory'],
                   repr(p['lat']), repr(p['lng']), p['cellId'],
                   '|'.join(f"{t['tag']}:{t['mentions']}" for t in p['tags']),
                   p['address'] or '', p['roadAddress'] or '', p['phone'] or '', p['placeUrl'] or '',
                   p['cuisine'] or '', p['cuisineDetail'] or '']
            f.write('\t'.join(x.replace('\t', ' ') for x in row) + '\n')
    if not CUISINE:   # 예린 확정본 오기 전: 임시 분류를 저장소 맨 위에 저장 → 예린이 고쳐서 place_cuisine.csv로
        with open(os.path.join(root, 'place_cuisine_draft.csv'), 'w', encoding='utf-8-sig', newline='') as f:
            w = csv.writer(f)
            w.writerow(CUISINE_COLS)
            for p in places:
                if p['cuisine']:
                    w.writerow([p['placeId'], p['name'], p['region'], p['category'], p['kakaoCategory'],
                                p['cuisine'], p['cuisineDetail'] or '', p['cuisineSource']])
    # 11주차: 셀 가운데 좌표 (혼잡 레이더 GET /api/congestion/grid용), 50m 칸
    with open(os.path.join(out, 'cells.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('cellId\tregion\tlat\tlng\n')
        for c, region, lat, lng in sorted(CELLS):
            f.write(f"{c}\t{region}\t{lat!r}\t{lng!r}\n")
    cells = sorted({p['cellId'] for p in places})
    write_congestion(os.path.join(out, 'congestion.tsv'), cells, CONG)
    if CONG_SEOUL:
        write_congestion(os.path.join(out, 'congestion_seoul.tsv'), cells, CONG_SEOUL)
    # 셀 성·연령·유형 (윤경 타깃 특성 점수용) - 칸 값 그대로, 유형·지역 평균은 서버가 계산
    cols = ['female_ratio', 'age_10s', 'age_20s', 'age_30s', 'age_40s', 'age_50s', 'age_60s']
    with open(os.path.join(out, 'cell_profile.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('cellId\tregion\tcluster\t' + '\t'.join(cols) + '\n')
        for c, prof in sorted(TARGET['cells'].items()):
            region = next((x[1] for x in CELLS if x[0] == c), '')
            cl = TARGET['cell_cluster'].get(c)
            f.write('\t'.join([c, region, '' if cl is None else str(int(cl))] + [repr(float(prof[k])) for k in cols]) + '\n')
    print(f'서버 데이터: 장소 {len(places)}곳, 셀 {len(cells)}개 → {out}')


def write_congestion(path, cells, cong):
    """셀·요일별 0~23시 혼잡도 두 줄 (sameTime, allDay), 값 형식: Q25 = 한산 25%, N = 보통, B = 혼잡, - = 없음"""
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('cellId\tdayType\tsameTime(h0..h23)\tallDay(h0..h23)\n')
        for c in cells:
            for day in ('WEEKDAY', 'WEEKEND'):
                cols2 = []
                for basis in ('same_time', 'all_day'):
                    hours = []
                    for hr in range(24):
                        r = cong.get((c, day, hr))
                        hours.append('-' if r is None else
                                     LEVEL_CODE[r[f'level_{basis}']][0] + str(round(float(r[f'pct_{basis}']))))
                    cols2.append(' '.join(hours))
                f.write(f"{c}\t{day}\t{cols2[0]}\t{cols2[1]}\n")


SCENARIOS = [
    ('search_seongsu_weekend_quiet.json', '토요일 오후 3시에 성수에서 친구랑 조용한 카페 가고 저녁도 먹고 싶어',
     {'region': 'SEONGSU', 'date': '2026-10-17', 'dayType': 'WEEKEND', 'startTime': '15:00', 'partySize': 2,
      'categories': ['CAFE', 'FOOD'], 'moods': ['조용한'], 'crowdPreference': 'QUIET', 'allergies': [],
      'gender': None, 'ageGroup': None, 'companionType': 'FRIEND', 'excludedFoods': [], 'cuisines': [], 'cuisineDetails': []}),
    ('search_hongdae_weekend_lively.json', '토요일 저녁 7시 홍대에서 남자친구랑 신나게 놀 수 있는 사람 많은 곳',
     {'region': 'HONGDAE', 'date': '2026-10-17', 'dayType': 'WEEKEND', 'startTime': '19:00', 'partySize': 2,
      'categories': ['FOOD', 'ACTIVITY'], 'moods': ['활기찬'], 'crowdPreference': 'LIVELY', 'allergies': [],
      'gender': None, 'ageGroup': None, 'companionType': 'COUPLE', 'excludedFoods': [], 'cuisines': [], 'cuisineDetails': []}),
    ('search_gangnam_weekday_group.json', '금요일 저녁 7시 강남역 근처에서 회사 동기 4명 모임, 한 명이 갑각류 알레르기 있어',
     {'region': 'GANGNAM', 'date': '2026-10-16', 'dayType': 'WEEKDAY', 'startTime': '19:00', 'partySize': 4,
      'categories': ['FOOD'], 'moods': [], 'crowdPreference': 'DEFAULT', 'allergies': ['SHELLFISH'],
      'gender': None, 'ageGroup': None, 'companionType': 'COWORKER', 'excludedFoods': [], 'cuisines': [], 'cuisineDetails': []}),
]


def no_course_notice(cond):
    if drinking(cond) is True and to_min(cond['startTime']) < 15 * 60:
        return '술집은 저녁 6시 이후로 넣어요. 시작 시간을 오후 3시 이후로 바꿔 보세요.'
    return '조건에 맞는 코스를 찾지 못했어요. 시간이나 조건을 바꿔 보세요.'


def main(root, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    load_team_data(root)
    places = load(os.path.join(root, 'output', 'places.csv'))
    fallback = sum(1 for p in places if cell_of(p['lat'], p['lng']) is None)
    print(f'장소 {len(places)}곳, 셀 목록 밖이라 가장 가까운 셀로 대신한 곳 {fallback}곳')
    dump_server_data(root, places)
    by_id = {p['placeId']: p for p in places}
    first = None
    for i, (fname, query, cond) in enumerate(SCENARIOS, 1):
        cond = party_moods(cond)
        plist, courses, stats = recommend(places, cond)
        data = {'searchId': f's_20261016_{i:04d}', 'query': query,
                # 분위기는 DB(user_preference.atmosphere)랑 이름 맞춰서 atmospheres로
                'conditions': {**{('atmospheres' if k == 'moods' else k): v for k, v in cond.items()},
                               'courseType': None, 'excludedCategories': [], 'includedCategories': [], 'playDetails': [],   # v0.7
                               'extractedBy': 'GEMINI'},
                'places': plist, 'courses': courses,
                'titlesBy': 'RULE', 'order': [], 'keepPlaceIds': [],   # v0.7: 감성 제목은 진짜 서버에서만
                'betterStart': better_start(courses[0], cond, by_id) if courses else None,
                'notice': None if courses else no_course_notice(cond)}
        dump(out_dir, fname, wrap(data))
        print(fname, stats)
        for c in courses:
            print('  ', c['courseId'], c['startAt'], '-', c['endAt'], c['totalMinutes'], '분 / 도보',
                  c['totalWalkMinutes'], '분', c['score'], ' | ',
                  ' → '.join(f"{s['name']}({s['category']},{s['arriveAt']})" for s in c['stops']))
        if first is None:
            first = (cond, data)

    cond, data = first
    c1 = data['courses'][0]
    # 장소 상세
    p = by_id[c1['stops'][1]['placeId']]
    score, cong = place_score(p, cond, 16)
    detail = {k: p[k] for k in ['placeId', 'name', 'category', 'region', 'address', 'roadAddress', 'phone',
                                'lat', 'lng', 'kakaoCategory', 'placeUrl']}
    detail.update({'cuisine': p['cuisine'], 'cuisineDetail': p['cuisineDetail']})
    detail.update({'openingHours': None, 'tags': p['tags'],
                   'congestionByHour': {'date': cond['date'], 'dayType': cond['dayType'],
                                        'basis': 'ALL_DAY',
                                        'hours': [congestion(p, cond['dayType'], hr, 'all_day')
                                                  for hr in range(9, 24)]},
                   # 11주차: 평일·주말 탭 (테이블링처럼) - 둘 다 9~23시, 하루 전체 비교
                   'congestionByDayType': {d: [congestion(p, d, hr, 'all_day') for hr in range(9, 24)]
                                           for d in ('WEEKDAY', 'WEEKEND')},
                   # 11주차: 요일 탭 7개 - 요일별 파일(윤경) 나오기 전엔 월~금 = 평일, 토·일 = 주말 값
                   'congestionByDay': {'source': 'DAY_TYPE',
                                       'today': ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][
                                           datetime.date.fromisoformat(cond['date']).weekday()],
                                       'days': {d: [congestion(p, 'WEEKEND' if d in ('SAT', 'SUN') else 'WEEKDAY',
                                                               hr, 'all_day') for hr in range(9, 24)]
                                                for d in ('MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN')}}})
    dump(out_dir, 'place_detail.json', wrap(detail))

    # 코스 수정 예시: 1번 체류 90분으로 늘리고 2번 카페를 다른 카페로 교체
    # 경고 2개(TOTAL_TIME_OVER·BUSY_AT_ARRIVAL)가 다 나오게: 도착 시각에 붐비는 카페로 교체 (앱 경고 화면 확인용)
    first = by_id[c1['stops'][0]['placeId']]
    used = {s['placeId'] for s in c1['stops']}
    def busy_on_arrival(x):
        arrive = to_min(cond['startTime']) + 90 + walk_min(round(dist_m(first, x)))
        return congestion(x, cond['dayType'], arrive // 60)['level'] == 'BUSY'
    alt = next(x for x in places if x['region'] == cond['region'] and x['category'] == 'CAFE'
               and x['placeId'] not in used and busy_on_arrival(x))
    edited = [(first, 90), (alt, 50), (by_id[c1['stops'][2]['placeId']], 60)]
    req = {'stops': [{'placeId': q['placeId'], 'stayMinutes': st} for q, st in edited]}
    dump(out_dir, 'course_update_request.json', req)
    upd = build_course(edited, cond, to_min(cond['startTime']))
    upd['title'], upd['reason'] = course_text(upd, cond, by_id)
    upd['keywords'] = course_keywords(upd, cond, by_id)
    upd['route'] = course_route(upd, by_id)
    upd = {'courseId': c1['courseId'], 'rank': None, 'title': upd['title'], 'reason': upd['reason'], 'keywords': upd['keywords'],
           'route': upd['route'],
           **{k: upd[k] for k in ['startAt', 'endAt', 'totalMinutes',
           'totalWalkMinutes', 'totalDistanceMeters', 'score', 'stops']}, 'warnings': warnings_of(upd, cond, by_id)}
    dump(out_dir, 'course_update_response.json', wrap(upd))

    # 공유
    lines = [f"[오디가] {cond['date']} {cond['startTime']} {REGION_LABEL[cond['region']]} 코스"]
    lines += [f"{s['order']}. {s['arriveAt']} {s['name']}" for s in c1['stops']]
    dump(out_dir, 'share_create_response.json', wrap({'shareCode': '7Hk2pQ',
         'shareUrl': 'https://example.com/share/7Hk2pQ', 'shareText': '\n'.join(lines)}))
    dump(out_dir, 'share_view_response.json', wrap({'shareCode': '7Hk2pQ', 'createdAt': '2026-10-16T20:00:00+09:00',
         'conditions': {k: cond[k] for k in ['region', 'date', 'dayType', 'startTime', 'partySize']}, 'course': c1}))

    # 회원: users(email, password_hash, region) / user_preference(atmosphere) / user_allergy(allergy_name)
    user = {'userId': 1, 'email': 'test@example.com', 'region': 'SEONGSU'}
    dump(out_dir, 'auth_signup_request.json', {'email': 'test@example.com', 'password': 'test1234!', 'region': 'SEONGSU'})
    dump(out_dir, 'auth_signup_response.json', wrap(user))
    dump(out_dir, 'auth_login_request.json', {'email': 'test@example.com', 'password': 'test1234!'})
    dump(out_dir, 'auth_login_response.json', wrap({'accessToken': 'eyJhbGciOiJIUzI1NiJ9.mock.token', 'tokenType': 'Bearer',
         'expiresIn': 3600, 'user': user}))
    dump(out_dir, 'auth_error_duplicate_email.json', error('DUPLICATE_EMAIL', '이미 사용 중인 이메일입니다.'))
    dump(out_dir, 'preferences.json', wrap({'region': 'SEONGSU', 'atmospheres': ['조용한', '감성적인'],
         'allergies': ['SHELLFISH']}))

    # 에러 예시
    dump(out_dir, 'search_error_condition_missing.json',
         error('CONDITION_MISSING', '어느 지역에서 찾을까요? (성수·홍대·강남)'))


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(here)   # 기본: mocks/ 의 상위 = 저장소
    out = sys.argv[2] if len(sys.argv) > 2 else here                      # 기본: mocks/ 폴더에 저장
    main(root, out)
