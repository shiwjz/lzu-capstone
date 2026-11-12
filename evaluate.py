"""
정량 평가 (이윤경) - LG 혼잡도 버전
- 비교: 랜덤 · 인기순 · 거리순 vs 오디가 → Precision@5, nDCG@5
- 혼잡도 반영 전후 비교 (같은 시나리오에서 혼잡도 넣기 전/후 상위 5곳)
- 가중치 ±0.1 민감도
- ⚠️ LG 혼잡도로 계산한 결과라 결과 파일은 레포 밖(OUT_DIR)에만 저장 → 깃허브·AI에 올리지 않기
"""
import math, os
import numpy as np, pandas as pd
from place_score import place_score

LG_DIR = os.environ.get("LG_DATA_DIR", r"C:\lzu_data")
PLACE_FILE = "places_with_cell.csv"
TAG_FILE = os.path.join("blog_tag", "place_tag.csv")                         # 예린이 최신 태그 (레포)
CONG_FILE = os.path.join(LG_DIR, "output", "cell_congestion_lg.csv")         # LG 혼잡도 (레포 밖)
OUT_DIR = os.path.join(LG_DIR, "output", "eval")                            # 결과도 레포 밖

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
os.makedirs(OUT_DIR, exist_ok=True)
places = pd.read_csv(PLACE_FILE, encoding="utf-8-sig", dtype={"place_id": str})
tags = pd.read_csv(TAG_FILE, encoding="utf-8-sig", dtype={"place_id": str})
cong = pd.read_csv(CONG_FILE, encoding="utf-8-sig", dtype={"cell_id": str})
cong_idx = cong.set_index(["cell_id", "day_type", "hour"])[["level_same_time", "pct_same_time"]]

mentions = {pid: dict(zip(g["tag"], g["mentions"])) for pid, g in tags.groupby("place_id")}
popularity = tags.groupby("place_id")["mentions"].sum().to_dict()


def congestion_of(cell_id, day, hour):
    key = (str(cell_id), day, hour % 24)
    if key not in cong_idx.index:
        return None, None                      # LG 데이터 없는 칸 (홍대 테두리 1칸) → 중립
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
    # 동점 정렬용: 요청 태그 언급 수 합 (서버와 같은 기준)
    c["req_mentions"] = [sum(mentions.get(pid, {}).get(a, 0) for a in s["atmospheres"]) for pid in c["place_id"]]
    cond = {"atmospheres": s["atmospheres"], "crowdPreference": s["crowdPreference"],
            "gender": None, "ageGroup": None}               # 시나리오에 성·연령 없음 → 타깃 0.5
    parts = [place_score(cond, mentions.get(pid, {}), None, None, None, lv)
             for pid, lv in zip(c["place_id"], c["level"])]
    for k in ("request", "target", "congestion"):
        c[k] = [p[k] for p in parts]
    return c.reset_index(drop=True)


def odiga_top(c, w):
    total = w["request"] * c["request"] + w["target"] * c["target"] + w["congestion"] * c["congestion"]
    # 동점이면: 요청 태그 언급 수 합 많은 순 → place_id 순 (서버와 같은 규칙)
    return (c.assign(total=total)
             .sort_values(["total", "req_mentions", "place_id"], ascending=[False, False, True], kind="stable")
             .head(K))


def method_top(c, method, seed=42):
    if method == "랜덤":
        return c.sample(n=min(K, len(c)), random_state=seed)
    if method == "인기순":
        return c.sort_values(["popularity", "place_id"], ascending=[False, True], kind="stable").head(K)
    if method == "거리순":
        return c.sort_values(["dist_m", "place_id"], kind="stable").head(K)
    return odiga_top(c, BASE_W)


def evaluate_method(c, method):
    all_rels = list(c["rel"])
    if method == "랜덤":
        rng = np.random.default_rng(42)
        ps, ns = [], []
        for _ in range(RANDOM_RUNS):
            top = method_top(c, "랜덤", seed=int(rng.integers(1e9)))
            ps.append(precision_at_k(list(top["rel"]))); ns.append(ndcg_at_k(list(top["rel"]), all_rels))
        return np.mean(ps), np.mean(ns)
    top = method_top(c, method)
    return precision_at_k(list(top["rel"])), ndcg_at_k(list(top["rel"]), all_rels)


