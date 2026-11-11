"""
블로그에서 "1차·2차" 코스 순서 표현 세기 (11주차 노션 3번) → 코스 틀 근거

- 저장해 둔 블로그 검색 결과(blog_tag/raw)에서 "1차", "2차", "3차"가 나온 글을 찾음
- "1차 고기 2차 이자카야", "2차로 노래방", "고기로 1차" 처럼 몇 차에 뭘 했는지 종류로 묶어서 셈
- 같은 글이 여러 장소 검색에 나와도 한 번만 셈 (링크로 중복 제거)
- "1차 접종", "2차전지", "3차원" 같은 엉뚱한 말은 빼고, 먹고 노는 단어가 같이 나온 것만

출력
  blog_tag/course_order_pairs.csv   "1차 → 2차" 짝별 글 수 (예: 고기 → 술집 120건)
  blog_tag/course_order_steps.csv   몇 차에 어떤 종류가 많았는지 (예: 2차 술집 300건)
  화면에 요약 표

실행 (API 호출 없음)
  python blog_tag/count_course_order.py
"""

import csv
import json
import os
import re
from collections import Counter, defaultdict

RAW_DIR = "blog_tag/raw"
PAIRS_CSV = "blog_tag/course_order_pairs.csv"
STEPS_CSV = "blog_tag/course_order_steps.csv"


# =========================================================
# 몇 차에 뭘 했는지 → 종류 (위에서부터 먼저 맞는 걸로)
# 서버 코스 칸이랑 맞춤: 식사(MEAL) / 술집(BAR) / 카페(CAFE) / 놀거리(PLAY)
# =========================================================

KINDS = [
    ("술집", ["술집", "이자카야", "포차", "호프", "맥주", "하이볼", "와인", "칵테일", "주점", "펍", "바에서",
             "막걸리", "소주", "한잔", "칵테일바", "와인바", "LP바", "lp바"]),
    ("노래방", ["노래방", "코노", "코인노래"]),
    ("카페", ["카페", "디저트", "커피", "빙수", "케이크"]),
    ("놀거리", ["방탈출", "보드게임", "볼링", "오락실", "당구", "포켓볼", "다트", "만화카페", "전시", "영화", "산책"]),
    ("고기", ["고기", "삼겹", "목살", "갈비", "곱창", "막창", "대창", "한우", "소고기", "족발", "보쌈", "닭갈비"]),
    ("식사", ["맛집", "식사", "저녁", "점심", "밥", "파스타", "피자", "초밥", "스시", "라멘", "국밥", "치킨",
             "떡볶이", "회", "횟집", "중식", "마라", "샤브", "버거"]),
]

# 엉뚱한 "N차"
NOT_COURSE = ["접종", "전지", "차원", "차선", "가공", "면접", "합격", "시험", "발표", "모집", "오픈", "예약",
              "웨이팅", "대기", "티켓", "판매", "출시", "드롭", "회차", "1차적", "2차적", "차례", "공고", "계약"]

# "1차 고기", "2차는 이자카야로", "2차로 노래방"
AFTER = re.compile(r"([1-4])\s*차\s*(?:는|은|로|으로|에|에서|도|까지|:|-|>|=)?\s*([^\s\d,.!?/·|]{1,12})")
# "고기로 1차", "이자카야에서 2차"
BEFORE = re.compile(r"([가-힣A-Za-z]{1,10})(?:로|으로|에서)\s*([1-4])\s*차(?![가-힣])")


def kind_of(word):
    for kind, words in KINDS:
        if any(w in word for w in words):
            return kind
    return None


def find_steps(text):
    """글에서 {차수: 종류} 찾기. 같은 차수가 여러 번이면 먼저 나온 것"""

    steps = {}

    for m in AFTER.finditer(text):
        n, word = int(m.group(1)), m.group(2)
        if any(bad in word for bad in NOT_COURSE):
            continue
        kind = kind_of(word)
        if kind is None:
            # 바로 뒤 단어로 모르면 조금 더 뒤까지 봄 ("2차 장소 추천 강남 술집"), 다음 "N차" 전까지만
            window = text[m.end():m.end() + 15]
            window = re.split(r"[1-4]\s*차", window)[0]
            kind = kind_of(window)
        if kind and n not in steps:
            steps[n] = kind

    for m in BEFORE.finditer(text):
        word, n = m.group(1), int(m.group(2))
        kind = kind_of(word)
        if kind and n not in steps:
            steps[n] = kind

    return steps


def main():
    seen_links = set()
    posts_total = 0
    posts_with_course = 0
    step_counter = Counter()          # (차수, 종류) → 글 수
    pair_counter = Counter()          # (1차 종류, 2차 종류) → 글 수
    chain_counter = Counter()         # "고기 → 술집 → 노래방" → 글 수
    examples = defaultdict(list)

    files = [f for f in os.listdir(RAW_DIR) if f.endswith(".json")]

    for name in files:
        with open(os.path.join(RAW_DIR, name), encoding="utf-8") as f:
            blogs = json.load(f)["blogs"]

        for blog in blogs:
            link = blog.get("link", "")
            if link in seen_links:
                continue
            seen_links.add(link)
            posts_total += 1

            text = blog.get("title", "") + " " + blog.get("description", "")
            if "차" not in text:
                continue

            steps = find_steps(text)
            if not steps:
                continue

            posts_with_course += 1
            for n, kind in steps.items():
                step_counter[(n, kind)] += 1

            if 1 in steps and 2 in steps:
                pair = (steps[1], steps[2])
                pair_counter[pair] += 1
                if len(examples[pair]) < 3:
                    examples[pair].append(blog.get("title", "")[:60])

            ordered = [steps[n] for n in sorted(steps)]
            if len(ordered) >= 2 and sorted(steps) == list(range(1, len(ordered) + 1)):
                chain_counter[" → ".join(ordered)] += 1

    # ---------------- 저장 ----------------
    with open(PAIRS_CSV, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["1차", "2차", "글 수", "예시 제목"])
        for (a, b), count in pair_counter.most_common():
            w.writerow([a, b, count, " / ".join(examples[(a, b)])])

    with open(STEPS_CSV, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["차수", "종류", "글 수"])
        for (n, kind), count in sorted(step_counter.items(), key=lambda x: (x[0][0], -x[1])):
            w.writerow([f"{n}차", kind, count])

    # ---------------- 요약 ----------------
    print("=" * 56)
    print(f"블로그 글 {posts_total:,}개 (중복 제거) 중 'N차' 코스 표현이 있는 글: {posts_with_course:,}개")
    print("=" * 56)

    for n in (1, 2, 3):
        row = [(kind, c) for (k, kind), c in step_counter.items() if k == n]
        total = sum(c for _, c in row)
        if not total:
            continue
        row.sort(key=lambda x: -x[1])
        text = ", ".join(f"{kind} {c}건({c / total:.0%})" for kind, c in row)
        print(f"{n}차 ({total}건): {text}")

    print()
    print("1차 → 2차 많이 나온 순서")
    for (a, b), count in pair_counter.most_common(10):
        print(f"  {a:<4} → {b:<4} {count:>4}건   예) {examples[(a, b)][0]}")

    print()
    print("3차 이상까지 이어진 코스")
    for chain, count in chain_counter.most_common(8):
        if chain.count("→") >= 2:
            print(f"  {chain}  {count}건")

    print()
    print(f"저장: {PAIRS_CSV}, {STEPS_CSV}")


if __name__ == "__main__":
    main()
