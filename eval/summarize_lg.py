"""
윤경 LG 정량평가 결과 → 발표자료용 표·그래프 (11/11) - 김예민
  python3 eval/summarize_lg.py --src /Users/min/lzu-private-data/eval_lg --out /Users/min/lzu-private-data/eval_slides

- 입력 (윤경 eval/*.py 결과, LG 기반이라 레포 밖에 두기)
  eval_methods_lg.csv            region, situation, method, candidates, precision@5, ndcg@5
  eval_congestion_effect_lg.csv  region, situation, pct_before, pct_after, crowd_fit_before, crowd_fit_after,
                                 same_places, ndcg_before, ndcg_after
  eval_congestion_top5_lg.csv    region, situation, when, rank, place_id, level, pct
  eval_sensitivity_lg.csv        change, top5_overlap_with_base, ndcg@5
  eval_top5_lg.csv               scenario, method, rank, place_id, moods   (발표 예시용, 요약은 개수만)
- 출력: summary.md (발표·보고서에 옮길 표) + 그래프 PNG 4장
- 결과는 평균·비율 같은 요약값만. 그래도 LG에서 나온 거라 깃허브·카톡·드라이브·AI에 올리지 말고,
  발표자료에 넣는 건 교수님 확인(평가 수치 공개 범위) 받고
"""
import argparse
import os
import sys

import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def inside_repo(path):
    return os.path.abspath(path).startswith(ROOT + os.sep) or os.path.abspath(path) == ROOT


def md_table(df, digits=3):
    df = df.copy()
    for c in df.columns:
        if pd.api.types.is_float_dtype(df[c]):
            df[c] = df[c].round(digits)
    head = '| ' + ' | '.join(map(str, df.columns)) + ' |'
    sep = '| ' + ' | '.join('---' for _ in df.columns) + ' |'
    rows = ['| ' + ' | '.join(map(str, r)) + ' |' for r in df.itertuples(index=False)]
    return '\n'.join([head, sep] + rows)


def plt_korean():
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib import font_manager
    for name in ('AppleGothic', 'Apple SD Gothic Neo', 'Malgun Gothic', 'NanumGothic', 'Noto Sans CJK KR'):
        if any(f.name == name for f in font_manager.fontManager.ttflist):
            plt.rcParams['font.family'] = name
            break
    plt.rcParams['axes.unicode_minus'] = False
    return plt


