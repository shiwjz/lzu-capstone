import requests
import csv
import os
import time
from math import radians, sin, cos, sqrt, atan2
from dotenv import load_dotenv

# =========================================================
# 0. 카카오 REST API 키
# =========================================================

load_dotenv()

REST_API_KEY = os.getenv("KAKAO_REST_API_KEY")

if not REST_API_KEY:
    raise SystemExit(".env 에 KAKAO_REST_API_KEY 가 없어요")

headers = {
    "Authorization": f"KakaoAK {REST_API_KEY}"
}

CATEGORY_URL = "https://dapi.kakao.com/v2/local/search/category.json"
KEYWORD_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"


# =========================================================
# 1. 지역별 중심좌표 (데이터 요청서 기준)
#    [8주차] 손으로 적던 동서남북 좌표 대신
#    중심 + 반경 500m 를 덮는 사각형을 자동으로 계산함
# =========================================================

region_centers = {
    "성수": (127.050400, 37.544045),
    "홍대": (126.922500, 37.556500),
    "강남": (127.026030, 37.501196)
}

# 중심좌표에서 이 거리 안의 장소만 저장 (꼭 지켜야 하는 조건)
RADIUS_M = 500

# 카카오 API 는 검색 한 번에 최대 45개(15개 x 3페이지)까지만 줌
KAKAO_MAX_RESULTS = 45

# 사각형을 이것보다 작게는 나누지 않음 (약 25m, 무한 반복 방지)
MIN_RECT_DEG = 0.00025

# API 호출 사이 쉬는 시간(초)
SLEEP_SEC = 0.1


# =========================================================
# 2. 카카오 기본 카테고리
# =========================================================

categories = {
    "음식": "FD6",
    "카페": "CE7",
    "문화": "CT1",
    "관광": "AT4"
}


# =========================================================
# 3. 오디가용 추가 검색 키워드
# =========================================================

keyword_groups = {

    "액티비티": [
        "방탈출",
        "보드게임카페",
        "볼링장",
        "오락실",
        "VR체험",
        "클라이밍",
        "노래방",
        "코인노래방",
        "탁구장",
        "양궁",
        "롤러스케이트"
    ],

    "체험": [
        "도자기공방",
        "향수공방",
        "반지공방",
        "가죽공방",
        "베이킹클래스",
        "쿠킹클래스",
        "원데이클래스",
        "드로잉카페",
        "캔들공방",
        "꽃공방"
    ],

    "문화": [
        "영화관",
        "미술관",
        "박물관",
        "전시관",
        "전시회",
        "갤러리",
        "공연장",
        "소극장",
        "연극"
    ],

    "쇼핑": [
        "팝업스토어",
        "소품샵",
        "편집샵",
        "빈티지샵",
        "독립서점",
        "서점",
        "전통시장"
    ],

    "자연/휴식": [
        "공원",
        "산책로",
        "정원",
        "식물원",
        "전망대",
        "야경명소",
        "북카페",
        "만화카페"
    ],

    "관광": [
        "아쿠아리움",
        "동물원",
        "테마파크",
        "놀이공원"
    ]
}


# =========================================================
# 3-1. [8주차] 장소 정리 규칙
#      (generate_mocks.py 의 load() 와 같은 기준)
# =========================================================

# 영어 코드 (API 명세 v0.2)
REGION_CODE = {
    "성수": "SEONGSU",
    "홍대": "HONGDAE",
    "강남": "GANGNAM"
}

CATEGORY_CODE = {
    "음식": "FOOD",
    "간식": "SNACK",
    "카페": "CAFE",
    "문화": "CULTURE",
    "액티비티": "ACTIVITY",   # = 놀거리
    "체험": "EXPERIENCE",
    "쇼핑": "SHOPPING",
    "관광": "TOUR",
    "자연/휴식": "NATURE"
}


# ---------------------------------------------------------
# 삭제 규칙
# ---------------------------------------------------------

