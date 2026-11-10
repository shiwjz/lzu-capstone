part of 'app_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.app});
  final AppState app;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final query = TextEditingController();
  bool _categoriesApplied = false;

  Future<void> openCategorySettings() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      barrierColor: const Color(0x47000000),
      builder: (_) => HomeCategorySettingsDialog(app: widget.app),
    );
    if (!mounted || selected == null) return;
    setState(() => _categoriesApplied = true);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void search() {
    final text = query.text.trim();
    if (text.isEmpty) {
      toast(context, searchInputMessage);
      return;
    }
    final conditions = SearchConditions(query: text, useSelectedRegion: false);
    openPage(
      context,
      RecommendationsScreen(app: widget.app, initialConditions: conditions),
      '/recommendations',
    );
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    showBack: false,
    mapBackground: true,
    scroll: false,
    child: PrototypeMap(
      app: widget.app,
      home: true,
      homeCategories: _categoriesApplied
          ? widget.app.preference.categories
          : null,
      homeInfo: () => _showRecommendationScoreInfo(context),
      homeSearch: Row(
        children: [
          Expanded(
            child: OdigaSearchField(
              controller: query,
              hint: '지금 내 주변에서 가고 싶은 곳은?',
              onSubmitted: (_) => search(),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '추천 검색',
            child: Material(
              color: OdigaTokens.brand,
              borderRadius: BorderRadius.circular(14),
              elevation: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: search,
                child: const SizedBox(
                  width: 52,
                  height: 54,
                  child: Center(
                    child: Icon(Icons.search, color: Colors.white, size: 25),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '카테고리 설정',
            child: Material(
              color: OdigaTokens.brand,
              borderRadius: BorderRadius.circular(14),
              elevation: 3,
              shadowColor: const Color(0x33292933),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: openCategorySettings,
                child: const SizedBox(
                  width: 54,
                  height: 54,
                  child: Icon(Icons.menu, color: Colors.white, size: 27),
                ),
              ),
            ),
          ),
        ],
      ),
      onPlace: (p) => openPage(
        context,
        NearbyScreen(app: widget.app, initial: p),
        '/nearby/${p.id}',
      ),
    ),
  );
}

class HomeCategorySettingsDialog extends StatefulWidget {
  const HomeCategorySettingsDialog({super.key, required this.app});
  final AppState app;

  @override
  State<HomeCategorySettingsDialog> createState() =>
      _HomeCategorySettingsDialogState();
}

class _HomeCategorySettingsDialogState
    extends State<HomeCategorySettingsDialog> {
  static const _categoryOptions = [
    (label: '음식점', value: '음식점', width: 59.0),
    (label: '카페', value: '카페', width: 48.0),
    (label: '놀거리', value: '놀거리', width: 126.0),
    (label: '문화시설', value: '문화시설', width: 74.0),
  ];

  late final _preferences = widget.app.preference.copy();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('카테고리 선택'),
    content: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in _categoryOptions)
          OdigaTag(
            label: option.label,
            selected: _preferences.categories.contains(option.value),
            onSelected: (selected) => setState(() {
              if (selected) {
                _preferences.categories.add(option.value);
              } else {
                _preferences.categories.remove(option.value);
              }
            }),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
      FilledButton(
        onPressed: () {
          widget.app.setPreference(_preferences);
          Navigator.pop(context, _preferences.categories);
        },
        child: const Text('적용'),
      ),
    ],
  );
}

enum CourseFrame {
  mealCafePlay('식사 → 카페 → 놀거리', ['식사', '카페', '놀거리']),
  cafePlayMeal('카페 → 놀거리 → 식사', ['카페', '놀거리', '식사']),
  mealCafe('식사 → 카페', ['식사', '카페']),
  cafePlay('카페 → 놀거리', ['카페', '놀거리']),
  mealPlay('식사 → 놀거리', ['식사', '놀거리']);

  const CourseFrame(this.label, this.slots);
  final String label;
  final List<String> slots;

  bool matches(Iterable<Place> places) {
    var matched = 0;
    for (final place in places) {
      final slot = switch (place.category) {
        '음식점' => '식사',
        '카페' => '카페',
        _ => '놀거리',
      };
      if (slot != slots[matched]) continue;
      matched++;
      if (matched == slots.length) return true;
    }
    return false;
  }
}

