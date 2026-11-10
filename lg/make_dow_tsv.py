"""
요일별 혼잡도 긴 표 → 서버가 읽는 짧은 모양 (11/11) - 김예민
  python lg/make_dow_tsv.py cell_congestion_dow_seoul.csv capstone-backend/src/main/resources/data/congestion_dow_seoul.tsv
- 입력: 윤경 cell_congestion_dow_*.csv (cell_id, region, dow, hour, ..., pct_all_day, level_all_day)
- 출력: cellId \t dow \t allDay(h0..h23)  (congestion.tsv의 allDay 칸이랑 같은 Q20·N55·B88 모양, 없는 시간은 -)
- 서울시 버전(공개 데이터)만 저장소에 넣기. LG 버전은 변환 안 해도 서버가 cell_congestion_dow_lg.csv를 바로 읽음
"""
import csv
import math
import sys

CODE = {'QUIET': 'Q', 'NORMAL': 'N', 'BUSY': 'B'}


def main(src, dst):
    rows = {}
    with open(src, encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f):
            key = (r['cell_id'], r['dow'].strip().upper())
            hours = rows.setdefault(key, ['-'] * 24)
            if r['level_all_day']:
                pct = int(math.floor(float(r['pct_all_day']) + 0.5))      # 서버(Java Math.round)랑 같은 반올림
                hours[int(r['hour'])] = CODE[r['level_all_day']] + str(pct)
    order = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
    with open(dst, 'w', encoding='utf-8', newline='\n') as f:
        f.write('cellId\tdow\tallDay(h0..h23)\n')
        for (cid, dow) in sorted(rows, key=lambda k: (k[0], order.index(k[1]))):
            f.write(f"{cid}\t{dow}\t{' '.join(rows[(cid, dow)])}\n")
    print(f'{len(rows):,}줄 → {dst}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
