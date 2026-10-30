part of 'app_screens.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({
    super.key,
    required this.app,
    this.group = false,
    this.expanded = false,
  });
  final AppState app;
  final bool group, expanded;
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  AppState get app => widget.app;
  bool get group => widget.group;
  bool get expanded => widget.expanded;
  Object? _requestKey;
  Future<List<Course>>? _request;
  int _selectedCourseIndex = 0;

  Future<List<Course>> recommendations() {
    final c = app.conditions;
    final p = app.preference;
    final key = (
      app.repository,
      c.region,
      c.start,
      c.people,
      c.mood,
      c.excluded,
      c.query,
      c.useSelectedRegion,
      p.categories.join(','),
      p.moods.join(','),
      p.allergies,
      p.dislikedFood,
      group,
    );
    if (_requestKey != key) {
      _requestKey = key;
      _selectedCourseIndex = 0;
      _request = app.repository.recommend(c.copy(), p.copy(), group: group);
    }
    return _request!;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: app,
    builder: (_, child) {
      return FutureBuilder<List<Course>>(
        future: recommendations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return AppFrame(
              app: app,
              title: '추천 코스',
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return AppFrame(
              app: app,
              title: '추천 코스',
              child: Column(
                children: [
                  Text(
                    snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : '추천을 불러오지 못했어요.',
                  ),
                  TextButton(
                    onPressed: () => openPage(
                      context,
                      ConditionsScreen(app: app, group: group),
                      '/conditions',
                    ),
                    child: const Text('검색 조건 수정'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _requestKey = null),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }
          final courses = snapshot.data ?? [];
          final selectedIndex = _selectedCourseIndex < courses.length
              ? _selectedCourseIndex
              : 0;
          final selectedCourse = courses.isEmpty
              ? null
              : courses[selectedIndex];
          return MapSheetFrame(
            app: app,
            title: courses.isEmpty
                ? '추천 결과 없음'
                : '추천 ${courses.length}개 · ${selectedCourse!.title}',
            course: selectedCourse,
            initialSize: expanded
                ? RecommendationSheetSize.expanded
                : RecommendationSheetSize.collapsed,
            children: [
              if (courses.isEmpty) ...[
                label('조건에 맞는 예시 장소가 없습니다.'),
                action(
                  '검색 조건 수정',
                  () => openPage(
                    context,
                    ConditionsScreen(app: app, group: group),
                    '/conditions',
                  ),
                ),
              ],
              for (var i = 0; i < courses.length; i++)
                RankedCourseCard(
                  rank: i + 1,
                  title: courses[i].title,
                  summary: _courseSummary(courses[i]),
                  reason: courses[i].reason,
                  keywords: _courseKeywords(courses[i]),
                  selected: i == selectedIndex,
                  onSelected: () => _openCourseDetail(courses[i], i),
                  onReason: () => _showRecommendationReasonPopup(
                    context,
                    app: app,
                    course: courses[i],
                    rank: i + 1,
                    group: group,
                  ),
                ),
              if (courses.isNotEmpty)
                action(
                  '조건 수정',
                  () => openPage(
                    context,
                    ConditionsScreen(app: app, group: group),
                    '/conditions',
                  ),
                  secondary: true,
                ),
            ],
          );
        },
      );
    },
  );

  Future<void> _openCourseDetail(Course course, int index) async {
    await openPage(
      context,
      CourseDetailScreen(app: app, initial: course),
      '/course/${course.id}',
    );
    if (!mounted) return;
    setState(() => _selectedCourseIndex = index);
  }

  List<String> _courseKeywords(Course course) {
    final keywords = <String>[];
    final mood = app.conditions.mood.trim();
    if (mood.isNotEmpty) keywords.add(mood);
    for (final stop in course.stops) {
      final category = app.repository.place(stop.placeId).category;
      if (!keywords.contains(category)) keywords.add(category);
      if (keywords.length == 2) break;
    }
    return keywords.take(2).toList();
  }

  String _courseSummary(Course course) {
    final congestion = course.stops
        .map(
          (stop) => app.repository.congestion(stop.placeId, stop.arrival).value,
        )
        .toList();
    final average = congestion.isEmpty
        ? 0
        : congestion.reduce((a, b) => a + b) / congestion.length;
    final congestionText = average < 40
        ? '한산'
        : average < 70
        ? '보통'
        : '혼잡';
    final hours = course.totalMinutes ~/ 60;
    final minutes = course.totalMinutes % 60;
    final duration = hours == 0
        ? '약 ${minutes}분'
        : '약 ${hours}시간${minutes == 0 ? '' : ' ${minutes}분'}';
    return '$duration · ${course.distanceKm.toStringAsFixed(1)}km · 평균 $congestionText ${average.round()}%';
  }
}

void _showRecommendationScoreInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: const Color(0x2E1F1A2E),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 350,
        constraints: const BoxConstraints(minHeight: 166),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: label('추천에 반영한 조건', size: 14, bold: true)),
                IconButton(
                  tooltip: '닫기',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: OdigaTokens.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            label(
              '조건 30% · 혼잡도 25% · 거리 15%',
              size: 12,
              color: OdigaTokens.muted,
            ),
            const SizedBox(height: 4),
            label(
              '체류 10% · 특징 10% · 그룹 10%',
              size: 12,
              color: OdigaTokens.muted,
            ),
            const SizedBox(height: 8),
            label('입력한 조건과 장소 정보를 함께 반영해 코스를 추천해요.', size: 12, bold: true),
          ],
        ),
      ),
    ),
  );
}

