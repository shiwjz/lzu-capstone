import numpy as np, pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
import matplotlib.pyplot as plt

pop = pd.read_csv("floating_pop_fake.csv")
gender_age = pd.read_csv("cell_gender_age_fake.csv").set_index("cell_id").drop(columns="region")
cells = pd.read_csv("grid_cells.csv").set_index("cell_id")

# 24시간 곡선 (주중 24 + 주말 24), 칸 평균으로 나눠 모양만 남김
pop["value"] = pop["stay_pop"] + 0.5 * pop["walk_pop"]
curve = pop.pivot_table(index="cell_id", columns=["day_type", "hour"], values="value", aggfunc="mean")
curve = curve.div(curve.mean(axis=1), axis=0)
curve.columns = [f"{d}_{h:02d}" for d, h in curve.columns]

# 체류 비율
s = pop.groupby("cell_id")[["stay_pop", "walk_pop"]].sum()
stay_ratio = (s["stay_pop"] / (s["stay_pop"] + s["walk_pop"])).rename("stay_ratio")

#특징 합치기 + 표준화
feat = curve.join(stay_ratio).join(gender_age).dropna()
X = StandardScaler().fit_transform(feat)

#곡선(48개)이 결과를 독차지하지 않게, 세 묶음의 영향력을 똑같이 맞춤
n_curve, n_ga = curve.shape[1], gender_age.shape[1]
w = np.r_[np.full(n_curve, 1 / np.sqrt(n_curve)), [1.0], np.full(n_ga, 1 / np.sqrt(n_ga))]
X = X * w

#K 정하기: 엘보우 + 실루엣
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
plt.savefig("cluster_k_selection.png", dpi=120)

# 5. 최종 군집
BEST_K = None                       # 그래프를 보고 직접 정하려면 숫자를 넣기
k = BEST_K or ks[int(np.argmax(sils))]
km = KMeans(n_clusters=k, n_init=10, random_state=42).fit(X)
feat["cluster"] = km.labels_

feat[["cluster"]].reset_index().to_csv("cell_cluster.csv", index=False, encoding="utf-8-sig")

#군집별 특징 요약
wk = [c for c in curve.columns if c.startswith("WEEKDAY")]
we = [c for c in curve.columns if c.startswith("WEEKEND")]
g = feat.groupby("cluster")
summary = pd.DataFrame({
    "cells": g.size(),
    "weekday_peak": g[wk].mean().idxmax(axis=1).str[-2:],
    "weekend_peak": g[we].mean().idxmax(axis=1).str[-2:],
    "weekend_vs_weekday": (g[we].mean().mean(axis=1) / g[wk].mean().mean(axis=1)).round(2),
    "stay_ratio": g["stay_ratio"].mean().round(2),
    "female_ratio": g["female_ratio"].mean().round(2),
    "age_20s": g["age_20s"].mean().round(2),
})
print(f"\n선택된 K = {k}")
print(summary)
print(pd.crosstab(feat["cluster"], cells.loc[feat.index, "region"]))