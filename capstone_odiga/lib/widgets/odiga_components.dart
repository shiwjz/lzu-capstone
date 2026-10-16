import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class OdigaTokens {
  static const brand = Color(0xFF8064D8);
  static const lavender = Color(0xFFEEE9FB);
  static const background = Color(0xFFF8F7FC);
  static const ink = Color(0xFF292638);
  static const muted = Color(0xFF817C91);
  static const border = Color(0xFFE9E5F1);
  static const green = Color(0xFF399F88);
  static const amber = Color(0xFFD39A37);
  static const red = Color(0xFFD97079);
  static TextStyle text(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Noto Sans KR',
    fontSize: size,
    height: 1.5,
    color: color,
    fontWeight: weight,
  );
}

Widget _svg(String file, double width, double height) =>
    SvgPicture.asset('assets/$file', width: width, height: height);
Widget _text(
  String text,
  double size, {
  Color color = OdigaTokens.ink,
  FontWeight weight = FontWeight.w400,
}) => Text(
  text,
  style: OdigaTokens.text(size, color: color, weight: weight),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

enum OdigaButtonVariant { primary, secondary }

/// Figma Button/Primary, Button/Secondary (24:45, 24:47).
class OdigaButton extends StatelessWidget {
  const OdigaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = OdigaButtonVariant.primary,
    this.height = 50,
  });
  final String label;
  final VoidCallback? onPressed;
  final OdigaButtonVariant variant;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: variant == OdigaButtonVariant.primary
            ? OdigaTokens.brand
            : OdigaTokens.lavender,
        foregroundColor: variant == OdigaButtonVariant.primary
            ? Colors.white
            : OdigaTokens.brand,
        disabledBackgroundColor: OdigaTokens.border,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: OdigaTokens.text(14, weight: FontWeight.w500),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

/// Figma Tag/Default, Tag/Selected (24:49, 24:51).
class OdigaTag extends StatelessWidget {
  const OdigaTag({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.width = 78,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? OdigaTokens.lavender : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelected == null ? null : () => onSelected!(!selected),
        child: SizedBox(
          width: width,
          height: 34,
          child: Center(
            child: _text(
              label,
              11,
              color: selected ? OdigaTokens.brand : OdigaTokens.muted,
            ),
          ),
        ),
      ),
    ),
  );
}

enum CongestionLevel {
  quiet('한산', OdigaTokens.green, '5edd9.svg', 'ff1e2.svg'),
  moderate('보통', OdigaTokens.amber, 'e620c.svg', '75e26.svg'),
  busy('혼잡', OdigaTokens.red, 'd38bd.svg', '15fa6.svg');

  const CongestionLevel(this.label, this.color, this.dotAsset, this.pinAsset);
  final String label, dotAsset, pinAsset;
  final Color color;
}

class CongestionBadge extends StatelessWidget {
  const CongestionBadge({super.key, required this.level});
  final CongestionLevel level;
  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    height: 28,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _svg(level.dotAsset, 6, 6),
        const SizedBox(width: 8),
        _text(level.label, 11, color: level.color),
      ],
    ),
  );
}

class OdigaMapPin extends StatelessWidget {
  const OdigaMapPin({
    super.key,
    required this.level,
    this.label = '●',
    this.onTap,
  });
  final CongestionLevel level;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${level.label} $label',
    button: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 40,
        child: Stack(
          children: [
            _svg(level.pinAsset, 34, 40),
            Positioned.fill(
              bottom: 7,
              child: Center(
                child: _text(
                  label,
                  14,
                  color: Colors.white,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OdigaAvatar extends StatelessWidget {
  const OdigaAvatar({super.key, required this.initial});
  final String initial;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 21,
    backgroundColor: OdigaTokens.lavender,
    child: _text(
      initial,
      14,
      color: OdigaTokens.brand,
      weight: FontWeight.w500,
    ),
  );
}

class OdigaSearchField extends StatelessWidget {
  const OdigaSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hint = '오늘 강남에서 조용한 카페 추천해줘',
  });
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged, onSubmitted;
  final String hint;
  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: OdigaTokens.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D33294D),
          offset: Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    ),
    child: Row(
      children: [
        _svg('5cb7c.svg', 22, 22),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: OdigaTokens.text(12),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: OdigaTokens.text(12, color: OdigaTokens.muted),
            ),
          ),
        ),
      ],
    ),
  );
}

