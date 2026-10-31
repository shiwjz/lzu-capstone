from tag_dictionary import TAG_KEYWORDS


NEGATIVE_PATTERNS = {
    "조용함": [
        "조용하지 않",
        "조용하지는 않",
        "시끄러웠",
        "시끄러워",
        "시끄러운",
        "북적였",
        "북적거",
        "북적북적"
    ],

    "데이트": [
        "데이트하기 별로",
        "데이트 장소로 별로"
    ],

    "단체": [
        "단체로 가기 어렵",
        "단체석 없"
    ],

    "혼자가능": [
    "혼자 가기 부담",
    "혼자 방문하기 부담",
    "혼자 가기 어렵",
    "1인 이용 어렵"
    ],

    "디저트": [
        "디저트 없",
        "디저트는 별로"
    ],

    "사진": [
        "사진 찍기 어렵",
        "사진은 별로"
    ],

    "가성비": [
        "비싸요",
        "비쌌",
        "비싼 편",
        "가격이 비쌈",
        "가격 부담"
    ]
}


def has_negative_expression(text, tag):
    patterns = NEGATIVE_PATTERNS.get(tag, [])

    for pattern in patterns:
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
        "성수 데이트로 갔는데 매장이 조용하고 디저트도 맛있었어요.",
        "사람이 많고 조용하지 않고 시끄러웠어요.",
        "웨이팅 없이 바로 입장했고 가성비도 좋았어요.",
        "혼밥하기 좋고 가격도 저렴했어요."
    ]

    for text in test_texts:
        print("문장:", text)
        print("태그:", extract_tags(text))
        print()