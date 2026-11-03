"""
구글 리뷰로 정량평가 정답 만들기 (10주차, 11/1 결정) - 김예민

왜 하나
- 윤경 평가(Precision@5 1.00)는 정답을 우리 점수랑 같은 신호(블로그 태그·혼잡도)로 정해서 우리한테 유리함 (순환)
- 정답을 '구글 리뷰'라는 다른 출처로 정하면 공정한 비교가 됨

하는 일
1. fetch: 평가에 나온 장소(카카오 place_id)마다 구글 Places API(New) Text Search로 같은 가게 찾기
   - 이름으로 검색 + 카카오 좌표 근처(반경 200m)로 치우치게 → 결과 중 150m 안에서 제일 가까운 것
   - 구글 별점·리뷰 수·가격대 + 리뷰 최대 5개에서 태그 단어 나오는지 '표시(숫자)'만 저장
   - **리뷰 글 자체는 파일에 저장하지 않음, 깃허브에도 안 올림** (구글 약관 + 개인정보)
2. score: 방법별 순위 CSV + fetch 결과로 Precision@5·nDCG@5 다시 계산

실행 (저장소 맨 위 폴더에서)
  export GOOGLE_PLACES_API_KEY=...        # 키는 코드·깃허브·카톡에 올리지 않기
  python eval/google_reviews.py fetch eval/eval_places.csv            # → eval/google_flags.csv
  python eval/google_reviews.py fetch eval/eval_places.csv --dry-run  # 요청 내용만 보기 (API 안 부름, 키 없어도 됨)
  python eval/google_reviews.py score eval/eval_ranking.csv           # → 화면에 표
  python eval/google_reviews.py fetch output/places.csv --limit 10    # 전체 장소용 (반려견 등 필터 정보), 먼저 10곳만

입력 파일
- eval_places.csv: place_id 열(또는 placeId)만 있으면 됨, 중복은 알아서 뺌
  → 윤경 평가에서 방법 4개 × 시나리오별 상위 5곳 합친 목록
- eval_ranking.csv: scenario, method, rank, place_id, moods 열 (moods는 '조용함|데이트'처럼 | 로 구분, 없으면 빈칸)
  → @이윤경 평가 스크립트에서 이 모양으로 뽑아주기

주의
- Text Search에 reviews 필드를 달면 비싼 등급(Enterprise + Atmosphere)으로 계산됨 → 먼저 --dry-run, 10곳만 --limit 10으로 시험
- 이미 결과 파일에 있는 장소는 건너뜀 → 중간에 끊겨도 다시 돌리면 이어서 함
- 구글이 주는 리뷰는 장소당 최대 5개라 '언급 수'는 0~5
"""
import argparse
import csv
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLACES_CSV = os.path.join(ROOT, 'output', 'places.csv')
DEFAULT_OUT = os.path.join(ROOT, 'eval', 'google_flags.csv')

API_URL = 'https://places.googleapis.com/v1/places:searchText'
FIELD_MASK = ','.join(['places.id', 'places.displayName', 'places.location', 'places.rating',
                       'places.userRatingCount', 'places.priceLevel', 'places.reviews']
                      + [f'places.{a}' for a in ('allowsDogs', 'outdoorSeating', 'goodForGroups',
                                                 'goodForChildren', 'reservable', 'servesDessert')])
# 구글이 예/아니오로 주는 장소 정보 (리뷰 추측 아님 → 필터용, 11/4 회의: 반려견 동반)
# - 값 없으면 빈칸 (구글이 모름), 저장값은 1 / 0 / 빈칸
ATTRS = {'allowsDogs': 'dogs', 'outdoorSeating': 'outdoor', 'goodForGroups': 'groups',
         'goodForChildren': 'children', 'reservable': 'reservable', 'servesDessert': 'dessert'}
BIAS_RADIUS_M = 200.0     # 검색 치우치게 하는 반경
MATCH_MAX_M = 150.0       # 이 거리 넘으면 다른 가게로 봄
SLEEP_SEC = 0.2           # 요청 사이 쉬기

