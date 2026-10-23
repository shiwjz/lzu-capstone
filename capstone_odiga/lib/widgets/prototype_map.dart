import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/domain.dart';
import '../state/app_state.dart';
import 'odiga_widgets.dart';

/// Local design map, not GPS/Kakao. Marker locations are illustrative fixtures.
class PrototypeMap extends StatelessWidget {
  const PrototypeMap({
    super.key,
    required this.app,
    required this.onPlace,
    this.course,
    this.places,
    this.region = '성수',
    this.home = false,
    this.homeSearch,
  });
  final AppState app;
  final Course? course;
  final List<Place>? places;
  final String region;
  final bool home;
  final Widget? homeSearch;
  final ValueChanged<Place> onPlace;
  static const positions = [
    Offset(310, 105),
    Offset(230, 168),
    Offset(74, 293),
    Offset(120, 360),
    Offset(290, 395),
    Offset(85, 440),
  ];
  Widget svg(String file, double width, double height) =>
      SvgPicture.asset('assets/$file', width: width, height: height);

  @override
  Widget build(BuildContext context) {
    final items =
        course?.stops.map((s) => app.repository.place(s.placeId)).toList() ??
        places ??
        app.repository.places.where((p) => p.region == region).toList();
    if (home) {
      return _HomeMap(places: items, onPlace: onPlace, search: homeSearch);
    }
    final points = items
        .map(
          (p) => positions[int.parse(p.id.split('-').last) % positions.length],
        )
        .toList();
    final originalRoute =
        course != null &&
        course!.stops.length == 3 &&
        List.generate(
          3,
          (i) => course!.stops[i].placeId.endsWith('-$i'),
        ).every((v) => v);
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 390,
              height: 748,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      region == '홍대' ? 'assets/e3b17.png' : 'assets/23d0a.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: .17),
                    ),
                  ),
                  if (originalRoute)
                    Positioned(
                      left: 74,
                      top: 121,
                      child: SizedBox(
                        width: 244,
                        height: 188,
                        child: OverflowBox(
                          maxWidth: 254.5,
                          maxHeight: 198.5,
                          child: svg('3a9c4.svg', 254.5, 198.5),
                        ),
                      ),
                    )
                  else if (course != null)
                    Positioned.fill(
                      child: CustomPaint(painter: _RoutePainter(points)),
                    ),
                  for (var i = 0; i < items.length; i++)
                    Positioned(
                      left: points[i].dx - 17,
                      top: points[i].dy - 20,
                      child: OdigaMapPin(
                        level:
                            CongestionLevel.values[app.repository
                                .congestion(
                                  items[i].id,
                                  course?.stops[i].arrival ??
                                      app.conditions.start,
                                )
                                .band
                                .index],
                        label: course == null ? '●' : '${i + 1}',
                        onTap: () => onPlace(items[i]),
                      ),
                    ),
                  if (course != null)
                    for (var i = 0; i < points.length - 1; i++)
                      Positioned(
                        left: ((points[i].dx + points[i + 1].dx) / 2 - 45)
                            .clamp(0, 280),
                        top: (points[i].dy + points[i + 1].dy) / 2 + 12,
                        child: MapTravelTime(
                          label: '도보 ${course!.stops[i].travelMinutesToNext}분',
                        ),
                      ),
                  Positioned(
                    left: 175,
                    top: 320,
                    child: svg('8c6a2.svg', 34, 34),
                  ),
                  Positioned(
                    left: 185,
                    top: 330,
                    child: svg('57b85.svg', 14, 14),
                  ),
                  Positioned(right: 16, top: 62, child: _location(context)),
                  Positioned(
                    left: 12,
                    top: 365,
                    child: _pill('예시 지도 · 실제 길찾기 아님', small: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _location(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('현재 위치는 성수의 예시 위치입니다.'))),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: svg('f6032.svg', 20, 20),
      ),
    ),
  );
  Widget _pill(String text, {bool small = false}) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 6 : 10,
      vertical: small ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: OdigaTokens.text(small ? 9 : 11)),
  );
}

