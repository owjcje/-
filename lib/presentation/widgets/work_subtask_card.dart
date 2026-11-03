import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/item_action_state.dart';
import 'package:work_time_tracker/application/time_entry_list_state.dart';
import 'package:work_time_tracker/application/time_tracker_providers.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';
import 'package:work_time_tracker/core/utils/time_formatters.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/entities/work_subtask_summary.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';
import 'package:work_time_tracker/presentation/widgets/design/glass_dialog.dart';
import 'package:work_time_tracker/presentation/widgets/work_item_management_dialogs.dart';

enum _SubtaskMenuAction { editTitle, editNote, delete }

/// 子任务卡片入口，组合任务信息、计时控制、排序与管理操作。
class WorkSubtaskCard extends ConsumerStatefulWidget {
  const WorkSubtaskCard({
    required this.subtaskId,
    required this.reorderIndex,
    required this.isReorderEnabled,
    required this.onEditSubtask,
    required this.onEditSubtaskNote,
    required this.onDeleteSubtask,
    super.key,
  });

  final String subtaskId;
  final int reorderIndex;
  final bool isReorderEnabled;
  final ValueChanged<WorkSubtaskSummary> onEditSubtask;
  final ValueChanged<WorkSubtaskSummary> onEditSubtaskNote;
  final ValueChanged<WorkSubtaskSummary> onDeleteSubtask;

  @override
  ConsumerState<WorkSubtaskCard> createState() {
    return _WorkSubtaskCardState();
  }
}

/// 展示子任务状态、计时操作、明细记录以及编辑删除入口。
class _WorkSubtaskCardState extends ConsumerState<WorkSubtaskCard> {
  bool _isTimeEntryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WorkSubtaskSummary?> subtaskValue = ref.watch(
      subtaskSummaryProvider(widget.subtaskId),
    );
    return subtaskValue.when(
      data: (WorkSubtaskSummary? subtask) {
        return subtask == null
            ? const SizedBox.shrink()
            : _buildCard(context, subtask);
      },
      loading: () => const SizedBox(
        height: 48, // 子任务加载占位高度与树节点一致
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (Object error, StackTrace stackTrace) {
        return Center(child: Text(AppLocalizations.of(context).dataLoadFailed));
      },
    );
  }