# ---------- 1. 방법 비교 ----------
METHODS = ["오디가", "인기순", "거리순", "랜덤"]
rows, cache = [], {}
for s in SCENARIOS:
    c = candidates(s)
    cache[(s["region"], s["name"])] = c
    for m in METHODS:
        p, n = evaluate_method(c, m)
        rows.append({"region": s["region"], "situation": s["name"], "method": m,
                     "candidates": len(c), "precision@5": round(p, 3), "ndcg@5": round(n, 3)})
res = pd.DataFrame(rows)
res.to_csv(os.path.join(OUT_DIR, "eval_methods_lg.csv"), index=False, encoding="utf-8-sig")
print("=== 1. 방법 비교 (9개 상황 평균) ===")
print(res.groupby("method")[["precision@5", "ndcg@5"]].mean().loc[METHODS].round(3))

# ---------- 2. 혼잡도 반영 전후 ----------
print("\n=== 2. 혼잡도 반영 전후 (같은 시나리오, 상위 5곳) ===")
no_cong = {"request": 0.45, "target": 0.30, "congestion": 0.0}
cmp_rows, summary = [], []
for s in SCENARIOS:
    c = cache[(s["region"], s["name"])]
    before, after = odiga_top(c, no_cong), odiga_top(c, BASE_W)
    keep = len(set(before["place_id"]) & set(after["place_id"]))
    fit = lambda t: t["level"].isin(CROWD_OK[s["crowdPreference"]]).sum()
    summary.append({"region": s["region"], "situation": s["name"],
                    "pct_before": round(before["pct"].mean(), 1), "pct_after": round(after["pct"].mean(), 1),
                    "crowd_fit_before": int(fit(before)), "crowd_fit_after": int(fit(after)),
                    "same_places": keep,
                    "ndcg_before": round(ndcg_at_k(list(before["rel"]), list(c["rel"])), 3),
                    "ndcg_after": round(ndcg_at_k(list(after["rel"]), list(c["rel"])), 3)})
    for tag, top in (("before", before), ("after", after)):
        for rank, r in enumerate(top.itertuples(), 1):
            cmp_rows.append({"region": s["region"], "situation": s["name"], "when": tag, "rank": rank,
                             "place_id": r.place_id, "level": r.level, "pct": r.pct})
summ = pd.DataFrame(summary)
summ.to_csv(os.path.join(OUT_DIR, "eval_congestion_effect_lg.csv"), index=False, encoding="utf-8-sig")
pd.DataFrame(cmp_rows).to_csv(os.path.join(OUT_DIR, "eval_congestion_top5_lg.csv"), index=False, encoding="utf-8-sig")
for pref, g in summ.groupby(summ["situation"]):
    print(f"[{pref}] 혼잡 선호 맞는 곳(5곳 중) {g['crowd_fit_before'].mean():.1f} → {g['crowd_fit_after'].mean():.1f}, "
          f"평균 혼잡도 백분위 {g['pct_before'].mean():.1f} → {g['pct_after'].mean():.1f}, "
          f"그대로 남은 곳 {g['same_places'].mean():.1f}곳, nDCG {g['ndcg_before'].mean():.3f} → {g['ndcg_after'].mean():.3f}")

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
sens.to_csv(os.path.join(OUT_DIR, "eval_sensitivity_lg.csv"), index=False, encoding="utf-8-sig")
print(sens.to_string(index=False))

# ---------- 4. 시나리오별 상위 5곳 목록 ----------
out = []
for s in SCENARIOS:
    c = cache[(s["region"], s["name"])]
    for m in METHODS:
        for rank, pid in enumerate(method_top(c, m)["place_id"], 1):
            out.append({"scenario": f'{s["region"]} {s["name"]}', "method": m, "rank": rank,
                        "place_id": pid, "moods": ",".join(s["atmospheres"])})
pd.DataFrame(out).to_csv(os.path.join(OUT_DIR, "eval_top5_lg.csv"), index=False, encoding="utf-8-sig")
print(f"\n결과 → {OUT_DIR} (LG 기반이라 깃허브·카톡·AI에 올리지 않기)")