class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({
    super.key,
    required this.app,
    required this.initialConditions,
    this.initialFrame,
  });
  final AppState app;
  final SearchConditions initialConditions;
  final CourseFrame? initialFrame;
  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  late final draft = widget.initialConditions.copy();
  late CourseFrame? frame = widget.initialFrame;
  late final query = TextEditingController(text: draft.query);
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: draft.start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(draft.start),
    );
    if (!mounted) return;
    setState(
      () => draft.start = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? draft.start.hour,
        time?.minute ?? draft.start.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    title: '검색 조건',
    showBottomNavigation: false,
    subtitle: '추천 조건을 수정할 수 있어요',
    child: stackItems([
      OdigaSearchField(controller: query, hint: '성수에서 조용한 카페 갔다가 저녁 먹을래'),
      panel([
        label('코스 틀', bold: true),
        label('이 순서로 방문하는 코스만 보여줘요.', size: 11),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in CourseFrame.values)
              OdigaTag(
                label: option.label,
                selected: frame == option,
                onSelected: (selected) => setState(() {
                  frame = selected ? option : null;
                }),
              ),
          ],
        ),
      ]),
      panel([
        label('✧ 추천 조건 · 수정 가능', bold: true),
        DropdownButtonFormField<String>(
          initialValue: draft.region,
          decoration: const InputDecoration(labelText: '지역'),
          items: supportedCongestionRegions
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => draft.region = v!),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: label('방문 날짜 · 시간'),
          subtitle: label(
            '${dateText(draft.start)} ${clockText(draft.start)}',
            color: OdigaTokens.brand,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: pickDate,
        ),
        DropdownButtonFormField<int>(
          initialValue: draft.people,
          decoration: const InputDecoration(labelText: '동행 인원'),
          items: List.generate(
            12,
            (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}명')),
          ),
          onChanged: (v) => setState(() => draft.people = v!),
        ),
        label('분위기', bold: true),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ['조용한', '활기찬', '감성적인', '가성비좋은', '넓고편한', '뷰좋은']
              .map(
                (v) => OdigaTag(
                  label: v,
                  selected: draft.mood == v,
                  onSelected: (_) => setState(() => draft.mood = v),
                ),
              )
              .toList(),
        ),
        label('지원 지역은 성수·홍대·강남이에요.', size: 11, color: OdigaTokens.muted),
      ]),
      action('수정 조건으로 바로 추천', () {
        draft.query = query.text.trim();
        draft.useSelectedRegion = true;
        Navigator.pop(context, (conditions: draft, frame: frame));
      }),
    ]),
  );
}

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.app, required this.initial});
  final AppState app;
  final Place initial;
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  late Place selected = widget.initial;
  String category = '전체';
  @override
  Widget build(BuildContext context) {
    final places = widget.app.repository.places
        .where(
          (p) =>
              p.region == selected.region &&
              (category == '전체' || p.category == category),
        )
        .toList();
    return MapSheetFrame(
      app: widget.app,
      title: '내 주변 장소',
      places: places,
      onPin: (p) => setState(() => selected = p),
      children: [
        OdigaCategoryFilter(
          selected: category,
          onChanged: (v) => setState(() => category = v),
        ),
        for (final p in places)
          PlaceCardView(
            app: widget.app,
            place: p,
            showCongestion: false,
            onTap: () => openPage(
              context,
              PlaceDetailScreen(app: widget.app, place: p),
              '/place/${p.id}',
            ),
          ),
        if (places.isEmpty) label('이 카테고리의 예시 장소가 없습니다.'),
        action(
          '${selected.name} 상세보기',
          () => openPage(
            context,
            PlaceDetailScreen(app: widget.app, place: selected),
            '/place/${selected.id}',
          ),
        ),
      ],
    );
  }
}

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({
    super.key,
    required this.app,
    required this.place,
    this.arrival,
  });
  final AppState app;
  final Place place;
  final DateTime? arrival;
  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final visit = widget.arrival ?? widget.app.conditions.start;
  late int selectedDay = visit.weekday;
  late var detail = loadDay(visit);
  final graphs = <bool, Future<({Place place, Map<int, Congestion> hours})>>{};

  Future<({Place place, Map<int, Congestion> hours})> loadDay(DateTime day) =>
      graphs.putIfAbsent(
        day.weekday >= DateTime.saturday,
        () => widget.app.repository.loadPlaceDetails(widget.place.id, day),
      );

  DateTime get graphDate => DateTime(
    visit.year,
    visit.month,
    visit.day + selectedDay - visit.weekday,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: detail,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppFrame(
          app: widget.app,
          title: '장소 상세',
          child: Column(
            children: [
              Text(apiFailureMessage(snapshot.error)),
              TextButton(
                onPressed: () => setState(() {
                  graphs.remove(visit.weekday >= DateTime.saturday);
                  detail = loadDay(visit);
                }),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return AppFrame(
          app: widget.app,
          title: '장소 상세',
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return AnimatedBuilder(
        animation: widget.app,
        builder: (_, child) {
          final p = snapshot.data!.place;
          return AppFrame(
            app: widget.app,
            title: p.name,
            subtitle: p.category,
            child: stackItems([
              label(
                p.address?.trim().isNotEmpty == true ? p.address! : '주소 정보 없음',
                size: 13,
              ),
              label(p.openingHours, size: 11, color: OdigaTokens.muted),
              if (supportedCongestionRegions.contains(p.region))
                panel([
                  label('주변 혼잡도', size: 18, bold: true),
                  label(
                    widget.app.repository.usesSampleData
                        ? 'LG 유동인구 기반 추정 · 예시 데이터'
                        : 'LG 유동인구 기반 추정',
                    size: 11,
                    color: OdigaTokens.muted,
                  ),
                  Row(
                    children: [
                      for (final (index, day) in [
                        '월',
                        '화',
                        '수',
                        '목',
                        '금',
                        '토',
                        '일',
                      ].indexed)
                        Expanded(
                          child: Semantics(
                            selected: selectedDay == index + 1,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: selectedDay == index + 1
                                    ? OdigaTokens.lavender
                                    : null,
                              ),
                              onPressed: () =>
                                  setState(() => selectedDay = index + 1),
                              child: Text(day),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label(
                    '도착 예정 · ${clockText(visit)}',
                    size: 12,
                    color: OdigaTokens.brand,
                  ),
                  FutureBuilder(
                    future: loadDay(graphDate),
                    builder: (context, graph) {
                      if (graph.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (graph.hasError) {
                        return TextButton(
                          onPressed: () => setState(() {
                            graphs.remove(
                              graphDate.weekday >= DateTime.saturday,
                            );
                          }),
                          child: const Text('혼잡도 다시 불러오기'),
                        );
                      }
                      final hours = graph.data!.hours;
                      if (hours.isEmpty) {
                        return label('시간대별 혼잡도 정보가 없어요.', size: 12);
                      }
                      return _HourlyCongestionChart(
                        key: ValueKey(selectedDay),
                        hours: hours,
                        arrivalHour: visit.hour,
                      );
                    },
                  ),
                ]),
              action('카카오맵 길찾기', () => openDirections(context, [p])),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: p.tags
                    .map((t) => OdigaTag(label: '#$t', selected: true))
                    .toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: action(
                      widget.app.savedPlaceIds.contains(p.id) ? '저장됨' : '저장하기',
                      () => widget.app.togglePlace(p.id),
                      secondary: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: action('코스에 추가', () {
                      final course = widget.app.repository.recalculate(
                        Course(
                          id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                          title: '${p.region} 나만의 코스',
                          region: p.region,
                          stops: [
                            CourseStop(
                              id: 'custom-stop',
                              placeId: p.id,
                              order: 1,
                              arrival: visit,
                              stayMinutes: 50,
                            ),
                          ],
                        ),
                      );
                      openPage(
                        context,
                        CourseEditorScreen(app: widget.app, initial: course),
                        '/course/edit',
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: action(
                      '지도 보기',
                      () => openPage(
                        context,
                        NearbyScreen(app: widget.app, initial: p),
                        '/nearby/${p.id}',
                      ),
                      secondary: true,
                    ),
                  ),
                ],
              ),
            ]),
          );
        },
      );
    },
  );
}

class _HourlyCongestionChart extends StatefulWidget {
  const _HourlyCongestionChart({
    super.key,
    required this.hours,
    required this.arrivalHour,
  });
  final Map<int, Congestion> hours;
  final int arrivalHour;

  @override
  State<_HourlyCongestionChart> createState() => _HourlyCongestionChartState();
}

class _HourlyCongestionChartState extends State<_HourlyCongestionChart> {
  static const barWidth = 42.0;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final offset =
          (widget.arrivalHour - 9) * barWidth -
          (scroll.position.viewportDimension - barWidth) / 2;
      scroll.jumpTo(offset.clamp(0.0, scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: scroll,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var hour = 9; hour <= 23; hour++) _bar(hour, widget.hours[hour]),
        ],
      ),
    ),
  );

  Widget _bar(int hour, Congestion? data) {
    final arrival = hour == widget.arrivalHour;
    final status = switch (data?.band) {
      CongestionBand.quiet => '한산',
      CongestionBand.moderate => '보통',
      CongestionBand.busy => '붐빔',
      null => '—',
    };
    final color = switch (data?.band) {
      CongestionBand.quiet => const Color(0xFF188653),
      CongestionBand.moderate => const Color(0xFFDB790C),
      CongestionBand.busy => const Color(0xFFCF3543),
      null => OdigaTokens.muted,
    };
    return Semantics(
      label: '$hour시 $status${arrival ? ' 도착 예정' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        width: barWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            label(status, size: 11, bold: arrival),
            const SizedBox(height: 4),
            Container(
              width: 22,
              height: (data?.percentile ?? 0).clamp(0, 100) * .9 + 4,
              decoration: BoxDecoration(
                color: color.withValues(alpha: arrival ? 1 : .44),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 4),
            label('$hour시', size: 11, bold: arrival),
          ],
        ),
      ),
    );
  }
}

class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({
    super.key,
    required this.app,
    required this.region,
    required this.existing,
  });
  final AppState app;
  final String region;
  final Set<String> existing;
  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  String category = '전체';
  @override
  Widget build(BuildContext context) {
    final places = widget.app.repository.places
        .where(
          (p) =>
              p.region == widget.region &&
              !widget.existing.contains(p.id) &&
              (category == '전체' || p.category == category),
        )
        .toList();
    return AppFrame(
      app: widget.app,
      title: '코스에 장소 추가',
      subtitle: '선택한 장소를 코스에 반영합니다.',
      child: stackItems([
        OdigaCategoryFilter(
          selected: category,
          onChanged: (v) => setState(() => category = v),
        ),
        for (final p in places)
          stackItems([
            PlaceCardView(
              app: widget.app,
              place: p,
              onTap: () => Navigator.pop(context, p),
            ),
            action(
              '이 장소 선택 · ${p.name}',
              () => Navigator.pop(context, p),
              secondary: true,
            ),
          ], gap: 6),
        if (places.isEmpty) label('추가할 수 있는 장소가 없습니다. 다른 카테고리를 선택하세요.'),
      ]),
    );
  }
}

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key, required this.app});
  final AppState app;
  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  String category = '전체';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.app,
    builder: (_, child) {
      final places = widget.app.repository.places
          .where(
            (p) =>
                widget.app.savedPlaceIds.contains(p.id) &&
                (category == '전체' || p.category == category),
          )
          .toList();
      return AppFrame(
        app: widget.app,
        title: '저장한 장소',
        subtitle: '취향에 맞았던 곳을 다시 만나세요',
        child: stackItems([
          OdigaCategoryFilter(
            selected: category,
            onChanged: (v) => setState(() => category = v),
          ),
          for (final p in places)
            PlaceCardView(
              app: widget.app,
              place: p,
              onTap: () => openPage(
                context,
                PlaceDetailScreen(app: widget.app, place: p),
                '/place/${p.id}',
              ),
            ),
          if (places.isEmpty)
            panel([
              label('저장한 장소가 없습니다.'),
              label('장소 상세에서 저장 버튼을 눌러보세요.', size: 11),
            ]),
        ]),
      );
    },
  );
}
