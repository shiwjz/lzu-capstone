"""
정량 평가 (이윤경)
- 비교: 랜덤 · 인기순 · 거리순 vs 오디가 → Precision@5, nDCG@5
- 혼잡도 반영 전후 비교 (조용한 곳 상황의 상위 5곳 평균 혼잡도)
- 가중치 ±0.1 민감도
"""
import math
import numpy as np, pandas as pd
from place_score import place_score

PLACE_FILE = "places_with_cell.csv"
TAG_FILE = "place_tag.csv"                
CONG_FILE = "cell_congestion_seoul.csv"    # 서울시 실제 데이터 기준

K = 5
RANDOM_RUNS = 100
BASE_W = {"request": 0.45, "target": 0.30, "congestion": 0.25}

CENTER = {"SEONGSU": (37.544045, 127.0504), "HONGDAE": (37.5565, 126.9225), "GANGNAM": (37.501196, 127.02603)}

# 검색 상황 9개 = 지역 3개 × 상황 3개
SITUATIONS = [
    {"name": "주말 15시 조용한 카페",       "category": "CAFE", "dayType": "WEEKEND", "hour": 15, "atmospheres": ["조용함"], "crowdPreference": "QUIET"},
    {"name": "주중 12시 가성비 식당",       "category": "FOOD", "dayType": "WEEKDAY", "hour": 12, "atmospheres": ["가성비"], "crowdPreference": "DEFAULT"},
    {"name": "주말 19시 활기찬 데이트 식당", "category": "FOOD", "dayType": "WEEKEND", "hour": 19, "atmospheres": ["데이트"], "crowdPreference": "LIVELY"},
]
SCENARIOS = [dict(s, region=r) for r in CENTER for s in SITUATIONS]

# ---------- 데이터 ----------
places = pd.read_csv(PLACE_FILE, encoding="utf-8-sig", dtype={"place_id": str})
tags = pd.read_csv(TAG_FILE, encoding="utf-8-sig", dtype={"place_id": str})
cong = pd.read_csv(CONG_FILE, dtype={"cell_id": str})
cong_idx = cong.set_index(["cell_id", "day_type", "hour"])[["level_same_time", "pct_same_time"]]

mentions = {pid: dict(zip(g["tag"], g["mentions"])) for pid, g in tags.groupby("place_id")}
popularity = tags.groupby("place_id")["mentions"].sum().to_dict()


def congestion_of(cell_id, day, hour):
    key = (str(cell_id), day, hour % 24)
    if key not in cong_idx.index:
        return None, None
    row = cong_idx.loc[key]
    return row["level_same_time"], float(row["pct_same_time"])


# ---------- 정답 규칙 (0·1·2점) ----------
CROWD_OK = {"QUIET": {"QUIET"}, "LIVELY": {"BUSY"}, "DEFAULT": {"QUIET", "NORMAL"}}

def relevance(pid, level, s):
    tag_ok = any(a in mentions.get(pid, {}) for a in s["atmospheres"])   # 파일에 그 태그가 있으면 있음
    cong_ok = level in CROWD_OK[s["crowdPreference"]]
    return int(tag_ok) + int(cong_ok)


# ---------- 지표 ----------
def precision_at_k(rels):
    return sum(r >= 1 for r in rels[:K]) / K

def dcg(rels):
    return sum((2 ** r - 1) / math.log2(i + 2) for i, r in enumerate(rels[:K]))

def ndcg_at_k(rels, all_rels):
    ideal = dcg(sorted(all_rels, reverse=True))
    return dcg(rels) / ideal if ideal > 0 else 0.0


# ---------- 후보 + 점수 ----------
def candidates(s):
    c = places[(places["region"] == s["region"]) & (places["category"] == s["category"])].copy()
    lat0, lng0 = CENTER[s["region"]]
    c["dist_m"] = np.hypot((c["latitude"] - lat0) * 111000, (c["longitude"] - lng0) * 88000)
    info = [congestion_of(cid, s["dayType"], s["hour"]) for cid in c["cell_id"]]
    c["level"] = [i[0] for i in info]
    c["pct"] = [i[1] for i in info]
    c["rel"] = [relevance(pid, lv, s) for pid, lv in zip(c["place_id"], c["level"])]
    c["popularity"] = c["place_id"].map(popularity).fillna(0)
    cond = {"atmospheres": s["atmospheres"], "crowdPreference": s["crowdPreference"],
            "gender": None, "ageGroup": None}               # 성·연령은 가짜라 평가에서 제외 → 타깃 0.5
    parts = [place_score(cond, mentions.get(pid, {}), None, None, None, lv)
             for pid, lv in zip(c["place_id"], c["level"])]
    for k in ("request", "target", "congestion"):
        c[k] = [p[k] for p in parts]
    return c.sort_values("place_id").reset_index(drop=True)   # 동점일 때 순서 고정


