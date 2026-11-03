import 'package:flutter/material.dart';
import 'package:work_time_tracker/application/work_status_filter.dart';

/// 统一展示任务与子任务列表的状态筛选标签。
class AppStatusFilterBar extends StatelessWidget {
  const AppStatusFilterBar({
    required this.selectedFilter,
    required this.labelBuilder,
    required this.semanticIdentifierPrefix,
    required this.onSelected,
    super.key,
  });

  final WorkStatusFilter selectedFilter;
  final String Function(WorkStatusFilter filter) labelBuilder;
  final String semanticIdentifierPrefix;
  final ValueChanged<WorkStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, // 状态标签横向间距
      runSpacing: 8, // 状态标签换行间距
      children: WorkStatusFilter.values.map((WorkStatusFilter filter) {
        return Semantics(
          identifier: '$semanticIdentifierPrefix.${filter.name}', // 自动化测试用标识：由调用方指定的状态筛选标签
          child: ChoiceChip(
            label: Text(labelBuilder(filter)),
            selected: selectedFilter == filter,
            onSelected: (bool isSelected) {
              if (isSelected) {
                onSelected(filter);
              }
            },
          ),
        );
      }).toList(growable: false),
    );
  }
}
