"""
LG 유동인구 3개 파일 → 우리 서비스용 파일 (11/5) - 김예민 (전처리 담당 @이윤경이 실행)

받은 파일 (월별 2025-01~12, 칸 = CELL_ID)
- FST  : 칸 × 시간대(TMZN)                 → 시간대 모양
- SECD : 칸 × 성별(SEX_DIVS_CD) × 연령대    → 성·연령 (타깃 점수)
- THRD : 칸 × 요일(DYBY_NM)                 → 주중/주말 비율
※ 필요한 '주중/주말 × 시간대' 표는 없음 → 아래 방법으로 추정

주중/주말 × 시간대 추정 (반복 비례 조정, IPF)
1. 시작값: 칸 시간대 값(LG FST) × 그 칸이 속한 행정동의 주중/주말 시간대 모양(서울시 생활인구)
2. 두 합계가 LG랑 같아질 때까지 번갈아 맞춤
   - 칸·시간대별 (주중 5일 + 주말 2일) 평균 = LG FST
   - 칸·주중/주말별 하루 합 비율 = LG THRD (월~금 평균 / 토·일 평균)
3. 결과: LG 숫자는 안 어기고, '주말 저녁에 몰림' 같은 모양은 서울시에서 빌려옴
   (보고서 한계: "주중·주말별 시간대 모양은 서울시 생활인구(행정동)에서 가져와 LG 합계에 맞춰 추정")

만드는 파일 (전부 --out 폴더에만, 깃허브·AI에 올리지 않기)
- floating_pop_lg.csv      : cell_id, day_type, hour, stay_pop, walk_pop  (윤경 make_congestion.py·cluster_cells.py 입력 모양 그대로)
- cell_congestion_lg.csv   : cell_congestion.csv랑 같은 열 (3×3 평균 → 백분위 → 등급, 윤경 방식 그대로)
- cell_gender_age_lg.csv   : cell_gender_age_fake.csv랑 같은 열
- check_lg.txt             : 확인용 요약 (칸 몇 개 맞았는지, 합계 오차, 등급 분포 - 칸별 숫자 없음)
- congestion_lg.tsv, cell_profile_lg.tsv : 서버가 읽는 모양 (resources/data/congestion.tsv·cell_profile.tsv랑 같음)
  → 서버 실행할 때 환경변수 ODIGA_DATA_DIR=이 폴더 넣으면 가짜 대신 이걸 읽음 (깃허브·jar에는 안 들어감)
  → 칸 유형(cluster)은 이 폴더에 cell_cluster_lg.csv(윤경 cluster_cells.py를 LG로 돌린 결과) 있으면 그걸, 없으면 저장소 cell_cluster.csv

실행 (저장소 맨 위 폴더에서, 원본·결과 폴더는 저장소 밖)
  python lg/make_lg_data.py --lg /Volumes/KIOXIA/lzu-private-data/lg --out /Volumes/KIOXIA/lzu-private-data/out
  옵션: --months 202509-202512 (기간), --value stay+0.5walk | walk | stay (혼잡도에 쓸 값, 기본 = 윤경 방식)
        --dow-basis total | avg (THRD 요일 값이 '그 달 그 요일 합계'인지 '하루 평균'인지, 처음 실행 때 check 보고 정하기)
시험 (가짜 LG 파일로)
  python lg/make_fake_lg.py --out /tmp/fake_lg
  python lg/make_lg_data.py --lg /tmp/fake_lg --out /tmp/fake_out
"""
import argparse
import calendar
import glob
import math
import os
import re
import sys

import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = {'FST': '_FST_TBL', 'SECD': '_SECD_TBL', 'THRD': '_THRD_TBL'}
VALUE_COLS = ['STAY_POPL_CNT', 'WALK_POPL_CNT', 'DRIV_POPL_CNT']
DAY_TYPES = ('WEEKDAY', 'WEEKEND')
DAYS = {'WEEKDAY': 5, 'WEEKEND': 2}
DOW = {'월': 0, '화': 1, '수': 2, '목': 3, '금': 4, '토': 5, '일': 6,
       'MON': 0, 'TUE': 1, 'WED': 2, 'THU': 3, 'FRI': 4, 'SAT': 5, 'SUN': 6}