# 카카오 분류 맨 앞 단어가 이거면 삭제
# (공간대여, 학원, 주차장 등)
NOISE_TOP = [
    "서비스,산업",
    "교육,학문",
    "의료,건강",
    "교통,수송",
    "부동산",
    "사회,공공기관"
]

# 카카오 분류 어디에든 이 단어가 있으면 삭제
# (키즈카페 + 검색에 딸려온 방문지 아닌 곳)
NOISE_WORDS = [
    "키즈카페",
    "출판사",
    "숙박",
    "미용실",
    "피부관리"
]


# ---------------------------------------------------------
# 카페 → 놀거리 규칙
# ---------------------------------------------------------

# 테마카페 중 놀거리로 옮길 것
# (세부 분류가 없는 테마카페는 대부분 방탈출이라 같이 옮김)
THEME_CAFE_TO_PLAY = [
    "사주카페",
    "고양이카페",
    "애견카페",
    "라이브카페"
]

# 카카오가 그냥 '카페'로 분류한 방탈출을 상호명으로 찾기
ESCAPE_NAME_WORDS = [
    "방탈출",
    "이스케이프",
    "황금열쇠",
    "제로월드",
    "넥스트에디션",
    "상상의문",
    "코코넛박스",
    "머더파커"
]


# ---------------------------------------------------------
# 음식 → 간식(SNACK) 분류 규칙
# ---------------------------------------------------------

# 카카오 세부 카테고리가 명확한 간식류
SNACK_CATEGORY_WORDS = [
    "제과,베이커리",
    "아이스크림",
    "도넛",
    "떡,한과",
    "초콜릿"
]

# 카카오가 세부 분류를 충분히 안 준 경우 장소명으로 보조 판별
SNACK_NAME_WORDS = [
    "만쥬",
    "베이글",
    "치아바타",
    "츄로",
    "초콜릿",
    "붕어빵",
    "호떡",
    "와플",
    "크레페",
    "츄러스",
    "마카롱",
    "젤라또",
    "푸딩",
    "타르트",
    "크로플",
    "꽈배기",
    "호두과자",
    "탕후루"
]

# 카카오상 '간식'이어도 식사로 두는 예외
SNACK_EXCLUDE_WORDS = [
    "닭강정"
]


def get_delete_reason(kakao_category):
    """삭제할 장소면 이유를, 아니면 None 을 돌려줌"""

    # 예: "서비스,산업 > 전문대행 > 공간대여" → "서비스,산업"
    top = kakao_category.split(" > ")[0]

    if top in NOISE_TOP:
        return top

    for word in NOISE_WORDS:
        if word in kakao_category:
            return word

    return None


def is_play_cafe(place):
    """카페처럼 분류됐지만 실제로는 노는 곳인지 확인"""

    kakao_category = place["kakao_category"]
    parts = kakao_category.split(" > ")

    # 보드게임카페, 만화카페, 방탈출카페 (카카오 '여가시설')
    if kakao_category.startswith("가정,생활 > 여가시설"):
        return True

    # 테마카페: 세부 분류가 없거나 사주·동물·라이브카페면 놀거리
    if "테마카페" in parts:

        if parts[-1] == "테마카페":
            return True

        sub = parts[parts.index("테마카페") + 1]

        if sub in THEME_CAFE_TO_PLAY:
            return True

    # 상호명으로 방탈출 찾기
    if any(
        word in place["name"]
        for word in ESCAPE_NAME_WORDS
    ):
        return True

    return False


