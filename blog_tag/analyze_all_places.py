"""
2단계: 저장된 블로그 검색 결과로 태그 만들기 (API 호출 없음)

입력: output/places.csv + blog_tag/raw/{place_id}.json (1단계 결과)
출력:
  blog_tag/place_tag.csv          장소별 확정 태그 (이윤경 전달용)
  blog_tag/place_blog_stats.csv   장소별 수집·필터 통계 (확인용)
  blog_tag/review_sample.csv      직접 읽어볼 글 샘플 (필터 정확도 확인용)

필터·태그 규칙을 바꾸면 이 파일만 다시 돌리면 됨 (몇 초면 끝남)
"""

import csv
import json
import os
import random
from collections import Counter, defaultdict

from extract_tags import extract_tags
from blog_filter import (
    get_base_place_name,
    normalize_text,
    is_ad_post,
    is_self_paid_post,
    is_relevant_post
)


# =========================================================
# 설정
# =========================================================

INPUT_CSV = "output/places.csv"
RAW_DIR = "blog_tag/raw"

OUTPUT_TAG_CSV = "blog_tag/place_tag.csv"
OUTPUT_STATS_CSV = "blog_tag/place_blog_stats.csv"
OUTPUT_REVIEW_CSV = "blog_tag/review_sample.csv"

MIN_BLOGGER_COUNT = 2

# 같은 이름이 이만큼 이상 있으면 프랜차이즈로 표시
FRANCHISE_MIN_COUNT = 3

# 직접 읽어볼 샘플 수
REVIEW_KEPT = 60
REVIEW_EXCLUDED = 40


# =========================================================
# 공통
# =========================================================

