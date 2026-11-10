"""
음식 취향 확정본 만들기 → blog_tag/place_cuisine.csv (김예민 요청, 명세 v0.5 '음식 취향')

장소마다 큰 종류(cuisine)·세부(detail)를 정함. 음식점(FOOD)·카페(CAFE)만.
정하는 순서 (앞에서 정해지면 뒤는 안 봄)
  1) KAKAO : 카카오 세부 분류          예) 음식점 > 일식 > 초밥,롤 → JAPANESE / 초밥·롤
  2) NAME  : 가게 이름                  예) ○○스시 → 초밥·롤
  3) BLOG  : 블로그 글에 나온 메뉴 단어  예) 블로거 5명이 "순대국" → 국밥
  4) NONE  : 세부 못 정함 (큰 종류만)

코드·이름은 서버 course/Cuisine.java 표와 똑같이
열: place_id, name, region, category, kakao_category, cuisine, detail, source

실행 (API 호출 없음, blog_tag/raw 에 저장된 검색 결과 사용)
  python blog_tag/make_place_cuisine.py
"""

import csv
import json
import os
from collections import Counter

from blog_filter import is_ad_post, is_relevant_post


INPUT_CSV = "output/places.csv"
RAW_DIR = "blog_tag/raw"
OUTPUT_CSV = "blog_tag/place_cuisine.csv"

# 블로그로 세부를 정할 때: 서로 다른 블로거 몇 명 이상이 말해야 하는지
BLOG_MIN_BLOGGERS = 2


# =========================================================
# 1. 카카오 분류 → 큰 종류 / 세부  (generate_mocks.py 임시 분류 + 보강)
# =========================================================

# 카카오 두 번째 칸 → 큰 종류
KAKAO_BIG = {
    "한식": "KOREAN", "일식": "JAPANESE", "양식": "WESTERN", "패밀리레스토랑": "WESTERN",
    "패스트푸드": "WESTERN", "중식": "CHINESE", "분식": "BUNSIK", "아시아음식": "ASIAN",
    "치킨": "CHICKEN", "술집": "BAR",
    # [보강] 예민 임시 분류에서 ETC 로 빠지던 것
    "샤브샤브": "KOREAN", "도시락": "KOREAN",
}

# 카카오 세 번째 칸(이후 아무 칸) → 세부
KAKAO_DETAIL = {
    "육류,고기": "고기", "해물,생선": "해물·생선", "국밥": "국밥", "찌개,전골": "찌개·전골", "국수": "국수",
    "초밥,롤": "초밥·롤", "일본식라면": "라멘", "돈까스,우동": "돈까스·우동", "참치회": "초밥·롤",
    "이탈리안": "이탈리안", "피자": "피자", "햄버거": "햄버거", "스테이크,립": "스테이크", "멕시칸,브라질": "멕시칸",
    "중국요리": "중국요리", "양꼬치": "양꼬치", "떡볶이": "떡볶이", "동남아음식": "동남아", "인도음식": "인도",
    "호프,요리주점": "호프·요리주점", "일본식주점": "이자카야", "칵테일바": "칵테일바", "와인바": "와인바",
    "실내포장마차": "포장마차", "디저트카페": "디저트카페", "갤러리카페": "갤러리·북카페", "북카페": "갤러리·북카페",
    # [보강] 예민 임시 분류에서 세부가 비던 것
    "순대": "국밥", "곰탕": "국밥", "설렁탕": "국밥", "해장국": "국밥",
    "감자탕": "찌개·전골", "샤브샤브": "찌개·전골",
    "냉면": "국수", "칼국수": "국수",
    "족발,보쌈": "고기", "곱창,막창,양": "고기", "닭요리": "고기",
    "오뎅바": "이자카야", "이자카야": "이자카야",
    "샌드위치": "햄버거",
    "두부전문점": "찌개·전골",
}

