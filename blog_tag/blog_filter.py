import re
import html


AD_KEYWORDS = [
    "협찬",
    "제공받아",
    "제공 받아",
    "지원받아",
    "지원 받아",
    "원고료",
    "소정의",
    "체험단",
    "업체로부터",
    "광고",
    "수수료"
]


NOT_AD_WORDS = [
    "광고아님",
    "광고x",
    "노광고",
    "비광고",
    "내돈내산"
]


REGION_KEYWORDS = {

    "SEONGSU": [
        "성수",
        "성수동",
        "서울숲",
        "뚝섬",
        "성동구"
    ],

    "HONGDAE": [
        "홍대",
        "연남",
        "연남동",
        "합정",
        "상수역",
        "마포구"
    ],

    "GANGNAM": [
        "강남",
        "강남역",
        "신논현",
        "역삼",
        "강남구"
    ]
}


OTHER_AREA_KEYWORDS = [
    "부산",
    "대구",
    "대전",
    "광주",
    "인천",
    "수원",
    "일산",
    "판교",
    "분당",
    "잠실",
    "송파",
    "신촌",
    "건대",
    "용산",
    "종로",
    "여의도",
    "압구정",
    "청담"
]


BRANCH_EXCLUDE_WORDS = {
    "좋은점",
    "아쉬운점",
    "장점",
    "단점",
    "편의점",
    "백화점"
}


def clean_html(text):
    """
    네이버가 붙이는 <b>, </b> 만 지움
    (예전엔 <...> 를 다 지워서 "홍대 칵테일 바 <깃털>"의 상호명까지 사라졌음)
    """
    text = text or ""

    text = re.sub(
        r"</?b>",
        "",
        text,
        flags=re.IGNORECASE
    )

    return html.unescape(text)


def normalize_text(text):
    text = clean_html(
        text
    ).lower()

    return re.sub(
        r"[^0-9a-zA-Z가-힣]",
        "",
        text
    )


def is_self_paid_post(text):

    normalized = normalize_text(
        text
    )

    return (
        "내돈내산"
        in normalized
    )


def is_ad_post(text):

    normalized = normalize_text(
        text
    )

    for word in NOT_AD_WORDS:

        if normalize_text(
            word
        ) in normalized:

            return False

    for keyword in AD_KEYWORDS:

        if normalize_text(
            keyword
        ) in normalized:

            return True

    return False


def get_base_place_name(
    place_name
):

    name = (
        place_name or ""
    ).strip()

    tokens = name.split()

    if len(tokens) >= 2:

        last = tokens[-1]

        if last.endswith(
            "점"
        ):

            return " ".join(
                tokens[:-1]
            )

    return name


def get_target_branch(
    place_name
):

    tokens = (
        place_name or ""
    ).split()

    if len(tokens) < 2:
        return ""

    last = tokens[-1]

    if last.endswith(
        "점"
    ):
        return last

    return ""


# ---------------------------------------------------------
# 상호명 비교용 이름 만들기
# ---------------------------------------------------------

# 이름 '끝'에 붙어 있을 때만 떼는 단어
SUFFIX_WORDS = [
    "카페",
    "커피",
    "cafe",
    "coffee",
    "갤러리",
    "쇼룸"
]

# 띄어쓰기로 '따로 떨어져' 있을 때만 빼는 지역 단어
REGION_TOKENS = {
    "서울",
    "서울숲",
    "성수",
    "홍대",
    "강남",
    "연남"
}

# 자동 규칙으로 못 찾는 곳은 직접 별명 적기
# (key: 카카오 상호명, value: 블로거들이 쓰는 이름)
NAME_ALIASES = {
    "미유 MEOW": ["미유"],
    "에디션덴마크 서울숲쇼룸": ["에디션덴마크쇼룸", "에디션덴마크"],
    "클래식 해례커피": ["해례커피"],
}


def strip_suffix(text):
    """
    끝에 붙은 카페/커피/쇼룸 등을 뗀다.

    예: 더블하이트갤러리카페 → 더블하이트
    """

    changed = True

    while changed:

        changed = False

        for word in SUFFIX_WORDS:

            if (
                text.endswith(word)
                and len(text) > len(word)
            ):
                text = text[: -len(word)]
                changed = True

    return text


def add_cafe_spelling(variants):
    """카페 ↔ cafe 표기 둘 다 넣기"""

    for value in list(variants):

        if "카페" in value:
            variants.add(value.replace("카페", "cafe"))

        if "cafe" in value:
            variants.add(value.replace("cafe", "카페"))

    return variants


