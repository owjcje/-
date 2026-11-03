import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/app.dart';

/// 初始化 Riverpod 容器并启动工时记录应用。
void main() {
  runApp(
    const ProviderScope(
      child: WorkTimeTrackerApp(),
    ),
  );
}