# 샐러드·다이어트 가게는 맞는 세부가 없어서 블로그로 억지로 정하지 않음 (예: 샐러드집 → 이탈리안 X)
NO_BLOG_GUESS = ["샐러드"]

CAFE_DRINK = ["전통찻집", "생과일전문점", "공차", "차백도", "흑화당", "홍콩다방", "차지", "다방"]


# =========================================================
# 2. 가게 이름 → 세부 (큰 종류 안에서만)
# =========================================================

NAME_DETAIL = {
    "KOREAN": [("고기", ["고기", "삼겹", "갈비", "한우", "정육", "곱창", "막창", "족발", "보쌈"]),
               ("국밥", ["국밥", "곰탕", "설렁탕", "순대국", "해장국"]),
               ("찌개·전골", ["찌개", "전골", "부대", "감자탕"]),
               ("국수", ["국수", "칼국수", "냉면"]),
               ("해물·생선", ["횟집", "수산", "해물", "아구", "조개"])],
    "JAPANESE": [("초밥·롤", ["스시", "초밥", "오마카세"]), ("라멘", ["라멘", "라면"]),
                 ("돈까스·우동", ["돈까스", "돈카츠", "카츠", "우동", "소바"]),
                 ("덮밥", ["덮밥", "텐동", "규동", "카이센동", "히츠마부시"])],
    "WESTERN": [("이탈리안", ["파스타", "이탈리", "트라토리아"]), ("피자", ["피자", "피제리아"]),
                ("햄버거", ["버거"]), ("스테이크", ["스테이크"]), ("멕시칸", ["타코", "멕시"])],
    "CHINESE": [("양꼬치", ["양꼬치"]), ("중국요리", ["마라", "짬뽕", "짜장", "반점", "훠궈"])],
    "BUNSIK": [("떡볶이", ["떡볶이"]), ("김밥", ["김밥"])],
    "ASIAN": [("동남아", ["쌀국수", "포", "타이", "베트남"]), ("인도", ["커리", "인디아", "탄두리"])],
    "BAR": [("이자카야", ["이자카야", "하이볼", "야키토리"]), ("와인바", ["와인"]),
            ("칵테일바", ["칵테일"]), ("포장마차", ["포차", "포장마차"]), ("호프·요리주점", ["호프", "맥주"])],
    "CAFE": [("디저트카페", ["디저트", "케이크", "베이커리", "구움과자"])],
}


# =========================================================
# 3. 블로그 메뉴 단어 → 세부
#    (너무 흔한 말은 빼고 메뉴 이름 위주. 예: "회"는 "회식"에도 걸려서 "횟집", "모둠회"로)
# =========================================================

BLOG_DETAIL = {
    "고기": ["삼겹살", "목살", "갈비", "한우", "소고기", "돼지고기", "고기집", "숯불", "곱창", "막창", "대창",
             "족발", "보쌈", "닭갈비"],
    "국밥": ["국밥", "순대국", "해장국", "곰탕", "설렁탕", "뼈해장국"],
    "찌개·전골": ["찌개", "전골", "감자탕", "닭볶음탕", "닭도리탕", "샤브샤브", "짜글이", "순두부"],
    "국수": ["칼국수", "냉면", "막국수", "잔치국수", "수제비"],
    "해물·생선": ["횟집", "모둠회", "활어", "해물", "조개", "아구찜", "방어", "낙지", "쭈꾸미"],
    "초밥·롤": ["초밥", "스시", "오마카세", "사시미"],
    "라멘": ["라멘", "돈코츠", "츠케멘", "마제소바"],
    "돈까스·우동": ["돈까스", "돈카츠", "우동", "메밀소바", "자루소바", "냉소바", "규카츠"],
    "덮밥": ["덮밥", "규동", "텐동", "카이센동", "사케동"],
    "이탈리안": ["파스타", "리조또", "이탈리안"],
    "피자": ["피자"],
    "햄버거": ["버거", "샌드위치"],
    "스테이크": ["스테이크"],
    "멕시칸": ["타코스", "부리또", "퀘사디아", "멕시칸"],   # "타코"는 타코야끼에도 걸려서 뺌
    "중국요리": ["짜장", "짬뽕", "탕수육", "마라탕", "딤섬", "훠궈", "꿔바로우"],
    "양꼬치": ["양꼬치"],
    "떡볶이": ["떡볶이"],
    "김밥": ["김밥"],
    "동남아": ["쌀국수", "팟타이", "분짜", "똠양", "반미", "나시고랭"],
    "인도": ["인도커리", "탄두리", "난과", "커리"],
    "호프·요리주점": ["호프", "생맥주", "요리주점"],
    "이자카야": ["이자카야", "하이볼", "사케", "야키토리", "꼬치"],
    "칵테일바": ["칵테일"],
    "와인바": ["와인바", "내추럴와인"],
    "포장마차": ["포장마차", "포차"],
}

