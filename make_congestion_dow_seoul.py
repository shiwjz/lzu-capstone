"""
서울시 생활인구로 '요일별' 혼잡도 만들기 (이윤경) → 렌더(서버)용
- 서울시 원본에 날짜가 있어서 요일 × 시간대를 직접 계산 (추정 아님)
- 칸 값 = 동 인구 ÷ 동 면적 × 칸 면적 (make_congestion_seoul.py와 같음)
- 3×3 평균 → 백분위 → 등급 (기존 혼잡도와 같음), day_type 대신 dow(MON~SUN)
"""
import glob, os
import pandas as pd

SRC_DIR = r"C:\yungyeong\3-2\기캡\2025공공데이터"
PATTERN = "LOCAL_PEOPLE_DONG_2025*.csv"
OUT_FILE = "cell_congestion_dow_seoul.csv"
COLS = ["기준일ID", "시간대구분", "행정동코드", "총생활인구수"]
DOW_NAME = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

# 1. 서울시 원본 읽기 (달마다 인코딩이 달라서 둘 다 시도)
parts = []
for f in sorted(glob.glob(os.path.join(SRC_DIR, PATTERN))):
    d = None
    for enc in ["utf-8-sig", "cp949"]:
        try:
            d = pd.read_csv(f, encoding=enc, index_col=False, usecols=[0, 1, 2, 3], dtype=str)
            break
        except UnicodeDecodeError:
            continue
    if d is None:
        raise SystemExit(f"못 읽은 파일: {f}")
    d.columns = COLS
    parts.append(d)
if not parts:
    raise SystemExit(f"파일이 없어요: {os.path.join(SRC_DIR, PATTERN)}")
df = pd.concat(parts, ignore_index=True)
for c in ["기준일ID", "시간대구분", "총생활인구수"]:
    df[c] = pd.to_numeric(df[c], errors="coerce")
df = df.dropna(subset=COLS)
df["date"] = pd.to_datetime(df["기준일ID"].astype("int64").astype(str), format="%Y%m%d")
df["dow"] = df["date"].dt.dayofweek.map(lambda i: DOW_NAME[i])
df["hour"] = df["시간대구분"].astype(int)
df["dong_code"] = df["행정동코드"].str.strip()
print("서울시 기간:", df["date"].min().date(), "~", df["date"].max().date(), "/", df["date"].nunique(), "일")

# 2. 동 × 요일 × 시간대 평균 (우리 칸이 걸친 동만)
cell_dong = pd.read_csv("cell_dong.csv", dtype={"dong_code": str})
dongs = set(cell_dong["dong_code"].dropna())
dow_hour = (df[df["dong_code"].isin(dongs)]
            .groupby(["dong_code", "dow", "hour"])["총생활인구수"].mean()
            .rename("avg_pop").reset_index())

# 3. 칸 값 = 동 인구 ÷ 동 면적 × 칸 면적(2,500㎡)
base = cell_dong[["cell_id", "region", "dong_code", "area_m2"]].merge(dow_hour, on="dong_code")
base["cell_value"] = base["avg_pop"] / base["area_m2"] * 2500
base = base[["cell_id", "region", "dow", "hour", "cell_value"]]

# 4. 주변 3×3 칸 평균
xy = base["cell_id"].str.split("_", expand=True).astype(int)
base = base.assign(ix=xy[0], iy=xy[1])
parts = []
for dx in (-1, 0, 1):
    for dy in (-1, 0, 1):
        nb = base[["ix", "iy", "dow", "hour", "cell_value"]].copy()
        nb["ix"] -= dx
        nb["iy"] -= dy
        parts.append(nb)
smooth = (pd.concat(parts).groupby(["ix", "iy", "dow", "hour"])["cell_value"].mean()
            .rename("smooth_value").reset_index())
cong = base.merge(smooth, on=["ix", "iy", "dow", "hour"], how="left")

# 5. 백분위 두 가지 + 등급 (같은 시간 비교는 '같은 지역·같은 요일·같은 시각')
def to_level(pct):
    return pd.cut(pct, [0, 30, 70, 100], labels=["QUIET", "NORMAL", "BUSY"], include_lowest=True)

cong["pct_same_time"] = (cong.groupby(["region", "dow", "hour"])["smooth_value"].rank(pct=True) * 100).round(1)
cong["level_same_time"] = to_level(cong["pct_same_time"])
cong["pct_all_day"] = (cong.groupby("region")["smooth_value"].rank(pct=True) * 100).round(1)
cong["level_all_day"] = to_level(cong["pct_all_day"])
cong["cell_value"] = cong["cell_value"].round(1)
cong["smooth_value"] = cong["smooth_value"].round(1)
cong["dow"] = pd.Categorical(cong["dow"], DOW_NAME, ordered=True)
cong = (cong.sort_values(["cell_id", "dow", "hour"])
            [["cell_id", "region", "dow", "hour", "cell_value", "smooth_value",
              "pct_same_time", "level_same_time", "pct_all_day", "level_all_day"]])

cong.to_csv(OUT_FILE, index=False, encoding="utf-8-sig")
print("칸:", cong["cell_id"].nunique(), "/ 행:", len(cong), "(칸 × 7요일 × 24시간)")
print("등급 분포:", cong["level_same_time"].value_counts().to_dict())
print("저장:", OUT_FILE)