class PlaceImage extends StatelessWidget {
  const PlaceImage({
    super.key,
    this.image = const AssetImage('assets/756cc.png'),
    this.width = 92,
    this.height = 92,
  });
  final ImageProvider image;
  final double width, height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Image(image: image, width: width, height: height, fit: BoxFit.cover),
  );
}

class OdigaCardSurface extends StatelessWidget {
  const OdigaCardSurface({
    super.key,
    required this.child,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });
  final Widget child;
  final bool selected;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: selected ? OdigaTokens.lavender : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: selected ? OdigaTokens.brand : OdigaTokens.border,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: child,
  );
}

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.title,
    required this.category,
    required this.rating,
    required this.description,
    required this.level,
    this.image = const AssetImage('assets/756cc.png'),
    this.onTap,
  });
  final String title, category, description;
  final double rating;
  final CongestionLevel level;
  final ImageProvider image;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: OdigaCardSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 138),
        child: Row(
          children: [
            PlaceImage(image: image),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _text(title, 18, weight: FontWeight.w700),
                  const SizedBox(height: 8),
                  _text(
                    '$category   ★ ${rating.toStringAsFixed(1)}',
                    11,
                    color: OdigaTokens.muted,
                  ),
                  const SizedBox(height: 8),
                  _text(description, 11, color: OdigaTokens.muted),
                  const SizedBox(height: 8),
                  CongestionBadge(level: level),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.title,
    required this.route,
    required this.summary,
    required this.reason,
    this.congestion = '평균 한산',
    this.image = const AssetImage('assets/5788c.png'),
    this.onTap,
  });
  final String title, route, summary, reason, congestion;
  final ImageProvider image;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: OdigaCardSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 146),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text(title, 18, weight: FontWeight.w700),
            const SizedBox(height: 8),
            _text(route, 14, color: OdigaTokens.muted),
            const SizedBox(height: 8),
            _text(summary, 11, color: OdigaTokens.muted),
            const SizedBox(height: 8),
            _text(
              congestion,
              14,
              color: OdigaTokens.green,
              weight: FontWeight.w500,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _text(reason, 11, color: OdigaTokens.muted)),
                PlaceImage(image: image, width: 32, height: 30),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class RankedCourseCard extends StatelessWidget {
  const RankedCourseCard({
    super.key,
    required this.rank,
    required this.title,
    required this.summary,
    required this.reason,
    this.selected = false,
    this.onReason,
    this.onDetails,
  });
  final int rank;
  final String title, summary, reason;
  final bool selected;
  final VoidCallback? onReason, onDetails;
  @override
  Widget build(BuildContext context) => OdigaCardSurface(
    selected: selected,
    padding: const EdgeInsets.all(10),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 126),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _text(
            '$rank순위',
            14,
            color: OdigaTokens.brand,
            weight: FontWeight.w500,
          ),
          const SizedBox(height: 3),
          _text(title, 16, weight: FontWeight.w500),
          const SizedBox(height: 3),
          _text(summary, 11, color: OdigaTokens.green),
          const SizedBox(height: 3),
          _text(reason, 11, color: OdigaTokens.muted),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: OdigaButton(
                  label: '추천 근거 보기',
                  onPressed: onReason,
                  variant: OdigaButtonVariant.secondary,
                  height: 36,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OdigaButton(
                  label: '코스 상세',
                  onPressed: onDetails,
                  variant: OdigaButtonVariant.secondary,
                  height: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class OdigaBottomNavigation extends StatelessWidget {
  const OdigaBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  }) : assert(currentIndex >= 0 && currentIndex < 4);
  final int currentIndex;
  final ValueChanged<int> onChanged;
  static const _labels = ['홈', '저장 코스', '친구', '마이'];
  static const _normal = ['72bd7.svg', 'ea1c0.svg', '63d1d.svg', '9b406.svg'];
  static const _active = ['d6e20.svg', '8e873.svg', 'e4b50.svg', '9156d.svg'];
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEBE5F2), width: .6),
        ),
        child: Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: Semantics(
                selected: currentIndex == index,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _svg(
                        currentIndex == index ? _active[index] : _normal[index],
                        22,
                        22,
                      ),
                      const SizedBox(height: 4),
                      _text(
                        _labels[index],
                        11,
                        color: currentIndex == index
                            ? OdigaTokens.brand
                            : OdigaTokens.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: OdigaTokens.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

enum RecommendationSheetSize { collapsed, medium, expanded }

class BottomSheetSurface extends StatelessWidget {
  const BottomSheetSurface({
    super.key,
    this.size = RecommendationSheetSize.collapsed,
    this.child,
    this.onHandleTap,
    this.onHandleDragEnd,
  });
  final RecommendationSheetSize size;
  final Widget? child;
  final VoidCallback? onHandleTap;
  final GestureDragEndCallback? onHandleDragEnd;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    height: switch (size) {
      RecommendationSheetSize.collapsed => 100,
      RecommendationSheetSize.medium => 340,
      RecommendationSheetSize.expanded => 610,
    },
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x241F173B),
          offset: Offset(0, -3),
          blurRadius: 7,
        ),
      ],
    ),
    child: Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onHandleTap,
          onVerticalDragEnd: onHandleDragEnd,
          child: const SheetHandle(),
        ),
        if (child != null) Expanded(child: child!),
      ],
    ),
  );
}

