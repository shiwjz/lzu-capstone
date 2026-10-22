import math, pandas as pd
from pyproj import Transformer

PLACE_FILE = "places.csv"

to_m = Transformer.from_crs("EPSG:4326", "EPSG:5179", always_xy=True)
CELL = 50

cells = pd.read_csv("grid_cells.csv")
valid_ids = set(cells["cell_id"])
places = pd.read_csv(PLACE_FILE, encoding="utf-8-sig")
places["region"] = places["region"].replace({"성수": "SEONGSU", "홍대": "HONGDAE", "강남": "GANGNAM"})

def find_cell(row):
    x, y = to_m.transform(row["longitude"], row["latitude"])
    cell_id = f"{math.floor(x / CELL)}_{math.floor(y / CELL)}"
    return cell_id if cell_id in valid_ids else None   # 장소가 있는 칸이 목록에 없으면 None

print("중복 제거 전:", len(places))
places = places.drop_duplicates("place_id")
print("중복 제거 후:", len(places))

places["cell_id"] = places.apply(find_cell, axis=1)

print()
print("지역별 매칭된 장소 수")
print(places.groupby("region")["cell_id"].apply(lambda s: s.notna().sum()))
print("cell_id 없음(NULL):", places["cell_id"].isna().sum())
print(places[places["cell_id"].isna()][["region", "name"]].to_string(index=False))

places.to_csv("places_with_cell.csv", index=False, encoding="utf-8-sig")
print()
print("places_with_cell.csv 저장 완료!")