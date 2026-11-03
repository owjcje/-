/// 描述本地数据发生的变化，供 Riverpod 协调器刷新受影响的模块。
sealed class WorkDataEvent {
  const WorkDataEvent();
}

final class TaskCreatedEvent extends WorkDataEvent {
  const TaskCreatedEvent({required this.taskId});

  final String taskId;
}

final class SubtaskCreatedEvent extends WorkDataEvent {
  const SubtaskCreatedEvent({
    required this.taskId,
    required this.subtaskId,
  });

  final String taskId;
  final String subtaskId;
}

final class TaskDeletedEvent extends WorkDataEvent {
  const TaskDeletedEvent({required this.taskId});

  final String taskId;
}

final class SubtaskDeletedEvent extends WorkDataEvent {
  const SubtaskDeletedEvent({
    required this.taskId,
    required this.subtaskId,
  });

  final String taskId;
  final String subtaskId;
}

final class WorkItemsChangedEvent extends WorkDataEvent {
  WorkItemsChangedEvent({
    required Set<String> taskIds,
    required Set<String> subtaskIds,
    required this.shouldRefreshTimeEntries,
  })  : taskIds = Set<String>.unmodifiable(taskIds),
        subtaskIds = Set<String>.unmodifiable(subtaskIds);

  final Set<String> taskIds;
  final Set<String> subtaskIds;
  final bool shouldRefreshTimeEntries;
}
