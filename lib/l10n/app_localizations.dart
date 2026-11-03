import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:work_time_tracker/application/work_status_filter.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';

/// 集中提供界面中的中文文案，避免页面直接硬编码用户可见文本。
class AppLocalizations {
  const AppLocalizations();

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh', 'CN'),
  ];

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations is not available.');
    return localizations!;
  }

  String get appTitle => '工时记录';
  String get navigationTitle => '任务';
  String get localStorageNotice => '任务与计时记录保存在本机';
  String get noTaskSelected => '创建或选择一个任务后查看详情';
  String get noTasksYet => '还没有任务，请先创建一个任务';
  String get noSubtasksYet => '当前任务还没有子任务';
  String get dataLoadFailed => '数据加载失败，请稍后重试';
  String get dataSaveFailed => '保存失败，请重试';
  String get loading => '加载中';
  String get loadMore => '加载更多';
  String get all => '全部';
  String get inProgress => '进行中';
  String get notStarted => '未开始';
  String get completed => '已结束';
  String get taskSearchHint => '搜索任务';
  String get subtaskSearchHint => '搜索子任务';
  String get createTask => '创建任务';
  String get export => '导出';
  String get exportWorkTime => '导出工时 Excel';
  String get exportDateRange => '导出日期范围';
  String get exportTaskSelectionHint => '请选择需要导出的主任务，可多选。';
  String get selectAll => '全选';
  String get clearSelection => '取消全选';
  String get exportCompleted => 'Excel 已导出';
  String get exportFailed => '导出失败，请重试';
  String get noTasksAvailableForExport => '没有可导出的主任务';
  String get exportSummarySheetName => '任务汇总';
  String get exportDetailSheetName => '子任务明细';
  String get exportTaskColumn => '主任务';
  String get exportTotalDurationColumn => '累计耗时（时:分:秒）';
  String get exportSubtaskCountColumn => '子任务数量';
  String get exportSubtaskColumn => '子任务';
  String get exportSubtaskNoteColumn => '备注';
  String get exportSubtaskDurationColumn => '子任务累计耗时（时:分:秒）';
  String get exportEntryNumberColumn => '记录序号';
  String get exportEntryDurationColumn => '本段耗时（时:分:秒）';
  String get exportFirstStartedAtColumn => '本段开始时间';
  String get exportLastEndedAtColumn => '本段结束时间';
  String get excelFileTypeLabel => 'Excel 文件';
  String get exportFileNamePrefix => '工时导出';
  String get exportEmptyValue => '';
  String get createSubtask => '创建子任务';
  String get taskName => '任务名称';
  String get subtaskName => '子任务名称';
  String get selectStatus => '选择状态';
  String get cancel => '取消';
  String get create => '创建';
  String get save => '保存';
  String get edit => '重新编辑';
  String get delete => '删除';
  String get editTaskTitle => '编辑任务名称';
  String get editSubtaskTitle => '编辑子任务名称';
  String get editSubtaskNote => '编辑子任务备注';
  String get editTimeEntry => '编辑计时记录';
  String get editTime => '编辑时间';
  String get runningEntryEditHint => '保存后将以所选结束时间停止当前计时。';
  String get invalidTimeRange => '结束时间必须晚于开始时间';
  String get subtaskNote => '备注';
  String get deleteTask => '删除任务';
  String get deleteSubtask => '删除子任务';
  String get moreActions => '更多操作';
  String get dragToReorder => '拖动排序';
  String get status => '状态';
  String get createdAt => '创建日期';
  String get noMatchingTasks => '没有符合条件的任务';
  String get noMatchingSubtasks => '没有符合条件的子任务';
  String get totalTime => '累计工时';
  String get taskOverview => '任务概览';
  String get subtaskList => '子任务';
  String get running => '计时中';
  String get idle => '未计时';
  String get startTimer => '开始计时';
  String get stopTimer => '停止计时';
  String get startedAt => '开始时间';
  String get endedAt => '结束时间';
  String get notRecorded => '尚未记录';
  String get timeEntries => '计时记录';
  String get entryNumber => '次数';
  String get duration => '本次用时';
  String get currentTiming => '计时中';
  String subtaskCount(int count) => '$count 个子任务';
  String timeEntryCount(int count) => '$count 条记录';
  String createdOn(String date) => '创建于 $date';
  String taskProgress(int completed, int total) => '$completed / $total 已投入工时';
  String deleteTaskConfirmation(String title) =>
      '确定删除“$title”吗？其子任务和全部计时记录也会一并删除，此操作无法撤销。';
  String deleteSubtaskConfirmation(String title) =>
      '确定删除“$title”吗？该子任务的全部计时记录也会一并删除，此操作无法撤销。';

  String workItemStatus(WorkItemStatus status) {
    return switch (status) {
      WorkItemStatus.inProgress => inProgress,
      WorkItemStatus.notStarted => notStarted,
      WorkItemStatus.completed => completed,
    };
  }

  String statusFilter(WorkStatusFilter filter) {
    return switch (filter) {
      WorkStatusFilter.all => all,
      WorkStatusFilter.inProgress => inProgress,
      WorkStatusFilter.notStarted => notStarted,
      WorkStatusFilter.completed => completed,
    };
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'zh';
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(const AppLocalizations());
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) {
    return false;
  }
}
