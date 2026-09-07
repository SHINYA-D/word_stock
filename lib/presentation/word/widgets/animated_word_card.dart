import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// タップで画面全体に浮き上がり、その場でインライン編集できるカード。
/// [WordEditPage] と [WordCreatePage] で共通利用する。
class AnimatedWordCard extends StatelessWidget {
  const AnimatedWordCard({
    super.key,
    required this.height,
    required this.fullHeight,
    required this.label,
    required this.controller,
    required this.expanded,
    required this.showSaveButton,
    required this.showValidationError,
    required this.onTap,
    required this.onClose,
    required this.onSave,
    required this.onDismissValidationError,
  });

  static const maxLength = 500;
  static const animationDuration = Duration(milliseconds: 350);
  static const animationCurve = Curves.easeInOutCubic;
  static const validationMessage = '1文字以上入力してください！';

  final double height;
  final double fullHeight;
  final String label;
  final TextEditingController controller;
  final bool expanded;
  final bool showSaveButton;
  final bool showValidationError;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final Future<void> Function() onSave;
  final VoidCallback onDismissValidationError;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animationDuration,
      curve: animationCurve,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(expanded ? 0 : 20),
      ),
      // 内側のコンテンツは常に fullHeight で配置し、外側の AnimatedContainer が
      // その一部だけを表示することでアニメーションさせる（内側を animate すると
      // Column が高さ 0 に潰れる過程で RenderFlex overflow になるため）
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: fullHeight,
        maxHeight: fullHeight,
        child: SizedBox(
          height: fullHeight,
          child: AnimatedOpacity(
            duration: animationDuration,
            curve: animationCurve,
            opacity: height == 0 ? 0 : 1,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: expanded ? 8 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(expanded ? 0 : 20),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: expanded ? null : onTap,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      // バリデーションエラー表示中は、カード内のどこをタップしても
                      // （テキスト入力欄を含め）エラーを閉じる
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: showValidationError ? onDismissValidationError : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (expanded && showValidationError)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  validationMessage,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            Expanded(
                              child: expanded
                                  ? TextField(
                                      controller: controller,
                                      autofocus: true,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      maxLength: maxLength,
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(maxLength),
                                      ],
                                      onTap: showValidationError ? onDismissValidationError : null,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        counterText: '',
                                      ),
                                    )
                                  : Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        controller.text,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (expanded)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: onClose,
                        ),
                      ),
                    if (expanded)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: showSaveButton ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !showSaveButton,
                            child: FilledButton.icon(
                              onPressed: onSave,
                              icon: const Icon(Icons.check),
                              label: const Text('保存'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