  Widget _buildCard(BuildContext context, WorkSubtaskSummary subtask) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ItemActionState actionState = ref.watch(
      subtaskItemViewModelProvider(subtask.id),
    );
    return Semantics(
      identifier: 'workTimeTrackerPage.subtaskCard.${subtask.id}', // 自动化测试用标识：子任务树节点
      container: true,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppGlassTokens.softBorder)),
        ),
        child: _buildTreeContent(context, localizations, subtask, actionState),
      ),
    );
  }

  Widget _buildTreeContent(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return constraints.maxWidth >= 680 // 树节点单行展示断点
                ? _buildWideTreeNode(context, localizations, subtask, actionState)
                : _buildCompactTreeNode(context, localizations, subtask, actionState);
          },
        ),
        if (actionState.errorMessage != null) _buildErrorMessage(localizations),
        if (_isTimeEntryExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 38, bottom: 4),
            child: _TimeEntryList(subtaskId: subtask.id),
          ),
      ],
    );
  }

  Widget _buildErrorMessage(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.only(left: 38, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          localizations.dataSaveFailed,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildWideTreeNode(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return SizedBox(
      height: 48, // 单行树节点高度，便于同屏查看更多任务
      child: Row(
        children: <Widget>[
          const _TreeBranch(),
          _buildStatusSelector(localizations, subtask, actionState),
          const SizedBox(width: 8),
          Expanded(child: _buildTreeTitle(context, subtask)),
          const SizedBox(width: 12),
          _buildTreeDuration(context, subtask),
          _buildCompactTimerButton(localizations, subtask, actionState),
          _buildCompactHistoryButton(localizations, subtask),
          _buildCompactManagementMenu(localizations, subtask),
          if (widget.isReorderEnabled)
            _buildCompactDragHandle(localizations, subtask),
        ],
      ),
    );
  }

  Widget _buildCompactTreeNode(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: _TreeBranch(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildTreeTitle(context, subtask),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    _buildStatusSelector(localizations, subtask, actionState),
                    const SizedBox(width: 8),
                    _buildTreeDuration(context, subtask),
                  ],
                ),
              ],
            ),
          ),
          _buildCompactTimerButton(localizations, subtask, actionState),
          _buildCompactHistoryButton(localizations, subtask),
          _buildCompactManagementMenu(localizations, subtask),
          if (widget.isReorderEnabled)
            _buildCompactDragHandle(localizations, subtask),
        ],
      ),
    );
  }

  Widget _buildTreeTitle(BuildContext context, WorkSubtaskSummary subtask) {
    final String displayTitle = subtask.note.trim().isEmpty
        ? subtask.title
        : '${subtask.title} · ${subtask.note}';
    return Text(
      displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: subtask.isRunning ? FontWeight.w700 : FontWeight.w500,
          ),
    );
  }

  Widget _buildTreeDuration(BuildContext context, WorkSubtaskSummary subtask) {
    return Text(
      formatDuration(subtask.completedSeconds),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: subtask.isRunning
                ? AppGlassTokens.running
                : AppGlassTokens.secondaryContent,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
    );
  }

  Widget _buildCompactTimerButton(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    if (subtask.isRunning) {
      return Semantics(
        identifier: 'workTimeTrackerPage.stopTimerButton.${subtask.id}', // 自动化测试用标识：停止计时按钮
        child: IconButton(
          tooltip: localizations.stopTimer,
          onPressed: actionState.isSaving
              ? null
              : () => ref
                  .read(subtaskItemViewModelProvider(subtask.id).notifier)
                  .stopTracking(),
          icon: const Icon(Icons.stop_circle_outlined, color: AppGlassTokens.running),
        ),
      );
    }
    return Semantics(
      identifier: 'workTimeTrackerPage.startTimerButton.${subtask.id}', // 自动化测试用标识：开始计时按钮
      child: IconButton(
        tooltip: localizations.startTimer,
        onPressed: actionState.isSaving || subtask.status == WorkItemStatus.completed
            ? null
            : () => ref
                .read(subtaskItemViewModelProvider(subtask.id).notifier)
                .startTracking(),
        icon: const Icon(Icons.play_circle_outline),
      ),
    );
  }

  Widget _buildCompactHistoryButton(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.timeEntryToggle.${subtask.id}', // 自动化测试用标识：计时记录展开收起按钮
      child: IconButton(
        tooltip: localizations.timeEntryCount(subtask.timeEntryCount),
        onPressed: () {
          setState(() {
            _isTimeEntryExpanded = !_isTimeEntryExpanded;
          });
        },
        icon: Icon(
          _isTimeEntryExpanded ? Icons.expand_less : Icons.history_outlined,
        ),
      ),
    );
  }

  Widget _buildCompactManagementMenu(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.subtaskMoreButton.${subtask.id}', // 自动化测试用标识：子任务更多操作按钮
      child: PopupMenuButton<_SubtaskMenuAction>(
        tooltip: localizations.moreActions,
        icon: const Icon(Icons.more_horiz),
        onSelected: (_SubtaskMenuAction action) {
          switch (action) {
            case _SubtaskMenuAction.editTitle:
              widget.onEditSubtask(subtask);
              return;
            case _SubtaskMenuAction.editNote:
              widget.onEditSubtaskNote(subtask);
              return;
            case _SubtaskMenuAction.delete:
              widget.onDeleteSubtask(subtask);
              return;
          }
        },
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<_SubtaskMenuAction>>[
            PopupMenuItem<_SubtaskMenuAction>(
              value: _SubtaskMenuAction.editTitle,
              child: Semantics(
                identifier: 'workTimeTrackerPage.editSubtaskButton.${subtask.id}', // 自动化测试用标识：编辑子任务名称按钮
                child: Text(localizations.edit),
              ),
            ),
            PopupMenuItem<_SubtaskMenuAction>(
              value: _SubtaskMenuAction.editNote,
              child: Semantics(
                identifier: 'workTimeTrackerPage.editSubtaskNoteButton.${subtask.id}', // 自动化测试用标识：编辑子任务备注按钮
                child: Text(localizations.editSubtaskNote),
              ),
            ),
            PopupMenuItem<_SubtaskMenuAction>(
              value: _SubtaskMenuAction.delete,
              child: Semantics(
                identifier: 'workTimeTrackerPage.deleteSubtaskButton.${subtask.id}', // 自动化测试用标识：删除子任务按钮
                child: Text(localizations.delete),
              ),
            ),
          ];
        },
      ),
    );
  }

  Widget _buildCompactDragHandle(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.subtaskDragHandle.${subtask.id}', // 自动化测试用标识：子任务拖动排序手柄
      child: ReorderableDragStartListener(
        index: widget.reorderIndex,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.drag_indicator,
            size: 18,
            color: AppGlassTokens.tertiaryContent,
            semanticLabel: localizations.dragToReorder,
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration(WorkSubtaskSummary subtask) {
    return BoxDecoration(
      color: subtask.isRunning
          ? AppGlassTokens.softSurface
          : AppGlassTokens.subtleSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: subtask.isRunning
            ? AppGlassTokens.primaryBorder
            : AppGlassTokens.glassBorder,
      ),
    );
  }

  Widget _buildResponsiveContent(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return constraints.maxWidth >= 680 // 子任务卡横向布局断点
            ? _buildWideContent(context, localizations, subtask, actionState)
            : _buildCompactContent(
                context,
                localizations,
                subtask,
                actionState,
              );
      },
    );
  }

  Widget _buildWideContent(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return Row(
      children: <Widget>[
        Expanded(flex: 3, child: _buildIdentity(context, localizations, subtask, actionState)),
        const SizedBox(width: 20),
        Expanded(flex: 4, child: _buildTimingDetails(context, localizations, subtask)),
        const SizedBox(width: 20),
        _buildActionButton(localizations, subtask, actionState),
      ],
    );
  }

  Widget _buildCompactContent(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildIdentity(context, localizations, subtask, actionState),
        const SizedBox(height: 16),
        _buildTimingDetails(context, localizations, subtask),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: _buildActionButton(localizations, subtask, actionState),
        ),
      ],
    );
  }

  Widget _buildIdentity(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              subtask.isRunning
                  ? Icons.radio_button_checked
                  : Icons.circle_outlined,
              size: 18,
              color: subtask.isRunning
                  ? AppGlassTokens.running
                  : AppGlassTokens.tertiaryContent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                subtask.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (widget.isReorderEnabled)
              Semantics(
                identifier: 'workTimeTrackerPage.subtaskDragHandle.${subtask.id}', // 自动化测试用标识：子任务拖动排序手柄
                child: ReorderableDragStartListener(
                  index: widget.reorderIndex,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: AppGlassTokens.tertiaryContent,
                      semanticLabel: localizations.dragToReorder,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildStatusSelector(localizations, subtask, actionState),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: _buildManagementActions(localizations, subtask),
        ),
      ],
    );
  }

  Widget _buildManagementActions(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          identifier: 'workTimeTrackerPage.editSubtaskButton.${subtask.id}', // 自动化测试用标识：编辑子任务名称按钮
          child: IconButton(
            tooltip: localizations.edit,
            onPressed: () => widget.onEditSubtask(subtask),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ),
        Semantics(
          identifier: 'workTimeTrackerPage.editSubtaskNoteButton.${subtask.id}', // 自动化测试用标识：编辑子任务备注按钮
          child: IconButton(
            tooltip: localizations.editSubtaskNote,
            onPressed: () => widget.onEditSubtaskNote(subtask),
            icon: const Icon(Icons.note_alt_outlined, size: 20),
          ),
        ),
        Semantics(
          identifier: 'workTimeTrackerPage.deleteSubtaskButton.${subtask.id}', // 自动化测试用标识：删除子任务按钮
          child: IconButton(
            tooltip: localizations.delete,
            onPressed: () => widget.onDeleteSubtask(subtask),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSelector(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.subtaskStatusSelect.${subtask.id}', // 自动化测试用标识：子任务状态选择器
      child: PopupMenuButton<WorkItemStatus>(
        enabled: !actionState.isSaving,
        initialValue: subtask.status,
        tooltip: localizations.selectStatus,
        onSelected: (WorkItemStatus status) {
          ref
              .read(subtaskItemViewModelProvider(subtask.id).notifier)
              .updateStatus(status);
        },
        itemBuilder: (BuildContext context) {
          return WorkItemStatus.values.map((WorkItemStatus status) {
            return PopupMenuItem<WorkItemStatus>(
              value: status,
              child: Semantics(
                identifier: 'workTimeTrackerPage.subtaskStatusOption.${subtask.id}.${status.name}', // 自动化测试用标识：子任务状态选项
                child: Text(localizations.workItemStatus(status)),
              ),
            );
          }).toList(growable: false);
        },
        child: Text(localizations.workItemStatus(subtask.status)),
      ),
    );
  }

  Widget _buildTimingDetails(
    BuildContext context,
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
  ) {
    return Wrap(
      spacing: 26,
      runSpacing: 12,
      children: <Widget>[
        _buildTimeField(context, localizations.createdAt, formatDate(subtask.createdAt), false),
        _buildTimeField(context, localizations.totalTime, formatDuration(subtask.completedSeconds), true),
        _buildTimeField(context, localizations.startedAt, _formatOptionalTime(localizations, subtask.lastStartedAt), false),
        _buildTimeField(context, localizations.endedAt, subtask.isRunning ? localizations.currentTiming : _formatOptionalTime(localizations, subtask.lastEndedAt), false),
      ],
    );
  }

  Widget _buildTimeField(
    BuildContext context,
    String label,
    String value,
    bool isEmphasized,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppGlassTokens.secondaryContent,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
    ItemActionState actionState,
  ) {
    if (subtask.isRunning) {
      return Semantics(
        identifier: 'workTimeTrackerPage.stopTimerButton.${subtask.id}', // 自动化测试用标识：停止计时按钮
        child: FilledButton.icon(
          onPressed: actionState.isSaving
              ? null
              : () => ref
                  .read(subtaskItemViewModelProvider(subtask.id).notifier)
                  .stopTracking(),
          icon: const Icon(Icons.stop_rounded, size: 18),
          label: Text(localizations.stopTimer),
          style: FilledButton.styleFrom(
            backgroundColor: AppGlassTokens.running,
          ),
        ),
      );
    }
    return Semantics(
      identifier: 'workTimeTrackerPage.startTimerButton.${subtask.id}', // 自动化测试用标识：开始计时按钮
      child: OutlinedButton.icon(
        onPressed: actionState.isSaving || subtask.status == WorkItemStatus.completed
            ? null
            : () => ref
                .read(subtaskItemViewModelProvider(subtask.id).notifier)
                .startTracking(),
        icon: const Icon(Icons.play_arrow_rounded, size: 19),
        label: Text(localizations.startTimer),
      ),
    );
  }

  Widget _buildTimeEntryToggle(
    AppLocalizations localizations,
    WorkSubtaskSummary subtask,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.timeEntryToggle.${subtask.id}', // 自动化测试用标识：计时记录展开收起按钮
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: false,
        tilePadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        onExpansionChanged: (bool isExpanded) {
          setState(() {
            _isTimeEntryExpanded = isExpanded;
          });
        },
        title: Text(
          localizations.timeEntryCount(subtask.timeEntryCount),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        children: _isTimeEntryExpanded
            ? <Widget>[_TimeEntryList(subtaskId: subtask.id)]
            : const <Widget>[],
      ),
    );
  }

  String _formatOptionalTime(
    AppLocalizations localizations,
    DateTime? dateTime,
  ) {
    return dateTime == null
        ? localizations.notRecorded
        : formatDateTime(dateTime);
  }
}

