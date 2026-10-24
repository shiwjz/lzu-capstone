import math, pandas as pd
from pyproj import Transformer

to_m = Transformer.from_crs("EPSG:4326", "EPSG:5179", always_xy=True)
to_deg = Transformer.from_crs("EPSG:5179", "EPSG:4326", always_xy=True)

REGIONS = {
    "SEONGSU": ("성수", 37.544045, 127.0504),
    "HONGDAE": ("홍대·연남", 37.5565, 126.9225),
    "GANGNAM": ("강남", 37.501196, 127.02603),
}
CELL, R = 50, 500

rows = []
for code, (name, lat, lon) in REGIONS.items():
    cx, cy = to_m.transform(lon, lat)
    for ix in range(math.floor((cx - R) / CELL), math.floor((cx + R) / CELL) + 1):
        for iy in range(math.floor((cy - R) / CELL), math.floor((cy + R) / CELL) + 1):
            x, y = (ix + 0.5) * CELL, (iy + 0.5) * CELL   # 셀 중심(m)
            d = math.hypot(x - cx, y - cy)
            if d <= R:
                lon_c, lat_c = to_deg.transform(x, y)
                rows.append({
                    "cell_id": f"{ix}_{iy}", "region": code, "region_name": name,
                    "center_lat": round(lat_c, 6), "center_lon": round(lon_c, 6),
                    "dist_m": round(d, 1),
                })

df = pd.DataFrame(rows)
print(df.groupby("region").size())   # 지역별 셀 수 확인
df.to_csv("grid_cells.csv", index=False, encoding="utf-8-sig")  # 엑셀 한글 깨짐 방지