part of 'app_screens.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({
    super.key,
    required this.app,
    this.group = false,
    this.expanded = false,
    this.initialConditions,
  });
  final AppState app;
  final bool group, expanded;
  final SearchConditions? initialConditions;
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  AppState get app => widget.app;
  late SearchConditions conditions =
      (widget.initialConditions ?? app.conditions).copy();
  late var request = app.repository.recommendResult(conditions, app.preference);
  CourseFrame? frame;
  final kept = <String>{};
  Set<String> requiredPlaces = {};
  int selectedIndex = 0;

  void refresh() {
    selectedIndex = 0;
    request = app.repository.recommendResult(conditions, app.preference);
  }

  Future<void> editConditions(SearchConditions resolved) async {
    final edited =
        await openPage<({SearchConditions conditions, CourseFrame? frame})>(
          context,
          ConditionsScreen(
            app: app,
            initialConditions: resolved,
            initialFrame: frame,
          ),
          '/conditions',
        );
    if (!mounted || edited == null) return;
    setState(() {
      conditions = edited.conditions;
      frame = edited.frame;
      refresh();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: request,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return AppFrame(
          app: app,
          title: '추천 코스',
          showBottomNavigation: false,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        final code = error is ApiException ? error.code : null;
        return AppFrame(
          app: app,
          title: '추천 코스',
          showBottomNavigation: false,
          child: stackItems([
            label(apiFailureMessage(error)),
            if (code == 'CONDITION_MISSING')
              action('검색으로 돌아가기', () => Navigator.maybePop(context))
            else
              action('다시 시도', () => setState(refresh)),
          ]),
        );
      }

      final result = snapshot.data!;
      final courses = result.courses.where((course) {
        final ids = course.stops.map((stop) => stop.placeId).toSet();
        return ids.containsAll(requiredPlaces) &&
            (frame?.matches(ids.map(app.repository.place)) ?? true);
      }).toList();
      final selectedCourse = courses.elementAtOrNull(selectedIndex);
      return MapSheetFrame(
        app: app,
        showBottomNavigation: false,
        title:
            '추천 ${courses.length}개 · ${visitConditionText(result.conditions)}',
        sheetTitle: '추천 코스',
        course: selectedCourse,
        initialSize: widget.expanded
            ? RecommendationSheetSize.expanded
            : RecommendationSheetSize.medium,
        onConditions: () => editConditions(result.conditions),
        children: [
          if (kept.isNotEmpty)
            panel([
              label('📌 킵 ${kept.length}곳', bold: true),
              Wrap(
                spacing: 6,
                children: [
                  for (final id in kept)
                    InputChip(
                      label: Text(app.repository.place(id).name),
                      onDeleted: () => setState(() => kept.remove(id)),
                    ),
                ],
              ),
              action('이 장소로 다시 찾기', () {
                setState(() {
                  requiredPlaces = {...kept};
                  refresh();
                });
              }),
            ]),
          if (requiredPlaces.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                requiredPlaces = {};
                selectedIndex = 0;
              }),
              child: const Text('킵 필터 해제'),
            ),
          if (courses.isEmpty)
            label(
              requiredPlaces.isNotEmpty
                  ? '킵한 장소를 모두 포함하는 코스가 없어요.'
                  : '선택한 조건에 맞는 코스가 없어요.',
            ),
          for (final (index, course) in courses.indexed)
            RankedCourseCard(
              rank: index + 1,
              title: course.title,
              summary: coursePlaceNames(app, course),
              route: courseRoute(app, course),
              reason: course.reason,
              keywords: course.keywords,
              selected: index == selectedIndex,
              onSelected: () {
                setState(() => selectedIndex = index);
                openPage(
                  context,
                  CourseDetailScreen(app: app, initial: course),
                  '/course/${course.id}',
                );
              },
              onMap: () => setState(() => selectedIndex = index),
              onReason: () => _showRecommendationReasonPopup(
                context,
                app: app,
                course: course,
                rank: index + 1,
                group: widget.group,
              ),
            ),
          if (selectedCourse != null) ...[
            label('선택한 코스의 장소', bold: true),
            for (final stop in selectedCourse.stops)
              PlaceCardView(
                app: app,
                place: app.repository.place(stop.placeId),
                visit: stop.arrival,
                kept: kept.contains(stop.placeId),
                onKeep: () => setState(() {
                  if (!kept.remove(stop.placeId)) kept.add(stop.placeId);
                }),
                onTap: () => openCourseStop(context, app, stop),
              ),
          ],
        ],
      );
    },
  );
}

