# 玻璃化 UI 统一改造方案

## 目标与边界

- 将桌面端工时记录应用统一为克制的 iOS 磨砂玻璃视觉：柔和背景、半透明分层表面、清晰的高对比数据与明确的主操作。
- 保持现有 SQLite、Repository、Use case、Riverpod 状态与所有业务交互不变。
- 不实现暗色模式；本轮只交付亮色主题。
- 不新增第三方依赖，使用 Flutter 自带的 `BackdropFilter`、`ThemeData` 与 Material 3 组件主题。

## 现有架构结论

当前业务层已满足改造前提，数据流为：

```text
LocalDatabaseService -> LocalTimeTrackerRepository -> Riverpod StateNotifier
-> presentation 页面 / Widget
```

视觉配置目前散落在 `app.dart`、页面和各个 Widget 中；相同的背景色、描边、圆角、按钮、输入框和状态筛选器被多处重复实现。`TaskSidebar`、`TaskDetailPanel`、`WorkSubtaskCard` 同时承担了视觉拼装和局部组件复用职责，导致统一改样成本较高。

## 视觉规则

| 角色 | 方案 |
| --- | --- |
| 画布 | 蓝灰底色叠加两至三个低透明度的柔和色光晕，避免纯白背景使玻璃效果失去层次。 |
| 玻璃表面 | 半透明白色填充、白色细描边、轻阴影；顶栏、侧栏、任务概览和弹窗使用真实背景模糊。 |
| 长列表卡片 | 使用低透明度填充和描边，不对每张卡使用 `BackdropFilter`，保证滚动性能。 |
| 强调色 | 延续现有靛蓝 `#5B5CE2`；任务自身颜色仍只表示任务身份，不改写业务含义。 |
| 状态与危险操作 | 运行中使用绿色语义色；删除始终使用 error 色；不能仅靠透明度或颜色表达状态。 |
| 排版与留白 | 维持当前桌面双栏断点（900）和子任务卡断点（680），增加同一视觉层级内的留白一致性。 |

## 目标文件结构

```text
lib/
  core/theme/
    app_theme.dart                 # 唯一的亮色 ThemeData 入口
    app_glass_tokens.dart          # 跨组件复用的颜色、模糊、描边语义配置
  presentation/widgets/design/
    glass_background.dart          # 全页渐变与装饰光晕
    glass_surface.dart             # 受限范围的磨砂容器
    app_status_filter_bar.dart     # 主任务、子任务共用状态筛选器
    app_empty_state.dart           # 共用空状态 / 错误状态展示
  presentation/pages/
    work_time_tracker_page.dart    # 页面编排和弹窗流程，不承载视觉细节
  presentation/widgets/
    ...                            # 仅保留各业务区域的内容组合
```

`app_glass_tokens.dart` 只放跨页面复用、具有视觉语义的值；单个 Widget 专属的间距、尺寸和圆角继续内联并补充中文用途注释，符合项目现有规范。

## 文件级修改计划

1. `lib/app.dart`
   - 使用 `AppTheme.buildLightTheme()` 构建唯一亮色主题。
   - 统一配置 `FilledButtonThemeData`、`OutlinedButtonThemeData`、`InputDecorationTheme`、`ChipThemeData`、`PopupMenuThemeData`、`DialogThemeData` 与文字层级。

2. 新增 `lib/core/theme/app_theme.dart` 与 `lib/core/theme/app_glass_tokens.dart`
   - 将当前散落的 `#F5F6FA`、白色卡片、灰色描边、辅助文字色等收敛为命名语义值。
   - 不把页面专属的宽高或间距提取为全局常量。

3. 新增 `glass_background.dart` 与 `glass_surface.dart`
   - `GlassBackground` 作为页面唯一背景，承载渐变与光晕。
   - `GlassSurface` 提供 `isBlurred`、`padding`、`borderRadius` 等明确类型参数；内部在 `ClipRRect` 后使用 `BackdropFilter`，避免模糊区域溢出。
   - 只让固定且面积有限的区域启用 `isBlurred`：应用顶栏、任务侧栏、任务概览、弹窗。子任务列表卡片使用非模糊变体。

4. `lib/presentation/pages/work_time_tracker_page.dart`
   - `Scaffold` body 改为 `GlassBackground`。
   - 顶栏改为固定玻璃表面；宽屏时侧栏也作为独立玻璃表面，与详情区保持可读的留白分层。
   - 保留原有选择、创建、编辑、删除和重排回调，不把 Riverpod 操作下沉到设计组件。

5. `task_sidebar.dart` 与 `task_detail_panel.dart`
   - 共同使用 `AppStatusFilterBar` 和主题化搜索框，移除重复的 `ChoiceChip`、输入框及空状态样式。
   - 保持原有 `Semantics.identifier` 不变；共用构建组件需接收显式的 `String semanticIdentifier` 或生成器参数，调用点仍保留逐项中文自动化测试注释。

6. `task_summary_header.dart`、`work_subtask_card.dart`
   - 任务概览使用模糊玻璃表面；运行中的任务采用强调描边、状态胶囊和可见的计时状态，不只依赖淡色背景。
   - 子任务卡改为轻玻璃表面；计时数据使用等宽数字与统一的辅助文字色；展开的计时明细采用内嵌次级表面。
   - 将单个文件内超过职责范围的视觉子区拆成私有 Widget，业务回调和 Provider 读取方式不变。

7. `create_work_item_dialog.dart` 与 `work_item_management_dialogs.dart`
   - 保留现有本地化和返回值类型；应用统一弹窗主题，并为删除确认保留明显危险操作样式。

## 实施顺序与验收

1. 先建立主题与基础玻璃组件，再接入页面背景和顶栏。
2. 接入侧栏、详情、概览和子任务卡，最后统一弹窗与菜单。
3. 每一步保持当前 `Semantics.identifier`、断点、筛选、搜索、拖拽、计时与弹窗流程可用。
4. 用现有 widget test 补充主题化控件和关键自动化标识回归；对宽屏、窄屏、运行中子任务、空列表、错误提示和长子任务列表做人工视觉检查。

## 性能约束

- 不在 `ReorderableListView` 的每个子任务卡或计时明细行使用真实背景模糊。
- 模糊容器必须裁剪，且仅用于固定表面或弹窗。
- 不将动画、计时刷新或业务状态放进设计组件；设计组件保持无状态，以免增加列表重建成本。
