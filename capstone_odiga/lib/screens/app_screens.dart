import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain.dart';
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
    this.mapBackground = false,
  });
  final AppState app;
  final Widget child;
  final String? title;
  final String subtitle;
  final bool scroll, showBack;
  final bool mapBackground;
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
            bottom: false,
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
          bottomNavigationBar: OdigaBottomNavigation(
            currentIndex: app.tab,
            onChanged: (i) => rootTab(context, app, i),
          ),
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
  });
  final AppState app;
  final Place place;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PlaceCard(
    title: place.name,
    category: place.category,
    rating: place.rating,
    description: place.description,
    level: level(app.repository.congestion(place.id, app.conditions.start)),
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
    this.places,
    this.initialSize = RecommendationSheetSize.medium,
    this.onPin,
  });
  final AppState app;
  final String title;
  final List<Widget> children;
  final Course? course;
  final List<Place>? places;
  final RecommendationSheetSize initialSize;
  final ValueChanged<Place>? onPin;
  @override
  State<MapSheetFrame> createState() => _MapSheetFrameState();
}

class _MapSheetFrameState extends State<MapSheetFrame> {
  late var size = widget.initialSize;
  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    scroll: false,
    child: LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Positioned.fill(
            child: PrototypeMap(
              app: widget.app,
              course: widget.course,
              places: widget.places,
              region: widget.course?.region ?? widget.app.conditions.region,
              onPlace:
                  widget.onPin ??
                  (p) => openPage(
                    context,
                    PlaceDetailScreen(app: widget.app, place: p),
                    '/place/${p.id}',
                  ),
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
                height: 40,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '뒤로',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left, size: 20),
                    ),
                    Expanded(
                      child: Text(
                        '${widget.course?.region ?? widget.app.conditions.region} · ${widget.app.conditions.people}명 · 외출 코스',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OdigaTokens.text(11),
                      ),
                    ),
                    TextButton(
                      onPressed: () => openPage(
                        context,
                        ConditionsScreen(app: widget.app),
                        '/conditions',
                      ),
                      child: const Text('조건 ⚙', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (box.maxHeight - 70).clamp(100, 610),
              ),
              child: OdigaContentSheet(
                title: widget.title,
                size: size,
                onSizeChanged: (value) => setState(() => size = value),
                children: widget.children,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
