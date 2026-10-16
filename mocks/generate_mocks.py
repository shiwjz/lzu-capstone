"""오디가 가짜 응답 JSON 생성 (API 명세 v0.2 기준) - 김예민

실행: 저장소 맨 위 폴더에서  python mocks/generate_mocks.py

입력 파일
- output/places.csv      최예린  카카오 장소 (이름·좌표·주소 그대로 사용)
- places_with_cell.csv   이윤경  장소 → 50m 셀 매칭 (셀 없으면 가장 가까운 셀로 대체)
- grid_cells.csv         이윤경  50m 셀 목록
- congestion_fake.csv    이윤경  셀·요일·시간별 혼잡도 (가짜 유동인구 기반)
    · 검색·코스 혼잡도: pct_same_time / level_same_time (같은 시간끼리 비교)
    · 장소 상세 시간대 그래프: pct_all_day / level_all_day (하루 전체 비교)

- 태그, 사용자 요구·타깃 점수: 블로그·성연령 데이터 전이라 아직 가짜 값 (place_id 해시)
- 거리·도보 시간·도착 시각·코스 조합: 코스 생성 규칙 v0.1대로 실제 계산
"""
import csv
import hashlib
import itertools
import json
import math
import os
import sys

# ---------------- 코드표 (명세 '공통 규칙'과 동일) ----------------
REGION_CODE = {'성수': 'SEONGSU', '홍대': 'HONGDAE', '강남': 'GANGNAM'}
REGION_LABEL = {v: k for k, v in REGION_CODE.items()}
CAT_CODE = {'음식': 'FOOD', '카페': 'CAFE', '문화': 'CULTURE', '액티비티': 'ACTIVITY',
            '체험': 'EXPERIENCE', '쇼핑': 'SHOPPING', '관광': 'TOUR', '자연/휴식': 'NATURE'}
PLAY_CATS = ['CULTURE', 'ACTIVITY', 'EXPERIENCE', 'SHOPPING', 'TOUR', 'NATURE']
LEVEL_LABEL = {'QUIET': '한산해요', 'NORMAL': '보통이에요', 'BUSY': '붐벼요'}
LEVEL_CODE = {'한산': 'QUIET', '보통': 'NORMAL', '혼잡': 'BUSY'}          # 윤경 CSV 값 → API 코드
GRID_REGION = {'SS': 'SEONGSU', 'HD': 'HONGDAE', 'GN': 'GANGNAM'}
CONG = {}       # (cell_id, 'weekday'/'weekend', hour) → 혼잡도 행
CELL_OF = {}    # place_id → cell_id
CELLS = []      # (cell_id, region, lat, lng)

# ---------------- 코스 생성 규칙 v0.1 (초기값) ----------------
STAY_MIN = {'FOOD': 60, 'CAFE': 50, 'CULTURE': 60, 'ACTIVITY': 60, 'EXPERIENCE': 90,
            'SHOPPING': 40, 'TOUR': 40, 'NATURE': 40}
WALK_M_PER_MIN = 67          # 걷는 속도 4km/h
DETOUR = 1.3                 # 직선거리 → 실제 걷는 거리 보정
TARGET_MIN, TOL_MIN = 180, 30  # 총 3시간 ±30분
WALK_ZERO_MIN = 40           # 총 도보 40분이면 이동 효율 0
TOP_K = 10                   # 칸별 후보 수
W_PLACE = {'request': 0.45, 'target': 0.30, 'congestion': 0.25}
W_COURSE = {'placeAvg': 0.70, 'moveEfficiency': 0.20, 'timeFit': 0.10}
BAR_FROM_HOUR = 18           # 술집은 18시 이후 도착일 때만
NOISE_TOP = {'서비스,산업', '교육,학문', '의료,건강', '교통,수송', '부동산', '사회,공공기관'}
THEME_CAFE_TO_PLAY = {'사주카페', '고양이카페', '애견카페', '라이브카페'}
ALLERGY_EXCLUDE = {          # 알레르기 → 제외할 카카오 카테고리 단어 (초안)
    'SHELLFISH': ['해물', '조개', '게,대게', '랍스터'],
    'SEAFOOD': ['해물', '생선', '회', '초밥'],
}
CONGESTION_FIT = {           # 혼잡 선호별 구간 점수 (초안)
    'QUIET':   {'QUIET': 1.0, 'NORMAL': 0.5, 'BUSY': 0.1},
    'DEFAULT': {'QUIET': 0.8, 'NORMAL': 1.0, 'BUSY': 0.5},
    'LIVELY':  {'QUIET': 0.2, 'NORMAL': 0.6, 'BUSY': 1.0},
}
TAG_POOL = {
    'FOOD': ['데이트', '단체석', '가성비', '웨이팅', '분위기', '혼밥'],
    'CAFE': ['조용함', '디저트', '사진·인테리어', '공간·좌석', '작업하기 좋음', '데이트'],
    'PLAY': ['데이트', '사진·인테리어', '실내', '활동적', '이색 체험', '조용함'],
}


