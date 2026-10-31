"""
1단계: 네이버 블로그 검색 결과 모으기 (API 호출은 여기서만)

- 장소마다 검색 결과를 blog_tag/raw/{place_id}.json 으로 저장
- 이미 저장된 장소는 건너뜀 → 중간에 멈춰도 다시 실행하면 이어서 진행
- 하루 호출 한도에 가까워지면 알아서 멈춤 → 다음 날 다시 실행

필터나 태그 규칙을 바꿔도 이 단계는 다시 안 돌려도 됨
(2단계 analyze_all_places.py 만 다시 돌리면 됨)
"""

import csv
import json
import os
import time
from datetime import datetime

from collect_blogs import search_blogs


# =========================================================
# 설정
# =========================================================

INPUT_CSV = "output/places.csv"
RAW_DIR = "blog_tag/raw"
FAILED_CSV = "blog_tag/failed_places.csv"

# True 면 아래 조건에 맞는 장소만 (파일럿용)
TEST_MODE = False
TEST_REGION = "SEONGSU"
TEST_CATEGORY = "CAFE"
TEST_LIMIT = 20

BLOG_DISPLAY = 50

# 네이버 검색 API 하루 한도(25,000)보다 조금 적게
DAILY_LIMIT = 24000

SLEEP_SEC = 0.15

REGION_KR = {
    "SEONGSU": "성수",
    "HONGDAE": "홍대",
    "GANGNAM": "강남"
}


# =========================================================
# 장소 불러오기
# =========================================================

def load_places():

    places = []

    with open(INPUT_CSV, "r", encoding="utf-8-sig") as f:

        for row in csv.DictReader(f):

            if TEST_MODE:

                if row["region"] != TEST_REGION:
                    continue

                if row["category"] != TEST_CATEGORY:
                    continue

                if len(places) >= TEST_LIMIT:
                    break

            places.append(row)

    return places


def raw_path(place_id):
    return os.path.join(RAW_DIR, f"{place_id}.json")


# =========================================================
# 실행
# =========================================================

def main():

    os.makedirs(RAW_DIR, exist_ok=True)

    places = load_places()

    todo = [
        place
        for place in places
        if not os.path.exists(raw_path(place["place_id"]))
    ]

    print("=" * 60)
    print(f"전체 장소: {len(places)}")
    print(f"이미 수집됨: {len(places) - len(todo)}")
    print(f"이번에 수집할 장소: {len(todo)}")
    print("=" * 60)

    call_count = 0
    failed = []

    for index, place in enumerate(todo, start=1):

        if call_count >= DAILY_LIMIT:
            print()
            print(f"오늘 호출 한도({DAILY_LIMIT})에 도달해서 멈춤")
            print("내일 다시 실행하면 이어서 진행돼요")
            break

        place_id = place["place_id"]
        region_kr = REGION_KR.get(place["region"], place["region"])

        try:
            call_count += 1

            blogs = search_blogs(
                place_name=place["name"],
                region=region_kr,
                display=BLOG_DISPLAY
            )

            # 장소 하나 끝날 때마다 바로 저장
            with open(raw_path(place_id), "w", encoding="utf-8") as f:
                json.dump(
                    {
                        "place_id": place_id,
                        "place_name": place["name"],
                        "query": f'{place["name"]} {region_kr}',
                        "collected_at": datetime.now().isoformat(timespec="seconds"),
                        "blogs": blogs
                    },
                    f,
                    ensure_ascii=False
                )

        except Exception as e:

            print(f"  실패: {place['name']} ({e})")

            failed.append({
                "place_id": place_id,
                "place_name": place["name"],
                "region": place["region"],
                "category": place["category"],
                "error": str(e)
            })

        # 진행 상황은 50곳마다 한 번씩만 출력
        if index % 50 == 0 or index == len(todo):
            print(f"[{index}/{len(todo)}] 진행 중 · 실패 {len(failed)}곳")

        time.sleep(SLEEP_SEC)

    # 실패 목록 저장 (다시 실행하면 실패한 곳은 자동으로 다시 시도함)
    with open(FAILED_CSV, "w", newline="", encoding="utf-8-sig") as f:

        writer = csv.DictWriter(
            f,
            fieldnames=["place_id", "place_name", "region", "category", "error"]
        )
        writer.writeheader()
        writer.writerows(failed)

    done = sum(
        1
        for place in places
        if os.path.exists(raw_path(place["place_id"]))
    )

    print()
    print("=" * 60)
    print(f"이번 호출 수: {call_count}")
    print(f"수집 완료: {done} / {len(places)}")
    print(f"실패: {len(failed)}곳 → {FAILED_CSV}")
    print("=" * 60)


if __name__ == "__main__":
    main()
