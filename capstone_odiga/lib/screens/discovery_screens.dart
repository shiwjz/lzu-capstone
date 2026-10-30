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
    query.text = widget.app.conditions.query;
    setState(() => _categoriesApplied = true);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void search() {
    final conditions = widget.app.conditions.copy()
      ..query = query.text.trim()
      ..useSelectedRegion = false;
    if (conditions.query.contains('홍대') || conditions.query.contains('연남')) {
      conditions.region = '홍대';
    }
    if (conditions.query.contains('성수') || conditions.query.contains('서울숲')) {
      conditions.region = '성수';
    }
    if (conditions.query.contains('강남')) conditions.region = '강남';
    final people = RegExp(r'(\d+)명').firstMatch(conditions.query);
    if (people != null) conditions.people = int.parse(people[1]!).clamp(1, 12);
    if (conditions.query.contains('저녁')) {
      conditions.start = DateTime(
        conditions.start.year,
        conditions.start.month,
        conditions.start.day,
        18,
      );
    }
    if (conditions.query.contains('조용')) conditions.mood = '조용한';
    widget.app.setConditions(conditions);
    openPage(
      context,
      RecommendationsScreen(app: widget.app),
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
    (label: '놀거리 / 놀이시설', value: '놀거리', width: 126.0),
    (label: '문화시설', value: '문화시설', width: 74.0),
  ];
  static const _moods = ['조용한', '활기찬', '감성적인', '사진', '데이트', '친구 모임'];

  late final _preferences = widget.app.preference.copy();
  late final _conditions = widget.app.conditions.copy();

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_conditions.start),
    );
    if (time == null || !mounted) return;
    setState(() {
      _conditions.start = DateTime(
        _conditions.start.year,
        _conditions.start.month,
        _conditions.start.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _editExcludedPlace() async {
    final value = await editText(
      context,
      '제외 장소',
      initial: _conditions.excluded,
    );
    if (value != null && mounted) setState(() => _conditions.excluded = value);
  }

  Future<void> _editDislikedFood() async {
    final value = await editText(
      context,
      '제외 음식',
      initial: _preferences.dislikedFood,
    );
    if (value != null && mounted) {
      setState(() => _preferences.dislikedFood = value);
    }
  }

  Future<void> _pickPeople() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('동행 인원'),
        children: List.generate(
          12,
          (index) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, index + 1),
            child: Text('${index + 1}명'),
          ),
        ),
      ),
    );
    if (value != null && mounted) setState(() => _conditions.people = value);
  }

  Future<void> _pickMood() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('분위기'),
        children: _moods
            .map(
              (mood) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, mood),
                child: Text(mood),
              ),
            )
            .toList(),
      ),
    );
    if (value != null && mounted) setState(() => _conditions.mood = value);
  }

  Future<void> _editOtherCondition() async {
    final value = await editText(context, '기타 조건', initial: _conditions.query);
    if (value != null && mounted) setState(() => _conditions.query = value);
  }

  Widget _conditionRow(String title, String value, {VoidCallback? onTap}) =>
      Material(
        color: OdigaTokens.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: OdigaTokens.text(11))),
                  Text(
                    value,
                    style: OdigaTokens.text(11, color: OdigaTokens.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: OdigaTokens.muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: Container(
      width: 350,
      height: 306,
      padding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(child: label('조건 · 카테고리', size: 14, bold: true)),
                IconButton(
                  tooltip: '닫기',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: OdigaTokens.brand,
                  ),
                ),
              ],
            ),
          ),
          label(
            '모두 선택 가능 · 조건은 입력하지 않아도 돼요.',
            size: 11,
            color: OdigaTokens.muted,
          ),
          const SizedBox(height: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in _categoryOptions) ...[
                  if (option != _categoryOptions.first)
                    const SizedBox(width: 5),
                  OdigaTag(
                    label: option.label,
                    width: option.width,
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
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _conditionRow('성별', '미입력'),
                const SizedBox(height: 4),
                _conditionRow('나이', '미입력'),
                const SizedBox(height: 4),
                _conditionRow(
                  '방문 시간',
                  clockText(_conditions.start),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 4),
                _conditionRow(
                  '제외 장소',
                  _conditions.excluded.isEmpty
                      ? '입력 안 함'
                      : _conditions.excluded,
                  onTap: _editExcludedPlace,
                ),
                const SizedBox(height: 4),
                _conditionRow(
                  '제외 음식',
                  _preferences.dislikedFood.isEmpty
                      ? '입력 안 함'
                      : _preferences.dislikedFood,
                  onTap: _editDislikedFood,
                ),
                const SizedBox(height: 4),
                _conditionRow(
                  '동행 인원 / 유형',
                  '${_conditions.people}명 · 인원 선택',
                  onTap: _pickPeople,
                ),
                const SizedBox(height: 4),
                _conditionRow('분위기', _conditions.mood, onTap: _pickMood),
                const SizedBox(height: 4),
                _conditionRow(
                  '기타 조건',
                  _conditions.query.isEmpty ? '추가 조건 입력' : _conditions.query,
                  onTap: _editOtherCondition,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          OdigaButton(
            label: '조건 적용',
            height: 36,
            onPressed: () {
              widget.app.setPreference(_preferences);
              widget.app.setConditions(_conditions);
              Navigator.of(context).pop(_preferences.categories);
            },
          ),
        ],
      ),
    ),
  );
}

