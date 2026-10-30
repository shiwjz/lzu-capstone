"""
장소 점수 모듈 (이윤경)
장소 점수 = 0.45 × 사용자 요구 + 0.30 × 타깃 특성 + 0.25 × 혼잡도 적합도 (각 0~1)
- 자바 PlaceScorerFactory로 옮길 계산식. 숫자는 전부 맨 위 상수에 모아 둠
"""
import pandas as pd

#계산에 쓰는 숫자 모아둔 거여서 혹시 비중 바꾸면 여기 수정!!
W_REQUEST, W_TARGET, W_FIT = 0.45, 0.30, 0.25
NEUTRAL = 0.5          # 정보가 없을 때 주는 중립 점수 (= 전체 평균 수준)
MENTION_FULL = 3       # (가정) 태그 언급 3번 이상이면 확실한 태그로 봄
CLUSTER_WEIGHT = 0.5   # (가정) 칸 비율과 같은 유형 칸들의 평균 비율을 섞는 비율

# 혼잡도 적합도 (명세 v0.3 초안)
CONGESTION_FIT = {
    "QUIET":   {"QUIET": 1.0, "NORMAL": 0.5, "BUSY": 0.1},
    "DEFAULT": {"QUIET": 0.8, "NORMAL": 1.0, "BUSY": 0.5},
    "LIVELY":  {"QUIET": 0.2, "NORMAL": 0.6, "BUSY": 1.0},
}


def request_score(atmospheres, place_tags):
    """사용자 요구: 요청 분위기 중 장소 태그와 일치하는 비율 (언급 수로 확실한 정도 반영)
    - atmospheres: ["조용함", "데이트"]
    - place_tags: {"조용함": 6, "디저트": 2}  (태그: 언급 수)
    """
    if not atmospheres:
        return NEUTRAL
    total = sum(min(place_tags.get(a, 0), MENTION_FULL) / MENTION_FULL for a in atmospheres)
    return total / len(atmospheres)


def target_score(cell, cluster, region_avg, gender, age_group):
    """타깃 특성: 칸의 타깃 집단 비율 ÷ 지역 평균 비율 → 0~1
    - cell: 이 칸의 성·연령 {"female_ratio": 0.6, "age_20s": 0.3, ...}
    - cluster: 같은 유형(cell_cluster) 칸들의 평균 성·연령 (없으면 None → 칸 값만 사용)
    - region_avg: 지역 평균 성·연령
    - gender: "F" / "M" / None,  age_group: "10s" ~ "60s" / None
    """
    if cell is None or (gender is None and age_group is None):
        return NEUTRAL

    def share(col):
        v = cell[col]
        if cluster is not None:
            v = (1 - CLUSTER_WEIGHT) * v + CLUSTER_WEIGHT * cluster[col]
        return v

    index = 1.0
    if gender is not None:
        f, f_avg = share("female_ratio"), region_avg["female_ratio"]
        index *= (f / f_avg) if gender == "F" else ((1 - f) / (1 - f_avg)) #여성이면
    if age_group is not None:
        col = f"age_{age_group}"
        index *= share(col) / region_avg[col] #20대면
    return index / (1 + index)


def congestion_fit(crowd_preference, level):
    """혼잡도 적합도: 혼잡 선호 × 도착 시각 혼잡 등급 (등급이 없으면 중립)"""
    if level is None:
        return NEUTRAL
    return CONGESTION_FIT[crowd_preference][level]


def place_score(conditions, place_tags, cell, cluster, region_avg, level):
    """장소 점수 하나 계산
    - conditions: {"atmospheres", "gender", "ageGroup", "crowdPreference"}
    - level: 도착 시각의 혼잡 등급 (QUIET/NORMAL/BUSY, 같은 시간끼리 비교한 level_same_time)
    """
    req = request_score(conditions.get("atmospheres"), place_tags)
    tgt = target_score(cell, cluster, region_avg, conditions.get("gender"), conditions.get("ageGroup"))
    fit = congestion_fit(conditions.get("crowdPreference", "DEFAULT"), level)
    total = W_REQUEST * req + W_TARGET * tgt + W_FIT * fit
    return {"total": total, "request": req, "target": tgt, "congestion": fit}


def load_target_data(ga_path="cell_gender_age_fake.csv", cluster_path="cell_cluster.csv"):
    """칸별 성·연령, 칸별 유형, 유형별 평균, 지역 평균 읽기
    사용 예: cluster = cluster_avg.get(cell_cluster.get(cell_id))
    """
    ga = pd.read_csv(ga_path).merge(pd.read_csv(cluster_path), on="cell_id", how="left")
    cols = ["female_ratio", "age_10s", "age_20s", "age_30s", "age_40s", "age_50s", "age_60s"]
    cells = ga.set_index("cell_id")[cols].to_dict("index")
    cell_cluster = ga.set_index("cell_id")["cluster"].to_dict()
    cluster_avg = ga.groupby("cluster")[cols].mean().to_dict("index")
    region_avg = ga.groupby("region")[cols].mean().to_dict("index")
    return cells, cell_cluster, cluster_avg, region_avg