# ---------------- 읽기 ----------------
def find_table(lg_dir, key):
    hits = [p for p in glob.glob(os.path.join(lg_dir, '*')) if TABLES[key] in os.path.basename(p).upper()
            and p.lower().endswith(('.csv', '.txt', '.xlsx'))]
    if not hits:
        sys.exit(f'{lg_dir} 안에 이름에 {TABLES[key]} 들어간 파일이 없음')
    return hits[0]


def read_table(path):
    if path.lower().endswith('.xlsx'):
        df = pd.read_excel(path, dtype=str)
    else:
        for enc in ('utf-8-sig', 'cp949'):
            try:
                df = pd.read_csv(path, dtype=str, encoding=enc, sep=None, engine='python')
                break
            except UnicodeDecodeError:
                continue
        else:
            sys.exit(f'{path} 인코딩을 못 읽음 (utf-8 / cp949 아님)')
    df.columns = [c.strip().upper() for c in df.columns]
    for c in VALUE_COLS + ['POI_CENTER_X_AXIS', 'POI_CENTER_Y_AXIS']:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c].str.replace(',', ''), errors='coerce')
    return df


# ---------------- 칸 맞추기 ----------------
def tm5179(lat, lng):
    """위경도 → EPSG:5179(UTM-K) m (mocks/generate_mocks.py랑 같은 식)"""
    a, f = 6378137.0, 1 / 298.257222101
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    k0, lat0, lng0, fe, fn = 0.9996, math.radians(38), math.radians(127.5), 1000000, 2000000

    def arc(phi):
        return a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
                    - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
                    + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
                    - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))
    phi, lam = math.radians(lat), math.radians(lng)
    n = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    t, c = math.tan(phi) ** 2, ep2 * math.cos(phi) ** 2
    A = (lam - lng0) * math.cos(phi)
    x = fe + k0 * n * (A + (1 - t + c) * A ** 3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * A ** 5 / 120)
    y = fn + k0 * (arc(phi) - arc(lat0) + n * math.tan(phi) * (
        A * A / 2 + (5 - t + 9 * c + 4 * c * c) * A ** 4 / 24 + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * A ** 6 / 720))
    return x, y


def add_our_cell(df, log):
    """LG 칸 중심 좌표 → 우리 칸 id (EPSG:5179 ÷ 50m). 좌표가 위경도면 변환, 이미 m 단위면 그대로"""
    x, y = df['POI_CENTER_X_AXIS'], df['POI_CENTER_Y_AXIS']
    if x.between(120, 135).all() and y.between(30, 45).all():
        kind = '위경도 → EPSG:5179 변환'
        xy = [tm5179(la, lo) for lo, la in zip(x, y)]
        mx, my = np.array([p[0] for p in xy]), np.array([p[1] for p in xy])
    elif x.between(100000, 1500000).all() and y.between(1000000, 2500000).all():
        kind = 'm 단위 (EPSG:5179로 보고 그대로)'
        mx, my = x.to_numpy(), y.to_numpy()
    else:
        sys.exit('POI_CENTER 좌표 단위를 모르겠음 → 범위만(최소·최대) 예민이한테 알려주기')
    df = df.copy()
    df['cell_id'] = [f'{math.floor(a / 50)}_{math.floor(b / 50)}' for a, b in zip(mx, my)]
    log.append(f'좌표: {kind}')
    return df


# ---------------- 시간·요일 ----------------
def parse_hour(v):
    m = re.search(r'\d+', str(v))
    return int(m.group()) % 24 if m else None


def parse_dow(v):
    s = str(v).strip().upper()
    for k, d in DOW.items():
        if s.startswith(k):
            return d
    if s.isdigit():                       # 1~7 숫자면 1 = 월요일로 가정 (check에 적음)
        return (int(s) - 1) % 7
    return None


def dow_count(yyyymm, dow):
    y, m = int(yyyymm[:4]), int(yyyymm[4:6])
    return sum(1 for d in range(1, calendar.monthrange(y, m)[1] + 1) if calendar.weekday(y, m, d) == dow)


