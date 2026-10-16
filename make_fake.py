import numpy as np, pandas as pd

rng = np.random.default_rng(42)
cells = pd.read_csv("grid_cells.csv")
prof = pd.read_csv("seoul_profile.csv")
hours = np.arange(24)

# 서울시 실측 곡선을 셀 단위로 축소 (지역별 주중 평균 = 100)
wk_mean = prof[prof.day_type == "weekday"].groupby("region")["avg_pop"].mean()
CURVE = {(r, t): g.sort_values("hour")["avg_pop"].values / wk_mean[r] * 100
         for (r, t), g in prof.groupby(["region", "day_type"])}
MONTH_FACTOR = {"2026-04": 1.00, "2026-05": 1.05, "2026-06": 1.00,
                "2026-07": 0.95}

rows = []
for c in cells.itertuples():
    weight = rng.lognormal(0, 0.5) * (1.3 - 0.6 * c.dist_m / 500)
    shift = rng.uniform(-2, 2)
    walk_share = rng.uniform(0.3, 0.5)
    for day_type in ["weekday", "weekend"]:
        curve = np.interp((hours - shift) % 24, hours, CURVE[(c.region, day_type)], period=24)
        for ym, mf in MONTH_FACTOR.items():
            total = rng.poisson(curve * weight * mf)
            walk = np.round(total * walk_share).astype(int)
            for h in hours:
                rows.append((c.cell_id, ym, day_type, h, total[h] - walk[h], walk[h]))

pop = pd.DataFrame(rows, columns=["cell_id", "ym", "day_type", "hour", "stay_pop", "walk_pop"])
pop.to_csv("floating_pop_fake.csv", index=False, encoding="utf-8-sig")
