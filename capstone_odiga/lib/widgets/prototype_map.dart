import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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

  @override
  State<PrototypeMap> createState() => _PrototypeMapState();
}

class _PrototypeMapState extends State<PrototypeMap> {
  final controller = MapController();
  LatLng? currentLocation;
  bool locating = false;

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
          (widget.homeCategories?.contains(place.category) ?? true);
    }).toList();
  }

  CongestionBand? _band(Place place, CourseStop stop) {
    if (!supportedCongestionRegions.contains(place.region)) return null;
    return stop.congestionBand ??
        widget.app.repository.congestionOrNull(place.id, stop.arrival)?.band;
  }

  Color _bandColor(CongestionBand band) => switch (band) {
    CongestionBand.quiet => const Color(0xFF3FAE79),
    CongestionBand.moderate => const Color(0xFFF0A933),
    CongestionBand.busy => const Color(0xFFE45C5C),
  };

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
    final circles = <CircleMarker>[
      if (course != null)
        for (final (i, stop) in course.stops.indexed)
          if (_band(items[i], stop) case final band?)
            CircleMarker(
              point: points[i],
              radius: 95,
              useRadiusInMeter: true,
              color: _bandColor(band).withValues(alpha: .18),
              borderColor: _bandColor(band).withValues(alpha: .38),
              borderStrokeWidth: 1,
            ),
    ];
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
                if (circles.isNotEmpty) CircleLayer(circles: circles),
                if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
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
                  if (widget.homeInfo case final onInfo?)
                    IconButton.filledTonal(
                      tooltip: '추천 점수 계산 기준',
                      onPressed: onInfo,
                      icon: const Icon(Icons.info_outline),
                    ),
                ],
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
                  child: Text('직선 거리 기준', style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