def fix_place(place):
    """저장 직전에 카테고리 보정 + 영어 코드"""

    kakao_category = place["kakao_category"]
    category = place["category"]

    # -------------------------
    # 1) 구내식당은 데이트 장소 후보에서 제외
    # -------------------------
    if "구내식당" in kakao_category:
        return None

    # -------------------------
    # 2) 카페 → 놀거리
    # -------------------------
    if (
        category in ["카페", "액티비티", "자연/휴식"]
        and is_play_cafe(place)
    ):
        category = "액티비티"

    # -------------------------
    # 3) 검색어 때문에 엉뚱한 칸에 들어간 장소 바로잡기
    #    예: '공원' 검색에 걸린 감자탕집 → 음식
    # -------------------------
    elif kakao_category.startswith("음식점 > 카페"):

        # 북카페는 자연/휴식 유지
        if category == "자연/휴식" and "북카페" not in kakao_category:
            category = "카페"

        elif category == "액티비티":
            category = "카페"

    elif kakao_category.startswith("음식점"):
        category = "음식"

    elif category == "문화" and "패션" in kakao_category:
        # '갤러리' 검색에 걸린 패션/액세서리 매장
        category = "쇼핑"

    # -------------------------
    # 4) 음식 → 간식(SNACK)
    # -------------------------
    if category == "음식":

        # 닭강정처럼 카카오가 간식으로 잡아도 식사 후보로 둘 항목
        is_snack_exception = any(
            word in kakao_category
            for word in SNACK_EXCLUDE_WORDS
        )

        if not is_snack_exception:

            # 카카오 세부 분류가 명확한 경우
            if any(
                word in kakao_category
                for word in SNACK_CATEGORY_WORDS
            ):
                category = "간식"

            # 카카오가 '음식점 > 간식'까지만 준 경우 장소명으로 보조 판별
            elif "음식점 > 간식" in kakao_category:
                if any(
                    word in place["name"]
                    for word in SNACK_NAME_WORDS
                ):
                    category = "간식"

    # -------------------------
    # 5) 영어 코드
    # -------------------------
    fixed = dict(place)
    fixed["region"] = REGION_CODE[place["region"]]
    fixed["category"] = CATEGORY_CODE[category]

    return fixed


# =========================================================
# 4. 장소 저장 공간
# =========================================================

places = {}


def calculate_distance(lat1, lon1, lat2, lon2):
    """두 위경도 좌표 사이의 거리를 미터(m)로 계산"""
    earth_radius = 6371000

    lat1 = radians(lat1)
    lon1 = radians(lon1)
    lat2 = radians(lat2)
    lon2 = radians(lon2)

    dlat = lat2 - lat1
    dlon = lon2 - lon1

    a = (
        sin(dlat / 2) ** 2
        + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    )

    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return earth_radius * c


# =========================================================
# 5. 키워드 검색 결과 검증
#    너무 강하게 거르지 않고 명백한 오탐만 제거
# =========================================================

