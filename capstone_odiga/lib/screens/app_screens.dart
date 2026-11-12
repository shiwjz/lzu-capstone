import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../models/domain.dart';
import '../api/api_codes.dart';
import '../api/odiga_api.dart';
import '../state/app_state.dart';
import '../widgets/odiga_widgets.dart';
import '../widgets/prototype_map.dart';

part 'discovery_screens.dart';
part 'course_screens.dart';
part 'social_screens.dart';

Future<T?> openPage<T>(BuildContext context, Widget child, String route) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute(
        settings: RouteSettings(name: route),
        builder: (_) => child,
      ),
    );

void rootTab(BuildContext context, AppState app, int index) {
  app.selectTab(index);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

String clockText(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
String dateText(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
CongestionLevel level(Congestion c) => CongestionLevel.values[c.band.index];
String summary(Course c) =>
    '${c.totalMinutes}분 · ${c.distanceKm.toStringAsFixed(1)}km · 장소 ${c.stops.length}개';
const searchInputMessage = '검색어를 확인 후 다시 입력해 주세요.';

String visitConditionText(SearchConditions conditions) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final start = conditions.start;
  final time = '${start.hour}시${start.minute == 0 ? '' : ' ${start.minute}분'}';
  return '${weekdays[start.weekday - 1]}요일 $time ${conditions.region}';
}

CongestionLevel? placeCongestion(AppState app, Place place, DateTime visit) {
  final value = app.repository.congestionOrNull(place.id, visit);
  return value == null ? null : level(value);
}

const _showKakaoDirections = false;

Future<void> openDirections(BuildContext context, List<Place> stops) async {
  final destination = stops.last;
  String coords(Place place) => '${place.latitude},${place.longitude}';
  String namedCoords(Place place) =>
      '${place.name.replaceAll(',', ' ')},${coords(place)}';
  final points = stops.length > 7 ? [...stops.take(6), destination] : stops;
  final webUrl = Uri(
    scheme: 'https',
    host: 'map.kakao.com',
    pathSegments: points.length == 1
        ? ['link', 'to', namedCoords(destination)]
        : ['link', 'by', 'walk', ...points.map(namedCoords)],
  );
  final appUrl = Uri(
    scheme: 'kakaomap',
    host: 'route',
    queryParameters: {
      if (points.length > 1) 'sp': coords(points.first),
      for (var i = 1; i < points.length - 1; i++)
        (i == 1 ? 'vp' : 'vp$i'): coords(points[i]),
      'ep': coords(destination),
      'by': 'foot',
    },
  );
  if (!kIsWeb && points.length > 1) {
    try {
      if (await launchUrl(appUrl, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // Try the Kakao Maps web link when the app cannot be opened.
    }
  }
  try {
    if (await launchUrl(webUrl, mode: LaunchMode.externalApplication)) return;
  } on PlatformException {
    // The user can retry from the same screen.
  }
  if (context.mounted) toast(context, '카카오맵을 열지 못했어요.');
}

String apiFailureMessage(Object? error) {
  if (error is! ApiException) return '정보를 불러오지 못했어요. 다시 시도해 주세요.';
  return switch (error.code) {
    'NETWORK_ERROR' => '서버에 연결할 수 없어요. 연결 상태를 확인해 주세요.',
    'CONDITION_MISSING' => searchInputMessage,
    'NOT_READY' => '아직 준비 중인 기능이에요.',
    _ => error.message,
  };
}

Text label(
  String text, {
  double size = 14,
  Color color = OdigaTokens.ink,
  bool bold = false,
}) => Text(
  text,
  style: OdigaTokens.text(
    size,
    color: color,
    weight: bold ? FontWeight.w700 : FontWeight.w400,
  ),
);
Widget action(String text, VoidCallback? onTap, {bool secondary = false}) =>
    OdigaButton(
      label: text,
      onPressed: onTap,
      variant: secondary
          ? OdigaButtonVariant.secondary
          : OdigaButtonVariant.primary,
    );
Widget stackItems(List<Widget> items, {double gap = 12}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      items[i],
    ],
  ],
);
Widget panel(List<Widget> children, {bool lavender = false}) => Material(
  color: lavender ? OdigaTokens.lavender : Colors.white,
  borderRadius: BorderRadius.circular(20),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: stackItems(children, gap: 8),
  ),
);
void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

Future<String?> editText(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
  // The dialog route owns an exit animation; dispose after it completes.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return value;
}

class AppFrame extends StatelessWidget {
  const AppFrame({
    super.key,
    required this.app,
    required this.child,
    this.title,
    this.subtitle = '',
    this.scroll = true,
    this.showBack = true,
    this.showBottomNavigation = true,
    this.mapBackground = false,
  });
  final AppState app;
  final Widget child;
  final String? title;
  final String subtitle;
  final bool scroll, showBack;
  final bool mapBackground;
  final bool showBottomNavigation;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFECE8F3),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Scaffold(
          backgroundColor: OdigaTokens.background,
          body: SafeArea(
            top: !mapBackground,
            bottom: !showBottomNavigation,
            child: Column(
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showBack && Navigator.canPop(context))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: IconButton(
                              tooltip: '뒤로',
                              onPressed: () => Navigator.maybePop(context),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.chevron_left),
                            ),
                          ),
                        Expanded(
                          child: stackItems([
                            label(title!, size: 22, bold: true),
                            if (subtitle.isNotEmpty)
                              label(
                                subtitle,
                                size: 11,
                                color: OdigaTokens.muted,
                              ),
                          ], gap: 3),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: scroll
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                          children: [child],
                        )
                      : child,
                ),
              ],
            ),
          ),
          bottomNavigationBar: showBottomNavigation
              ? OdigaBottomNavigation(
                  currentIndex: app.tab,
                  onChanged: (i) => rootTab(context, app, i),
                )
              : null,
        ),
      ),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: app,
    builder: (_, child) => switch (app.tab) {
      1 => SavedCoursesScreen(app: app),
      2 => FriendsScreen(app: app),
      3 => ProfileScreen(app: app),
      _ => HomeScreen(app: app),
    },
  );
}