def h(*parts):
    """같은 입력이면 항상 같은 0~1 값 (가짜 점수용)"""
    s = '|'.join(map(str, parts))
    return int(hashlib.md5(s.encode()).hexdigest()[:8], 16) / 0xFFFFFFFF


def slot_of(cat):
    return {'FOOD': 'MEAL', 'CAFE': 'CAFE'}.get(cat, 'PLAY')


def hm(minutes):
    return f'{minutes // 60:02d}:{minutes % 60:02d}'


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


# ---------------- 가짜 장소 속성 ----------------
def tags_of(p):
    pool = TAG_POOL['PLAY' if slot_of(p['category']) == 'PLAY' else p['category']]
    picked = sorted(pool, key=lambda t: h(p['placeId'], 'tag', t))[:3]
    return [{'tag': t, 'mentions': 2 + int(h(p['placeId'], 'm', t) * 9)} for t in picked]


def congestion(p, day_type, hour, basis='same_time'):
    """혼잡도 조회. basis = same_time(추천 점수용) / all_day(시간대 그래프용)"""
    row = CONG[(p['cellId'], day_type.lower(), hour % 24)]
    return {'hour': hour % 24, 'level': LEVEL_CODE[row[f'level_{basis}']],
            'percentile': round(float(row[f'pct_{basis}']))}


def place_score(p, cond, hour):
    tags = [t['tag'] for t in p['tags']]
    match = any(m in tags for m in cond['moods'])
    request = 0.5 + (0.4 if match else 0) + 0.1 * h(p['placeId'], 'req')
    target = 0.5 + 0.45 * h(p['placeId'], 'tgt', cond['partySize'])
    cong = congestion(p, cond['dayType'], hour)
    cfit = CONGESTION_FIT[cond['crowdPreference']][cong['level']]
    total = W_PLACE['request'] * request + W_PLACE['target'] * target + W_PLACE['congestion'] * cfit
    return {'total': round(total, 2), 'request': round(request, 2),
            'target': round(target, 2), 'congestion': round(cfit, 2)}, cong


def reason(p, cond, cong):
    tags = sorted(p['tags'], key=lambda t: -t['mentions'])
    top = next((t['tag'] for t in tags if t['tag'] in cond['moods']), tags[0]['tag'])
    day = '주말' if cond['dayType'] == 'WEEKEND' else '평일'
    return f"블로그 후기에서 '{top}' 언급이 많고, {day} {cong['hour']}시 주변이 {LEVEL_LABEL[cong['level']]}"


def summary(p, cond, hour):
    score, cong = place_score(p, cond, hour)
    return {
        'placeId': p['placeId'], 'name': p['name'], 'category': p['category'],
        'region': p['region'], 'address': p['roadAddress'] or p['address'],
        'lat': p['lat'], 'lng': p['lng'], 'phone': p['phone'], 'placeUrl': p['placeUrl'],
        'tags': p['tags'], 'congestion': cong, 'score': score, 'reason': reason(p, cond, cong),
    }