# 세부 → 큰 종류 (서버 Cuisine.DETAIL_FAMILY 와 같음)
DETAIL_FAMILY = {
    "고기": "KOREAN", "국밥": "KOREAN", "찌개·전골": "KOREAN", "국수": "KOREAN", "해물·생선": "KOREAN",
    "초밥·롤": "JAPANESE", "라멘": "JAPANESE", "돈까스·우동": "JAPANESE", "덮밥": "JAPANESE",
    "이탈리안": "WESTERN", "피자": "WESTERN", "햄버거": "WESTERN", "스테이크": "WESTERN", "멕시칸": "WESTERN",
    "중국요리": "CHINESE", "양꼬치": "CHINESE", "떡볶이": "BUNSIK", "김밥": "BUNSIK",
    "동남아": "ASIAN", "인도": "ASIAN",
    "호프·요리주점": "BAR", "이자카야": "BAR", "칵테일바": "BAR", "와인바": "BAR", "포장마차": "BAR",
}


# =========================================================
# 분류
# =========================================================

def from_kakao_and_name(place):
    """1) 카카오 → 2) 이름. 반환 (cuisine, detail, source)"""

    parts = [x.strip() for x in place["kakao_category"].split(">")]
    name = place["name"]

    if place["category"] == "FOOD":
        l2 = parts[1] if len(parts) > 1 else ""
        l3 = parts[2] if len(parts) > 2 else ""

        big = KAKAO_BIG.get(l2)
        if l2 == "퓨전요리":
            big = "JAPANESE" if l3 == "퓨전일식" else "KOREAN" if l3 == "퓨전한식" else None
        big = big or "ETC"

        # 두 번째 칸부터 끝까지 중 아는 세부가 있으면 (예: 음식점 > 샤브샤브)
        for part in parts[1:]:
            if part in KAKAO_DETAIL:
                return big, KAKAO_DETAIL[part], "KAKAO"
        if l2 == "분식" and "김밥" in l3:
            return big, "김밥", "KAKAO"
        if l2 == "패스트푸드" and "버거" in (l3 + name):
            return big, "햄버거", "KAKAO"

    elif place["category"] == "CAFE":
        big = "CAFE"
        l2 = parts[2] if len(parts) > 2 else ""
        l3 = parts[3] if len(parts) > 3 else ""
        if l3 in KAKAO_DETAIL:
            return big, KAKAO_DETAIL[l3], "KAKAO"
        if l2 in CAFE_DRINK:
            return big, "차·음료", "KAKAO"
        if l2 == "바나프레소" or (l2 == "커피전문점" and l3):
            return big, "프랜차이즈", "KAKAO"

    else:
        return None, None, None

    for detail, words in NAME_DETAIL.get(big, []):
        if any(w in name for w in words):
            return big, detail, "NAME"

    if big == "CAFE":
        return big, "개인카페", "KAKAO"

    return big, None, "NONE"


