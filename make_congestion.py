import pandas as pd

POP_FILE = "floating_pop_fake.csv"     # 실제 데이터가 오면 여기만 바꾸기
OUT_FILE = "congestion_fake.csv"

cells = pd.read_csv("grid_cells.csv")
pop = pd.read_csv(POP_FILE)

# 체류 + 보행 = 총 인구 (빈 값은 0으로 처리)
pop["total"] = pop["stay_pop"].fillna(0) + pop["walk_pop"].fillna(0)

# 셀·요일유형·시간별 평균 인구 (여러 달 평균)
cong = (pop.groupby(["cell_id", "day_type", "hour"])["total"].mean()
           .rename("avg_pop").reset_index()
           .merge(cells[["cell_id", "region"]], on="cell_id"))
cong["avg_pop"] = cong["avg_pop"].round(1)

# 지역 전체(모든 셀·평일/주말·모든 시간) 안에서 순위 → 0~100 백분위
cong["congestion_pct"] = (cong.groupby("region")["avg_pop"].rank(pct=True) * 100).round(1)

# 하위 30% 한산 / 상위 30% 혼잡 / 나머지 보통
cong["congestion_level"] = pd.cut(cong["congestion_pct"], [0, 30, 70, 100],
                                  labels=["한산", "보통", "혼잡"], include_lowest=True)

cong.to_csv(OUT_FILE, index=False, encoding="utf-8-sig")
print(len(cong), "행")
print(cong.columns.tolist())