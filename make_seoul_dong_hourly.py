"""
서울시 행정동 생활인구 원본 → 동별 주중/주말 × 시간대 평균 (이윤경)
- 서울 열린데이터광장 '행정동 단위 서울 생활인구(내국인)' 공공데이터
- LG 데이터 기간(2025년 1~12월)에 맞춤
- 결과: seoul_dong_hourly_2025.csv (공공데이터라 깃허브에 올려도 됨)
"""
import glob, os
import pandas as pd

SRC_DIR = r"C:\yungyeong\3-2\기캡\2025공공데이터"
PATTERN = "LOCAL_PEOPLE_DONG_2025*.csv"
OUT_FILE = "seoul_dong_hourly_2025.csv"
COLS = ["기준일ID", "시간대구분", "행정동코드", "총생활인구수"]

parts = []
for f in sorted(glob.glob(os.path.join(SRC_DIR, PATTERN))):
    d, used = None, None
    for enc in ["utf-8-sig", "cp949"]:        # 달마다 인코딩이 달라서 둘 다 시도
        try:
            # 원본은 줄 끝에 쉼표가 하나 더 있어서 index_col=False 필요
            d = pd.read_csv(f, encoding=enc, index_col=False, usecols=[0, 1, 2, 3], dtype=str)
            used = enc
            break
        except UnicodeDecodeError:
            continue
    if d is None:
        raise SystemExit(f"못 읽은 파일: {f}")
    d.columns = COLS                          # 달마다 컬럼 이름이 달라도 같은 이름으로
    parts.append(d)
    print("읽음:", os.path.basename(f), len(d), f"({used})")

if not parts:
    raise SystemExit(f"파일이 없어요: {os.path.join(SRC_DIR, PATTERN)}")
df = pd.concat(parts, ignore_index=True)

# 날짜·시간·인구를 숫자로 (빈 줄이나 이상한 값은 빼기)
df["기준일ID"] = pd.to_numeric(df["기준일ID"], errors="coerce")
df["시간대구분"] = pd.to_numeric(df["시간대구분"], errors="coerce")
df["총생활인구수"] = pd.to_numeric(df["총생활인구수"], errors="coerce")
before = len(df)
df = df.dropna(subset=["기준일ID", "시간대구분", "행정동코드", "총생활인구수"])
print("\n빈 값·이상한 값이라 뺀 줄:", before - len(df))

df["date"] = pd.to_datetime(df["기준일ID"].astype("int64").astype(str), format="%Y%m%d")
df["hour"] = df["시간대구분"].astype(int)
df["dong_code"] = df["행정동코드"].str.strip()
df["day_type"] = df["date"].dt.dayofweek.map(lambda x: "WEEKEND" if x >= 5 else "WEEKDAY")

# 동 × 주중/주말 × 시간대별 평균 생활인구
out = (df.groupby(["dong_code", "day_type", "hour"])["총생활인구수"].mean()
         .round(1).rename("avg_pop").reset_index())
out.to_csv(OUT_FILE, index=False, encoding="utf-8-sig")

print("기간:", df["date"].min().date(), "~", df["date"].max().date(), "/", df["date"].nunique(), "일")
print("행:", len(out), "/ 동:", out["dong_code"].nunique())
print("저장:", OUT_FILE)