def load_places():
    with open(INPUT_CSV, "r", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def load_raw(place_id):
    path = os.path.join(RAW_DIR, f"{place_id}.json")
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def find_franchises(places):
    """지점명을 뗀 이름이 여러 번 나오면 프랜차이즈"""
    counter = Counter(
        normalize_text(get_base_place_name(place["name"]))
        for place in places
    )
    return {
        name
        for name, count in counter.items()
        if count >= FRANCHISE_MIN_COUNT
    }


def remove_duplicate_links(blogs):
    seen = set()
    result = []
    for blog in blogs:
        link = blog.get("link", "").strip()
        if link and link in seen:
            continue
        seen.add(link)
        result.append(blog)
    return result


def get_blogger_id(blog):
    if blog.get("blogger_link"):
        return blog["blogger_link"].strip()
    if blog.get("blogger_name"):
        return "name:" + blog["blogger_name"].strip()
    return "post:" + blog.get("link", "")


# =========================================================
# 장소 하나 분석
# =========================================================

def analyze_place(place, blogs):
    """
    반환: (태그 행 목록, 통계, 통과한 글, 제외된 글)
    """

    blogs = remove_duplicate_links(blogs)

    reason_counter = Counter()
    self_paid_count = 0
    kept_posts = []
    excluded_posts = []
    blogger_tags = defaultdict(set)

    for blog in blogs:

        text = blog.get("title", "") + " " + blog.get("description", "")

        # 1. 광고
        if is_ad_post(text):
            reason_counter["AD"] += 1
            excluded_posts.append((blog, "AD"))
            continue

        if is_self_paid_post(text):
            self_paid_count += 1

        # 2. 무관 / 다른 지점 / 다른 지역
        relevant, reason = is_relevant_post(
            text=text,
            place_name=place["name"],
            region_code=place["region"],
            address=place.get("address", ""),
            road_address=place.get("road_address", "")
        )

        if not relevant:
            reason_counter[reason] += 1
            excluded_posts.append((blog, reason))
            continue

        # 3. 블로거별로 태그 모으기 (같은 블로거 여러 글 → 한 명)
        blogger_id = get_blogger_id(blog)
        tags = extract_tags(text)
        blogger_tags[blogger_id].update(tags)

        kept_posts.append((blog, tags))

    # 태그별 "서로 다른 블로거 수"
    tag_counter = Counter()
    for tags in blogger_tags.values():
        for tag in tags:
            tag_counter[tag] += 1

    blogger_count = len(blogger_tags)

    tag_rows = []

    for tag, count in tag_counter.most_common():

        if count < MIN_BLOGGER_COUNT:
            continue

        tag_rows.append({
            "place_id": place["place_id"],
            "place_name": place["name"],
            "region": place["region"],
            "category": place["category"],
            "tag": tag,
            "mentions": count,
            "ratio": round(count / blogger_count, 2) if blogger_count else 0,
            "blogger_count": blogger_count
        })

    stats = {
        "search_count": len(blogs),
        "ad_count": reason_counter["AD"],
        "name_not_found": reason_counter["PLACE_NAME_NOT_FOUND"],
        "other_branch": reason_counter["OTHER_BRANCH"],
        "other_region": reason_counter["OTHER_REGION"],
        "short_name_no_region": reason_counter["SHORT_NAME_WITHOUT_REGION"],
        "self_paid_count": self_paid_count,
        "blogger_count": blogger_count,
        "tag_count": len(tag_rows)
    }

    return tag_rows, stats, kept_posts, excluded_posts


# =========================================================
# 실행
# =========================================================

def main():

    random.seed(42)

    places = load_places()
    franchises = find_franchises(places)

    all_tag_rows = []
    all_stats = []
    all_kept = []
    all_excluded = []
    missing = 0

    for place in places:

        raw = load_raw(place["place_id"])

        if raw is None:
            missing += 1
            continue

        tag_rows, stats, kept, excluded = analyze_place(place, raw["blogs"])

        is_franchise = (
            normalize_text(get_base_place_name(place["name"])) in franchises
        )

        all_tag_rows.extend(tag_rows)

        all_stats.append({
            "place_id": place["place_id"],
            "place_name": place["name"],
            "region": place["region"],
            "category": place["category"],
            "is_franchise": "Y" if is_franchise else "N",
            **stats
        })

        for blog, tags in kept:
            all_kept.append((place, blog, "KEPT", "|".join(tags)))

        for blog, reason in excluded:
            all_excluded.append((place, blog, reason, ""))

    os.makedirs("blog_tag", exist_ok=True)

    # ---------------------------------------------
    # 1) place_tag.csv
    # ---------------------------------------------
    with open(OUTPUT_TAG_CSV, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "place_id", "place_name", "region", "category",
            "tag", "mentions", "ratio", "blogger_count"
        ])
        writer.writeheader()
        writer.writerows(all_tag_rows)

    # ---------------------------------------------
    # 2) place_blog_stats.csv
    # ---------------------------------------------
    if all_stats:
        with open(OUTPUT_STATS_CSV, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.DictWriter(f, fieldnames=list(all_stats[0].keys()))
            writer.writeheader()
            writer.writerows(all_stats)

    # ---------------------------------------------
    # 3) review_sample.csv: 직접 읽고 맞는지 표시하는 용도
    # ---------------------------------------------
    sample = (
        random.sample(all_kept, min(REVIEW_KEPT, len(all_kept)))
        + random.sample(all_excluded, min(REVIEW_EXCLUDED, len(all_excluded)))
    )

    with open(OUTPUT_REVIEW_CSV, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow([
            "결과", "장소", "지역", "카테고리", "글 제목", "요약", "붙은 태그", "링크",
            "우리 장소 글 맞음?(O/X)", "광고?(O/X)"
        ])
        for place, blog, result, tags in sample:
            writer.writerow([
                result, place["name"], place["region"], place["category"],
                blog.get("title", ""), blog.get("description", ""),
                tags, blog.get("link", ""), "", ""
            ])

    # ---------------------------------------------
    # 4) 요약 출력: 지역 × 카테고리별 태그 확정 비율
    # ---------------------------------------------
    print("=" * 60)
    print(f"분석한 장소: {len(all_stats)}곳 (아직 수집 안 된 곳 {missing}곳)")
    print(f"태그 행: {len(all_tag_rows)}개")
    print("=" * 60)

    group = defaultdict(lambda: [0, 0, 0])   # [장소 수, 태그 확정 수, 블로거 합]

    for row in all_stats:
        key = (row["region"], row["category"])
        group[key][0] += 1
        group[key][1] += 1 if row["tag_count"] > 0 else 0
        group[key][2] += row["blogger_count"]

    print(f'{"지역":<9}{"카테고리":<12}{"장소":>5}{"태그확정":>8}{"비율":>7}{"평균블로거":>9}')

    for (region, category), (count, tagged, bloggers) in sorted(group.items()):
        print(
            f"{region:<9}{category:<12}{count:>5}{tagged:>8}"
            f"{tagged / count:>7.0%}{bloggers / count:>9.1f}"
        )

    franchise_tagged = sum(
        1 for row in all_stats
        if row["is_franchise"] == "Y" and row["tag_count"] > 0
    )
    franchise_total = sum(1 for row in all_stats if row["is_franchise"] == "Y")

    print()
    print(f"프랜차이즈: {franchise_total}곳 중 {franchise_tagged}곳 태그 확정")
    print()
    print(f"저장: {OUTPUT_TAG_CSV}, {OUTPUT_STATS_CSV}, {OUTPUT_REVIEW_CSV}")
    print("=" * 60)


if __name__ == "__main__":
    main()