# 태그 7개(예린)와 같은 이름, 리뷰에 이 단어가 있으면 그 태그 '언급'으로 셈
# - 블로그 태그 사전이랑 일부러 똑같이 하지 않음 (같으면 또 순환) → 리뷰에서 자연스럽게 쓰는 말 위주
TAG_WORDS = {
    '조용함': ['조용', '한적', '아늑', '차분', '잔잔'],
    '데이트': ['데이트', '연인', '남자친구', '여자친구', '남친', '여친', '기념일'],
    '단체': ['단체', '모임', '회식', '여럿이', '단체석', '룸'],
    '혼자가능': ['혼밥', '혼자', '혼술', '혼카페', '1인'],
    '디저트': ['디저트', '케이크', '빵', '마카롱', '쿠키', '타르트'],
    '사진': ['사진', '인스타', '포토', '감성', '예쁘', '이쁘'],
    '가성비': ['가성비', '저렴', '싸고', '착한 가격', '가격 대비', '양 많'],
}
# 혼잡 반대 신호 (조용함 판단 때 같이 봄)
BUSY_WORDS = ['시끄', '북적', '웨이팅', '줄 서', '줄서', '복잡', '사람 많']

OUT_COLS = (['place_id', 'name', 'google_place_id', 'match_m', 'rating', 'rating_count', 'price_level', 'n_reviews']
            + [f'flag_{t}' for t in TAG_WORDS] + ['flag_busy'] + [f'attr_{v}' for v in ATTRS.values()] + ['status'])

PRICE = {'PRICE_LEVEL_FREE': 0, 'PRICE_LEVEL_INEXPENSIVE': 1, 'PRICE_LEVEL_MODERATE': 2,
         'PRICE_LEVEL_EXPENSIVE': 3, 'PRICE_LEVEL_VERY_EXPENSIVE': 4}


# ---------------- 공통 ----------------
def load_places():
    with open(PLACES_CSV, encoding='utf-8-sig') as f:
        return {r['place_id']: r for r in csv.DictReader(f)}


def read_ids(path):
    ids = []
    with open(path, encoding='utf-8-sig') as f:
        for r in csv.DictReader(f):
            pid = (r.get('place_id') or r.get('placeId') or '').strip()
            if pid and pid not in ids:
                ids.append(pid)
    return ids


def meters(lat1, lng1, lat2, lng2):
    """두 좌표 거리(m), 짧은 거리라 단순 공식"""
    k = 111320.0
    dx = (lng2 - lng1) * k * math.cos(math.radians((lat1 + lat2) / 2))
    dy = (lat2 - lat1) * k
    return math.hypot(dx, dy)


# ---------------- fetch ----------------
def request_body(place):
    return {
        'textQuery': place['name'],
        'languageCode': 'ko',
        'regionCode': 'KR',
        'maxResultCount': 5,
        'locationBias': {'circle': {
            'center': {'latitude': float(place['latitude']), 'longitude': float(place['longitude'])},
            'radius': BIAS_RADIUS_M}},
    }


def call_api(body, key):
    req = urllib.request.Request(API_URL, data=json.dumps(body).encode('utf-8'), method='POST', headers={
        'Content-Type': 'application/json', 'X-Goog-Api-Key': key, 'X-Goog-FieldMask': FIELD_MASK})
    with urllib.request.urlopen(req, timeout=15) as res:
        return json.loads(res.read().decode('utf-8'))


def pick(place, results):
    """구글 결과 중 카카오 좌표에서 150m 안 제일 가까운 것 (없으면 None)"""
    lat, lng = float(place['latitude']), float(place['longitude'])
    best, best_m = None, None
    for g in results or []:
        loc = g.get('location') or {}
        if 'latitude' not in loc:
            continue
        m = meters(lat, lng, loc['latitude'], loc['longitude'])
        if m <= MATCH_MAX_M and (best_m is None or m < best_m):
            best, best_m = g, m
    return best, best_m


