"""
블로그 글에서 태그 찾기 (Kiwi 형태소 분석으로 부정 표현 처리)

1) 사전 단어가 글에 있는지 찾음
2) Kiwi로 그 단어 앞뒤를 봐서 부정이면 빼기
   - 앞에 "안", "못"       → "안 조용했어요"
   - 뒤에 "않", "못", "없", "별로", "아니" → "조용하진 않았어요", "데이트 장소로는 별로"
3) 반대말을 부정하면 태그 붙이기 → "안 시끄러웠어요" = 조용한
"""

from kiwipiepy import Kiwi

from tag_dictionary import TAG_KEYWORDS, NEGATIVE_PATTERNS, OPPOSITE_WORDS


kiwi = Kiwi()

NEG_BEFORE = {"안", "못"}                          # 단어 바로 앞
NEG_AFTER = {"않", "못하", "못", "없", "별로", "아니"}  # 단어 뒤
CONTINUE_EC = {"지", "진", "게"}                    # "조용하지 않"처럼 부정이 이어지는 어미
WINDOW = 4                                          # 단어 뒤로 몇 낱말까지 볼지


def find_all(text, word):
    """글에서 word가 나오는 위치를 전부"""
    start = text.find(word)
    while start != -1:
        yield start
        start = text.find(word, start + 1)


def is_negated(tokens, start, end):
    """글의 start~end 위치에 있는 단어가 부정됐는지"""

    # 1) 바로 앞에 "안", "못" (예: 안 조용했어요)
    for t in tokens:
        t_end = t.start + t.len
        if (
            t.form in NEG_BEFORE
            and t.tag == "MAG"
            and t_end <= start
            and start - t_end <= 1
        ):
            return True

    # 2) 뒤쪽 몇 낱말 안에 "않", "못", "없", "별로" (예: 조용하진 않았어요)
    after = [t for t in tokens if t.start >= end]

    for t in after[:WINDOW]:
        if t.form in NEG_AFTER:
            return True
        # 문장이 끝나거나(. ! ?) 다른 말로 넘어가면(~고, ~서) 그만 봄
        if t.tag in ("SF", "SP", "SS"):
            break
        if t.tag == "EC" and t.form not in CONTINUE_EC:
            break

    return False


def has_positive_mention(text, tokens, word):
    """word가 부정되지 않은 채로 한 번이라도 나오는지"""
    for start in find_all(text, word):
        # "북적이지 않", "비싸지 않"처럼 단어 자체가 부정형이면 그대로 인정
        if "않" in word:
            return True
        if not is_negated(tokens, start, start + len(word)):
            return True
    return False


def extract_tags(text):
    tokens = kiwi.tokenize(text)
    found_tags = []

    for tag, keywords in TAG_KEYWORDS.items():

        # 반대 표현이 있으면 빼기 (단, "안 시끄러웠"처럼 반대 표현이 부정되면 무시)
        if any(has_positive_mention(text, tokens, p) for p in NEGATIVE_PATTERNS.get(tag, [])):
            continue

        if any(has_positive_mention(text, tokens, k) for k in keywords):
            found_tags.append(tag)

    # 반대말을 부정하면 태그 붙이기 (안 시끄러웠어요 → 조용한)
    for tag, words in OPPOSITE_WORDS.items():
        if tag in found_tags:
            continue
        for word in words:
            if any(is_negated(tokens, s, s + len(word)) for s in find_all(text, word)):
                found_tags.append(tag)
                break

    return found_tags


if __name__ == "__main__":
    # (문장, 맞는 태그)
    tests = [
        ("안 조용했어요", []),
        ("조용했어요", ["조용한"]),
        ("하나도 안 시끄러웠어요", ["조용한"]),
        ("시끄럽진 않았어요", ["조용한"]),
        ("조용하진 않았어요", []),
        ("조용하고 분위기 좋았어요", ["조용한", "감성적인"]),
        ("가성비는 별로예요", []),
        ("안 비싸요", ["가성비좋은"]),
        ("데이트 장소로는 별로였어요", []),
        ("데이트하기 좋은 곳이에요", ["데이트"]),
        ("노키즈존이라 아이랑은 못 가요", []),
        ("아이랑 가기 좋아요", ["아이"]),
        ("사람이 많아서 시끄러웠어요", []),
        ("북적이지 않아서 좋았어요", ["조용한"]),
    ]

    ok = 0
    for text, answer in tests:
        result = extract_tags(text)
        mark = "✅" if sorted(result) == sorted(answer) else "❌"
        ok += mark == "✅"
        print(f"{mark} {text}  →  {result}  (정답 {answer})")

    print(f"\n{ok} / {len(tests)} 맞음")
