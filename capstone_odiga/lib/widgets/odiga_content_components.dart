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

enum RecommendationReasonPopupState { keyword, firstRank }

/// Figma 2147:3936: shared popup for keyword and first-rank explanations.
class RecommendationReasonPopup extends StatelessWidget {
  const RecommendationReasonPopup({
    super.key,
    required this.state,
    required this.rank,
    required this.courseTitle,
    required this.keyword,
    required this.conditionMatch,
    required this.congestion,
    required this.distance,
    required this.stay,
    required this.placeFeatures,
    required this.groupPreference,
    required this.onClose,
  });

  final RecommendationReasonPopupState state;
  final int rank;
  final String courseTitle;
  final String keyword;
  final String conditionMatch;
  final String congestion;
  final String distance;
  final String stay;
  final String placeFeatures;
  final String groupPreference;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
    label: state == RecommendationReasonPopupState.keyword
        ? '키워드 추천 근거'
        : '$rank순위 추천 근거',
    child: Container(
      width: 350,
      height: 550,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: OdigaTokens.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(19, 14, 19, 19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '추천 근거',
                      style: OdigaTokens.text(18, weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    icon: const Icon(
                      Icons.close,
                      size: 21,
                      color: OdigaTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '키워드에 담긴 추천 이유를 확인해 보세요.',
              style: OdigaTokens.text(12, color: OdigaTokens.muted),
            ),
            const SizedBox(height: 17),
            const Divider(height: 1, color: OdigaTokens.border),
            const SizedBox(height: 13),
            Text(
              '$rank순위  $courseTitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OdigaTokens.text(16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            Container(
              constraints: const BoxConstraints(minWidth: 102, minHeight: 26),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: OdigaTokens.lavender,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                keyword,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OdigaTokens.text(12, color: OdigaTokens.brand),
              ),
            ),
            const SizedBox(height: 13),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _RecommendationPopupRow(
                      label: '사용자 조건 일치도',
                      value: conditionMatch,
                    ),
                    _RecommendationPopupRow(label: '예상 혼잡도', value: congestion),
                    _RecommendationPopupRow(label: '이동거리', value: distance),
                    _RecommendationPopupRow(label: '체류시간', value: stay),
                    _RecommendationPopupRow(
                      label: '장소 특징',
                      value: placeFeatures,
                    ),
                    _RecommendationPopupRow(
                      label: '그룹 선호도',
                      value: groupPreference,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 60,
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
                      decoration: BoxDecoration(
                        color: OdigaTokens.lavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '추천에 반영한 조건',
                            style: OdigaTokens.text(
                              11,
                              weight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '조건 30% · 혼잡도 25% · 거리 15%',
                            style: OdigaTokens.text(
                              10,
                              color: OdigaTokens.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '체류 10% · 특징 10% · 그룹 10%',
                            style: OdigaTokens.text(
                              10,
                              color: OdigaTokens.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecommendationPopupRow extends StatelessWidget {
  const _RecommendationPopupRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    height: 41,
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: OdigaTokens.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OdigaTokens.text(10, color: OdigaTokens.muted),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OdigaTokens.text(10),
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
