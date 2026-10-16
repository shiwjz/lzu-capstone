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
  });
  final AppState app;
  final Course? course;
  final List<Place>? places;
  final String region;
  final bool home;
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 350 / 506,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: 350,
              height: 506,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset('assets/23d0a.png', fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: 145,
                    top: 223,
                    child: svg('f16f2.svg', 60, 60),
                  ),
                  Positioned(
                    left: 167,
                    top: 245,
                    child: svg('85a2f.svg', 16, 16),
                  ),
                  Positioned(left: 134, top: 276, child: _pill('현재 내 위치')),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _pill('내 주변 · 음식점 · 카페 · 놀거리'),
                  ),
                  Positioned(right: 12, top: 12, child: _location(context)),
                  for (var i = 0; i < items.length && i < 6; i++)
                    Positioned(
                      left: [66.0, 239.0, 96.0, 273.0, 42.0, 196.0][i],
                      top: [134.0, 181.0, 351.0, 376.0, 421.0, 88.0][i],
                      child: GestureDetector(
                        onTap: () => onPlace(items[i]),
                        child: Column(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: OdigaTokens.brand,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: svg(
                                items[i].category == '카페'
                                    ? '542bf.svg'
                                    : items[i].category == '음식점'
                                    ? '9d91f.svg'
                                    : '7ff54.svg',
                                23,
                                23,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _pill(items[i].category),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _pill('지도 미리보기', small: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