def blog_texts(place):
    """그 장소의 블로그 글 중 필터 통과한 것만 (블로거별로 묶음)"""

    path = os.path.join(RAW_DIR, f'{place["place_id"]}.json')
    if not os.path.exists(path):
        return {}

    with open(path, encoding="utf-8") as f:
        blogs = json.load(f)["blogs"]

    by_blogger = {}
    for blog in blogs:
        text = blog.get("title", "") + " " + blog.get("description", "")
        if is_ad_post(text):
            continue
        ok, _ = is_relevant_post(
            text=text,
            place_name=place["name"],
            region_code=place["region"],
            address=place.get("address", ""),
            road_address=place.get("road_address", ""),
        )
        if not ok:
            continue
        blogger = blog.get("blogger_link") or blog.get("blogger_name") or blog.get("link", "")
        by_blogger.setdefault(blogger, []).append(text)

    return by_blogger


def from_blog(place, big):
    """3) 블로그 메뉴 단어로 세부 정하기. 큰 종류를 알면 그 안에서만 고름"""

    by_blogger = blog_texts(place)
    if not by_blogger:
        return None

    counter = Counter()
    for texts in by_blogger.values():
        joined = " ".join(texts)
        said = set()
        for detail, words in BLOG_DETAIL.items():
            if big not in (None, "ETC") and DETAIL_FAMILY[detail] != big:
                continue
            if any(w in joined for w in words):
                said.add(detail)
        counter.update(said)          # 블로거 한 명당 한 번만

    if not counter:
        return None

    ranked = counter.most_common(2)
    top, top_count = ranked[0]
    second_count = ranked[1][1] if len(ranked) > 1 else 0

    # 2명 이상이 말했고, 2등보다 확실히 많을 때만
    # 큰 종류도 모르는 곳(ETC)은 더 엄격하게 3명 이상
    need = BLOG_MIN_BLOGGERS + (1 if big in (None, "ETC") else 0)
    if top_count >= need and top_count > second_count:
        return top

    return None


def classify(place):
    big, detail, source = from_kakao_and_name(place)

    if big is None:
        return None

    no_guess = any(w in place["kakao_category"] for w in NO_BLOG_GUESS)
    if detail is None and big != "CHICKEN" and not no_guess:       # 치킨은 세부가 없음
        blog_detail = from_blog(place, big)
        if blog_detail:
            # 큰 종류를 몰랐으면(ETC) 세부로 큰 종류도 정함
            if big == "ETC":
                big = DETAIL_FAMILY[blog_detail]
            return big, blog_detail, "BLOG"

    return big, detail, source


# =========================================================
# 실행
# =========================================================

def main():
    with open(INPUT_CSV, encoding="utf-8-sig") as f:
        places = list(csv.DictReader(f))

    rows = []
    for place in places:
        result = classify(place)
        if result is None:
            continue
        big, detail, source = result
        rows.append({
            "place_id": place["place_id"],
            "name": place["name"],
            "region": place["region"],
            "category": place["category"],
            "kakao_category": place["kakao_category"],
            "cuisine": big,
            "detail": detail or "",
            "source": source,
        })

    os.makedirs(os.path.dirname(OUTPUT_CSV), exist_ok=True)
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print("=" * 50)
    print(f"음식점·카페: {len(rows)}곳 → {OUTPUT_CSV}")
    print()
    print("세부를 어디서 정했나")
    for source, count in Counter(r["source"] for r in rows).most_common():
        print(f"  {source:<6} {count:>5}곳")
    print()
    print("큰 종류")
    for big, count in Counter(r["cuisine"] for r in rows).most_common():
        print(f"  {big:<9} {count:>5}곳")
    food = [r for r in rows if r["category"] == "FOOD"]
    no_detail = sum(1 for r in food if not r["detail"] and r["cuisine"] != "CHICKEN")
    print()
    print(f"음식점 중 세부 못 정한 곳: {no_detail} / {len(food)} (치킨 제외)")
    print("=" * 50)


if __name__ == "__main__":
    main()