/// Figma 26:5. Only the map artwork scales; the controls keep their touch size.
class _HomeMap extends StatelessWidget {
  const _HomeMap({required this.places, required this.onPlace, this.search});
  final List<Place> places;
  final ValueChanged<Place> onPlace;
  final Widget? search;

  static const _markers = [
    (category: '음식점', position: Offset(86, 270)),
    (category: '카페', position: Offset(259, 317)),
    (category: '놀거리', position: Offset(116, 487)),
    (category: '음식점', position: Offset(293, 512)),
    (category: '카페', position: Offset(62, 557)),
    (category: '음식점', position: Offset(216, 224)),
  ];

  @override
  Widget build(BuildContext context) {
    // Match each design marker to a distinct fixture of the same category.
    final remaining = [...places];
    final markers = <({Place place, Offset position})>[];
    for (final marker in _markers) {
      final index = remaining.indexWhere((p) => p.category == marker.category);
      if (index >= 0) {
        markers.add((
          place: remaining.removeAt(index),
          position: marker.position,
        ));
      }
    }
    final searchTop = (MediaQuery.paddingOf(context).top + 12).clamp(
      52.0,
      double.infinity,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 390,
                height: 748,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset('assets/23d0a.png', fit: BoxFit.cover),
                    ),
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0x0BFFFFFF)),
                    ),
                    Positioned(
                      left: 165,
                      top: 360,
                      child: SvgPicture.asset(
                        'assets/f16f2.svg',
                        width: 60,
                        height: 60,
                      ),
                    ),
                    Positioned(
                      left: 187,
                      top: 382,
                      child: SvgPicture.asset(
                        'assets/85a2f.svg',
                        width: 16,
                        height: 16,
                      ),
                    ),
                    const Positioned(
                      left: 154,
                      top: 413,
                      child: _HomeMapLabel(
                        '현재 내 위치',
                        width: 82,
                        height: 29,
                        color: OdigaTokens.brand,
                      ),
                    ),
                    for (final marker in markers)
                      Positioned(
                        left: marker.position.dx - 5,
                        top: marker.position.dy,
                        child: NearbyCategoryMarker(
                          place: marker.place,
                          onTap: () => onPlace(marker.place),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (search != null)
          Positioned(left: 20, right: 20, top: searchTop, child: search!),
        Positioned(
          left: 20,
          right: 12,
          top: searchTop + 66,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 225,
                    height: 32,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '내 주변 · 음식점 · 카페 · 놀거리',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OdigaTokens.text(11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: const Color(0x24292933),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('현재 위치는 성수의 예시 위치입니다.')),
                    ),
                    child: Semantics(
                      label: '현재 위치로 이동',
                      button: true,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/f6032.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          left: 10,
          bottom: 0,
          child: _HomeMapLabel(
            '100 m',
            width: 55,
            height: 20,
            radius: 5,
            color: OdigaTokens.muted,
          ),
        ),
      ],
    );
  }
}

/// Category pin and label share one action and the same place data.
class NearbyCategoryMarker extends StatelessWidget {
  const NearbyCategoryMarker({
    super.key,
    required this.place,
    required this.onTap,
  });
  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${place.category} · ${place.name}',
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: OdigaTokens.brand,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/${switch (place.category) {
                  '음식점' => '9d91f.svg',
                  '카페' => '542bf.svg',
                  _ => '7ff54.svg',
                }}',
                width: 23,
                height: 23,
              ),
            ),
          ),
          const SizedBox(height: 2),
          _HomeMapLabel(
            place.category,
            width: place.category == '음식점' ? 54 : 46,
            height: 24,
            radius: 12,
          ),
        ],
      ),
    ),
  );
}

class _HomeMapLabel extends StatelessWidget {
  const _HomeMapLabel(
    this.text, {
    required this.width,
    required this.height,
    this.radius = 14,
    this.color = OdigaTokens.ink,
  });
  final String text;
  final double width, height, radius;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Text(text, style: OdigaTokens.text(11, color: color)),
  );
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points);
  final List<Offset> points;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = OdigaTokens.brand
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.points.toString() != points.toString();
}
