import os
import re
import html
import time
import requests

from dotenv import load_dotenv


load_dotenv()


NAVER_CLIENT_ID = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")


API_URL = (
    "https://naverapihub.apigw.ntruss.com/"
    "search/v1/blog"
)


def clean_text(text):
    """
    네이버 검색 결과의 HTML 태그와
    HTML 엔티티를 정리한다.
    """

    text = text or ""

    text = re.sub(
        r"<[^>]+>",
        "",
        text
    )

    return html.unescape(text)


def search_blogs(
    place_name,
    region=None,
    display=50,
    max_retries=3,
    retry_delay=1.0
):

    if (
        not NAVER_CLIENT_ID
        or not NAVER_CLIENT_SECRET
    ):
        raise ValueError(
            "NAVER_CLIENT_ID 또는 "
            "NAVER_CLIENT_SECRET이 없습니다."
        )

    query = (
        f"{place_name} {region}"
        if region
        else place_name
    )

    headers = {
        "X-NCP-APIGW-API-KEY-ID":
            NAVER_CLIENT_ID,
        "X-NCP-APIGW-API-KEY":
            NAVER_CLIENT_SECRET
    }

    params = {
        "query": query,
        "display": display,
        "start": 1,
        "sort": "sim"
    }

    last_error = None

    for attempt in range(
        1,
        max_retries + 1
    ):

        try:

            response = requests.get(
                API_URL,
                headers=headers,
                params=params,
                timeout=10
            )

            response.raise_for_status()

            data = response.json()

            results = []

            for item in data.get(
                "items",
                []
            ):

                results.append({

                    "title":
                        clean_text(
                            item.get(
                                "title",
                                ""
                            )
                        ),

                    "description":
                        clean_text(
                            item.get(
                                "description",
                                ""
                            )
                        ),

                    "link":
                        item.get(
                            "link",
                            ""
                        ),

                    "blogger_name":
                        clean_text(
                            item.get(
                                "bloggername",
                                ""
                            )
                        ),

                    "blogger_link":
                        item.get(
                            "bloggerlink",
                            ""
                        ),

                    "post_date":
                        item.get(
                            "postdate",
                            ""
                        )
                })

            return results

        except (
            requests.RequestException,
            ValueError
        ) as e:

            last_error = e

            if attempt < max_retries:
                time.sleep(
                    retry_delay * attempt
                )

    raise RuntimeError(
        f"네이버 블로그 검색 실패 "
        f"(재시도 {max_retries}회): "
        f"{last_error}"
    )


if __name__ == "__main__":

    blogs = search_blogs(
        place_name="커피냅로스터스",
        region="성수",
        display=10
    )

    for index, blog in enumerate(
        blogs,
        start=1
    ):

        print(
            f"[{index}]",
            blog["title"]
        )

        print(
            "블로거:",
            blog["blogger_name"]
        )

        print(
            "블로그 주소:",
            blog["blogger_link"]
        )

        print()
