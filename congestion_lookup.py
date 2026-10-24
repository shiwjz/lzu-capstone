import pandas as pd

CONG_FILE = "cell_congestion.csv"

# 파일을 한 번만 읽어서 (cell_id, day_type, hour)로 바로 찾을 수 있게 준비
_cong = pd.read_csv(CONG_FILE, dtype={"cell_id": str}).set_index(["cell_id", "day_type", "hour"])

DAY_TYPE = {"WEEKDAY": "WEEKDAY", "WEEKEND": "WEEKEND", "주중": "WEEKDAY", "주말": "WEEKEND"}

#입력된 값을 표에서 찾아서 혼잡도로 다시 출력
def get_congestion(cell_id, day_type, hour):
    """
    셀의 주중/주말·시간대 혼잡 구간을 돌려준다.
    - cell_id: places_with_cell.csv의 cell_id (NULL이면 None)
    - day_type: "WEEKDAY" / "WEEKEND" (또는 "주중" / "주말")
    - hour: 0~23
    반환: {"level_same_time", "pct_same_time", "level_all_day", "pct_all_day"}
          셀이 없거나 정보가 없으면 None
    """
    if cell_id is None or pd.isna(cell_id):
        return None                                  # 테두리 장소 등 칸이 null인 경우

    day = DAY_TYPE.get(str(day_type).upper(), DAY_TYPE.get(str(day_type)))
    if day is None or not 0 <= int(hour) <= 23:
        raise ValueError(f"잘못된 입력: day_type={day_type}, hour={hour}")

    key = (str(cell_id), day, int(hour))
    if key not in _cong.index:
        return None

    row = _cong.loc[key]
    return {
        "level_same_time": row["level_same_time"],   # 추천 점수용(같은 시간대!!)
        "pct_same_time": float(row["pct_same_time"]),
        "level_all_day": row["level_all_day"],       # 화면 표시용(전체 시간대!!)
        "pct_all_day": float(row["pct_all_day"]),
    }


if __name__ == "__main__":
    # 동작 확인용: 첫 번째 셀로 조회
    sample_cell = _cong.index[0][0]
    print("셀:", sample_cell)
    print("주말 18시:", get_congestion(sample_cell, "WEEKEND", 18))
    print("주중 4시:", get_congestion(sample_cell, "주중", 4))
    print("칸 없는 장소:", get_congestion(None, "WEEKEND", 18))