def is_valid_place(doc, category, search_keyword):

    kakao_category = doc["category_name"]

    # -------------------------
    # 자연 / 휴식
    # -------------------------

    if category == "자연/휴식":

        # "공원" 검색 시 편의점, 음식점 등이
        # 상호명 때문에 검색될 수 있으므로 제거
        if search_keyword == "공원":

            allowed = [
                "공원",
                "관광,명소"
            ]

            if not any(
                word in kakao_category
                for word in allowed
            ):
                return False


        # "정원"은 상호명에 자주 들어가므로
        # 명백한 업종만 제거
        if search_keyword == "정원":

            invalid_words = [
                "철강",
                "광고",
                "마케팅",
                "편의점",
                "금융",
                "화장실",
                "제조",
                "부동산",
                "자동차"
            ]

            if any(
                word in kakao_category
                for word in invalid_words
            ):
                return False


    # -------------------------
    # 문화
    # -------------------------

    if category == "문화":

        culture_rules = {

            "영화관": [
                "영화관"
            ],

            "미술관": [
                "미술관"
            ],

            "박물관": [
                "박물관"
            ],

            "전시관": [
                "전시관",
                "미술관",
                "문화시설"
            ],

            "갤러리": [
                "미술관",
                "화랑",
                "전시관",
                "갤러리"
            ],

            "공연장": [
                "공연장",
                "연극극장"
            ],

            "소극장": [
                "공연장",
                "연극극장",
                "영화관"
            ]
        }

        if search_keyword in culture_rules:

            allowed = culture_rules[
                search_keyword
            ]

            if not any(
                word in kakao_category
                for word in allowed
            ):
                return False


    # -------------------------
    # 액티비티
    # -------------------------

    if category == "액티비티":

        activity_rules = {

            "방탈출": [
                "방탈출",
                "테마카페"
            ],

            "보드게임카페": [
                "보드카페",
                "테마카페"
            ],

            "볼링장": [
                "볼링"
            ],

            "오락실": [
                "오락실",
                "게임"
            ],

            "VR체험": [
                "VR",
                "가상현실",
                "체험",
                "테마카페"
            ],

            "클라이밍": [
                "클라이밍",
                "암벽"
            ],

            "노래방": [
                "노래방"
            ],

            "코인노래방": [
                "노래방"
            ],

            "탁구장": [
                "탁구"
            ],

            "양궁": [
                "양궁",
                "궁도",
                "스포츠시설"
            ],

            "롤러스케이트": [
                "롤러",
                "스케이트"
            ]
        }

        if search_keyword in activity_rules:

            allowed = activity_rules[
                search_keyword
            ]

            if not any(
                word in kakao_category
                for word in allowed
            ):
                return False


    # -------------------------
    # [8주차] 체험 / 쇼핑
    # 키워드 검색에 딸려온 엉뚱한 업종 제거
    # ('원데이클래스'는 범위가 넓어서 검사 안 함)
    # -------------------------

    if category in ["체험", "쇼핑"]:

        shop_rules = {

            "도자기공방": ["도자기", "공예"],
            "향수공방": ["향수", "화장품", "공예"],
            "반지공방": ["액세서리", "보석", "패션잡화", "공예"],
            "가죽공방": ["가죽", "공예", "패션잡화"],
            "베이킹클래스": ["요리", "제과", "베이커리", "공예", "문화"],
            "쿠킹클래스": ["요리", "제과", "공예", "문화"],
            "드로잉카페": ["미술", "공예", "화랑", "카페"],
            "캔들공방": ["공예", "생활용품", "인테리어", "향수", "화장품"],
            "꽃공방": ["꽃", "공예"],

            "팝업스토어": ["팝업", "이벤트", "패션"],
            "소품샵": ["생활용품", "문구", "인테리어", "패션", "공예", "취미", "꽃", "장난감"],
            "편집샵": ["패션", "의류", "생활용품"],
            "빈티지샵": ["패션", "의류", "중고", "생활용품"],
            "독립서점": ["서점", "도서"],
            "서점": ["서점", "도서"],
            "전통시장": ["시장"]
        }

        if search_keyword in shop_rules:

            allowed = shop_rules[
                search_keyword
            ]

            if not any(
                word in kakao_category
                for word in allowed
            ):
                return False


    return True


# =========================================================
# 6. 장소 저장
# =========================================================

def save_place(
    doc,
    region,
    category,
    search_keyword
):

    # [8주차] 공간대여·학원·주차장·키즈카페 등은 저장하지 않음
    if get_delete_reason(doc["category_name"]):
        return


    # 키워드 검색 결과일 때만 검증
    if search_keyword:

        if not is_valid_place(
            doc,
            category,
            search_keyword
        ):
            return


    # 데이터 요청서의 대표 중심좌표 기준 500m 이내인지 확인
    center_x, center_y = region_centers[region]

    distance = calculate_distance(
        center_y,
        center_x,
        float(doc["y"]),
        float(doc["x"])
    )

    # 대표 중심좌표에서 500m를 넘는 장소는 저장하지 않음
    if distance > 500:
        return

    place_id = doc["id"]


    # 이미 저장된 장소라면
    # search_keyword만 합쳐줌
    if place_id in places:

        existing_keywords = (
            places[place_id]["search_keyword"]
        )

        if (
            search_keyword
            and search_keyword
            not in existing_keywords.split(",")
        ):

            if existing_keywords:

                places[place_id][
                    "search_keyword"
                ] += f",{search_keyword}"

            else:

                places[place_id][
                    "search_keyword"
                ] = search_keyword

        return


    places[place_id] = {

        "place_id": place_id,

        "region": region,

        "category": category,

        "search_keyword": search_keyword,

        "name": doc["place_name"],

        "address": doc["address_name"],

        "road_address": doc[
            "road_address_name"
        ],

        "phone": doc["phone"],

        "longitude": doc["x"],

        "latitude": doc["y"],

        "kakao_category": doc[
            "category_name"
        ],

        "place_url": doc["place_url"]
    }


