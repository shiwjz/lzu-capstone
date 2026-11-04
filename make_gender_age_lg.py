"""
LG 성·연령 데이터(파일 2) → 칸별 성·연령 비율 (이윤경)
- 결과는 레포 밖(C:\\lzu_data\\output)에 저장 → 깃허브에 xx
"""
import os, math
import pandas as pd
from pyproj import Transformer

LG_DIR = os.environ.get("LG_DATA_DIR", r"C:\lzu_data")
OUT_DIR = os.path.join(LG_DIR, "output")
FILE2 = "DATADNI197_DATADNI197_YGH_HANSUNG_5TEAM_SECD_TBL.csv"

MONTHS = None              # 쓸 달 (None이면 전체). 예: ["202504", "202505", "202506", "202507", "202508"]
STAY_W, WALK_W = 1.0, 0.5  # (가정) 성·연령 비율에 쓸 인구 = 체류 + 0.5 × 보행 (혼잡도와 같은 기준)

AGE_MAP = {"20대 미만": "10s", "20대": "20s", "30대": "30s", "40대": "40s", "50대": "50s", "60대 이상": "60s"}
SEX_MAP = {"FEMALE": "f", "MALE": "m"}

os.makedirs(OUT_DIR, exist_ok=True)
df = pd.read_csv(os.path.join(LG_DIR, FILE2), encoding="utf-8-sig",
                 dtype={"CELL_ID": str, "P_YYYYMM": str})
print("읽은 줄:", len(df))

# 1. 성별·연령 모르는 줄 빼기, 쓸 달만 남기기
df = df.dropna(subset=["SEX_DIVS_CD", "YY10_AGLV_ID"])
if MONTHS:
    df = df[df["P_YYYYMM"].isin(MONTHS)]
print("성별·연령 있는 줄:", len(df), "/ 월:", df["P_YYYYMM"].nunique())

# 2. LG 셀 → 우리 cell_id (좌표 → EPSG:5179 ÷ 50m)
to_m = Transformer.from_crs("EPSG:4326", "EPSG:5179", always_xy=True)
cell_xy = df.drop_duplicates("CELL_ID")[["CELL_ID", "POI_CENTER_X_AXIS", "POI_CENTER_Y_AXIS"]]
cell_map = {}
for cid, x, y in zip(cell_xy["CELL_ID"], cell_xy["POI_CENTER_X_AXIS"], cell_xy["POI_CENTER_Y_AXIS"]):
    mx, my = to_m.transform(float(x), float(y))
    cell_map[cid] = f"{math.floor(mx / 50)}_{math.floor(my / 50)}"
df["cell_id"] = df["CELL_ID"].map(cell_map)

grid = pd.read_csv("grid_cells.csv")
df = df[df["cell_id"].isin(set(grid["cell_id"]))]           # 우리 945칸 밖(LG에만 있는 칸) 버리기

# 3. 인구 값 (9·10월에 동이 나뉜 줄은 여기서 자동으로 더해짐)
df["pop"] = STAY_W * df["STAY_POPL_CNT"].fillna(0).astype(float) + WALK_W * df["WALK_POPL_CNT"].fillna(0).astype(float)
df["sex"] = df["SEX_DIVS_CD"].map(SEX_MAP)
df["age"] = df["YY10_AGLV_ID"].map(AGE_MAP)
print("코드 매핑 안 된 줄 (성별/연령):", df["sex"].isna().sum(), "/", df["age"].isna().sum())

# 4. 칸별 성별 × 연령 합계 → 비율
tab = df.pivot_table(index="cell_id", columns=["sex", "age"], values="pop", aggfunc="sum", fill_value=0)
total = tab.sum(axis=1)
joint = tab.div(total, axis=0)
joint.columns = [f"{s}_{a}" for s, a in joint.columns]           # 예: f_20s = 20대 여성 비율

out = pd.DataFrame(index=joint.index)
out["female_ratio"] = joint[[c for c in joint.columns if c.startswith("f_")]].sum(axis=1)
for a in AGE_MAP.values():
    out[f"age_{a}"] = joint[[c for c in joint.columns if c.endswith(a)]].sum(axis=1)
out = out.join(joint).round(4).reset_index()
out = out.merge(grid[["cell_id", "region"]], on="cell_id", how="left")
out = out[["cell_id", "region"] + [c for c in out.columns if c not in ("cell_id", "region")]]

path = os.path.join(OUT_DIR, "cell_gender_age_lg.csv")
out.to_csv(path, index=False, encoding="utf-8-sig")
print("칸 수:", len(out), "/ 945")
print("컬럼:", out.columns.tolist())
print("저장:", path)