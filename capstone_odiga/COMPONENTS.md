# 오디가 공통 컴포넌트

선택한 Figma 화면 중 코스 수정(133:1972), 추천 근거(133:2243), 친구(26:14)의 코드와 렌더를 기준으로 반복 요소를 분리했습니다. 선택된 62개 노드 전체의 구현을 완료한 것은 아닙니다.

## 사용

```dart
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
```

기존 `odiga_components.dart`의 버튼, 태그, 카드, 아바타, 지도 요소는 그대로 재사용합니다. 새 조합 위젯은 `odiga_content_components.dart`에 있습니다.

| 클래스 | 역할 |
| --- | --- |
| `OdigaContentSheet` | 제목, 핸들, 내부 스크롤, 접힘·중간·확장 전환 |
| `OdigaCategoryFilter` | 카테고리 태그 선택과 가로 스크롤 |
| `CourseSummaryCard` | 계산된 코스 요약과 보조 설명 |
| `CourseStopTile` | 방문 순서, 장소명, 방문 시간, 체류시간 버튼, 삭제 |
| `CourseTravelDivider` | 장소 사이 이동시간 |
| `RecommendationRankHeader` | 추천 순위와 평가 기준 |
| `RecommendationReasonRow` | 조건명과 근거 값 |
| `FriendCard` | 아바타, 친구 이름, 상태 메시지 |

위젯은 전달받은 값을 표시하고 콜백으로 변경을 알립니다. 데이터 수정·동선 계산·저장·네트워크 호출은 화면 또는 상태 관리 계층이 담당합니다. 삭제 결과와 체류시간별로 다른 화면 클래스를 만들지 않고 같은 `CourseStopTile`에 갱신된 데이터를 전달합니다. 순서 변경은 `ReorderableListView` 안에서 `reorderHandle`을 연결합니다. 시트는 높이가 제한된 부모의 하단에 배치합니다.

## 미리보기

```sh
flutter run -t lib/component_preview.dart
```

코스 수정·추천 근거·친구 탭에서 확인할 수 있습니다. 코스 수정 탭은 임시 데이터로 태그 선택, 체류시간 선택, 장소 삭제, 손잡이 드래그로 순서 변경, 시트 크기 전환을 제공합니다. 방문 시간은 예제용 도보 10분으로 계산하며 실제 지도·추천 API와 연결되지 않습니다. 앱 기본 진입점인 `main.dart`는 기존 상태를 유지합니다.

기존 디자인 토큰의 `Noto Sans KR` 글꼴은 현재 프로젝트에 등록되어 있지 않아 시스템 대체 글꼴로 표시됩니다. 글꼴 파일 등록 후 Figma와 최종 비교가 필요합니다.
