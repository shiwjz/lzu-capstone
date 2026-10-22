import pandas as pd

POP_FILE = "floating_pop_fake.csv"     # 실제 데이터가 오면 여기만 바꾸기
OUT_FILE = "cell_congestion.csv"

cells = pd.read_csv("grid_cells.csv")
pop = pd.read_csv(POP_FILE)

#셀 값 = 체류 + 0.5 × 보행 (빈 값은 0)
pop["cell_value"] = pop["stay_pop"].fillna(0) + 0.5 * pop["walk_pop"].fillna(0)

#월별 값을 평균 내기, 셀·주중/주말·시간별 하나의 값
base = pop.groupby(["cell_id", "day_type", "hour"])["cell_value"].mean().reset_index()

#주변 3*3 격자 기준 평균 구하기 (가운데 칸으로 위치로 모은뒤에 평균 내는 방식)
xy = base["cell_id"].str.split("_", expand=True).astype(int)
base["ix"], base["iy"] = xy[0], xy[1]

parts = []
for dx in (-1, 0, 1):
    for dy in (-1, 0, 1):
        nb = base[["ix", "iy", "day_type", "hour", "cell_value"]].copy()
        nb["ix"] -= dx      # 이웃 칸의 값을 가운데 칸 위치로 옮겨 놓기
        nb["iy"] -= dy
        parts.append(nb)

smooth = (pd.concat(parts)
            .groupby(["ix", "iy", "day_type", "hour"])["cell_value"].mean()
            .rename("smooth_value").reset_index())
# 격자 밖 이웃은 데이터가 없으니 자동으로 빠지고, 있는 이웃끼리만 평균

cong = (base.merge(smooth, on=["ix", "iy", "day_type", "hour"], how="left")
            .merge(cells[["cell_id", "region"]], on="cell_id"))

def to_level(pct):
    # 하위 30% QUIET / 30~70% NORMAL / 상위 30% BUSY
    return pd.cut(pct, [0, 30, 70, 100], labels=["QUIET", "NORMAL", "BUSY"], include_lowest=True)

#추천 점수용: 같은 지역·같은 주중/주말·같은 시간 안에서 백분위
cong["pct_same_time"] = (cong.groupby(["region", "day_type", "hour"])["smooth_value"]
                             .rank(pct=True) * 100).round(1)
cong["level_same_time"] = to_level(cong["pct_same_time"])

#화면 표시용: 같은 지역 안 모든 칸·주중/주말·24시간을 섞어서 백분위
cong["pct_all_day"] = (cong.groupby("region")["smooth_value"].rank(pct=True) * 100).round(1)
cong["level_all_day"] = to_level(cong["pct_all_day"])

cong["cell_value"] = cong["cell_value"].round(1)
cong["smooth_value"] = cong["smooth_value"].round(1)
cong = cong[["cell_id", "region", "day_type", "hour", "cell_value", "smooth_value",
             "pct_same_time", "level_same_time", "pct_all_day", "level_all_day"]]

cong.to_csv(OUT_FILE, index=False, encoding="utf-8-sig")
print(len(cong), "행")
print(cong.columns.tolist())
print(cong["level_same_time"].value_counts())