# =========================================================
# 7. [8주차] 카카오 API 요청 (실패하면 다시 시도)
# =========================================================

api_call_count = 0
failed_requests = []


def request_kakao(url, params):
    """
    카카오 API 호출.
    실패하면 조금 쉬었다가 최대 3번까지 다시 시도하고,
    그래도 안 되면 프로그램을 멈추지 않고 None 을 돌려줌
    """

    global api_call_count

    for attempt in range(1, 4):

        try:
            api_call_count += 1

            response = requests.get(
                url,
                headers=headers,
                params=params,
                timeout=10
            )

            # 너무 자주 불러서 막힌 경우 → 오래 쉬고 다시
            if response.status_code == 429:
                print("    호출 한도 초과, 10초 쉬고 다시 시도")
                time.sleep(10)
                continue

            response.raise_for_status()

            time.sleep(SLEEP_SEC)

            return response.json()

        except requests.RequestException as error:
            print(f"    요청 실패 ({attempt}/3): {error}")
            time.sleep(attempt * 2)

    failed_requests.append(params)

    return None


# =========================================================
# 8. [8주차] 사각형 나눠서 검색
#    결과가 45개를 넘으면 사각형을 4등분해서 다시 검색
#    → 장소가 많은 곳(홍대 음식점 등)도 빠짐없이 수집
# =========================================================

def meters_to_degrees(center_y):
    """위도 기준 1m 가 위도/경도로 몇 도인지"""

    lat_per_m = 1 / 111320
    lng_per_m = 1 / (111320 * cos(radians(center_y)))

    return lat_per_m, lng_per_m


def circle_to_rect(center_x, center_y, radius_m):
    """중심 + 반경 원을 딱 덮는 사각형 (왼쪽x, 아래y, 오른쪽x, 위y)"""

    lat_per_m, lng_per_m = meters_to_degrees(center_y)

    return (
        center_x - radius_m * lng_per_m,
        center_y - radius_m * lat_per_m,
        center_x + radius_m * lng_per_m,
        center_y + radius_m * lat_per_m
    )


def rect_touches_circle(rect, center_x, center_y, radius_m):
    """사각형이 반경 원과 겹치는지 (안 겹치면 검색할 필요 없음)"""

    left, bottom, right, top = rect

    # 사각형 안에서 중심과 가장 가까운 점
    nearest_x = min(max(center_x, left), right)
    nearest_y = min(max(center_y, bottom), top)

    distance = calculate_distance(
        center_y,
        center_x,
        nearest_y,
        nearest_x
    )

    return distance <= radius_m


def split_rect(rect):
    """사각형을 4등분"""

    left, bottom, right, top = rect

    mid_x = (left + right) / 2
    mid_y = (bottom + top) / 2

    return [
        (left, bottom, mid_x, mid_y),
        (mid_x, bottom, right, mid_y),
        (left, mid_y, mid_x, top),
        (mid_x, mid_y, right, top)
    ]


