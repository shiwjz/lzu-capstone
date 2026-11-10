"""
가짜 LG 파일 3개 만들기 (열 이름만 진짜랑 같고 숫자는 전부 랜덤) - make_lg_data.py 시험용
  python lg/make_fake_lg.py --out /tmp/fake_lg
- 진짜 파일 모양(코드값 형식, 좌표 단위, 합계/평균 기준)이 다르면 여기랑 make_lg_data.py 같이 고치기
"""
import argparse
import calendar
import os
import sys

import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'lg'))
from make_lg_data import tm5179  # noqa: E402

PREFIX = 'DATADNI197_DATADNI197_YGH_HANSUNG_5TEAM'
VALS = ['STAY_POPL_CNT', 'WALK_POPL_CNT', 'DRIV_POPL_CNT']
DOW_NAMES = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--seed', type=int, default=7)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(args.seed)

    cells = pd.read_csv(os.path.join(ROOT, 'grid_cells.csv'))
    dong = pd.read_csv(os.path.join(ROOT, 'cell_dong.csv')).set_index('cell_id')['emdnm'].to_dict()
    months = [f'2025{m:02d}' for m in range(1, 13)]
    hours = np.arange(24)
    day_curve = np.clip(np.sin((hours - 6) / 24 * 2 * np.pi) + 0.6, 0.1, None)   # 낮에 많고 밤에 적게

    fst, secd, thrd = [], [], []
    for c in cells.itertuples():
        x, y = tm5179(c.center_lat, c.center_lon)
        base = dict(ADNG_NM=dong.get(c.cell_id, ''), CELL_ID=f'LG{c.cell_id}',
                    POI_CENTER_X_AXIS=round(x, 1), POI_CENTER_Y_AXIS=round(y, 1))
        size = rng.lognormal(3, 0.6)
        weekend = rng.uniform(0.7, 1.4)
        for m in months:
            nd = calendar.monthrange(int(m[:4]), int(m[4:]))[1]
            for h in hours:                    # 월 합계 기준 (하루 값 × 일수)
                v = size * day_curve[h] * nd * rng.uniform(0.9, 1.1)
                fst.append({'P_YYYYMM': m, **base, 'TMZN': f'{h:02d}', 'STAY_POPL_CNT': round(v * 0.6),
                            'WALK_POPL_CNT': round(v * 0.4), 'DRIV_POPL_CNT': round(v * 0.3)})
            for d, name in enumerate(DOW_NAMES):
                n = sum(1 for k in range(1, nd + 1) if calendar.weekday(int(m[:4]), int(m[4:]), k) == d)
                v = size * day_curve.sum() * (weekend if d >= 5 else 1) * n * rng.uniform(0.9, 1.1)
                thrd.append({'P_YYYYMM': m, **base, 'DYBY_NM': name, 'STAY_POPL_CNT': round(v * 0.6),
                             'WALK_POPL_CNT': round(v * 0.4), 'DRIV_POPL_CNT': round(v * 0.3)})
            share = rng.dirichlet(np.ones(14) * 3)
            for i, (sex, age) in enumerate((s, a) for s in ('1', '2') for a in range(10, 80, 10)):
                v = size * day_curve.sum() * nd * share[i]
                secd.append({'P_YYYYMM': m, **base, 'SEX_DIVS_CD': sex, 'YY10_AGLV_ID': str(age),
                             'STAY_POPL_CNT': round(v * 0.6), 'WALK_POPL_CNT': round(v * 0.4),
                             'DRIV_POPL_CNT': round(v * 0.3)})
    for rows, tag in ((fst, 'FST'), (secd, 'SECD'), (thrd, 'THRD')):
        pd.DataFrame(rows).to_csv(os.path.join(args.out, f'{PREFIX}_{tag}_TBL.csv'), index=False, encoding='utf-8-sig')
    print(f'가짜 LG 파일 3개 → {args.out} (FST {len(fst):,} · SECD {len(secd):,} · THRD {len(thrd):,}행)')


if __name__ == '__main__':
    main()
