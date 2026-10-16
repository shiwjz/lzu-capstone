import 'package:flutter/material.dart';

import 'odiga_components.dart';

/// Figma 133:1972, 133:2243: shared collapsed/medium/expanded content sheet.
/// Parent owns the size; children scroll independently from the drag header.
class OdigaContentSheet extends StatelessWidget {
  const OdigaContentSheet({
    super.key,
    required this.title,
    required this.size,
    required this.onSizeChanged,
    required this.children,
  });

  final String title;
  final RecommendationSheetSize size;
  final ValueChanged<RecommendationSheetSize> onSizeChanged;
  final List<Widget> children;

  void _toggle() => onSizeChanged(switch (size) {
    RecommendationSheetSize.collapsed => RecommendationSheetSize.medium,
    RecommendationSheetSize.medium => RecommendationSheetSize.expanded,
    RecommendationSheetSize.expanded => RecommendationSheetSize.collapsed,
  });

  void _drag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 100) return;
    final index = (size.index + (velocity < 0 ? 1 : -1)).clamp(0, 2);
    final next = RecommendationSheetSize.values[index];
    if (next != size) onSizeChanged(next);
  }

  @override
  Widget build(BuildContext context) => BottomSheetSurface(
    size: size,
    onHandleTap: _toggle,
    onHandleDragEnd: _drag,
    child: Column(
      children: [
        GestureDetector(
          onVerticalDragEnd: _drag,
          child: Semantics(
            button: true,
            label: '$title, ${size.name}',
            child: InkWell(
              onTap: _toggle,
              child: SizedBox(
                height: 34,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OdigaTokens.text(
                          14,
                          color: OdigaTokens.brand,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      size == RecommendationSheetSize.expanded
                          ? '내리기 ⌄'
                          : '올리기 ⌃',
                      style: OdigaTokens.text(11, color: OdigaTokens.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (size != RecommendationSheetSize.collapsed)
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: children.length,
              itemBuilder: (_, index) => children[index],
              separatorBuilder: (_, index) => const SizedBox(height: 6),
            ),
          ),
      ],
    ),
  );
}

/// The same category strip is used by home, editing, and adding places.
class OdigaCategoryFilter extends StatelessWidget {
  const OdigaCategoryFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    this.categories = const ['전체', '음식점', '카페', '놀거리', '문화시설'],
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final List<String> categories;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    color: OdigaTokens.background,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, index) => const SizedBox(width: 6),
      itemBuilder: (_, index) {
        final label = categories[index];
        return Align(
          alignment: Alignment.topCenter,
          child: OdigaTag(
            label: label,
            width: switch (label) {
              '전체' || '카페' => 50,
              '음식점' || '놀거리' => 55,
              '문화시설' => 66,
              _ => 78,
            },
            selected: selected == label,
            onSelected: (_) => onChanged(label),
          ),
        );
      },
    ),
  );
}

/// Figma 133:1937: summary supplied by the course calculation/state layer.
class CourseSummaryCard extends StatelessWidget {
  const CourseSummaryCard({
    super.key,
    required this.summary,
    required this.detail,
  });

  final String summary, detail;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 72),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: OdigaTokens.lavender,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary,
          style: OdigaTokens.text(
            14,
            color: OdigaTokens.brand,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(detail, style: OdigaTokens.text(11, color: OdigaTokens.brand)),
      ],
    ),
  );
}

/// Figma 133:1940: one reusable stop for every deletion/order/duration state.
/// Pass ReorderableDragStartListener as [reorderHandle] inside a reorderable list.
class CourseStopTile extends StatelessWidget {
  const CourseStopTile({
    super.key,
    required this.order,
    required this.title,
    required this.visitLabel,
    required this.stayMinutes,
    this.onStayPressed,
    this.onDelete,
    this.reorderHandle,
  }) : assert(order > 0),
       assert(stayMinutes > 0);

  final int order, stayMinutes;
  final String title, visitLabel;
  final VoidCallback? onStayPressed, onDelete;
  final Widget? reorderHandle;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 66),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        reorderHandle ??
            Text(
              '≡',
              style: OdigaTokens.text(
                18,
                color: OdigaTokens.muted,
                weight: FontWeight.w700,
              ),
            ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$order. $title',
                style: OdigaTokens.text(14, weight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                visitLabel,
                style: OdigaTokens.text(11, color: OdigaTokens.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: OdigaButton(
            label: '$stayMinutes분 ⌄',
            height: 28,
            variant: OdigaButtonVariant.secondary,
            onPressed: onStayPressed,
          ),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: Semantics(
            button: true,
            label: '$title 삭제',
            excludeSemantics: true,
            enabled: onDelete != null,
            onTap: onDelete,
            child: InkWell(
              onTap: onDelete,
              child: Center(
                child: Text(
                  '×',
                  style: OdigaTokens.text(14, color: OdigaTokens.muted),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Figma 133:1948: connector between course stops (not a map overlay).
class CourseTravelDivider extends StatelessWidget {
  const CourseTravelDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: OdigaTokens.background,
    child: Center(
      child: Text(
        '↓ $label',
        style: OdigaTokens.text(11, color: OdigaTokens.muted),
      ),
    ),
  );
}

/// Figma 133:2221–133:2236: shared by individual and group recommendation reasons.
class RecommendationReasonRow extends StatelessWidget {
  const RecommendationReasonRow({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 41),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: OdigaTokens.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            label,
            style: OdigaTokens.text(11, color: OdigaTokens.muted),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(flex: 2, child: Text(value, style: OdigaTokens.text(11))),
      ],
    ),
  );
}

/// Figma 133:2218. Rank and explanation change without a separate widget type.
class RecommendationRankHeader extends StatelessWidget {
  const RecommendationRankHeader({
    super.key,
    required this.rank,
    this.description = '조건·혼잡도·동선 종합',
  }) : assert(rank > 0);
  final int rank;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: OdigaTokens.lavender,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$rank순위',
          style: OdigaTokens.text(
            18,
            color: OdigaTokens.brand,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            textAlign: TextAlign.end,
            style: OdigaTokens.text(11, color: OdigaTokens.muted),
          ),
        ),
      ],
    ),
  );
}

/// Figma 29:402, 29:408, 29:414. Reuses the existing avatar.
class FriendCard extends StatelessWidget {
  const FriendCard({
    super.key,
    required this.name,
    required this.initial,
    required this.status,
    this.onTap,
  });

  final String name, initial, status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OdigaAvatar(initial: initial),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: OdigaTokens.text(14, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status,
                    style: OdigaTokens.text(11, color: OdigaTokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