# ---------------- 계산 ----------------
def value_of(df, how):
    s, w = df['STAY_POPL_CNT'].fillna(0), df['WALK_POPL_CNT'].fillna(0)
    return {'stay+0.5walk': s + 0.5 * w, 'walk': w, 'stay': s}[how]


def ipf(seed, hour_margin, day_ratio, iters=200, tol=1e-9):
    """seed[dt, h] (2×24) → 두 합계 맞추기
    - (5×주중 + 2×주말)/7 = hour_margin[h]
    - 주중/주말 하루 합 = day_ratio[dt] × hour_margin 합"""
    x = np.where(seed > 0, seed, 1e-9).astype(float)
    w = np.array([DAYS['WEEKDAY'], DAYS['WEEKEND']], float)[:, None] / 7
    day_total = day_ratio * hour_margin.sum()
    for _ in range(iters):
        mix = (w * x).sum(axis=0)
        x *= np.divide(hour_margin, mix, out=np.zeros_like(mix), where=mix > 0)[None, :]
        tot = x.sum(axis=1)
        x *= np.divide(day_total, tot, out=np.zeros_like(tot), where=tot > 0)[:, None]
        err = np.abs((w * x).sum(axis=0) - hour_margin).max() / max(hour_margin.max(), 1e-9)
        if err < tol:
            break
    return x, err


def congestion_table(base, cells):
    """윤경 make_congestion.py 4~5단계 그대로: 3×3 평균 → 백분위 → 등급"""
    xy = base['cell_id'].str.split('_', expand=True).astype(int)
    base = base.assign(ix=xy[0], iy=xy[1])
    parts = []
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            nb = base[['ix', 'iy', 'day_type', 'hour', 'cell_value']].copy()
            nb['ix'] -= dx
            nb['iy'] -= dy
            parts.append(nb)
    smooth = (pd.concat(parts).groupby(['ix', 'iy', 'day_type', 'hour'])['cell_value'].mean()
              .rename('smooth_value').reset_index())
    cong = (base.merge(smooth, on=['ix', 'iy', 'day_type', 'hour'], how='left')
            .merge(cells[['cell_id', 'region']], on='cell_id'))

    def to_level(pct):
        return pd.cut(pct, [0, 30, 70, 100], labels=['QUIET', 'NORMAL', 'BUSY'], include_lowest=True)
    cong['pct_same_time'] = (cong.groupby(['region', 'day_type', 'hour'])['smooth_value'].rank(pct=True) * 100).round(1)
    cong['level_same_time'] = to_level(cong['pct_same_time'])
    cong['pct_all_day'] = (cong.groupby('region')['smooth_value'].rank(pct=True) * 100).round(1)
    cong['level_all_day'] = to_level(cong['pct_all_day'])
    cong['cell_value'] = cong['cell_value'].round(1)
    cong['smooth_value'] = cong['smooth_value'].round(1)
    return cong[['cell_id', 'region', 'day_type', 'hour', 'cell_value', 'smooth_value',
                 'pct_same_time', 'level_same_time', 'pct_all_day', 'level_all_day']]