def flags(reviews):
    """리뷰 글에서 태그 단어 나온 리뷰 수만 셈 (글은 여기서 버림)"""
    texts = [((r.get('text') or {}).get('text') or (r.get('originalText') or {}).get('text') or '') for r in reviews or []]
    out = {t: sum(1 for x in texts if any(w in x for w in ws)) for t, ws in TAG_WORDS.items()}
    out['busy'] = sum(1 for x in texts if any(w in x for w in BUSY_WORDS))
    return out, len(texts)


def row_for(place, g, m):
    if g is None:
        return {'place_id': place['place_id'], 'name': place['name'], 'status': 'NO_MATCH'}
    f, n = flags(g.get('reviews'))
    row = {'place_id': place['place_id'], 'name': place['name'], 'google_place_id': g.get('id', ''),
           'match_m': round(m), 'rating': g.get('rating', ''), 'rating_count': g.get('userRatingCount', ''),
           'price_level': PRICE.get(g.get('priceLevel'), ''), 'n_reviews': n, 'flag_busy': f['busy'], 'status': 'OK'}
    for t in TAG_WORDS:
        row[f'flag_{t}'] = f[t]
    for k, v in ATTRS.items():
        row[f'attr_{v}'] = '' if g.get(k) is None else int(bool(g[k]))
    return row


def fetch(args):
    places = load_places()
    ids = read_ids(args.input)
    missing = [i for i in ids if i not in places]
    if missing:
        print(f'output/places.csv에 없는 place_id {len(missing)}개 건너뜀: {missing[:5]}')
    ids = [i for i in ids if i in places]

    done = set()
    if os.path.exists(args.out):
        with open(args.out, encoding='utf-8-sig') as f:
            done = {r['place_id'] for r in csv.DictReader(f)}
    todo = [i for i in ids if i not in done][:args.limit] if args.limit else [i for i in ids if i not in done]
    print(f'장소 {len(ids)}곳 중 이미 한 곳 {len(done & set(ids))}, 이번에 {len(todo)}곳')

    if args.dry_run:
        for pid in todo[:3]:
            print(json.dumps(request_body(places[pid]), ensure_ascii=False))
        print(f'(dry-run) 요청 {len(todo)}번 예정, FieldMask: {FIELD_MASK}')
        return

    key = os.environ.get('GOOGLE_PLACES_API_KEY')
    if not key:
        sys.exit('GOOGLE_PLACES_API_KEY 환경변수 넣고 다시 실행 (키는 코드에 쓰지 않기)')
    if not key.isascii() or ' ' in key:
        sys.exit('키에 한글·공백이 들어가 있음 → export GOOGLE_PLACES_API_KEY=AIza... 처럼 키만 다시 넣기')

    new_file = not os.path.exists(args.out)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, 'a', encoding='utf-8', newline='') as f:
        w = csv.DictWriter(f, fieldnames=OUT_COLS)
        if new_file:
            w.writeheader()
        errors = 0
        for k, pid in enumerate(todo, 1):
            place = places[pid]
            try:
                res = call_api(request_body(place), key)
                g, m = pick(place, res.get('places'))
                row = row_for(place, g, m)
            except urllib.error.HTTPError as e:
                if e.code in (401, 403):
                    sys.exit(f'API 키·권한 문제 ({e.code}) → Places API (New) 켜졌는지, 키 제한 확인')
                if e.code == 429:
                    print('요청 너무 많음 → 30초 쉬고 다음 장소'); time.sleep(30)
                row = {'place_id': pid, 'name': place['name'], 'status': f'HTTP_{e.code}'}
            except Exception as e:      # 인터넷 끊김 등 → 저장 안 하고 넘어감 (다시 돌리면 그 장소만 다시 함)
                errors += 1
                print(f'  실패 {pid} {type(e).__name__}')
                if errors >= 3:
                    sys.exit('3번 연속 실패 → 멈춤 (키·인터넷 확인)')
                continue
            errors = 0
            w.writerow(row)
            f.flush()
            if k % 20 == 0 or k == len(todo):
                print(f'  {k}/{len(todo)}')
            time.sleep(SLEEP_SEC)
    print(f'저장: {args.out}')