def read(src, name):
    path = os.path.join(src, name)
    if not os.path.exists(path):
        print(f'  (없음) {name}')
        return None
    return pd.read_csv(path, encoding='utf-8-sig')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True, help='윤경 eval_*_lg.csv 있는 폴더 (레포 밖)')
    ap.add_argument('--out', required=True, help='결과 폴더 (레포 밖)')
    a = ap.parse_args()
    for p in (a.src, a.out):
        if inside_repo(p):
            sys.exit(f'레포 안 폴더는 안 돼요 (LG 결과가 깃허브에 올라갈 수 있어서): {p}')
    os.makedirs(a.out, exist_ok=True)
    plt = plt_korean()
    md = ['# 정량평가 요약 (LG 혼잡도 기준)', '']

    # 1. 방법별 평균 (오디가 vs 인기순 vs 거리순 vs 랜덤)
    m = read(a.src, 'eval_methods_lg.csv')
    if m is not None:
        avg = (m.groupby('method')[['precision@5', 'ndcg@5']].mean()
               .sort_values('precision@5', ascending=False).reset_index())
        avg.insert(1, '시나리오 수', m.groupby('method').size().reindex(avg['method']).values)
        md += ['## 1. 방법별 평균 Precision@5 · nDCG@5', '', md_table(avg), '']
        by_region = m.pivot_table(index='method', columns='region', values='precision@5', aggfunc='mean')
        md += ['지역별 Precision@5', '', md_table(by_region.reset_index()), '']
        ax = avg.set_index('method')[['precision@5', 'ndcg@5']].plot.bar(rot=0, figsize=(7, 4),
                                                                          color=['#3b6fd8', '#9db8f0'])
        ax.set_ylim(0, 1)
        ax.set_title('추천 방법별 정확도 (구글 리뷰 기준)')
        for c in ax.containers:
            ax.bar_label(c, fmt='%.2f', fontsize=8)
        plt.tight_layout(); plt.savefig(os.path.join(a.out, '1_methods.png'), dpi=200); plt.close()

    # 2. 혼잡도 반영 전후
    e = read(a.src, 'eval_congestion_effect_lg.csv')
    if e is not None:
        rows = []
        for label, b, af in (('평균 혼잡 백분위 (낮을수록 한산)', 'pct_before', 'pct_after'),
                             ('혼잡 선호 적합도', 'crowd_fit_before', 'crowd_fit_after'),
                             ('nDCG@5 (추천 정확도)', 'ndcg_before', 'ndcg_after')):
            rows.append({'지표': label, '반영 전': e[b].mean(), '반영 후': e[af].mean(),
                         '차이': e[af].mean() - e[b].mean()})
        t = pd.DataFrame(rows)
        md += ['## 2. 혼잡도 반영 전후 (상위 5곳)', '', md_table(t), '',
               f"- 시나리오 {len(e)}개 중 혼잡도가 낮아진 곳: {(e['pct_after'] < e['pct_before']).sum()}개",
               f"- 상위 5곳 중 그대로 남은 장소: 평균 {e['same_places'].mean():.1f}곳", '']
        fig, axes = plt.subplots(1, 2, figsize=(8, 3.6))
        axes[0].bar(['반영 전', '반영 후'], [e['pct_before'].mean(), e['pct_after'].mean()], color=['#c9c9c9', '#3b6fd8'])
        axes[0].set_title('평균 혼잡 백분위 (낮을수록 한산)')
        axes[1].bar(['반영 전', '반영 후'], [e['ndcg_before'].mean(), e['ndcg_after'].mean()], color=['#c9c9c9', '#3b6fd8'])
        axes[1].set_ylim(0, 1); axes[1].set_title('nDCG@5 (추천 정확도)')
        for ax in axes:
            for c in ax.containers:
                ax.bar_label(c, fmt='%.2f', fontsize=8)
        plt.tight_layout(); plt.savefig(os.path.join(a.out, '2_congestion_effect.png'), dpi=200); plt.close()

    # 3. 상위 5곳 혼잡 등급 분포 (전/후)
    c5 = read(a.src, 'eval_congestion_top5_lg.csv')
    if c5 is not None:
        dist = (c5.groupby(['when', 'level']).size().unstack(fill_value=0))
        dist = dist.reindex(columns=[x for x in ('QUIET', 'NORMAL', 'BUSY') if x in dist.columns])
        share = (dist.T / dist.sum(axis=1)).T
        md += ['## 3. 상위 5곳 혼잡 등급 비율', '', md_table(share.reset_index()), '']
        ax = share.plot.barh(stacked=True, figsize=(7, 2.8), color=['#7cc4a0', '#f0c27a', '#e07a6a'][:len(share.columns)])
        ax.set_xlim(0, 1); ax.set_title('상위 5곳 혼잡 등급 비율'); ax.set_ylabel('')
        plt.tight_layout(); plt.savefig(os.path.join(a.out, '3_congestion_levels.png'), dpi=200); plt.close()

    # 4. 민감도 (가중치 바꿔도 결과가 안정적인지)
    s = read(a.src, 'eval_sensitivity_lg.csv')
    if s is not None:
        md += ['## 4. 민감도 (가중치를 바꿨을 때)', '', md_table(s), '',
               f"- 기본 대비 상위 5곳 겹침 평균 {s['top5_overlap_with_base'].mean():.2f}, nDCG@5 범위 "
               f"{s['ndcg@5'].min():.2f} ~ {s['ndcg@5'].max():.2f}", '']
        ax = s.set_index('change')['top5_overlap_with_base'].plot.barh(figsize=(7, 0.45 * len(s) + 1), color='#3b6fd8')
        ax.set_title('가중치 바꿨을 때 기본 상위 5곳과 겹치는 정도'); ax.set_ylabel('')
        plt.tight_layout(); plt.savefig(os.path.join(a.out, '4_sensitivity.png'), dpi=200); plt.close()

    t5 = read(a.src, 'eval_top5_lg.csv')
    if t5 is not None:
        md += ['## 5. 예시용 상위 5곳 목록', '',
               f"- 시나리오 {t5['scenario'].nunique()}개 × 방법 {t5['method'].nunique()}개 (eval_top5_lg.csv에서 골라서 발표 예시로)", '']

    with open(os.path.join(a.out, 'summary.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(md))
    print(f'끝 → {a.out} (summary.md + 그래프 PNG)')


if __name__ == '__main__':
    main()
