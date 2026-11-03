import 'package:flutter_test/flutter_test.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry.dart';

void main() {
  group('WorkTimeEntry', () {
    test('正在计时的记录不产生已完成工时', () {
      final WorkTimeEntry entry = WorkTimeEntry(
        id: 'entry_running',
        subtaskId: 'subtask_1',
        startedAt: DateTime(2026, 10, 28, 9),
      );

      expect(entry.isRunning, isTrue);
      expect(entry.completedSeconds, isNull);
    });

    test('停止计时后按固定开始和结束时间计算工时', () {
      final WorkTimeEntry entry = WorkTimeEntry(
        id: 'entry_completed',
        subtaskId: 'subtask_1',
        startedAt: DateTime(2026, 10, 28, 9),
        endedAt: DateTime(2026, 10, 28, 10, 30),
      );

      expect(entry.isRunning, isFalse);
      expect(entry.completedSeconds, 5400);
    });
  });
}
