#데모데이터- 진짜 데이터 오면 빠질 예정
import pandas as pd, geopandas as gpd, admdongkor as adk

cells = pd.read_csv("grid_cells.csv")
hourly = pd.read_csv("seoul_dong_hourly.csv", dtype={"dong_code": str})

# 1. 행정동 경계 (2016년, EPSG:5179) - 서울만
dong = adk.get("20160201", "emd")
dong = dong[dong["sidonm"].str.contains("서울")].copy()

# 2016년 지도는 코드가 비어 있음 → 최신 지도에서 '구 이름 + 동 이름'으로 행정안전부 코드(emdcd 앞 8자리)를 가져옴
recent = adk.get(adk.versions()[-1], "emd")
recent = recent[recent["sidonm"].str.contains("서울")].copy()
print(recent[recent["emdnm"] == "역삼1동"][["emd7", "emd8", "emdcd"]])   # 코드 종류 확인용
recent["dong_code"] = recent["emdcd"].astype(str).str.replace(r"\.0$", "", regex=True).str[:8]
dong = dong.drop(columns="emd8").merge(recent[["sggnm", "emdnm", "dong_code"]],
                                       on=["sggnm", "emdnm"], how="left")
dong["area_m2"] = dong.geometry.area

# 2. 칸 중심점이 어느 동 안에 있는지 (cell_id "ix_iy" → 중심 좌표)
xy = cells["cell_id"].str.split("_", expand=True).astype(int)
pts = gpd.GeoDataFrame(cells[["cell_id", "region"]],
                       geometry=gpd.points_from_xy((xy[0] + 0.5) * 50, (xy[1] + 0.5) * 50),
                       crs="EPSG:5179")
cell_dong = gpd.sjoin(pts, dong[["dong_code", "sggnm", "emdnm", "area_m2", "geometry"]],
                      predicate="within", how="left")
cell_dong = pd.DataFrame(cell_dong.drop(columns=["geometry", "index_right"], errors="ignore"))

print("지역별로 걸친 동, 코드, 칸 수")
print(cell_dong.groupby(["region", "emdnm", "dong_code"]).size())
print("동 코드를 못 찾은 칸:", cell_dong["dong_code"].isna().sum())
missing = set(cell_dong["dong_code"].dropna()) - set(hourly["dong_code"])
print("생활인구에 없는 동 코드:", missing if missing else "없음")

# 지난번에 확인한 코드와 같은지 검증
KNOWN = {"역삼1동": "11680640", "서교동": "11440660", "연남동": "11440710",
         "성수1가1동": "11200650", "성수1가2동": "11200660", "성수2가1동": "11200670", "성수2가3동": "11200690"}
got = cell_dong.drop_duplicates("emdnm").set_index("emdnm")["dong_code"].to_dict()
print("기존 코드와 일치:", all(got.get(k) == v for k, v in KNOWN.items()))
cell_dong.to_csv("cell_dong.csv", index=False, encoding="utf-8-sig")

# 3. 칸 값 = 동 총인구 ÷ 동 면적 × 칸 면적(2,500㎡)
#    서울시 데이터는 체류·보행 구분이 없어 총인구 기준 (체류 + 0.5 × 보행은 LG 데이터용 make_congestion.py)
df = cell_dong.merge(hourly, on="dong_code", how="left")
df["cell_value"] = df["avg_pop"] / df["area_m2"] * 2500
base = df[["cell_id", "day_type", "hour", "cell_value"]].copy()

# 4. 주변 3×3 칸 평균 (기존 make_congestion.py와 같은 방식)
xy = base["cell_id"].str.split("_", expand=True).astype(int)
base["ix"], base["iy"] = xy[0], xy[1]
parts = []
for dx in (-1, 0, 1):
    for dy in (-1, 0, 1):
        nb = base[["ix", "iy", "day_type", "hour", "cell_value"]].copy()
        nb["ix"] -= dx
        nb["iy"] -= dy
        parts.append(nb)
smooth = (pd.concat(parts).groupby(["ix", "iy", "day_type", "hour"])["cell_value"].mean()
            .rename("smooth_value").reset_index())
cong = (base.merge(smooth, on=["ix", "iy", "day_type", "hour"], how="left")
            .merge(cells[["cell_id", "region"]], on="cell_id"))

# 5. 백분위 두 가지 + 등급 (기존과 같음)
def to_level(pct):
    return pd.cut(pct, [0, 30, 70, 100], labels=["QUIET", "NORMAL", "BUSY"], include_lowest=True)

cong["pct_same_time"] = (cong.groupby(["region", "day_type", "hour"])["smooth_value"]
                             .rank(pct=True) * 100).round(1)
cong["level_same_time"] = to_level(cong["pct_same_time"])
cong["pct_all_day"] = (cong.groupby("region")["smooth_value"].rank(pct=True) * 100).round(1)
cong["level_all_day"] = to_level(cong["pct_all_day"])

cong["cell_value"] = cong["cell_value"].round(1)
cong["smooth_value"] = cong["smooth_value"].round(1)
cong = cong[["cell_id", "region", "day_type", "hour", "cell_value", "smooth_value",
             "pct_same_time", "level_same_time", "pct_all_day", "level_all_day"]]

cong.to_csv("cell_congestion_seoul.csv", index=False, encoding="utf-8-sig")
print()
print(len(cong), "행")
print(cong.columns.tolist())