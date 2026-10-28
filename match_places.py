import math, pandas as pd
from pyproj import Transformer

PLACE_FILE = "output/places.csv"

to_m = Transformer.from_crs("EPSG:4326", "EPSG:5179", always_xy=True)
CELL = 50

cells = pd.read_csv("grid_cells.csv")
valid_ids = set(cells["cell_id"])

# 셀 중심의 미터 좌표 (격자 목록 밖 장소에 가장 가까운 셀 찾을 때 사용)
cell_xy = {cid: to_m.transform(lon, lat)
           for cid, lat, lon in zip(cells["cell_id"], cells["center_lat"], cells["center_lon"])}

places = pd.read_csv(PLACE_FILE, encoding="utf-8-sig")
places["region"] = places["region"].replace({"성수": "SEONGSU", "홍대": "HONGDAE", "강남": "GANGNAM"})

def find_cell(row):
    x, y = to_m.transform(row["longitude"], row["latitude"])
    cell_id = f"{math.floor(x / CELL)}_{math.floor(y / CELL)}"
    if cell_id in valid_ids:
        return pd.Series([cell_id, False])
    # 격자 목록 밖(테두리) 장소 → 가장 가까운 셀로 대체 (팀 결정, 서버와 같은 방식)
    nearest = min(cell_xy, key=lambda c: math.hypot(cell_xy[c][0] - x, cell_xy[c][1] - y))
    return pd.Series([nearest, True])

print("중복 제거 전:", len(places))
places = places.drop_duplicates("place_id")
print("중복 제거 후:", len(places))

places[["cell_id", "is_estimated"]] = places.apply(find_cell, axis=1)

print()
print("지역별 매칭된 장소 수")
print(places.groupby("region")["cell_id"].count())
print("가장 가까운 셀로 대체(is_estimated):", places["is_estimated"].sum())

places.to_csv("places_with_cell.csv", index=False, encoding="utf-8-sig")
print()
print("places_with_cell.csv 저장 완료!")