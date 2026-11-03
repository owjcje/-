import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';
import 'package:work_time_tracker/core/utils/time_formatters.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';
import 'package:work_time_tracker/presentation/widgets/design/glass_surface.dart';

/// 展示当前主任务的名称、创建时间、总工时与投入进度。
class TaskSummaryHeader extends StatelessWidget {
  const TaskSummaryHeader({
    required this.task,
    super.key,
  });

  final WorkTaskSummary task;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return GlassSurface(
      isBlurred: true,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 32,
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _buildTitle(context, localizations),
          _buildTotalTime(context, localizations),
        ],
      ),
    );
  }

  Widget _buildTitle(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          localizations.taskOverview,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppGlassTokens.secondaryContent,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(task.colorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              task.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Semantics(
          identifier: 'workTimeTrackerPage.selectedTaskCreatedAt.${task.id}', // 自动化测试用标识：当前主任务创建日期
          child: Text(
            localizations.createdOn(formatDate(task.createdAt)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppGlassTokens.secondaryContent,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalTime(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          localizations.totalTime,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppGlassTokens.secondaryContent,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          formatDuration(task.completedSeconds),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Color(task.colorValue),
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
        ),
        Text(
          localizations.taskProgress(
            task.trackedSubtaskCount,
            task.subtaskCount,
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF85899A),
              ),
        ),
      ],
    );
  }
}