def odiga_top(c, w):
    total = w["request"] * c["request"] + w["target"] * c["target"] + w["congestion"] * c["congestion"]
    return c.assign(total=total).sort_values("total", ascending=False, kind="stable").head(K)


def evaluate_method(c, method):
    all_rels = list(c["rel"])
    if method == "랜덤":
        rng = np.random.default_rng(42)
        ps, ns = [], []
        for _ in range(RANDOM_RUNS):
            top = c.sample(n=min(K, len(c)), random_state=rng.integers(1e9))
            ps.append(precision_at_k(list(top["rel"]))); ns.append(ndcg_at_k(list(top["rel"]), all_rels))
        return np.mean(ps), np.mean(ns)
    if method == "인기순":
        top = c.sort_values("popularity", ascending=False, kind="stable").head(K)
    elif method == "거리순":
        top = c.sort_values("dist_m", kind="stable").head(K)
    else:
        top = odiga_top(c, BASE_W)
    rels = list(top["rel"])
    return precision_at_k(rels), ndcg_at_k(rels, all_rels)


# ---------- 1. 방법 비교 ----------
METHODS = ["랜덤", "인기순", "거리순", "오디가"]
rows, cache = [], {}
for s in SCENARIOS:
    c = candidates(s)
    cache[(s["region"], s["name"])] = c
    for m in METHODS:
        p, n = evaluate_method(c, m)
        rows.append({"region": s["region"], "situation": s["name"], "method": m,
                     "candidates": len(c), "precision@5": round(p, 3), "ndcg@5": round(n, 3)})
res = pd.DataFrame(rows)
res.to_csv("eval_methods.csv", index=False, encoding="utf-8-sig")

print("=== 1. 방법 비교 (9개 상황 평균) ===")
print(res.groupby("method")[["precision@5", "ndcg@5"]].mean().loc[METHODS].round(3))

# ---------- 2. 혼잡도 반영 전후 (조용한 곳 상황) ----------
print("\n=== 2. 혼잡도 반영 전후: 조용한 곳 상황 상위 5곳 평균 혼잡도 백분위 (낮을수록 한산) ===")
no_cong = {"request": 0.45, "target": 0.30, "congestion": 0.0}
before, after = [], []
for s in SCENARIOS:
    if s["crowdPreference"] != "QUIET":
        continue
    c = cache[(s["region"], s["name"])]
    b = odiga_top(c, no_cong)["pct"].mean()
    a = odiga_top(c, BASE_W)["pct"].mean()
    before.append(b); after.append(a)
    print(f"{s['region']:8} 반영 전 {b:5.1f} → 반영 후 {a:5.1f}")
print(f"평균     반영 전 {np.mean(before):5.1f} → 반영 후 {np.mean(after):5.1f}")

# ---------- 3. 가중치 ±0.1 민감도 ----------
print("\n=== 3. 가중치 ±0.1 민감도 (9개 상황 평균) ===")
sens = []
for key in BASE_W:
    for d in (-0.1, 0.1):
        w = dict(BASE_W); w[key] = round(w[key] + d, 2)
        tot = sum(w.values()); w = {k: v / tot for k, v in w.items()}   # 합이 1이 되게 다시 맞춤
        overlaps, ndcgs = [], []
        for s in SCENARIOS:
            c = cache[(s["region"], s["name"])]
            base_ids = set(odiga_top(c, BASE_W)["place_id"])
            top = odiga_top(c, w)
            overlaps.append(len(base_ids & set(top["place_id"])))
            ndcgs.append(ndcg_at_k(list(top["rel"]), list(c["rel"])))
        sens.append({"change": f"{key} {d:+.1f}", "top5_overlap_with_base": round(np.mean(overlaps), 2),
                     "ndcg@5": round(np.mean(ndcgs), 3)})
sens = pd.DataFrame(sens)
sens.to_csv("eval_sensitivity.csv", index=False, encoding="utf-8-sig")
print(sens.to_string(index=False))