# ---------------- score ----------------
def relevance(flag_row, moods):
    """구글 기준 '맞는 장소' 점수 0~1 (윤경이랑 맞출 것, 지금은 초안)
    - 요청 분위기 있으면: 분위기마다 리뷰 1개 이상 언급 → 1, 아니면 0 → 평균
      · 조용함은 '시끄·웨이팅' 언급이 조용 언급보다 많으면 0
    - 요청 분위기 없으면: 구글 별점 4.0 이상 → 1
    - 구글에서 못 찾은 장소는 None (평가에서 뺌)"""
    if flag_row is None or flag_row.get('status') != 'OK':
        return None
    if not moods:
        try:
            return 1.0 if float(flag_row['rating']) >= 4.0 else 0.0
        except (TypeError, ValueError):
            return None
    hits = []
    for t in moods:
        n = int(flag_row.get(f'flag_{t}') or 0)
        if t == '조용함' and int(flag_row.get('flag_busy') or 0) > n:
            n = 0
        hits.append(1.0 if n >= 1 else 0.0)
    return sum(hits) / len(hits)


def ndcg(rels, k=5):
    dcg = sum(r / math.log2(i + 2) for i, r in enumerate(rels[:k]))
    ideal = sorted(rels, reverse=True)
    idcg = sum(r / math.log2(i + 2) for i, r in enumerate(ideal[:k]))
    return dcg / idcg if idcg > 0 else 0.0


def score(args):
    with open(args.flags, encoding='utf-8-sig') as f:
        fl = {r['place_id']: r for r in csv.DictReader(f)}
    groups = {}
    with open(args.input, encoding='utf-8-sig') as f:
        for r in csv.DictReader(f):
            moods = [m for m in (r.get('moods') or '').split('|') if m]
            groups.setdefault((r['method'], r['scenario']), []).append((int(r['rank']), r['place_id'], moods))
    by_method = {}
    skipped = 0
    for (method, _), rows in groups.items():
        rows.sort()
        rels = []
        for _, pid, moods in rows[:5]:
            rel = relevance(fl.get(pid), moods)
            if rel is None:
                skipped += 1
                continue
            rels.append(rel)
        if not rels:
            continue
        p5 = sum(1 for r in rels if r >= 0.5) / len(rels)
        by_method.setdefault(method, []).append((p5, ndcg(rels)))
    print(f'| 방법 | 시나리오 수 | Precision@5 | nDCG@5 |')
    print(f'| --- | --- | --- | --- |')
    for method, vals in sorted(by_method.items(), key=lambda kv: -sum(v[1] for v in kv[1]) / len(kv[1])):
        n = len(vals)
        print(f'| {method} | {n} | {sum(v[0] for v in vals) / n:.2f} | {sum(v[1] for v in vals) / n:.2f} |')
    print(f'구글에서 못 찾아서 뺀 장소: {skipped}개')


def main():
    ap = argparse.ArgumentParser(description='구글 리뷰로 정량평가 정답 만들기')
    sub = ap.add_subparsers(dest='cmd', required=True)
    a = sub.add_parser('fetch', help='장소별 구글 별점·리뷰 표시 가져오기')
    a.add_argument('input', help='place_id 열 있는 CSV')
    a.add_argument('--out', default=DEFAULT_OUT)
    a.add_argument('--limit', type=int, default=0, help='이번에 최대 몇 곳 (시험용)')
    a.add_argument('--dry-run', action='store_true', help='API 안 부르고 요청만 보기')
    b = sub.add_parser('score', help='Precision@5·nDCG@5 계산')
    b.add_argument('input', help='scenario, method, rank, place_id, moods 열 있는 CSV')
    b.add_argument('--flags', default=DEFAULT_OUT)
    args = ap.parse_args()
    fetch(args) if args.cmd == 'fetch' else score(args)


if __name__ == '__main__':
    main()
