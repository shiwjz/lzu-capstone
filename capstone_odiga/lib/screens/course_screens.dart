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
          return MapSheetFrame(
            app: app,
            title: courses.isEmpty
                ? '추천 결과 없음'
                : '추천 ${courses.length}개 · ${courses.first.title}',
            course: courses.isEmpty ? null : courses.first,
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
                  summary: summary(courses[i]),
                  reason: courses[i].reason,
                  selected: i == 0,
                  onReason: () => openPage(
                    context,
                    ReasonScreen(
                      app: app,
                      course: courses[i],
                      rank: i + 1,
                      group: group,
                    ),
                    '/recommendation/reason/${i + 1}',
                  ),
                  onDetails: () => openPage(
                    context,
                    CourseDetailScreen(app: app, initial: courses[i]),
                    '/course/${courses[i].id}',
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
}

class ReasonScreen extends StatelessWidget {
  const ReasonScreen({
    super.key,
    required this.app,
    required this.course,
    required this.rank,
    this.group = false,
  });
  final AppState app;
  final Course course;
  final int rank;
  final bool group;
  @override
  Widget build(BuildContext context) {
    final values = course.stops.map(
      (s) => app.repository.congestion(s.placeId, s.arrival).value,
    );
    final average = values.isEmpty
        ? 0
        : values.reduce((a, b) => a + b) / values.length;
    return MapSheetFrame(
      app: app,
      title: group ? '그룹 추천 근거' : '추천 근거',
      course: course,
      initialSize: RecommendationSheetSize.expanded,
      children: [
        RecommendationRankHeader(rank: rank),
        RecommendationReasonRow(
          label: '코스 종합 점수',
          value: '${course.matchScore}% · 예시 추천 점수',
        ),
        RecommendationReasonRow(
          label: '예시 지역 혼잡도',
          value: '평균 백분위 ${average.round()}',
        ),
        RecommendationReasonRow(
          label: '이동거리',
          value: '${course.distanceKm.toStringAsFixed(1)}km · 예시 도보 추정',
        ),
        RecommendationReasonRow(
          label: '체류시간',
          value: course.stops.map((s) => '${s.stayMinutes}분').join(' · '),
        ),
        RecommendationReasonRow(label: '장소 특징', value: course.reason),
        RecommendationReasonRow(
          label: '그룹 선호도',
          value: '지역별 고정 샘플 · 취향 변경은 결과에 반영되지 않아요',
        ),
        panel([
          label('추천에 반영한 조건', bold: true),
          label('장소 평균 점수 70% · 이동 효율 20% · 시간 적합도 10%', size: 11),
          label(
            '점수는 API 명세의 계산 기준을 따르는 예시입니다.',
            size: 11,
            color: OdigaTokens.muted,
          ),
        ]),
        action(
          '코스 상세',
          () => openPage(
            context,
            CourseDetailScreen(app: app, initial: course),
            '/course/${course.id}',
          ),
        ),
      ],
    );
  }
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
