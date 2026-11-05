from tag_dictionary import TAG_KEYWORDS, NEGATIVE_PATTERNS


def has_negative_expression(text, tag):
    for pattern in NEGATIVE_PATTERNS.get(tag, []):
        if pattern in text:
            return True
    return False


def extract_tags(text):
    found_tags = []

    for tag, keywords in TAG_KEYWORDS.items():

        if has_negative_expression(text, tag):
            continue

        for keyword in keywords:
            if keyword in text:
                found_tags.append(tag)
                break

    return found_tags


if __name__ == "__main__":
    test_texts = [
        "데이트하기 좋은 곳, 분위기 좋고 조용해서 좋았어요",
        "회식 장소로 딱이에요. 룸이 있어서 단체로 가기 좋아요",
        "혼밥하기 좋고 가성비도 좋아요",
        "루프탑 뷰 맛집! 매장이 넓고 포토존도 많아요",
        "노키즈존이라 아이랑은 못 가요",
        "아이랑 가기 좋고 아기의자도 있어요",
        "사람이 많아서 시끄러웠어요",
        "핫플이라 활기 넘치는 분위기",
        "#성수데이트 #성수카페",
    ]

    for text in test_texts:
        print("문장:", text)
        print("태그:", extract_tags(text))
        print()