class _TreeBranch extends StatelessWidget {
  const _TreeBranch();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 30, // 树状连接线预留宽度
      height: 24,
      child: CustomPaint(painter: _TreeBranchPainter()),
    );
  }
}

class _TreeBranchPainter extends CustomPainter {
  const _TreeBranchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppGlassTokens.tertiaryContent
      ..strokeWidth = 1;
    final double centerY = size.height / 2;
    canvas.drawLine(Offset(14, 0), Offset(14, centerY), paint);
    canvas.drawLine(Offset(14, centerY), Offset(size.width, centerY), paint);
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) {
    return false;
  }
}

class _TimeEntryList extends ConsumerWidget {
  const _TimeEntryList({required this.subtaskId});

  final String subtaskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TimeEntryListState state = ref.watch(
      timeEntryListViewModelProvider(subtaskId),
    );
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      );
    }
    if (state.errorMessage != null && state.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(localizations.dataLoadFailed),
      );
    }
    if (state.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(localizations.notRecorded),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.entries.length + (state.hasMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index == state.entries.length) {
          return _buildLoadMore(ref, localizations, state);
        }
        return _buildEntryRow(context, ref, localizations, state.entries[index]);
      },
    );
  }

  Widget _buildLoadMore(
    WidgetRef ref,
    AppLocalizations localizations,
    TimeEntryListState state,
  ) {
    return Center(
      child: TextButton(
        onPressed: state.isLoadingMore
            ? null
            : () => ref
                .read(timeEntryListViewModelProvider(subtaskId).notifier)
                .loadMore(),
        child: Text(
          state.isLoadingMore ? localizations.loading : localizations.loadMore,
        ),
      ),
    );
  }

  Widget _buildEntryRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations localizations,
    WorkTimeEntry entry,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.timeEntryRow.${entry.id}', // 自动化测试用标识：单次计时记录行
      child: ListTile(
        dense: true,
        title: Text(formatDateTime(entry.startedAt)),
        subtitle: Text(
          entry.endedAt == null
              ? localizations.currentTiming
              : formatDateTime(entry.endedAt),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              entry.completedSeconds == null
                  ? localizations.currentTiming
                  : formatDuration(entry.completedSeconds!),
            ),
            Semantics(
              identifier: 'workTimeTrackerPage.editTimeEntryButton.${entry.id}', // 自动化测试用标识：编辑计时记录时间按钮
              child: IconButton(
                tooltip: localizations.editTime,
                onPressed: () => _showEditTimeEntryDialog(context, ref, entry),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTimeEntryDialog(
    BuildContext context,
    WidgetRef ref,
    WorkTimeEntry entry,
  ) async {
    final TimeEntryEditResult? result = await showDialog<TimeEntryEditResult>(
      context: context,
      builder: (BuildContext context) {
        return GlassDialog(child: EditTimeEntryDialog(entry: entry));
      },
    );
    if (result == null || !context.mounted) {
      return;
    }
    final bool isUpdated = await ref
        .read(timeEntryListViewModelProvider(subtaskId).notifier)
        .updateEntryTime(
          entryId: entry.id,
          startedAt: result.startedAt,
          endedAt: result.endedAt,
        );
    if (!isUpdated && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).dataSaveFailed)),
      );
    }
  }
}
