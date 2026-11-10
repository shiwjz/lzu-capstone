"""
장소 점수 모듈 (이윤경)
장소 점수 = 0.45 × 사용자 요구 + 0.30 × 타깃 특성 + 0.25 × 혼잡도 적합도 (각 0~1)
- 자바 PlaceScorerFactory로 옮길 계산식. 숫자는 전부 맨 위 상수에 모아 둠
"""
import pandas as pd

W_REQUEST, W_TARGET, W_FIT = 0.45, 0.30, 0.25
NEUTRAL = 0.5          # 정보가 없을 때 주는 중립 점수 (= 전체 평균 수준)
MENTION_FULL = 3       # (가정) 태그 언급 3번 이상이면 확실한 태그로 봄
CLUSTER_WEIGHT = 0.5   # (가정) 칸 비율과 같은 유형 칸들의 평균 비율을 섞는 비율

# 혼잡도 적합도 (명세 v0.4 확정)
CONGESTION_FIT = {
    "QUIET":   {"QUIET": 1.0, "NORMAL": 0.5, "BUSY": 0.1},
    "DEFAULT": {"QUIET": 0.8, "NORMAL": 1.0, "BUSY": 0.5},
    "LIVELY":  {"QUIET": 0.2, "NORMAL": 0.6, "BUSY": 1.0},
}

# 음식 세부 → 큰 종류 (명세 v0.5 음식 취향 표, Cuisine.java와 같음)
CUISINE_DETAILS = {
    "KOREAN":   ["고기", "국밥", "찌개·전골", "국수", "해물·생선"],
    "JAPANESE": ["초밥·롤", "라멘", "돈까스·우동", "덮밥"],
    "WESTERN":  ["이탈리안", "피자", "햄버거", "스테이크", "멕시칸"],
    "CHINESE":  ["중국요리", "양꼬치"],
    "BUNSIK":   ["떡볶이", "김밥"],
    "ASIAN":    ["동남아", "인도"],
    "BAR":      ["호프·요리주점", "이자카야", "칵테일바", "와인바", "포장마차"],
    "CAFE":     ["디저트카페", "개인카페", "프랜차이즈", "갤러리·북카페", "차·음료"],
}
DETAIL_TO_CUISINE = {d: c for c, ds in CUISINE_DETAILS.items() for d in ds}

# 음식 세부 점수 (명세 v0.5)
DETAIL_EXACT, DETAIL_NONE, DETAIL_OTHER = 1.0, 0.5, 0.2


def mood_score(atmosphere, place_tags):
    """분위기 하나 점수: 언급 수 ÷ 3 (최대 1). 태그가 하나도 없는 장소는 모르니까 중립 0.5"""
    if not place_tags:
        return NEUTRAL
    return min(place_tags.get(atmosphere, 0), MENTION_FULL) / MENTION_FULL


def detail_score(cuisine_details, place_cuisine, place_detail):
    """음식 세부 점수 (명세 v0.5). 계산 안 하는 경우는 None
    - 장소 세부가 요청 세부에 있음 → 1.0
    - 요청 세부 중 장소와 같은 큰 종류가 있음: 장소 세부 없음 → 0.5 / 다른 세부 → 0.2
    - 요청 세부가 모두 다른 큰 종류 → None (계산 안 함)
    """
    if not cuisine_details:
        return None
    if place_detail is not None and place_detail in cuisine_details:
        return DETAIL_EXACT
    same_kind = [d for d in cuisine_details if DETAIL_TO_CUISINE.get(d) == place_cuisine]
    if not same_kind:
        return None
    return DETAIL_NONE if place_detail is None else DETAIL_OTHER


def request_score(atmospheres, place_tags, cuisine_details=None, place_cuisine=None, place_detail=None):
    """사용자 요구: (분위기 점수 합 + 음식 세부 점수) ÷ (분위기 수 + 1)
    - atmospheres: ["조용함", "데이트"]
    - place_tags: {"조용함": 6, "디저트": 2}  (태그: 언급 수, 태그 없는 장소는 {})
    - 세부 점수를 계산 안 하면 분위기 점수 평균, 분위기도 없으면 0.5
    """
    moods = atmospheres or []
    scores = [mood_score(a, place_tags) for a in moods]
    d = detail_score(cuisine_details, place_cuisine, place_detail)
    if d is not None:
        scores.append(d)
    if not scores:
        return NEUTRAL
    return sum(scores) / len(scores)


