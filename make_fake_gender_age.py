import numpy as np, pandas as pd

#랜덤으로 돌리기
rng = np.random.default_rng(7)

#더미데이터상 성 연령 데이터 불러오기
cells = pd.read_csv("grid_cells.csv")
prof = pd.read_csv("seoul_gender_age_profile.csv").set_index("region")   # 서울시 실측 지역별 성·연령 구성

AGES = ["age_10s", "age_20s", "age_30s", "age_40s", "age_50s", "age_60s"]

#칸마다 평균 가져오기
rows = []
for c in cells.itertuples():
    p = prof.loc[c.region]
    ages = rng.dirichlet(p[AGES].values.astype(float) * 60)            # 지역 평균 근처에서 칸마다 조금씩 다르게
    female = np.clip(rng.normal(p["female_ratio"], 0.05), 0.3, 0.7)
    rows.append({"cell_id": c.cell_id, "region": c.region, "female_ratio": round(female, 3),
                 **{a: round(v, 3) for a, v in zip(AGES, ages)}})

pd.DataFrame(rows).to_csv("cell_gender_age_fake.csv", index=False, encoding="utf-8-sig")
print(len(rows), "행")