"""
LG 데이터로 칸 군집 분석 (이윤경)
- 특징 4묶음: 24시간 곡선(파일 1) · 체류 비율(파일 1) · 성·연령(성·연령 결과 파일) · 요일 모양(파일 3)
- 주중/주말 × 시간대가 없어서, 시간 곡선은 '모든 날 섞인 곡선' + 요일 모양을 따로 씀
- 결과·그림은 레포 밖(C:\\lzu_data\\output)에 저장 → 깃허브에 올리지 않음
"""
import os, math
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pyproj import Transformer
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

LG_DIR = os.environ.get("LG_DATA_DIR", r"C:\lzu_data")
OUT_DIR = os.path.join(LG_DIR, "output")
FILE1 = "DATADNI197_DATADNI197_YGH_HANSUNG_5TEAM_FST_TBL.csv"      # 시간대
FILE3 = "DATADNI197_DATADNI197_YGH_HANSUNG_5TEAM_THRD_TBL.csv"      # 요일
GA_FILE = os.path.join(OUT_DIR, "cell_gender_age_lg.csv")   # make_gender_age_lg.py 결과

MONTHS = None            # 쓸 달 (None이면 전체)
STAY_W, WALK_W = 1.0, 0.5
BEST_K = None            # 그래프 보고 직접 정하려면 숫자 (예: 2)
DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

os.makedirs(OUT_DIR, exist_ok=True)
grid = pd.read_csv("grid_cells.csv")
our_ids = set(grid["cell_id"])
to_m = Transformer.from_crs("EPSG:4326", "EPSG:5179", always_xy=True)


def load_lg(fname):
    """LG 파일 읽기 → 쓸 달만 → LG 셀을 우리 cell_id로 바꾸고 945칸 밖은 버림"""
    df = pd.read_csv(os.path.join(LG_DIR, fname), encoding="utf-8-sig",
                     dtype={"CELL_ID": str, "P_YYYYMM": str})
    if MONTHS:
        df = df[df["P_YYYYMM"].isin(MONTHS)]
    xy = df.drop_duplicates("CELL_ID")[["CELL_ID", "POI_CENTER_X_AXIS", "POI_CENTER_Y_AXIS"]]
    cmap = {}
    for cid, x, y in zip(xy["CELL_ID"], xy["POI_CENTER_X_AXIS"], xy["POI_CENTER_Y_AXIS"]):
        mx, my = to_m.transform(float(x), float(y))
        cmap[cid] = f"{math.floor(mx / 50)}_{math.floor(my / 50)}"
    df["cell_id"] = df["CELL_ID"].map(cmap)
    df = df[df["cell_id"].isin(our_ids)].copy()
    df["value"] = STAY_W * df["STAY_POPL_CNT"].fillna(0).astype(float) + WALK_W * df["WALK_POPL_CNT"].fillna(0).astype(float)
    return df


# 1. 24시간 곡선 (모든 날 섞임) + 체류 비율 ← 파일 1
d1 = load_lg(FILE1)
d1["hour"] = d1["TMZN"].astype(int)
d1["STAY_POPL_CNT"] = d1["STAY_POPL_CNT"].fillna(0).astype(float)
d1["WALK_POPL_CNT"] = d1["WALK_POPL_CNT"].fillna(0).astype(float)
by_m = d1.groupby(["cell_id", "P_YYYYMM", "hour"])[["value", "STAY_POPL_CNT", "WALK_POPL_CNT"]].sum().reset_index()  # 9·10월 동 나뉜 줄 더하기
curve = by_m.pivot_table(index="cell_id", columns="hour", values="value", aggfunc="mean")
curve = curve.div(curve.mean(axis=1), axis=0)                    # 모양만 남김
curve.columns = [f"h{h:02d}" for h in curve.columns]
s = by_m.groupby("cell_id")[["STAY_POPL_CNT", "WALK_POPL_CNT"]].sum()
stay_ratio = (s["STAY_POPL_CNT"] / (s["STAY_POPL_CNT"] + s["WALK_POPL_CNT"])).rename("stay_ratio")

# 2. 요일 모양 ← 파일 3 (요일별 비율, 합 1)
d3 = load_lg(FILE3)
dow = d3.groupby(["cell_id", "DYBY_NM"])["value"].sum().unstack()[DAYS]
dow = dow.div(dow.sum(axis=1), axis=0)
dow.columns = [f"dow_{d}" for d in DAYS]

# 3. 성·연령 ← make_gender_age_lg.py 결과
ga = pd.read_csv(GA_FILE).set_index("cell_id")
ga = ga[["female_ratio", "age_10s", "age_20s", "age_30s", "age_40s", "age_50s", "age_60s"]]

# 4. 합치기 + 표준화 + 네 묶음 영향력 같게
feat = curve.join(stay_ratio).join(ga).join(dow).dropna()
blocks = [list(curve.columns), ["stay_ratio"], list(ga.columns), list(dow.columns)]
X = StandardScaler().fit_transform(feat)
w = np.concatenate([np.full(len(b), 1 / np.sqrt(len(b))) for b in blocks])
X = X * w
print("군집에 쓴 칸:", len(feat), "/ 945")