void _showRecommendationReasonPopup(
  BuildContext context, {
  required AppState app,
  required Course course,
  required int rank,
  required bool group,
}) {
  final congestionValues = course.stops
      .map((s) => app.repository.congestion(s.placeId, s.arrival).value)
      .toList();
  final averageCongestion = congestionValues.isEmpty
      ? 0
      : congestionValues.reduce((a, b) => a + b) / congestionValues.length;
  final congestionLabel = averageCongestion < 40
      ? '한산'
      : averageCongestion < 70
      ? '보통'
      : '혼잡';
  final staySummary = course.stops
      .map((stop) {
        final category = app.repository.place(stop.placeId).category;
        return '$category ${stop.stayMinutes}분';
      })
      .join(' · ');
  final keyword = app.conditions.mood.isNotEmpty
      ? app.conditions.mood
      : app.preference.moods.isEmpty
      ? '추천 포인트'
      : app.preference.moods.first;
  final groupPreference = group
      ? '미연결 · 전체 평균 기준 적용'
      : app.preference.moods.isEmpty
      ? '저장된 취향 없음'
      : '${app.preference.moods.join(' · ')} 반영';

  showDialog<void>(
    context: context,
    barrierColor: const Color(0x660E0D15),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 350,
          maxHeight: MediaQuery.sizeOf(dialogContext).height - 32,
        ),
        child: SingleChildScrollView(
          child: RecommendationReasonPopup(
            state: rank == 1
                ? RecommendationReasonPopupState.firstRank
                : RecommendationReasonPopupState.keyword,
            rank: rank,
            courseTitle: course.title,
            keyword: keyword,
            conditionMatch:
                '${course.matchScore}% · ${app.conditions.region} · ${app.conditions.people}명 · ${clockText(app.conditions.start)}',
            congestion: '평균 ${averageCongestion.round()}% · $congestionLabel',
            distance: '${course.distanceKm.toStringAsFixed(1)}km · 도보 이동 중심',
            stay: staySummary,
            placeFeatures: course.reason.isEmpty
                ? '장소 특징 정보 없음'
                : course.reason,
            groupPreference: groupPreference,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    ),
  );
}

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({
    super.key,
    required this.app,
    required this.initial,
  });
  final AppState app;
  final Course initial;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: app,
    builder: (_, child) {
      final course =
          app.savedCourses.where((c) => c.id == initial.id).firstOrNull ??
          initial;
      return MapSheetFrame(
        app: app,
        title: '코스 상세 · ${course.stops.length}개 장소',
        course: course,
        children: [
          for (final stop in course.stops) ...[
            InkWell(
              onTap: () => openPage(
                context,
                PlaceDetailScreen(
                  app: app,
                  place: app.repository.place(stop.placeId),
                ),
                '/place/${stop.placeId}',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlaceImage(
                      image: AssetImage(
                        app.repository.place(stop.placeId).imageAsset,
                      ),
                      width: 36,
                      height: 36,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: stackItems([
                        label(
                          '${stop.order}. ${app.repository.place(stop.placeId).name}',
                          bold: true,
                        ),
                        label(
                          '${clockText(stop.arrival)} 방문 · ${stop.stayMinutes}분 체류',
                          size: 11,
                          color: OdigaTokens.muted,
                        ),
                      ], gap: 8),
                    ),
                    CongestionBadge(
                      level: level(
                        app.repository.congestion(stop.placeId, stop.arrival),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (stop.travelMinutesToNext > 0)
              CourseTravelDivider(label: '도보 ${stop.travelMinutesToNext}분'),
          ],
          CourseSummaryCard(
            summary: summary(course),
            detail: '방문 시간에 따라 예상 지역 혼잡도가 달라집니다.',
          ),
          Row(
            children: [
              Expanded(
                child: action('코스 저장', () {
                  app.saveCourse(course);
                  toast(context, '저장 코스에 반영했습니다.');
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: action(
                  '친구 공유',
                  () => _shareCourse(context, app, course),
                  secondary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: action(
                  '코스 수정',
                  () => openPage(
                    context,
                    CourseEditorScreen(app: app, initial: course),
                    '/course/edit',
                  ),
                  secondary: true,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

String courseText(AppState app, Course course) =>
    '${course.title}\n${summary(course)}\n${course.stops.map((s) => '${s.order}. ${app.repository.place(s.placeId).name} · ${clockText(s.arrival)} · ${s.stayMinutes}분').join('\n')}';

Future<void> _shareCourse(
  BuildContext context,
  AppState app,
  Course course,
) async {
  try {
    final share = await app.repository.api.createShare(course.id);
    if (!context.mounted) return;
    final sharedCourse = await app.repository.loadSharedCourse(share.shareCode);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('예시 코스 공유'),
        content: SingleChildScrollView(
          child: SelectableText(
            '현재는 고정된 예시 공유 결과입니다.\n\n${share.shareText}\n\n${share.shareUrl}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: '${share.shareText}\n${share.shareUrl}'),
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                toast(context, '코스 요약을 복사했습니다.');
              }
            },
            child: const Text('복사'),
          ),
          TextButton(
            onPressed: () {
              app.sendMessage(
                '함께 가고 싶은 코스예요! ${share.shareUrl}',
                course: sharedCourse,
              );
              Navigator.pop(dialogContext);
              openPage(context, ChatScreen(app: app), '/group/chat');
            },
            child: const Text('예시 모임에 공유'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openPage(
                context,
                CourseDetailScreen(app: app, initial: sharedCourse),
                '/share/${share.shareCode}',
              );
            },
            child: const Text('공유 코스 보기'),
          ),
        ],
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
  }
}

class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({
    super.key,
    required this.app,
    required this.initial,
  });
  final AppState app;
  final Course initial;
  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  bool saving = false;
  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final result = await widget.app.repository.updateCourse(draft);
      if (!mounted) return;
      widget.app.saveCourse(result.course);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('예시 코스 수정 결과'),
          content: Text(
            [
              '현재는 입력과 관계없이 고정된 예시 수정 결과를 반환합니다.',
              ...result.warnings.map((w) => w.message),
            ].join('\n\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (mounted) rootTab(context, widget.app, 1);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  late Course draft = widget.initial.copyWith();
  late final start =
      widget.initial.stops.firstOrNull?.arrival ?? widget.app.conditions.start;
  void update(List<CourseStop> stops) => setState(
    () => draft = widget.app.repository.recalculate(
      draft.copyWith(stops: stops),
      start: start,
    ),
  );
  Future<void> stay(CourseStop stop) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('체류시간 선택'),
        children: [
          for (final m in [30, 50, 60, 70, 90, 120])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Text('$m분'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (!mounted || minutes == null) return;
    update(
      draft.stops
          .map((s) => s.id == stop.id ? s.withStay(minutes) : s)
          .toList(),
    );
  }

  Future<void> add({CourseStop? replacing}) async {
    final place = await openPage<Place>(
      context,
      PlacePickerScreen(
        app: widget.app,
        region: draft.region,
        existing: draft.stops.map((s) => s.placeId).toSet(),
      ),
      '/course/place-picker',
    );
    if (!mounted || place == null) return;
    final stops = [...draft.stops];
    final stop = CourseStop(
      id: replacing?.id ?? 'stop-${DateTime.now().microsecondsSinceEpoch}',
      placeId: place.id,
      order: 1,
      arrival: start,
      stayMinutes: replacing?.stayMinutes ?? 45,
    );
    if (replacing == null) {
      stops.add(stop);
    } else {
      stops[stops.indexWhere((s) => s.id == replacing.id)] = stop;
    }
    update(stops);
  }

  @override
  Widget build(BuildContext context) => MapSheetFrame(
    app: widget.app,
    title: '코스 수정 · 동선 자동 계산',
    course: draft,
    initialSize: RecommendationSheetSize.expanded,
    children: [
      CourseSummaryCard(
        summary: summary(draft),
        detail: '변경하면 도착 시각·혼잡도 자동 재계산',
      ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: draft.stops.length,
        onReorderItem: (oldIndex, newIndex) {
          final stops = [...draft.stops];
          stops.insert(newIndex, stops.removeAt(oldIndex));
          update(stops);
        },
        itemBuilder: (_, index) {
          final stop = draft.stops[index];
          final p = widget.app.repository.place(stop.placeId);
          return Column(
            key: ValueKey(stop.id),
            children: [
              CourseStopTile(
                order: index + 1,
                title: p.name,
                visitLabel:
                    '${clockText(stop.arrival)} 방문 · ${level(widget.app.repository.congestion(p.id, stop.arrival)).label}',
                stayMinutes: stop.stayMinutes,
                onStayPressed: () => stay(stop),
                onDelete: () =>
                    update(draft.stops.where((s) => s.id != stop.id).toList()),
                reorderHandle: ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: '드래그하여 순서 변경',
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: label('≡', size: 18),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => add(replacing: stop),
                  child: const Text(
                    '다른 장소로 교체',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              if (stop.travelMinutesToNext > 0)
                CourseTravelDivider(label: '도보 ${stop.travelMinutesToNext}분'),
            ],
          );
        },
      ),
      if (draft.stops.isEmpty) panel([label('장소를 추가해 코스를 만들어보세요.')]),
      action('+ 장소 추가', add, secondary: true),
      action(
        saving ? '저장 중…' : '수정한 코스 저장',
        draft.stops.isEmpty || saving ? null : save,
      ),
      label('동선은 좌표 기반 임시 도보 추정입니다.', size: 11, color: OdigaTokens.muted),
    ],
  );
}

class SavedCoursesScreen extends StatefulWidget {
  const SavedCoursesScreen({super.key, required this.app});
  final AppState app;
  @override
  State<SavedCoursesScreen> createState() => _SavedCoursesScreenState();
}

class _SavedCoursesScreenState extends State<SavedCoursesScreen> {
  String region = '전체';
  @override
  Widget build(BuildContext context) {
    final courses = widget.app.savedCourses
        .where((c) => region == '전체' || c.region == region)
        .toList();
    return AppFrame(
      app: widget.app,
      title: '저장 코스',
      subtitle: '다시 가고 싶은 하루를 모아두었어요',
      showBack: false,
      child: stackItems([
        OdigaCategoryFilter(
          selected: region,
          categories: const ['전체', '성수', '홍대'],
          onChanged: (v) => setState(() => region = v),
        ),
        for (final c in courses)
          stackItems([
            CourseCard(
              title: c.title,
              route: c.stops
                  .map((s) => widget.app.repository.place(s.placeId).category)
                  .join(' → '),
              summary: summary(c),
              reason: '저장한 코스 · 상세보기 ›',
              congestion: '방문 시간별 지역 혼잡도 확인',
              onTap: () => openPage(
                context,
                CourseDetailScreen(app: widget.app, initial: c),
                '/course/${c.id}',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.app.deleteCourse(c.id),
                child: const Text('저장 해제'),
              ),
            ),
          ], gap: 0),
        if (courses.isEmpty)
          panel([
            label('저장한 코스가 없습니다.'),
            action(
              '새 코스 찾아보기',
              () => rootTab(context, widget.app, 0),
              secondary: true,
            ),
          ]),
      ]),
    );
  }
}
