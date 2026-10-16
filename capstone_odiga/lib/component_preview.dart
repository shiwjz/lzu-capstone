import 'package:flutter/material.dart';

import 'widgets/odiga_widgets.dart';

/// Run with flutter run -t lib/component_preview.dart.
void main() => runApp(const ComponentPreviewApp());

class ComponentPreviewApp extends StatelessWidget {
  const ComponentPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: OdigaTokens.brand),
    ),
    home: const _Preview(),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  var _size = RecommendationSheetSize.expanded;
  var _category = '전체';
  final _stops = [
    (id: 'restaurant', title: '성수 작은 식탁', minutes: 50),
    (id: 'cafe', title: '카페 온도 성수', minutes: 50),
    (id: 'park', title: '서울숲 산책', minutes: 55),
  ];

  Future<void> _selectStay(String id) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('체류시간 선택'),
        children: [
          for (final minutes in [30, 50, 60, 90, 120])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, minutes),
              child: Text('$minutes분'),
            ),
        ],
      ),
    );
    if (!mounted || minutes == null) return;
    final index = _stops.indexWhere((stop) => stop.id == id);
    if (index < 0) return;
    setState(() {
      final stop = _stops[index];
      _stops[index] = (id: stop.id, title: stop.title, minutes: minutes);
    });
  }

  String _visitLabel(int index) {
    var minutes = 12 * 60;
    for (var i = 0; i < index; i++) {
      minutes += _stops[i].minutes + 10;
    }
    return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')} 방문 · 한산';
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: OdigaTokens.background,
      appBar: AppBar(
        title: const Text('오디가 컴포넌트 미리보기'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '코스 수정'),
            Tab(text: '추천 근거'),
            Tab(text: '친구'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 390,
            child: TabBarView(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: OdigaContentSheet(
                    title: '코스 수정 · 동선 자동 계산',
                    size: _size,
                    onSizeChanged: (size) => setState(() => _size = size),
                    children: [
                      OdigaCategoryFilter(
                        selected: _category,
                        onChanged: (value) => setState(() => _category = value),
                      ),
                      CourseSummaryCard(
                        summary:
                            '체류 ${_stops.fold(0, (sum, stop) => sum + stop.minutes)}분 · 장소 ${_stops.length}개',
                        detail: '임시 데이터 · 체류시간과 순서 변경 가능',
                      ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _stops.length,
                        onReorderItem: (oldIndex, newIndex) => setState(() {
                          _stops.insert(newIndex, _stops.removeAt(oldIndex));
                        }),
                        itemBuilder: (context, index) {
                          final stop = _stops[index];
                          return Column(
                            key: ValueKey(stop.id),
                            children: [
                              CourseStopTile(
                                order: index + 1,
                                title: stop.title,
                                visitLabel: _visitLabel(index),
                                stayMinutes: stop.minutes,
                                onStayPressed: () => _selectStay(stop.id),
                                onDelete: () => setState(
                                  () => _stops.removeWhere(
                                    (s) => s.id == stop.id,
                                  ),
                                ),
                                reorderHandle: ReorderableDragStartListener(
                                  index: index,
                                  child: Semantics(
                                    label: '${stop.title} 순서 변경',
                                    child: Text(
                                      '≡',
                                      style: OdigaTokens.text(
                                        18,
                                        color: OdigaTokens.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (index < _stops.length - 1)
                                const CourseTravelDivider(label: '도보 10분'),
                            ],
                          );
                        },
                      ),
                      if (_stops.isEmpty) const Text('모든 장소를 삭제했습니다.'),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: OdigaContentSheet(
                    title: '추천 근거',
                    size: _size,
                    onSizeChanged: (size) => setState(() => _size = size),
                    children: const [
                      RecommendationRankHeader(rank: 1),
                      RecommendationReasonRow(
                        label: '사용자 조건 일치도',
                        value: '96% · 지역·인원·시간·분위기 일치',
                      ),
                      RecommendationReasonRow(
                        label: '예상 혼잡도',
                        value: '평균 28% · 한산한 시간 선택',
                      ),
                      RecommendationReasonRow(
                        label: '이동거리',
                        value: '2.1km · 도보 이동 중심',
                      ),
                      RecommendationReasonRow(
                        label: '체류시간',
                        value: '식사 50분 · 카페 50분 · 산책 55분',
                      ),
                      RecommendationReasonRow(
                        label: '장소 특징',
                        value: '조용한 실내 · 디저트 · 산책',
                      ),
                      RecommendationReasonRow(
                        label: '그룹 선호도',
                        value: '미연결 · 전체 평균 기준 적용',
                      ),
                    ],
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [
                    FriendCard(
                      name: '예민',
                      initial: '예',
                      status: '오늘은 감성 카페가 좋아요',
                    ),
                    SizedBox(height: 12),
                    FriendCard(
                      name: '예령',
                      initial: '예',
                      status: '사진 찍기 좋은 곳을 찾아요',
                    ),
                    SizedBox(height: 12),
                    FriendCard(name: '정헌', initial: '정', status: '맛있는 한식과 산책'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