class PlaceCardView extends StatelessWidget {
  const PlaceCardView({
    super.key,
    required this.app,
    required this.place,
    required this.onTap,
    this.visit,
    this.kept = false,
    this.onKeep,
    this.showCongestion = true,
  });
  final AppState app;
  final Place place;
  final VoidCallback onTap;
  final DateTime? visit;
  final bool kept, showCongestion;
  final VoidCallback? onKeep;
  @override
  Widget build(BuildContext context) => PlaceCard(
    title: place.name,
    category: [
      place.category,
      if (place.cuisineDetail?.isNotEmpty == true) place.cuisineDetail!,
      if ((place.cuisineDetail == null || place.cuisineDetail!.isEmpty) &&
          place.cuisine != null)
        const {
              'KOREAN': '한식',
              'JAPANESE': '일식',
              'WESTERN': '양식',
              'CHINESE': '중식',
              'BUNSIK': '분식',
              'ASIAN': '아시아',
              'CHICKEN': '치킨',
              'BAR': '술집',
              'CAFE': '카페',
            }[place.cuisine] ??
            place.cuisine!,
    ].join(' · '),
    rating: place.rating,
    description: place.description,
    level: showCongestion
        ? placeCongestion(app, place, visit ?? app.conditions.start)
        : null,
    trailing: onKeep == null
        ? null
        : IconButton(
            tooltip: kept ? '킵 해제' : '킵',
            isSelected: kept,
            onPressed: onKeep,
            icon: const Icon(Icons.push_pin_outlined),
            selectedIcon: const Icon(Icons.push_pin, color: OdigaTokens.brand),
          ),
    image: AssetImage(place.imageAsset),
    onTap: onTap,
  );
}

class MapSheetFrame extends StatefulWidget {
  const MapSheetFrame({
    super.key,
    required this.app,
    required this.title,
    required this.children,
    this.course,
    this.radarConditions,
    this.sheetTitle,
    this.onConditions,
    this.places,
    this.initialSize = RecommendationSheetSize.medium,
    this.onPin,
    this.showBottomNavigation = true,
  });
  final AppState app;
  final String title;
  final String? sheetTitle;
  final VoidCallback? onConditions;
  final List<Widget> children;
  final Course? course;
  final SearchConditions? radarConditions;
  final List<Place>? places;
  final RecommendationSheetSize initialSize;
  final ValueChanged<Place>? onPin;
  final bool showBottomNavigation;
  @override
  State<MapSheetFrame> createState() => _MapSheetFrameState();
}

class _MapSheetFrameState extends State<MapSheetFrame> {
  late var size = widget.initialSize;
  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    scroll: false,
    showBottomNavigation: widget.showBottomNavigation,
    child: LayoutBuilder(
      builder: (context, box) {
        final maxSheetHeight = (box.maxHeight - 200).clamp(100.0, 610.0);
        final sheetHeight = BottomSheetSurface.heightFor(size)
            .clamp(0.0, maxSheetHeight);
        final hasConditions = widget.onConditions != null;
        final headerHeight = hasConditions ? 52.0 : 40.0;
        return Stack(
          children: [
            Positioned(
              top: headerHeight + 16,
              left: 0,
              right: 0,
              bottom: sheetHeight - 12,
              child: PrototypeMap(
                app: widget.app,
                course: widget.course,
                places: widget.places,
                region:
                    widget.radarConditions?.region ??
                    widget.course?.region ??
                    widget.app.conditions.region,
                radarVisit:
                    widget.radarConditions?.start ??
                    widget.course?.stops.firstOrNull?.arrival,
                onPlace: (place) {
                  final stop = widget.course?.stops
                      .where((stop) => stop.placeId == place.id)
                      .firstOrNull;
                  if (widget.onPin case final onPin?) {
                    onPin(place);
                  } else if (stop != null) {
                    openCourseStop(context, widget.app, stop);
                  } else {
                    openPage(
                      context,
                      PlaceDetailScreen(app: widget.app, place: place),
                      '/place/${place.id}',
                    );
                  }
                },
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: headerHeight,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '뒤로',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.chevron_left, size: 20),
                      ),
                      Expanded(
                        child: Tooltip(
                          message: widget.title,
                          excludeFromSemantics: true,
                          child: Text(
                            widget.title,
                            maxLines: hasConditions ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: OdigaTokens.text(13),
                          ),
                        ),
                      ),
                      if (hasConditions)
                        TextButton(
                          onPressed: widget.onConditions,
                          child: const Text('조건'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: OdigaContentSheet(
                  title: widget.sheetTitle ?? widget.title,
                  size: size,
                  onSizeChanged: (value) => setState(() => size = value),
                  children: widget.children,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