# ---------------- 데이터 읽기 ----------------
def load(csv_path):
    rows = []
    with open(csv_path, encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            p = {'placeId': r['place_id'], 'region': REGION_CODE[r['region']],
                 'category': CAT_CODE[r['category']], 'name': r['name'],
                 'address': r['address'], 'roadAddress': r['road_address'] or None,
                 'phone': r['phone'] or None, 'lat': round(float(r['latitude']), 7),
                 'lng': round(float(r['longitude']), 7), 'kakaoCategory': r['kakao_category'],
                 'placeUrl': r['place_url'], 'searchKeyword': r['search_keyword'] or None}
            # 데이터 정리 규칙 v0.1
            top = p['kakaoCategory'].split(' > ')[0]
            if top in NOISE_TOP or '키즈카페' in p['kakaoCategory']:   # 공간대여·학원·주차장·키즈카페 제외
                continue
            if p['category'] == 'CAFE' and p['kakaoCategory'].startswith('가정,생활 > 여가시설'):
                p['category'] = 'ACTIVITY'             # 보드게임·만화카페는 놀거리로
            parts = p['kakaoCategory'].split(' > ')
            if p['category'] == 'CAFE' and '테마카페' in parts:
                sub = parts[parts.index('테마카페') + 1] if parts[-1] != '테마카페' else None
                if sub is None or sub in THEME_CAFE_TO_PLAY:
                    p['category'] = 'ACTIVITY'         # 방탈출·사주·동물카페는 놀거리로
            p['cellId'] = CELL_OF.get(p['placeId']) or nearest_cell(p)
            p['tags'] = tags_of(p)
            rows.append(p)
    return rows


def nearest_cell(p):
    """셀 매칭 없는 장소(500m 경계 근처 등)는 같은 지역에서 가장 가까운 셀로 대체"""
    same = [c for c in CELLS if c[1] == p['region']]
    return min(same, key=lambda c: dist_m(p, {'lat': c[2], 'lng': c[3]}))[0]


def load_team_data(root):
    with open(os.path.join(root, 'grid_cells.csv'), encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            CELLS.append((r['cell_id'], GRID_REGION[r['region']], float(r['center_lat']), float(r['center_lon'])))
    with open(os.path.join(root, 'places_with_cell.csv'), encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            if r['cell_id']:
                CELL_OF[r['place_id']] = r['cell_id']
    with open(os.path.join(root, 'congestion_fake.csv'), encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            CONG[(r['cell_id'], r['day_type'], int(r['hour']))] = r


def allowed(p, cond, arrive_hour):
    if p['region'] != cond['region']:
        return False
    if '술집' in p['kakaoCategory'] and arrive_hour < BAR_FROM_HOUR:
        return False
    if p['category'] == 'FOOD' and ('간식' in p['kakaoCategory'] or '구내식당' in p['kakaoCategory']):
        return False                                   # 베이커리·아이스크림·구내식당은 식사 칸 제외
    for code in cond['allergies']:
        if any(w in p['kakaoCategory'] for w in ALLERGY_EXCLUDE.get(code, [])):
            return False
    return True


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
        stops.append({'order': i, 'slot': slot_of(p['category']), 'placeId': p['placeId'],
                      'name': p['name'], 'category': p['category'], 'lat': p['lat'], 'lng': p['lng'],
                      'arriveAt': hm(t), 'leaveAt': hm(t + stay), 'stayMinutes': stay,
                      'walkMinutesFromPrev': w, 'distanceMetersFromPrev': d,
                      'congestion': {'level': cong['level'], 'percentile': cong['percentile']},
                      'placeScore': score['total']})
        t += stay
        prev = p
    total = t - start
    place_avg = sum(s['placeScore'] for s in stops) / len(stops)
    move_eff = max(0.0, 1 - walk_total / WALK_ZERO_MIN)
    time_fit = max(0.0, 1 - abs(total - TARGET_MIN) / TOL_MIN)
    course_total = (W_COURSE['placeAvg'] * place_avg + W_COURSE['moveEfficiency'] * move_eff
                    + W_COURSE['timeFit'] * time_fit)
    return {'startAt': hm(start), 'endAt': hm(t), 'totalMinutes': total,
            'totalWalkMinutes': walk_total, 'totalDistanceMeters': dist_total,
            'score': {'total': round(course_total, 2), 'placeAvg': round(place_avg, 2),
                      'moveEfficiency': round(move_eff, 2), 'timeFit': round(time_fit, 2)},
            'stops': stops}


def warnings_of(course, cond):
    out = []
    if course['totalMinutes'] > TARGET_MIN + TOL_MIN:
        out.append({'code': 'TOTAL_TIME_OVER', 'message': f"총 {course['totalMinutes']}분으로 3시간 30분을 넘어요"})
    if course['totalMinutes'] < TARGET_MIN - TOL_MIN:
        out.append({'code': 'TOTAL_TIME_UNDER', 'message': f"총 {course['totalMinutes']}분으로 2시간 30분보다 짧아요"})
    for s in course['stops']:
        if s['walkMinutesFromPrev'] and s['walkMinutesFromPrev'] > 15:
            out.append({'code': 'LONG_WALK', 'message': f"{s['name']}까지 걸어서 {s['walkMinutesFromPrev']}분 걸려요"})
        if cond['crowdPreference'] == 'QUIET' and s['congestion']['level'] == 'BUSY':
            out.append({'code': 'BUSY_AT_ARRIVAL', 'message': f"{s['arriveAt']}에 {s['name']} 주변이 붐벼요"})
    return out


def recommend(places, cond):
    start = to_min(cond['startTime'])
    order = slot_order(start)
    # 칸별 대략 도착 시각 (후보 순위용), 이동은 칸마다 10분으로 가정
    nominal, t = {}, start
    for slot in order:
        nominal[slot] = t // 60
        t += {'MEAL': 60, 'CAFE': 50, 'PLAY': 60}[slot] + 10
    play_cats = [c for c in cond['categories'] if c in PLAY_CATS] or PLAY_CATS
    cands = {}
    for slot in order:
        cats = {'MEAL': ['FOOD'], 'CAFE': ['CAFE'], 'PLAY': play_cats}[slot]
        pool = [p for p in places if p['category'] in cats and allowed(p, cond, nominal[slot])]
        pool.sort(key=lambda p: -place_score(p, cond, nominal[slot])[0]['total'])
        cands[slot] = pool[:TOP_K]
    combos, passed = [], 0
    for combo in itertools.product(*(cands[s] for s in order)):
        c = build_course([(p, STAY_MIN[p['category']]) for p in combo], cond, start)
        if abs(c['totalMinutes'] - TARGET_MIN) <= TOL_MIN:
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
        if len(chosen) == 3:
            break
    for i, c in enumerate(chosen, 1):
        c['courseId'] = f"c_{cond['region'].lower()}_{i}"
        c['rank'] = i
    # 추천 장소 목록: 후보 전체에서 점수 상위 10곳
    seen, plist = set(), []
    for slot in order:
        for p in cands[slot]:
            if p['placeId'] not in seen:
                seen.add(p['placeId'])
                plist.append(summary(p, cond, nominal[slot]))
    plist.sort(key=lambda x: -x['score']['total'])
    stats = {'order': order, 'candidates': {s: len(v) for s, v in cands.items()},
             'combos': math.prod(len(v) for v in cands.values()), 'passedTimeRule': passed}
    return plist[:10], [ {k: c[k] for k in ['courseId', 'rank', 'startAt', 'endAt', 'totalMinutes',
                          'totalWalkMinutes', 'totalDistanceMeters', 'score', 'stops']} for c in chosen], stats


def wrap(data):
    # 백엔드 ApiResponse(success, code, message, data)와 같은 모양
    return {'success': True, 'code': 'SUCCESS', 'message': '요청 성공', 'data': data}


def error(code, message):
    return {'success': False, 'code': code, 'message': message, 'data': None}


def dump(out_dir, name, obj):
    with open(os.path.join(out_dir, name), 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


SCENARIOS = [
    ('search_seongsu_weekend_quiet.json', '토요일 오후 3시에 성수에서 친구랑 조용한 카페 가고 저녁도 먹고 싶어',
     {'region': 'SEONGSU', 'date': '2026-10-17', 'dayType': 'WEEKEND', 'startTime': '15:00', 'partySize': 2,
      'categories': ['CAFE', 'FOOD'], 'moods': ['조용함'], 'crowdPreference': 'QUIET', 'allergies': []}),
    ('search_hongdae_weekend_lively.json', '토요일 저녁 7시 홍대에서 남자친구랑 신나게 놀 수 있는 사람 많은 곳',
     {'region': 'HONGDAE', 'date': '2026-10-17', 'dayType': 'WEEKEND', 'startTime': '19:00', 'partySize': 2,
      'categories': ['FOOD', 'ACTIVITY'], 'moods': ['데이트'], 'crowdPreference': 'LIVELY', 'allergies': []}),
    ('search_gangnam_weekday_group.json', '금요일 저녁 7시 강남역 근처에서 회사 동기 4명 모임, 한 명이 갑각류 알레르기 있어',
     {'region': 'GANGNAM', 'date': '2026-10-16', 'dayType': 'WEEKDAY', 'startTime': '19:00', 'partySize': 4,
      'categories': ['FOOD'], 'moods': ['단체석'], 'crowdPreference': 'DEFAULT', 'allergies': ['SHELLFISH']}),
]


def main(root, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    load_team_data(root)
    places = load(os.path.join(root, 'output', 'places.csv'))
    fallback = sum(1 for p in places if p['placeId'] not in CELL_OF)
    print(f'장소 {len(places)}곳, 셀 매칭 없어 가장 가까운 셀로 대신한 곳 {fallback}곳')
    by_id = {p['placeId']: p for p in places}
    first = None
    for i, (fname, query, cond) in enumerate(SCENARIOS, 1):
        plist, courses, stats = recommend(places, cond)
        data = {'searchId': f's_20261016_{i:04d}', 'query': query,
                # 분위기는 DB(user_preference.atmosphere)랑 이름 맞춰서 atmospheres로
                'conditions': {**{('atmospheres' if k == 'moods' else k): v for k, v in cond.items()},
                               'extractedBy': 'GEMINI'},
                'places': plist, 'courses': courses,
                'notice': None if courses else '조건에 맞는 코스를 찾지 못했어요. 시간이나 조건을 바꿔 보세요.'}
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
    detail.update({'openingHours': None, 'tags': p['tags'],
                   'congestionByHour': {'date': cond['date'], 'dayType': cond['dayType'],
                                        'basis': 'ALL_DAY',
                                        'hours': [congestion(p, cond['dayType'], hr, 'all_day')
                                                  for hr in range(9, 24)]}})
    dump(out_dir, 'place_detail.json', wrap(detail))

    # 코스 수정 예시: 1번 체류 90분으로 늘리고 2번 카페를 다른 카페로 교체
    alt = next(x for x in places if x['region'] == cond['region'] and x['category'] == 'CAFE'
               and x['placeId'] not in {s['placeId'] for s in c1['stops']} and '조용함' in [t['tag'] for t in x['tags']])
    edited = [(by_id[c1['stops'][0]['placeId']], 90), (alt, 50), (by_id[c1['stops'][2]['placeId']], 60)]
    req = {'stops': [{'placeId': q['placeId'], 'stayMinutes': st} for q, st in edited]}
    dump(out_dir, 'course_update_request.json', req)
    upd = build_course(edited, cond, to_min(cond['startTime']))
    upd = {'courseId': c1['courseId'], 'rank': None, **{k: upd[k] for k in ['startAt', 'endAt', 'totalMinutes',
           'totalWalkMinutes', 'totalDistanceMeters', 'score', 'stops']}, 'warnings': warnings_of(upd, cond)}
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
    dump(out_dir, 'preferences.json', wrap({'region': 'SEONGSU', 'atmospheres': ['조용함', '디저트'],
         'allergies': ['SHELLFISH']}))

    # 에러 예시
    dump(out_dir, 'search_error_condition_missing.json',
         error('CONDITION_MISSING', '어느 지역에서 찾을까요? (성수·홍대·강남)'))


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(here)   # 기본: mocks/ 의 상위 = 저장소
    out = sys.argv[2] if len(sys.argv) > 2 else here                      # 기본: mocks/ 폴더에 저장
    main(root, out)
