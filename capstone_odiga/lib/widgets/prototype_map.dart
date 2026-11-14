import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_models.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import 'odiga_components.dart';
import 'odiga_widgets.dart';

/// OpenStreetMap-backed map for nearby places and recommended courses.
class PrototypeMap extends StatefulWidget {
  const PrototypeMap({
    super.key,
    required this.app,
    required this.onPlace,
    this.course,
    this.places,
    this.homeCategories,
    this.region = '성수',
    this.radarVisit,
    this.home = false,
    this.homeSearch,
    this.homeInfo,
  });
  final AppState app;
  final Course? course;
  final List<Place>? places;
  final Set<String>? homeCategories;
  final String region;
  final DateTime? radarVisit;
  final bool home;
  final Widget? homeSearch;
  final VoidCallback? homeInfo;
  final ValueChanged<Place> onPlace;

  @override
  State<PrototypeMap> createState() => _PrototypeMapState();
}

class _PrototypeMapState extends State<PrototypeMap> {
  final controller = MapController();
  LatLng? currentLocation;
  bool locating = false;
  bool showResultRadar = true;
  final grids = <(String, DateTime?), Future<CongestionGridDto>>{};

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        message('기기에서 위치 서비스를 켜 주세요.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        message('앱의 위치 권한을 허용해 주세요.');
        return;
      }
      const timeLimit = Duration(seconds: 15);
      final settings =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(forceLocationManager: true, timeLimit: timeLimit)
          : const LocationSettings(timeLimit: timeLimit);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => currentLocation = point);
      controller.move(point, 15);
    } catch (_) {
      message('현재 위치를 가져오지 못했어요.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  static const _regionCenters = <String, LatLng>{
    '성수': LatLng(37.5438, 127.0553),
    '홍대': LatLng(37.5563, 126.9236),
    '강남': LatLng(37.4979, 127.0276),
  };

  List<Place> _visiblePlaces() {
    final app = widget.app;
    final course = widget.course;
    if (course != null) {
      return [
        for (final stop in course.stops) app.repository.place(stop.placeId),
      ];
    }
    if (widget.places case final places?) return places;
    if (!widget.home) return [];
    final location = currentLocation;
    const distance = Distance();
    return app.repository.places.where((place) {
      final nearby = location == null
          ? place.region == widget.region
          : distance(location, LatLng(place.latitude, place.longitude)) <= 2000;
      return nearby &&
          (widget.homeCategories?.contains(
                place.category == '술집' ? '음식점' : place.category,
              ) ??
              true);
    }).toList();
  }

  Polygon gridPolygon(CongestionCellDto cell, double sizeMeters) {
    final lat = sizeMeters / 2 / 111320;
    final lng = lat / math.cos(cell.lat * math.pi / 180);
    final color = switch (cell.level) {
      'QUIET' => const Color(0xFF3FAE79),
      'NORMAL' => const Color(0xFFF0A933),
      'BUSY' => const Color(0xFFE45C5C),
      _ => Colors.transparent,
    };
    return Polygon(
      points: [
        LatLng(cell.lat - lat, cell.lng - lng),
        LatLng(cell.lat - lat, cell.lng + lng),
        LatLng(cell.lat + lat, cell.lng + lng),
        LatLng(cell.lat + lat, cell.lng - lng),
      ],
      color: color.withValues(alpha: color == Colors.transparent ? 0 : .44),
      borderColor: color,
      borderStrokeWidth: .5,
    );
  }

  List<CircleMarker> stopRadar(LatLng point, CongestionBand band) {
    final level = CongestionLevel.values[band.index];
    return [
      CircleMarker(
        point: point,
        radius: 28,
        color: level.color.withValues(alpha: .18),
        borderColor: level.color,
        borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: point,
        radius: 20,
        color: level.color.withValues(alpha: .14),
        borderColor: level.color.withValues(alpha: .65),
        borderStrokeWidth: 1,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final items = _visiblePlaces();
    final points = [
      for (final place in items) LatLng(place.latitude, place.longitude),
    ];
    final center =
        currentLocation ??
        points.firstOrNull ??
        _regionCenters[widget.region] ??
        _regionCenters['성수']!;
    final polylines = course == null || points.length < 2
        ? <Polyline>[]
        : [
            Polyline(
              points: points,
              color: OdigaTokens.brand,
              strokeWidth: 4,
              pattern: const StrokePattern.dotted(),
            ),
          ];
    final visit = widget.radarVisit;
    final hasCourseRadar =
        course != null &&
        items.any((place) => supportedCongestionRegions.contains(place.region));
    final region =
        !widget.home &&
            course == null &&
            visit != null &&
            showResultRadar &&
            supportedCongestionRegions.contains(widget.region)
        ? widget.region
        : null;
    final grid = region == null
        ? null
        : grids.putIfAbsent((
            region,
            visit,
          ), () => widget.app.repository.loadCongestionGrid(region, visit));
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              key: course == null
                  ? const ValueKey('places')
                  : ValueKey((points.join(','), box.biggest)),
              mapController: widget.home ? controller : null,
              options: MapOptions(
                initialCenter: center,
                initialZoom: course == null ? 14.4 : 16,
                initialCameraFit: course != null && points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.fromLTRB(32, 16, 32, 64),
                        maxZoom: 17,
                      )
                    : null,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'Odiga',
                ),
                if (grid != null)
                  FutureBuilder(
                    future: grid,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox.shrink();
                      }
                      final data = snapshot.data;
                      if (data == null) return const SizedBox.shrink();
                      return PolygonLayer(
                        polygons: [
                          for (final cell in data.cells)
                            gridPolygon(cell, data.cellSizeMeters),
                        ],
                      );
                    },
                  ),
                if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                if (hasCourseRadar && showResultRadar)
                  for (final (i, stop) in course.stops.indexed)
                    _CourseRadarLayer(
                      key: ValueKey((
                        stop.id,
                        stop.placeId,
                        stop.arrival,
                        stop.congestionBand,
                      )),
                      load: () =>
                          widget.app.repository.loadStopCongestion(stop),
                      circles: (band) => stopRadar(points[i], band),
                    ),
                MarkerLayer(
                  markers: [
                    for (final (i, place) in items.indexed)
                      Marker(
                        point: points[i],
                        width: 50,
                        height: 54,
                        alignment: Alignment.topCenter,
                        child: CourseCategoryMapPin(
                          category: place.category,
                          visitOrder: course == null ? null : i + 1,
                          onTap: () => widget.onPlace(place),
                        ),
                      ),
                    if (currentLocation case final location?)
                      Marker(
                        point: location,
                        width: 30,
                        height: 30,
                        child: Semantics(
                          label: '내 위치',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
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
          if (widget.homeSearch case final search?)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 20,
              right: 20,
              child: search,
            ),
          if (widget.home)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 78,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: '내 위치',
                    onPressed: locating ? null : locate,
                    child: locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  if (widget.homeInfo case final onInfo?) ...[
                    const SizedBox(height: 8),
                    IconButton.filledTonal(
                      tooltip: '추천 점수 계산 기준',
                      onPressed: onInfo,
                      icon: const Icon(Icons.info_outline),
                    ),
                  ],
                ],
              ),
            ),
          if (!widget.home &&
              (hasCourseRadar || (course == null && visit != null)))
            Positioned(
              top: 6,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: showResultRadar ? '혼잡 레이더 끄기' : '혼잡 레이더 켜기',
                onPressed: () => setState(() {
                  showResultRadar = !showResultRadar;
                  if (!showResultRadar) grids.clear();
                }),
                icon: Icon(
                  hasCourseRadar
                      ? Icons.radar
                      : (showResultRadar ? Icons.grid_on : Icons.grid_off),
                ),
              ),
            ),
          if (hasCourseRadar && showResultRadar)
            Positioned(
              top: 8,
              left: 12,
              right: 62,
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        const Text('도착 시각 혼잡도', style: TextStyle(fontSize: 10)),
                        for (final level in CongestionLevel.values)
                          Text(
                            level.label,
                            style: TextStyle(fontSize: 10, color: level.color),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (grid != null)
            Positioned(
              top: 8,
              left: 12,
              child: FutureBuilder(
                future: grid,
                builder: (context, snapshot) {
                  final text = switch (snapshot) {
                    AsyncSnapshot(connectionState: ConnectionState.waiting) =>
                      '혼잡도 불러오는 중',
                    AsyncSnapshot(hasError: true) => '혼잡도를 불러오지 못했어요',
                    AsyncSnapshot(hasData: false) => '표시할 혼잡도 없음',
                    _ when snapshot.data!.cells.isEmpty => '표시할 혼잡도 없음',
                    _ => '$region 혼잡도  ·  한산 / 보통 / 붐빔',
                  };
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(text, style: const TextStyle(fontSize: 10)),
                    ),
                  );
                },
              ),
            ),
          if (polylines.isNotEmpty)
            Positioned(
              left: 12,
              bottom: 16,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text('장소 간 직선 연결', style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseRadarLayer extends StatefulWidget {
  const _CourseRadarLayer({
    super.key,
    required this.load,
    required this.circles,
  });

  final Future<CongestionBand?> Function() load;
  final List<CircleMarker> Function(CongestionBand) circles;

  @override
  State<_CourseRadarLayer> createState() => _CourseRadarLayerState();
}

class _CourseRadarLayerState extends State<_CourseRadarLayer> {
  late final congestion = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: congestion,
    builder: (context, snapshot) => switch (snapshot.data) {
      final band? => CircleLayer(circles: widget.circles(band)),
      null => const SizedBox.shrink(),
    },
  );
}
