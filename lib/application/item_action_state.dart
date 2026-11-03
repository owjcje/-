/// 单个任务执行状态更新或计时操作时的保存状态。
class ItemActionState {
  const ItemActionState({
    required this.isSaving,
    required this.errorMessage,
  });

  const ItemActionState.idle() : this(isSaving: false, errorMessage: null);

  final bool isSaving;
  final String? errorMessage;
}
