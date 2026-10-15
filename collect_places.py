import requests
import csv
import os
from math import radians, sin, cos, sqrt, atan2
from dotenv import load_dotenv

# =========================================================
# 0. 카카오 REST API 키
# =========================================================

load_dotenv()

REST_API_KEY = os.getenv("KAKAO_REST_API_KEY")

headers = {
    "Authorization": f"KakaoAK {REST_API_KEY}"
}

CATEGORY_URL = "https://dapi.kakao.com/v2/local/search/category.json"
KEYWORD_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"


# =========================================================
# 1. 지역별 검색 좌표
# =========================================================

regions = {
    "성수": [
        (127.050400, 37.544045),  # 중심
        (127.046900, 37.544045),  # 서쪽
        (127.053900, 37.544045),  # 동쪽
        (127.050400, 37.541245),  # 남쪽
        (127.050400, 37.546845),  # 북쪽
    ],

    "홍대": [
        (126.922500, 37.556500),  # 중심
        (126.918900, 37.556500),  # 서쪽
        (126.926100, 37.556500),  # 동쪽
        (126.922500, 37.553700),  # 남쪽
        (126.922500, 37.559300),  # 북쪽
    ],

    "강남": [
        (127.026030, 37.501196),  # 중심
        (127.022430, 37.501196),  # 서쪽
        (127.029630, 37.501196),  # 동쪽
        (127.026030, 37.498396),  # 남쪽
        (127.026030, 37.503996),  # 북쪽
    ]
}


# 데이터 요청서 기준 대표 중심좌표
# 최종 저장 시 이 좌표로부터 500m 이내 장소만 남김
region_centers = {
    "성수": (127.050400, 37.544045),
    "홍대": (126.922500, 37.556500),
    "강남": (127.026030, 37.501196)
}


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
# 7. 기본 카테고리 검색
# =========================================================

def collect_category(
    region_name,
    x,
    y,
    category_name,
    category_code
):

    for page in range(1, 4):

        params = {

            "category_group_code":
                category_code,

            "x": x,

            "y": y,

            "radius": 500,

            "page": page,

            "size": 15,

            "sort": "distance"
        }


        response = requests.get(
            CATEGORY_URL,
            headers=headers,
            params=params
        )


        response.raise_for_status()


        data = response.json()


        for doc in data["documents"]:

            save_place(
                doc,
                region_name,
                category_name,
                ""
            )


        if data["meta"]["is_end"]:
            break


# =========================================================
# 8. 키워드 검색
# =========================================================

def collect_keyword(
    region_name,
    x,
    y,
    category_name,
    keyword
):

    for page in range(1, 4):

        params = {

            "query": keyword,

            "x": x,

            "y": y,

            "radius": 500,

            "page": page,

            "size": 15,

            "sort": "distance"
        }


        response = requests.get(
            KEYWORD_URL,
            headers=headers,
            params=params
        )


        response.raise_for_status()


        data = response.json()


        for doc in data["documents"]:

            save_place(
                doc,
                region_name,
                category_name,
                keyword
            )


        if data["meta"]["is_end"]:
            break


# =========================================================
# 9. 실제 데이터 수집
# =========================================================

for region_name, points in regions.items():

    print()
    print(
        "================================="
    )
    print(f"[{region_name}]")
    print(
        "================================="
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

        for x, y in points:

            collect_category(
                region_name,
                x,
                y,
                category_name,
                category_code
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

            for x, y in points:

                collect_keyword(
                    region_name,
                    x,
                    y,
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
        places.values()
    )


# =========================================================
# 11. 결과 출력
# =========================================================

print()
print(
    "================================="
)
print(
    f"총 {len(places)}개 장소 수집 완료"
)
print(
    f"{output_path} 저장 완료"
)
print(
    "================================="
)