def gender_age(secd, how):
    """SECD → female_ratio, age_10s~age_60s (10세 미만 빼고, 70대 이상은 60s에 합침)"""
    df = secd.copy()
    df['v'] = value_of(df, how)
    sex = df['SEX_DIVS_CD'].astype(str).str.strip().str.upper()
    female = sex.isin(['F', '2', '여', '여성', 'FEMALE'])
    male = sex.isin(['M', '1', '남', '남성', 'MALE'])
    age = pd.to_numeric(df['YY10_AGLV_ID'].astype(str).str.extract(r'(\d+)')[0], errors='coerce')
    age = np.where(age < 10, age * 10, age)              # '2' 같은 코드면 20대로
    df['age'] = np.clip((age // 10) * 10, 0, 60)
    s = df[female | male].assign(female=female[female | male])
    out = []
    for cid, g in s.groupby('cell_id'):
        tot = g['v'].sum()
        if tot <= 0:
            continue
        row = {'cell_id': cid, 'female_ratio': round(g.loc[g['female'], 'v'].sum() / tot, 3)}
        adult = g[g['age'] >= 10]
        at = adult['v'].sum()
        for a in range(10, 70, 10):
            row[f'age_{a}s'] = round(adult.loc[adult['age'] == a, 'v'].sum() / at, 3) if at > 0 else 0
        out.append(row)
    return pd.DataFrame(out), sorted(sex.unique().tolist())


def write_server_files(out, cong, ga, cells, log):
    """서버 PlaceStore가 읽는 모양 (mocks/generate_mocks.py write_congestion·cell_profile이랑 같게)"""
    code = {'QUIET': 'Q', 'NORMAL': 'N', 'BUSY': 'B'}
    c = cong.set_index(['cell_id', 'day_type', 'hour'])
    with open(os.path.join(out, 'congestion_lg.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('cellId\tdayType\tsameTime(h0..h23)\tallDay(h0..h23)\n')
        for cid in sorted(cells['cell_id']):
            for dt in DAY_TYPES:
                cols = []
                for basis in ('same_time', 'all_day'):
                    hours = []
                    for h in range(24):
                        if (cid, dt, h) in c.index:
                            r = c.loc[(cid, dt, h)]
                            hours.append(code[str(r[f'level_{basis}'])] + str(round(float(r[f'pct_{basis}']))))
                        else:
                            hours.append('-')
                    cols.append(' '.join(hours))
                f.write(f'{cid}\t{dt}\t{cols[0]}\t{cols[1]}\n')
    own = os.path.join(out, 'cell_cluster_lg.csv')
    cl_path = own if os.path.exists(own) else os.path.join(ROOT, 'cell_cluster.csv')
    cluster = pd.read_csv(cl_path).set_index('cell_id')['cluster'].to_dict()
    cols = ['female_ratio', 'age_10s', 'age_20s', 'age_30s', 'age_40s', 'age_50s', 'age_60s']
    with open(os.path.join(out, 'cell_profile_lg.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('cellId\tregion\tcluster\t' + '\t'.join(cols) + '\n')
        for r in ga.sort_values('cell_id').itertuples():
            cl = cluster.get(r.cell_id)
            f.write('\t'.join([r.cell_id, r.region, '' if cl is None or pd.isna(cl) else str(int(cl))]
                              + [repr(float(getattr(r, k))) for k in cols]) + '\n')
    log.append(f'서버용 파일: congestion_lg.tsv, cell_profile_lg.tsv (칸 유형: {os.path.basename(cl_path)})')


def inside(path, root):
    path, root = os.path.realpath(path), os.path.realpath(root)
    return path == root or path.startswith(root + os.sep)


def main():
    ap = argparse.ArgumentParser(description='LG 유동인구 → 혼잡도·성연령 (결과는 저장소 밖 폴더에만)')
    ap.add_argument('--lg', default=os.environ.get('LG_DATA_DIR'), help='LG 원본 폴더 (FST·SECD·THRD)')
    ap.add_argument('--out', default=os.environ.get('LG_OUT_DIR'), help='결과 폴더 (저장소 밖)')
    ap.add_argument('--months', default=None, help='예: 202509-202512 (기본 전체)')
    ap.add_argument('--value', default='stay+0.5walk', choices=['stay+0.5walk', 'walk', 'stay'])
    ap.add_argument('--dow-basis', default='total', choices=['total', 'avg'],
                    help="THRD 요일 값: total = 그 달 그 요일들 합계 / avg = 하루 평균")
    args = ap.parse_args()
    if not args.lg or not args.out:
        sys.exit('--lg (원본 폴더)랑 --out (결과 폴더) 넣기')
    if inside(args.out, ROOT) or inside(args.lg, ROOT):
        sys.exit('원본·결과 폴더가 저장소 안에 있음 → 깃허브·AI 도구에 올라갈 수 있어서 멈춤. 저장소 밖 폴더로 바꾸기')
    os.makedirs(args.out, exist_ok=True)
    log = []

    cells = pd.read_csv(os.path.join(ROOT, 'grid_cells.csv'))
    cell_ids = set(cells['cell_id'])
    cell_dong = pd.read_csv(os.path.join(ROOT, 'cell_dong.csv'), dtype={'dong_code': str})
    seoul = pd.read_csv(os.path.join(ROOT, 'seoul_dong_hourly.csv'), dtype={'dong_code': str})

    t = {k: read_table(find_table(args.lg, k)) for k in TABLES}
    for k, df in t.items():
        df['P_YYYYMM'] = df['P_YYYYMM'].str.replace(r'\D', '', regex=True).str[:6]
        if args.months:
            lo, hi = args.months.split('-')
            t[k] = df = df[(df['P_YYYYMM'] >= lo) & (df['P_YYYYMM'] <= hi)]
        t[k] = add_our_cell(df, log if k == 'FST' else [])
        m = t[k]['cell_id'].isin(cell_ids)
        log.append(f'{k}: {len(df):,}행, 월 {df["P_YYYYMM"].min()}~{df["P_YYYYMM"].max()}, '
                   f'우리 칸에 맞은 행 {m.mean():.0%}, 맞은 칸 {t[k].loc[m, "cell_id"].nunique()} / {len(cell_ids)}')
        t[k] = t[k][m]

    # 1) 시간대 합계: 칸 × 시간 하루 평균 (월별 → 그 달 일수로 나눠 하루 평균, 월끼리 평균)
    fst = t['FST'].copy()
    fst['hour'] = fst['TMZN'].map(parse_hour)
    days_in = fst['P_YYYYMM'].map(lambda s: calendar.monthrange(int(s[:4]), int(s[4:6]))[1])
    for c in ('STAY_POPL_CNT', 'WALK_POPL_CNT'):
        fst[c] = fst[c] / days_in
    hour_m = (fst.groupby(['cell_id', 'P_YYYYMM', 'hour'])[['STAY_POPL_CNT', 'WALK_POPL_CNT']].sum()
              .groupby(['cell_id', 'hour']).mean())

    # 2) 요일 비율: 칸 × 주중/주말 하루 평균의 비율
    thrd = t['THRD'].copy()
    thrd['dow'] = thrd['DYBY_NM'].map(parse_dow)
    if thrd['dow'].isna().any():
        log.append(f'요일 이름 못 읽은 값: {sorted(thrd.loc[thrd["dow"].isna(), "DYBY_NM"].unique())[:10]}')
    thrd = thrd.dropna(subset=['dow'])
    if str(t['THRD']['DYBY_NM'].iloc[0]).strip().isdigit():
        log.append('요일이 숫자라 1 = 월요일로 가정함 → 맞는지 확인')
    if args.dow_basis == 'total':
        n = [dow_count(m, int(d)) for m, d in zip(thrd['P_YYYYMM'], thrd['dow'])]
        for c in ('STAY_POPL_CNT', 'WALK_POPL_CNT'):
            thrd[c] = thrd[c] / n
    thrd['day_type'] = np.where(thrd['dow'] >= 5, 'WEEKEND', 'WEEKDAY')
    day_m = (thrd.groupby(['cell_id', 'P_YYYYMM', 'day_type'])[['STAY_POPL_CNT', 'WALK_POPL_CNT']].mean()
             .groupby(['cell_id', 'day_type']).mean())

    # 월 합계인지 하루 평균인지 확인용: FST 24시간 합 vs THRD 7요일 합 (원래 값 기준)
    f_raw = t['FST'].groupby(['cell_id', 'P_YYYYMM'])['STAY_POPL_CNT'].sum()
    d_raw = t['THRD'].groupby(['cell_id', 'P_YYYYMM'])['STAY_POPL_CNT'].sum()
    ratio = (f_raw / d_raw).replace([np.inf, -np.inf], np.nan).dropna()
    log.append(f'[확인] FST 24시간 합 ÷ THRD 7요일 합 (체류, 칸·월별 중앙값) = {ratio.median():.2f}'
               ' → 1 근처면 둘 다 같은 기준(합계), 아니면 기준이 다름 (--dow-basis 다시 보기)')

    # 3) 서울시 모양 (행정동 × 주중/주말 × 시간) → 시작값
    sp = seoul.pivot_table(index=['dong_code', 'hour'], columns='day_type', values='avg_pop')
    dong_of = cell_dong.set_index('cell_id')['dong_code'].to_dict()

    rows, errs, no_seed = [], [], 0
    for cid in sorted(set(hour_m.index.get_level_values(0)) & set(day_m.index.get_level_values(0))):
        dong = dong_of.get(cid)
        if dong in sp.index.get_level_values(0):
            sh = sp.loc[dong].reindex(range(24))
            shape = np.vstack([sh['WEEKDAY'].to_numpy(), sh['WEEKEND'].to_numpy()])
            mix = (5 * shape[0] + 2 * shape[1]) / 7
            shape = shape / np.where(mix > 0, mix, 1)
        else:
            shape = np.ones((2, 24))          # 서울시 동 없음 → 주중·주말 모양 같다고 봄 (방법 A)
            no_seed += 1
        est = {}
        for col, name in (('STAY_POPL_CNT', 'stay_pop'), ('WALK_POPL_CNT', 'walk_pop')):
            hm = hour_m.loc[cid][col].reindex(range(24)).fillna(0).to_numpy()
            dm = day_m.loc[cid][col].reindex(list(DAY_TYPES)).to_numpy()
            mean = (5 * dm[0] + 2 * dm[1]) / 7
            ratio_dt = dm / mean if mean > 0 and not np.isnan(dm).any() else np.ones(2)
            x, err = ipf(shape * hm[None, :], hm, ratio_dt)
            est[name] = x
            errs.append(err)
        for i, dt in enumerate(DAY_TYPES):
            for h in range(24):
                rows.append((cid, dt, h, est['stay_pop'][i, h], est['walk_pop'][i, h]))
    pop = pd.DataFrame(rows, columns=['cell_id', 'day_type', 'hour', 'stay_pop', 'walk_pop'])
    pop[['stay_pop', 'walk_pop']] = pop[['stay_pop', 'walk_pop']].round(2)
    pop.to_csv(os.path.join(args.out, 'floating_pop_lg.csv'), index=False, encoding='utf-8-sig')
    log.append(f'추정 칸 {pop["cell_id"].nunique()}개, 서울시 모양 없어서 주중=주말 모양으로 한 칸 {no_seed}개, '
               f'합계 최대 오차 {max(errs) if errs else 0:.1e}')

    # 4) 혼잡도
    base = pop.assign(cell_value=value_of(pop.rename(columns={'stay_pop': 'STAY_POPL_CNT', 'walk_pop': 'WALK_POPL_CNT'}),
                                          args.value))[['cell_id', 'day_type', 'hour', 'cell_value']]
    cong = congestion_table(base, cells)
    cong.to_csv(os.path.join(args.out, 'cell_congestion_lg.csv'), index=False, encoding='utf-8-sig')
    log.append(f'혼잡도 ({args.value}): {len(cong):,}행, 등급 분포 {cong["level_same_time"].value_counts().to_dict()}')

    # 5) 성·연령
    ga, sex_codes = gender_age(t['SECD'], args.value)
    ga = ga.merge(cells[['cell_id', 'region']], on='cell_id')
    ga = ga[['cell_id', 'region', 'female_ratio'] + [f'age_{a}s' for a in range(10, 70, 10)]]
    ga.to_csv(os.path.join(args.out, 'cell_gender_age_lg.csv'), index=False, encoding='utf-8-sig')
    log.append(f'성·연령: 칸 {len(ga)}개, 성별 코드 {sex_codes} (1·2면 1 = 남, 2 = 여로 봄 → 맞는지 확인)')

    # 6) 서버용 파일 (resources/data랑 같은 모양, 이 폴더에만)
    write_server_files(args.out, cong, ga, cells, log)

    with open(os.path.join(args.out, 'check_lg.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(log) + '\n')
    print('\n'.join(log))
    print(f'\n결과 → {args.out}  (깃허브·카톡·AI에 올리지 않기, check_lg.txt만 공유해도 됨)')


if __name__ == '__main__':
    main()