def target_score(cell, cluster, region_avg, gender, age_group):
    """타깃 특성: 칸의 타깃 집단 비율 ÷ 지역 평균 비율 → 0~1
    - cell: 이 칸의 성·연령 {"female_ratio": 0.6, "age_20s": 0.3, "f_20s": 0.18, ...}
    - cluster: 같은 유형(cell_cluster) 칸들의 평균 성·연령 (없으면 None → 칸 값만 사용)
    - region_avg: 지역 평균 성·연령
    - gender: "F" / "M" / None,  age_group: "10s" ~ "60s" / None
    - 성별·연령이 둘 다 있고 칸에 성별 × 연령 비율(f_20s 등)이 있으면 그 값을 바로 사용 (LG 데이터)
      없으면 성별 배수 × 연령 배수로 추정 (가짜 데이터용)
    """
    if cell is None or (gender is None and age_group is None):
        return NEUTRAL

    def share(col):
        v = cell[col]
        if cluster is not None:
            v = (1 - CLUSTER_WEIGHT) * v + CLUSTER_WEIGHT * cluster[col]
        return v

    joint_col = f"{gender.lower()}_{age_group}" if gender and age_group else None
    if joint_col and joint_col in cell:
        index = share(joint_col) / region_avg[joint_col]
    else:
        index = 1.0
        if gender is not None:
            f, f_avg = share("female_ratio"), region_avg["female_ratio"]
            index *= (f / f_avg) if gender == "F" else ((1 - f) / (1 - f_avg))
        if age_group is not None:
            col = f"age_{age_group}"
            index *= share(col) / region_avg[col]
    return index / (1 + index)


def congestion_fit(crowd_preference, level):
    """혼잡도 적합도: 혼잡 선호 × 도착 시각 혼잡 등급 (등급이 없으면 중립)"""
    if level is None:
        return NEUTRAL
    return CONGESTION_FIT[crowd_preference][level]


def place_score(conditions, place_tags, cell, cluster, region_avg, level,
                place_cuisine=None, place_detail=None):
    """장소 점수 하나 계산
    - conditions: {"atmospheres", "gender", "ageGroup", "crowdPreference", "cuisineDetails"}
    - level: 도착 시각의 혼잡 등급 (QUIET/NORMAL/BUSY, 같은 시간끼리 비교한 level_same_time)
    - place_cuisine / place_detail: 장소 음식 큰 종류 / 세부 (모르면 None)
    """
    req = request_score(conditions.get("atmospheres"), place_tags,
                        conditions.get("cuisineDetails"), place_cuisine, place_detail)
    tgt = target_score(cell, cluster, region_avg, conditions.get("gender"), conditions.get("ageGroup"))
    fit = congestion_fit(conditions.get("crowdPreference", "DEFAULT"), level)
    total = W_REQUEST * req + W_TARGET * tgt + W_FIT * fit
    return {"total": total, "request": req, "target": tgt, "congestion": fit}


def load_target_data(ga_path="cell_gender_age_fake.csv", cluster_path="cell_cluster.csv"):
    """칸별 성·연령, 칸별 유형, 유형별 평균, 지역 평균 읽기
    사용 예: cluster = cluster_avg.get(cell_cluster.get(cell_id))
    """
    ga = pd.read_csv(ga_path).merge(pd.read_csv(cluster_path), on="cell_id", how="left")
    cols = [c for c in ga.columns if c not in ("cell_id", "region", "cluster")]   # 성·연령 컬럼 전부 (LG면 f_20s 등 포함)    cells = ga.set_index("cell_id")[cols].to_dict("index")
    cell_cluster = ga.set_index("cell_id")["cluster"].to_dict()
    cluster_avg = ga.groupby("cluster")[cols].mean().to_dict("index")
    region_avg = ga.groupby("region")[cols].mean().to_dict("index")
    return cells, cell_cluster, cluster_avg, region_avg