import math
from place_score import request_score, target_score, congestion_fit, place_score

AVG = {"female_ratio": 0.5, "age_20s": 0.25, "age_30s": 0.25}       # 지역 평균
CELL = {"female_ratio": 0.6, "age_20s": 0.5, "age_30s": 0.2}        # 이 칸
CLUSTER = {"female_ratio": 0.4, "age_20s": 0.3, "age_30s": 0.3}     # 같은 유형 칸들의 평균
# 반반 섞으면 → 여성 0.5, 20대 0.4, 30대 0.25

def check(no, got, expected):
    ok = math.isclose(got, expected, abs_tol=1e-4)
    print(f"{no:>2}. {'통과' if ok else '실패'}  결과 {got:.4f}  정답 {expected:.4f}")
    return ok

results = [
    # 사용자 요구
    check(1, request_score(["조용함"], {"조용함": 3}), 1.0),                      # 언급 충분 → 1
    check(2, request_score(["조용함", "데이트"], {"조용함": 3}), 0.5),            # 2개 중 1개 일치
    check(3, request_score(["조용함"], {"조용함": 1}), 1 / 3),                    # 언급 1번 → 1/3
    check(4, request_score([], {"조용함": 3}), 0.5),                              # 분위기 요청 없음 → 중립
    # 타깃 특성
    check(5, target_score(CELL, CLUSTER, AVG, "F", "20s"), 1.6 / 2.6),            # 유형 반영: 1.0×1.6=1.6
    check(6, target_score(CELL, CLUSTER, AVG, "M", "30s"), 0.5),                  # 유형 반영: 1.0×1.0=1.0
    check(7, target_score(CELL, None, AVG, "F", "20s"), 2.4 / 3.4),               # 유형 없음: 1.2×2.0=2.4
    check(8, target_score(CELL, CLUSTER, AVG, None, None), 0.5),                  # 성별·연령 없음 → 전체 평균
    # 혼잡도 적합도
    check(9, congestion_fit("QUIET", "BUSY"), 0.1),                               # 조용한 곳 원하는데 혼잡
    # 장소 점수 전체
    check(10, place_score({"atmospheres": ["조용함"], "gender": "F", "ageGroup": "20s",
                           "crowdPreference": "QUIET"},
                          {"조용함": 3}, CELL, CLUSTER, AVG, "QUIET")["total"],
          0.45 * 1.0 + 0.30 * (1.6 / 2.6) + 0.25 * 1.0),                          # = 0.8846
]
print(f"\n{sum(results)}/10 통과")