class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({super.key, required this.app, this.group = false});
  final AppState app;
  final bool group;
  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  late final draft = widget.app.conditions.copy();
  late final query = TextEditingController(text: draft.query);
  late final excluded = TextEditingController(text: draft.excluded);
  @override
  void dispose() {
    query.dispose();
    excluded.dispose();
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
    subtitle: '입력한 조건으로 예시 추천을 살펴보세요',
    child: stackItems([
      OdigaSearchField(controller: query, hint: '성수에서 조용한 카페 갔다가 저녁 먹을래'),
      panel([
        label('✧ 추천 조건 · 수정 가능', bold: true),
        DropdownButtonFormField<String>(
          initialValue: draft.region,
          decoration: const InputDecoration(labelText: '지역'),
          items: [
            '성수',
            '홍대',
            '강남',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
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
          children: ['조용한', '활기찬', '사진']
              .map(
                (v) => OdigaTag(
                  label: v,
                  selected: draft.mood == v,
                  onSelected: (_) => setState(() => draft.mood = v),
                ),
              )
              .toList(),
        ),
        TextField(
          controller: excluded,
          decoration: const InputDecoration(
            labelText: '제외 장소·태그·카테고리',
            hintText: '예: 카페, 한식 (쉼표로 구분)',
          ),
        ),
        label(
          '예시 지원 지역: 성수·홍대·강남 · 지역별 고정 샘플을 표시합니다.',
          size: 11,
          color: OdigaTokens.muted,
        ),
      ]),
      action('수정 조건으로 바로 추천', () {
        draft.query = query.text.trim();
        draft.useSelectedRegion = true;
        draft.excluded = excluded.text.trim();
        widget.app.setConditions(draft);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/recommendations'),
            builder: (_) => RecommendationsScreen(
              app: widget.app,
              group: widget.group,
              expanded: true,
            ),
          ),
        );
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
  const PlaceDetailScreen({super.key, required this.app, required this.place});
  final AppState app;
  final Place place;
  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late DateTime visit = widget.app.conditions.start;
  late Future<Place> detail = widget.app.repository.loadPlace(
    widget.place.id,
    visit,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Place>(
    future: detail,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppFrame(
          app: widget.app,
          title: '장소 상세',
          child: Column(
            children: [
              Text(
                snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : '장소 정보를 불러오지 못했어요.',
              ),
              TextButton(
                onPressed: () => setState(() {
                  detail = widget.app.repository.loadPlace(
                    widget.place.id,
                    visit,
                  );
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
          final p = snapshot.data!;
          final hasHourly = widget.app.repository.hasHourlyCongestion(p.id);
          final congestion = widget.app.repository.congestion(
            p.id,
            visit,
            detail: hasHourly,
          );
          return AppFrame(
            app: widget.app,
            title: p.name,
            subtitle: p.rating == null
                ? p.category
                : '${p.category} · ★ ${p.rating}',
            child: stackItems([
              if (p.id != widget.place.id)
                label('현재는 선택한 장소와 관계없이 고정된 예시 상세를 표시합니다.', size: 11),
              PlaceImage(
                image: AssetImage(p.imageAsset),
                width: double.infinity,
                height: 148,
              ),
              label(
                '서울 · ${p.region} · ${p.openingHours}',
                size: 11,
                color: OdigaTokens.muted,
              ),
              panel([
                label(
                  '${dateText(visit)} ${clockText(visit)}',
                  size: 11,
                  color: OdigaTokens.brand,
                ),
                label(
                  '예시 지역 혼잡도 · ${level(congestion).label}',
                  size: 18,
                  bold: true,
                  color: level(congestion).color,
                ),
                label(
                  '샘플 ${congestion.weekend ? '주말' : '평일'} ${congestion.hour}시 · 백분위 ${congestion.percentile.round()}',
                  size: 11,
                  color: OdigaTokens.muted,
                ),
              ], lavender: true),
              if (hasHourly)
                panel([
                  label('시간대별 예시 혼잡도 · 하루 전체 비교', bold: true),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(6, (i) {
                        final time = DateTime(
                          visit.year,
                          visit.month,
                          visit.day,
                          12 + i,
                        );
                        final c = widget.app.repository.congestion(
                          p.id,
                          time,
                          detail: true,
                        );
                        return Expanded(
                          child: InkWell(
                            onTap: () => setState(() => visit = time),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 22,
                                  height: c.value,
                                  decoration: BoxDecoration(
                                    color: level(c).color,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                label(
                                  '${12 + i}시',
                                  size: 11,
                                  color: OdigaTokens.muted,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  label(
                    '막대를 누르면 방문 시간의 혼잡도를 볼 수 있어요.',
                    size: 11,
                    color: OdigaTokens.muted,
                  ),
                ])
              else
                panel([label('이 장소의 시간대별 혼잡도 샘플은 아직 없어요.', size: 11)]),
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
                      widget.app.savedPlaceIds.contains(p.id) ? '저장됨' : '저장',
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