# 5. K 정하기: 엘보우 + 실루엣
ks = list(range(2, 11))
inertias, sils = [], []
print("K  inertia  silhouette")
for k in ks:
    km = KMeans(n_clusters=k, n_init=10, random_state=42).fit(X)
    inertias.append(km.inertia_)
    sils.append(silhouette_score(X, km.labels_))
    print(f"{k:<2} {km.inertia_:8.1f}  {sils[-1]:.3f}")

fig, ax = plt.subplots(1, 2, figsize=(10, 4))
ax[0].plot(ks, inertias, "o-"); ax[0].set_title("Elbow (inertia)"); ax[0].set_xlabel("K")
ax[1].plot(ks, sils, "o-"); ax[1].set_title("Silhouette"); ax[1].set_xlabel("K")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "cluster_k_selection_lg.png"), dpi=120)
plt.close()

# 6. 최종 군집
k = BEST_K or ks[int(np.argmax(sils))]
km = KMeans(n_clusters=k, n_init=10, random_state=42).fit(X)
feat["cluster"] = km.labels_
feat[["cluster"]].reset_index().to_csv(os.path.join(OUT_DIR, "cell_cluster_lg.csv"), index=False, encoding="utf-8-sig")

# 7. 군집별 특징 요약 (이름 붙일 때 보는 표 → 숫자는 공유하지 말고 직접 해석)
g = feat.groupby("cluster")
hours = [c for c in curve.columns]
summary = pd.DataFrame({
    "cells": g.size(),
    "peak_hour": g[hours].mean().idxmax(axis=1).str[1:],
    "night_share(0-5h)": (g[hours[0:6]].mean().sum(axis=1) / g[hours].mean().sum(axis=1)).round(3),
    "weekend_share": g[["dow_Sat", "dow_Sun"]].mean().sum(axis=1).round(3),
    "stay_ratio": g["stay_ratio"].mean().round(3),
    "female_ratio": g["female_ratio"].mean().round(3),
    "age_20s": g["age_20s"].mean().round(3),
    "age_60s": g["age_60s"].mean().round(3),
})
print(f"\n선택된 K = {k}")
print(summary.to_string())
reg = grid.set_index("cell_id")["region"]
print(pd.crosstab(feat["cluster"], reg.loc[feat.index]))

# 8. 지역별 지도 그림 (칸 중심을 군집 색으로)
fig, axes = plt.subplots(1, 3, figsize=(15, 5))
cm = grid.set_index("cell_id").join(feat["cluster"])
for ax, region in zip(axes, ["SEONGSU", "HONGDAE", "GANGNAM"]):
    sub = cm[cm["region"] == region]
    has = sub["cluster"].notna()
    ax.scatter(sub.loc[~has, "center_lon"], sub.loc[~has, "center_lat"], c="lightgray", s=18, marker="s")
    ax.scatter(sub.loc[has, "center_lon"], sub.loc[has, "center_lat"], c=sub.loc[has, "cluster"],
               cmap="tab10", vmin=0, vmax=9, s=18, marker="s")
    ax.set_title(region); ax.set_aspect(1.25); ax.set_xticks([]); ax.set_yticks([])
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "cluster_map_lg.png"), dpi=150)
plt.close()
print("\n저장:", OUT_DIR, "(cell_cluster_lg.csv, cluster_k_selection_lg.png, cluster_map_lg.png)")

# 9. 군집 비교를 말로 출력 (숫자 없이 → 공유 가능)
def when(h):
    h = int(h)
    return "새벽" if h < 6 else "오전" if h < 11 else "점심" if h < 14 else "오후" if h < 17 else "저녁" if h < 21 else "밤"

def compare(col, label):
    v = summary[col].astype(float)
    hi, lo = v.idxmax(), v.idxmin()
    gap = (v.max() - v.min()) / (abs(v.mean()) + 1e-9)
    size = "비슷함" if gap < 0.05 else "조금 차이" if gap < 0.2 else "확실히 차이"
    return f"{label}: {hi}번이 가장 높고 {lo}번이 가장 낮음 ({size})"

print("\n===== 공유용 비교 (숫자 없음) =====")
print("실루엣 크기:", f"0.{int(max(sils) * 10)}대", "/ 가장 높은 K:", ks[int(np.argmax(sils))])
for c in summary.index:
    print(f"{c}번 정점 시간대: {when(summary.loc[c, 'peak_hour'])}")
print(compare("cells", "칸 수"))
print(compare("night_share(0-5h)", "새벽 비중"))
print(compare("weekend_share", "주말 비중"))
print(compare("stay_ratio", "체류 비율"))
print(compare("female_ratio", "여성 비율"))
print(compare("age_20s", "20대 비율"))
print(compare("age_60s", "60대 비율"))
ct = pd.crosstab(feat["cluster"], reg.loc[feat.index])
for region in ct.columns:
    share = ct[region] / ct[region].sum()
    top = share.idxmax()
    desc = "대부분" if share.max() >= 0.7 else "조금 더 많음" if share.max() >= 0.55 else "반반"
    print(f"{region}: {top}번 {desc}")