def make_name_variants(
    place_name
):
    """
    반환: (전체 이름들, 줄인 이름들)

    줄인 이름으로만 찾은 글은
    지역 확인을 꼭 하도록 따로 돌려준다.
    """

    base_name = get_base_place_name(
        place_name
    )

    full = {
        normalize_text(base_name)
    }

    # 1) 'A by B' → A
    head = re.split(
        r"\s+by\s+",
        base_name,
        flags=re.IGNORECASE
    )[0]

    # 2) 따로 떨어진 지역 단어 빼기 (밋보어 서울 → 밋보어)
    tokens = [
        token
        for token in head.split()
        if token not in REGION_TOKENS
    ]

    joined = normalize_text(
        " ".join(tokens)
    )

    # 3) 끝에 붙은 카페/커피 등 떼기
    short = {
        joined,
        strip_suffix(joined)
    }

    # 4) 직접 적은 별명
    for alias in NAME_ALIASES.get(place_name, []):
        short.add(normalize_text(alias))

    full = add_cafe_spelling(full)
    short = add_cafe_spelling(short)

    # 너무 짧게 줄어든 이름은 쓰지 않음 (예: 카페 정상 → 정상)
    short = {
        value
        for value in short
        if len(value) >= 3
        and value not in full
    }

    # 별명은 2글자도 허용 (사람이 직접 확인한 것이라서)
    for alias in NAME_ALIASES.get(place_name, []):
        short.add(normalize_text(alias))

    return (
        {value for value in full if value},
        short
    )


# 이름 바로 뒤에 붙어도 되는 말 (조사·지점 등)
ALLOWED_AFTER_NAME = (
    "에서", "으로", "이랑", "은", "는", "이", "가", "을", "를", "에", "의",
    "와", "과", "랑", "도", "만", "로", "점", "카페", "커피"
)


def is_separate_word(text, name):
    """
    짧은 이름이 다른 단어의 일부가 아니라 따로 쓰였는지 확인

    예: 소노 → "소노관리"(X), "신화랑풍류"(X), "소노에서 커피"(O), "#소노 "(O)
    """

    cleaned = clean_html(text).lower()
    name = name.lower()
    start = cleaned.find(name)

    while start != -1:
        before = cleaned[start - 1] if start > 0 else " "
        after = cleaned[start + len(name):]

        before_ok = not re.match(r"[가-힣]", before)
        after_ok = (
            after == ""
            or not re.match(r"[가-힣]", after[0])
            or after.startswith(ALLOWED_AFTER_NAME)
        )

        if before_ok and after_ok:
            return True

        start = cleaned.find(name, start + 1)

    return False


def find_place_name(
    text,
    place_name
):
    """
    반환:
    "FULL"  → 전체 이름으로 찾음
    "SHORT" → 줄인 이름/별명으로만 찾음 (지역 확인 필요)
    None    → 못 찾음
    """

    normalized_text = normalize_text(
        text
    )

    full, short = make_name_variants(
        place_name
    )

    if any(value in normalized_text for value in full):
        return "FULL"

    if any(value in normalized_text for value in short):
        return "SHORT"

    return None


def extract_address_keywords(
    address,
    road_address
):

    keywords = set()

    combined = (
        f"{address or ''} "
        f"{road_address or ''}"
    )

    words = re.findall(
        r"[가-힣0-9]+",
        combined
    )

    for word in words:

        if (
            "동" in word
            and len(word) >= 2
        ):
            keywords.add(
                word
            )

        if (
            word.endswith("길")
            or word.endswith("로")
        ):
            keywords.add(
                word
            )

    return keywords


def has_target_region(
    text,
    region_code,
    address="",
    road_address=""
):

    normalized = (
        normalize_text(
            text
        )
    )

    for keyword in (
        REGION_KEYWORDS.get(
            region_code,
            []
        )
    ):

        if (
            normalize_text(
                keyword
            )
            in normalized
        ):
            return True

    for keyword in (
        extract_address_keywords(
            address,
            road_address
        )
    ):

        if (
            normalize_text(
                keyword
            )
            in normalized
        ):
            return True

    return False


