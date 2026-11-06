import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/domain.dart';
import '../state/app_state.dart';
import 'odiga_components.dart';
import 'odiga_widgets.dart';

/// OpenStreetMap-backed map for nearby places and recommended courses.
class PrototypeMap extends StatelessWidget {
  const PrototypeMap({
    super.key,
    required this.app,
    required this.onPlace,
    this.course,
    this.places,
    this.homeCategories,
    this.region = '성수',
    this.home = false,
    this.homeSearch,
    this.homeInfo,
  });
  final AppState app;
  final Course? course;
  final List<Place>? places;
  final Set<String>? homeCategories;
  final String region;
  final bool home;
  final Widget? homeSearch;
  final VoidCallback? homeInfo;
  final ValueChanged<Place> onPlace;

  static const _regionCenters = <String, LatLng>{
    '성수': LatLng(37.5438, 127.0553),
    '홍대': LatLng(37.5563, 126.9236),
    '강남': LatLng(37.4979, 127.0276),
  };

  List<Place> _visiblePlaces() {
    final source =
        course?.stops
            .map((stop) => app.repository.place(stop.placeId))
            .toList() ??
        places ??
        app.repository.places.where((place) => place.region == region).toList();
    if (!home || homeCategories == null) return source;
    return source
        .where((place) => homeCategories!.contains(place.category))
        .toList();
  }

  CongestionBand _band(Place place, int index) {
    if (course != null && index < course!.stops.length) {
      final actual = course!.stops[index].congestionBand;
      if (actual != null) return actual;
      return app.repository
          .congestion(place.id, course!.stops[index].arrival)
          .band;
    }
    return app.repository.congestion(place.id, app.conditions.start).band;
  }

  Color _bandColor(CongestionBand band) => switch (band) {
    CongestionBand.quiet => const Color(0xFF3FAE79),
    CongestionBand.moderate => const Color(0xFFF0A933),
    CongestionBand.busy => const Color(0xFFE45C5C),
  };

  @override
  Widget build(BuildContext context) {
    final items = _visiblePlaces();
    final points = <LatLng>[
      for (final place in items) LatLng(place.latitude, place.longitude),
    ];
    final center = points.isEmpty
        ? _regionCenters[region] ?? _regionCenters['성수']!
        : LatLng(
            points.map((point) => point.latitude).reduce((a, b) => a + b) /
                points.length,
            points.map((point) => point.longitude).reduce((a, b) => a + b) /
                points.length,
          );
    final route = course == null ? <LatLng>[] : points;
    final polylines = <Polyline>[];
    if (route.length > 1) {
      for (var i = 0; i < route.length - 1; i++) {
        polylines.add(
          Polyline(
            points: [route[i], route[i + 1]],
            color: _bandColor(_band(items[i + 1], i + 1)),
            strokeWidth: 6,
            borderColor: Colors.white,
            borderStrokeWidth: 2,
          ),
        );
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: course != null ? 15.7 : 14.4,
              minZoom: 10,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.capstone_odiga',
              ),
              if (items.isNotEmpty)
                CircleLayer(
                  circles: [
                    for (var i = 0; i < items.length; i++)
                      CircleMarker(
                        point: points[i],
                        radius: 95,
                        useRadiusInMeter: true,
                        color: _bandColor(_band(items[i], i))
                            .withValues(alpha: .18),
                        borderColor: _bandColor(_band(items[i], i))
                            .withValues(alpha: .38),
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < items.length; i++)
                    Marker(
                      point: points[i],
                      width: 50,
                      height: 54,
                      alignment: Alignment.topCenter,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CourseCategoryMapPin(
                            category: items[i].category,
                            visitOrder: course == null ? null : i + 1,
                            onTap: () => onPlace(items[i]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (homeSearch != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 20,
            right: 20,
            child: homeSearch!,
          ),
        if (home)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 78,
            left: 20,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '내 주변 · ${homeCategories?.join(' · ') ?? '음식점 · 카페 · 놀거리'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (homeInfo != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '추천 점수 계산 기준',
                    onPressed: homeInfo,
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ],
            ),
          ),
        Positioned(
          left: 12,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text('한산 · 보통 · 혼잡', style: TextStyle(fontSize: 10)),
            ),
          ),
        ),
      ],
    );
  }
}