def collect_in_rect(
    url,
    base_params,
    rect,
    region_name,
    category_name,
    search_keyword
):
    """
    사각형 안 장소를 수집.
    url: 카테고리 검색 or 키워드 검색 주소
    base_params: {"category_group_code": "FD6"} or {"query": "방탈출"}
    """

    center_x, center_y = region_centers[region_name]

    # 반경 500m 원과 안 겹치는 사각형은 건너뜀
    if not rect_touches_circle(rect, center_x, center_y, RADIUS_M):
        return

    rect_text = ",".join(str(round(v, 7)) for v in rect)

    # 1페이지를 먼저 받아서 전체 개수 확인
    params = dict(base_params)
    params.update({
        "rect": rect_text,
        "page": 1,
        "size": 15
    })

    data = request_kakao(url, params)

    if data is None:
        return

    total_count = data["meta"]["total_count"]

    left, bottom, right, top = rect
    can_split = (right - left) > MIN_RECT_DEG

    # 45개를 넘으면 다 못 받으니까 4등분해서 다시 검색
    if total_count > KAKAO_MAX_RESULTS and can_split:

        for small_rect in split_rect(rect):

            collect_in_rect(
                url,
                base_params,
                small_rect,
                region_name,
                category_name,
                search_keyword
            )

        return

    # 45개 이하면 이 사각형에서 전부 받기 (최대 3페이지)
    for doc in data["documents"]:
        save_place(doc, region_name, category_name, search_keyword)

    page = 1

    while not data["meta"]["is_end"] and page < 3:

        page += 1
        params["page"] = page

        data = request_kakao(url, params)

        if data is None:
            break

        for doc in data["documents"]:
            save_place(doc, region_name, category_name, search_keyword)


# =========================================================
# 9. 실제 데이터 수집
# =========================================================

for region_name, (center_x, center_y) in region_centers.items():

    print()
    print(
        "================================="
    )
    print(f"[{region_name}]")
    print(
        "================================="
    )

    # 중심 반경 500m 를 덮는 사각형
    region_rect = circle_to_rect(
        center_x,
        center_y,
        RADIUS_M
    )


    # -------------------------
    # 기본 카카오 카테고리
    # -------------------------

    for (
        category_name,
        category_code
    ) in categories.items():

        print(
            f"  {category_name} 수집 중..."
        )

        collect_in_rect(
            CATEGORY_URL,
            {"category_group_code": category_code},
            region_rect,
            region_name,
            category_name,
            ""
        )


    # -------------------------
    # 오디가 추가 키워드
    # -------------------------

    for (
        category_name,
        keywords
    ) in keyword_groups.items():

        for keyword in keywords:

            print(
                f"  {category_name}"
                f" - {keyword} 수집 중..."
            )

            collect_in_rect(
                KEYWORD_URL,
                {"query": keyword},
                region_rect,
                region_name,
                category_name,
                keyword
            )


# =========================================================
# 10. CSV 저장
# =========================================================

os.makedirs(
    "output",
    exist_ok=True
)


# [8주차] 저장 직전에 카테고리 보정 + 간식 분리 + 영어 코드
final_places = []

for place in places.values():
    fixed = fix_place(place)

    if fixed is not None:
        final_places.append(fixed)


output_path = (
    "output/places.csv"
)


with open(
    output_path,
    "w",
    newline="",
    encoding="utf-8-sig"
) as f:

    fieldnames = [

        "place_id",

        "region",

        "category",

        "search_keyword",

        "name",

        "address",

        "road_address",

        "phone",

        "longitude",

        "latitude",

        "kakao_category",

        "place_url"
    ]


    writer = csv.DictWriter(
        f,
        fieldnames=fieldnames
    )


    writer.writeheader()


    writer.writerows(
        final_places
    )


# =========================================================
# 11. 결과 출력
# =========================================================

print()
print(
    "================================="
)
print(
    f"총 {len(final_places)}개 장소 수집 완료"
)
print(
    f"{output_path} 저장 완료"
)
print(
    f"API 호출 {api_call_count}번"
)

if failed_requests:
    print(
        f"⚠ 끝까지 실패한 요청 {len(failed_requests)}개 "
        "(이 부분 장소가 빠졌을 수 있음, 다시 실행 추천)"
    )
print(
    "================================="
)