def has_other_region(
    text,
    region_code,
    place_name=""
):
    """
    상호명 자체에 들어있는 지역 단어는
    다른 지역 검사에서 제외한다.
    """

    text_without_place = (
        text or ""
    )

    base_name = (
        get_base_place_name(
            place_name
        )
    )

    if base_name:

        text_without_place = re.sub(
            re.escape(
                base_name
            ),
            " ",
            text_without_place,
            flags=re.IGNORECASE
        )

    normalized = normalize_text(
        text_without_place
    )

    for keyword in (
        REGION_KEYWORDS.get(
            region_code,
            []
        )
    ):

        if (
            normalize_text(
                keyword
            )
            in normalized
        ):
            return False

    for keyword in (
        OTHER_AREA_KEYWORDS
    ):

        if (
            normalize_text(
                keyword
            )
            in normalized
        ):
            return True

    return False


def has_wrong_branch(
    text,
    place_name
):

    target_branch = (
        get_target_branch(
            place_name
        )
    )

    if not target_branch:
        return False

    # [개선] 우리 지점 이름이 글에 있으면 다른 지점 해시태그가 있어도 우리 글로 봄
    #        예: "육몽 홍대본점 후기 #용산직영점 #방이직영점"
    # (단, "#홍대점심"처럼 지점 이름 뒤에 한글이 이어지면 지점이 아님)
    if re.search(
        re.escape(normalize_text(target_branch)) + r"(?![가-힣])",
        normalize_text(text)
    ):
        return False

    base_name = (
        get_base_place_name(
            place_name
        )
    )

    if not base_name:
        return False

    cleaned_text = clean_html(
        text
    )

    escaped_parts = [
        re.escape(part)
        for part in base_name.split()
    ]

    base_pattern = (
        r"\s*".join(
            escaped_parts
        )
    )

    pattern = (
        base_pattern
        + r"\s*"
        + r"([가-힣A-Za-z0-9]{1,15}점)"
    )

    branches = re.findall(
        pattern,
        cleaned_text,
        flags=re.IGNORECASE
    )

    if not branches:
        return False

    normalized_target = (
        normalize_text(
            target_branch
        )
    )

    for branch in branches:

        normalized_branch = (
            normalize_text(
                branch
            )
        )

        if (
            normalized_branch
            in {
                normalize_text(x)
                for x in BRANCH_EXCLUDE_WORDS
            }
        ):
            continue

        if (
            normalized_target
            == normalized_branch
        ):
            continue

        if (
            normalized_target
            in normalized_branch
            or normalized_branch
            in normalized_target
        ):
            continue

        return True

    return False


def is_relevant_post(
    text,
    place_name,
    region_code,
    address="",
    road_address=""
):

    # 1. 상호명
    match = find_place_name(
        text,
        place_name
    )

    if match is None:

        return (
            False,
            "PLACE_NAME_NOT_FOUND"
        )

    # [개선] 줄인 이름(3글자 이하)으로만 찾았으면 그것도 다른 단어의 일부인지 확인
    #        예: "더스크 성수" → "더스크"로 찾았는데 글은 "나이트더스크블루"
    if match == "SHORT":
        _, short_names = make_name_variants(place_name)
        found = [v for v in short_names if v in normalize_text(text)]
        if found and all(len(v) <= 3 for v in found) and not any(
            is_separate_word(text, v) for v in found
        ):

            return (
                False,
                "NAME_PART_OF_OTHER_WORD"
            )

    # [개선] 이름이 3글자 이하면 다른 단어의 일부인지 확인 (소노관리, 글렌그란트 등)
    short_base = get_base_place_name(place_name).strip()
    if (
        len(normalize_text(short_base)) <= 3
        and " " not in short_base
        and not is_separate_word(text, short_base)
    ):

        return (
            False,
            "NAME_PART_OF_OTHER_WORD"
        )

    # 2. 다른 지점
    if has_wrong_branch(
        text,
        place_name
    ):

        return (
            False,
            "OTHER_BRANCH"
        )

    # 3. 다른 지역
    if has_other_region(
        text,
        region_code,
        place_name=place_name
    ):

        return (
            False,
            "OTHER_REGION"
        )

    # 4. 이름이 짧거나, 줄인 이름으로만 찾았으면 지역 확인 필수
    base_name = normalize_text(
        get_base_place_name(
            place_name
        )
    )

    if (
        len(base_name) <= 3
        or match == "SHORT"
    ):

        if not has_target_region(
            text=text,
            region_code=region_code,
            address=address,
            road_address=road_address
        ):

            return (
                False,
                "SHORT_NAME_WITHOUT_REGION"
            )

    return (
        True,
        "OK"
    )