String coursePlaceNames(AppState app, Course course) => course.stops
    .take(3)
    .map((stop) => stop.name ?? app.repository.place(stop.placeId).name)
    .join(' · ');

List<String> courseRoute(AppState app, Course course) => course.stops
    .map((stop) => app.repository.place(stop.placeId).category)
    .toList();

void openCourseStop(BuildContext context, AppState app, CourseStop stop) {
  openPage(
    context,
    PlaceDetailScreen(
      app: app,
      place: app.repository.place(stop.placeId),
      arrival: stop.arrival,
    ),
    '/place/${stop.placeId}',
  );
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
              '장소 점수: 요청 적합도 0.45 · 타깃 특성 0.30 · 혼잡도 0.25',
              size: 12,
              color: OdigaTokens.muted,
            ),
            const SizedBox(height: 4),
            label(
              '코스 점수: 장소 평균 0.70 · 이동 효율 0.20 · 시간 적합도 0.10',
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
  final selectedConditions = <String>[
    if (app.conditions.mood.isNotEmpty) app.conditions.mood,
    if (app.conditions.gender != '무관') app.conditions.gender,
    if (app.conditions.ageGroup != '무관') app.conditions.ageGroup,
    app.conditions.companionType,
    '${app.conditions.people}명',
    if (app.preference.categories.isNotEmpty)
      app.preference.categories.join('·'),
    if (app.preference.cuisines.isNotEmpty) app.preference.cuisines.join('·'),
    if (app.preference.cuisineDetails.isNotEmpty)
      app.preference.cuisineDetails.join('·'),
    if (app.preference.dislikedFood.trim().isNotEmpty)
      '제외 ${app.preference.dislikedFood.trim()}',
    if (app.preference.allergies.trim().isNotEmpty)
      '알레르기 ${app.preference.allergies.trim()}',
  ];
  final groupPreference = [
    ...selectedConditions,
    if (group) '그룹 평균 기준',
  ].join(' · ');

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
                '총점 ${(course.score['total'] ?? course.matchScore / 100).toStringAsFixed(2)} · 장소 ${(course.score['placeAvg'] ?? 0).toStringAsFixed(2)} · 이동 ${(course.score['moveEfficiency'] ?? 0).toStringAsFixed(2)} · 시간 ${(course.score['timeFit'] ?? 0).toStringAsFixed(2)}',
            congestion: course.reason,
            distance: '${course.distanceKm.toStringAsFixed(1)}km · 도보 이동 중심',
            stay: staySummary,
            placeFeatures: course.keywords.join(' · '),
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
        title: course.title,
        sheetTitle: '코스 상세 · ${course.stops.length}개 장소',
        course: course,
        children: [
          RouteTags(categories: courseRoute(app, course)),
          for (final (index, stop) in course.stops.indexed) ...[
            InkWell(
              onTap: () => openCourseStop(context, app, stop),
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
                          '${index + 1}. ${app.repository.place(stop.placeId).name}',
                          bold: true,
                        ),
                        label(
                          '${clockText(stop.arrival)} 방문 · ${stop.stayMinutes}분 체류',
                          size: 11,
                          color: OdigaTokens.muted,
                        ),
                      ], gap: 8),
                    ),
                    if (placeCongestion(
                          app,
                          app.repository.place(stop.placeId),
                          stop.arrival,
                        )
                        case final crowd?)
                      CongestionBadge(level: crowd),
                  ],
                ),
              ),
            ),
            if (stop.travelMinutesToNext > 0)
              CourseTravelDivider(label: '도보 ${stop.travelMinutesToNext}분'),
          ],
          CourseSummaryCard(summary: summary(course), detail: '직선 거리 기준'),
          if (course.stops.isNotEmpty)
            action(
              '카카오맵 길찾기',
              () => openDirections(context, [
                for (final stop in course.stops)
                  app.repository.place(stop.placeId),
              ]),
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
    '${course.title}\n${summary(course)}\n${course.stops.indexed.map((entry) => '${entry.$1 + 1}. ${app.repository.place(entry.$2.placeId).name} · ${clockText(entry.$2.arrival)} · ${entry.$2.stayMinutes}분').join('\n')}';

void _shareCourse(BuildContext context, AppState app, Course course) {
  openPage(
    context,
    CourseShareScreen(app: app, course: course),
    '/course/${course.id}/share',
  );
}

class CourseShareScreen extends StatefulWidget {
  const CourseShareScreen({super.key, required this.app, required this.course});
  final AppState app;
  final Course course;
  @override
  State<CourseShareScreen> createState() => _CourseShareScreenState();
}

class _CourseShareScreenState extends State<CourseShareScreen> {
  late Future<ShareCreateDto> share = widget.app.repository.api.createShare(
    widget.course.id,
  );

  Future<void> openSharedCourse(ShareCreateDto value) async {
    try {
      final course = await widget.app.repository.loadSharedCourse(
        value.shareCode,
      );
      if (!mounted) return;
      openPage(
        context,
        CourseDetailScreen(app: widget.app, initial: course),
        '/share/${value.shareCode}',
      );
    } on ApiException catch (error) {
      if (mounted) toast(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ShareCreateDto>(
    future: share,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppFrame(
          app: widget.app,
          title: '코스 공유',
          child: stackItems([
            label('공유 링크를 만들지 못했어요.'),
            action(
              '다시 시도',
              () => setState(
                () => share = widget.app.repository.api.createShare(
                  widget.course.id,
                ),
              ),
            ),
          ]),
        );
      }
      if (!snapshot.hasData) {
        return AppFrame(
          app: widget.app,
          title: '코스 공유',
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      final value = snapshot.data!;
      return AppFrame(
        app: widget.app,
        title: '코스 공유',
        subtitle: '친구에게 이 코스를 보내보세요',
        child: stackItems([
          panel([
            label(widget.course.title, size: 18, bold: true),
            label(summary(widget.course), color: OdigaTokens.brand),
            SelectableText(value.shareText),
          ], lavender: true),
          panel([label('공유 링크', bold: true), SelectableText(value.shareUrl)]),
          action('링크와 코스 설명 복사', () async {
            await Clipboard.setData(
              ClipboardData(text: '${value.shareText}\n${value.shareUrl}'),
            );
            if (context.mounted) toast(context, '공유 내용을 복사했습니다.');
          }),
          action('공유 코스 미리 보기', () => openSharedCourse(value), secondary: true),
          action('예시 모임 채팅에 공유', () async {
            final course = await widget.app.repository.loadSharedCourse(
              value.shareCode,
            );
            if (!context.mounted) return;
            widget.app.sendMessage(
              '함께 가고 싶은 코스예요! ${value.shareUrl}',
              course: course,
            );
            openPage(context, ChatScreen(app: widget.app), '/group/chat');
          }, secondary: true),
          label('현재는 예시 공유 응답을 표시합니다.', size: 11, color: OdigaTokens.muted),
        ]),
      );
    },
  );
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
          title: const Text('코스 수정 안내'),
          content: Text(result.warnings.map((w) => w.message).join(' · ')),
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
      if (draft.totalMinutes > 210)
        label(
          '총 ${draft.totalMinutes}분으로 3시간 30분을 넘어요.',
          color: OdigaTokens.red,
          bold: true,
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
          final crowd = placeCongestion(widget.app, p, stop.arrival);
          return Column(
            key: ValueKey(stop.id),
            children: [
              CourseStopTile(
                order: index + 1,
                title: p.name,
                visitLabel: [
                  '${clockText(stop.arrival)} 방문',
                  if (crowd != null) crowd.label,
                ].join(' · '),
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
          categories: const ['전체', ...supportedCongestionRegions],
          onChanged: (v) => setState(() => region = v),
        ),
        for (final c in courses)
          stackItems([
            CourseCard(
              title: c.title,
              route: courseRoute(widget.app, c).join(' → '),
              places: coursePlaceNames(widget.app, c),
              keywords: c.keywords,
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