/// Controlled sheet. Place inside an Align(alignment: Alignment.bottomCenter).
class BottomSheetRecommendations extends StatelessWidget {
  const BottomSheetRecommendations({
    super.key,
    required this.size,
    required this.onSizeChanged,
    required this.cards,
    this.selectedTitle = '',
  });
  final RecommendationSheetSize size;
  final ValueChanged<RecommendationSheetSize> onSizeChanged;
  final List<RankedCourseCard> cards;
  final String selectedTitle;
  void _cycle() => onSizeChanged(switch (size) {
    RecommendationSheetSize.collapsed => RecommendationSheetSize.medium,
    RecommendationSheetSize.medium => RecommendationSheetSize.expanded,
    RecommendationSheetSize.expanded => RecommendationSheetSize.collapsed,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onVerticalDragEnd: (d) {
      final velocity = d.primaryVelocity ?? 0;
      if (velocity < -100) {
        onSizeChanged(
          size == RecommendationSheetSize.collapsed
              ? RecommendationSheetSize.medium
              : RecommendationSheetSize.expanded,
        );
      } else if (velocity > 100) {
        onSizeChanged(
          size == RecommendationSheetSize.expanded
              ? RecommendationSheetSize.medium
              : RecommendationSheetSize.collapsed,
        );
      }
    },
    child: BottomSheetSurface(
      size: size,
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: InkWell(
              onTap: _cycle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _text(
                      '추천 ${cards.length}개${size == RecommendationSheetSize.collapsed && selectedTitle.isNotEmpty ? ' · $selectedTitle' : ''}',
                      14,
                      color: OdigaTokens.brand,
                      weight: FontWeight.w500,
                    ),
                  ),
                  _text(
                    size == RecommendationSheetSize.expanded
                        ? '지도 크게 ⌄'
                        : '펼치기 ⌃',
                    11,
                    color: OdigaTokens.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          if (size != RecommendationSheetSize.collapsed)
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: cards.length,
                itemBuilder: (_, i) => cards[i],
                separatorBuilder: (_, i) => const SizedBox(height: 8),
              ),
            ),
        ],
      ),
    ),
  );
}

class MapTravelTime extends StatelessWidget {
  const MapTravelTime({super.key, this.label = '도보 10분'});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: OdigaTokens.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x241F173B),
          offset: Offset(0, 2),
          blurRadius: 3,
        ),
      ],
    ),
    child: Center(widthFactor: 1, child: _text(label, 11)),
  );
}

class MapRouteSegment extends StatelessWidget {
  const MapRouteSegment({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    height: 8,
    child: OverflowBox(
      maxWidth: 108,
      maxHeight: 8,
      child: _svg('0a386.svg', 108, 8),
    ),
  );
}
