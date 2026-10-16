import pandas as pd

POP_FILE = "floating_pop_fake.csv"     # 실제 데이터가 오면 여기만 바꾸기
OUT_FILE = "congestion_fake.csv"

cells = pd.read_csv("grid_cells.csv")
pop = pd.read_csv(POP_FILE)

pop["total"] = pop["stay_pop"].fillna(0) + pop["walk_pop"].fillna(0)

cong = (pop.groupby(["cell_id", "day_type", "hour"])["total"].mean()
           .rename("avg_pop").reset_index()
           .merge(cells[["cell_id", "region"]], on="cell_id"))
cong["avg_pop"] = cong["avg_pop"].round(1)

def to_level(pct):
    return pd.cut(pct, [0, 30, 70, 100], labels=["한산", "보통", "혼잡"], include_lowest=True)

# 추천 점수용: 같은 지역·같은 요일유형·같은 시간대 안에서 순위
cong["pct_same_time"] = (cong.groupby(["region", "day_type", "hour"])["avg_pop"]
                             .rank(pct=True) * 100).round(1)
cong["level_same_time"] = to_level(cong["pct_same_time"])

# 화면 표시용: 같은 지역 안 모든 칸·평일/주말·24시간을 섞어서 순위
cong["pct_all_day"] = (cong.groupby("region")["avg_pop"].rank(pct=True) * 100).round(1)
cong["level_all_day"] = to_level(cong["pct_all_day"])

cong.to_csv(OUT_FILE, index=False, encoding="utf-8-sig")
print(len(cong), "행")
print(cong.columns.tolist())