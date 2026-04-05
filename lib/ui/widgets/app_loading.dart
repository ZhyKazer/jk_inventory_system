import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLoading {
  const AppLoading._();

  static Future<T> run<T>(
    BuildContext context, {
    required Future<T> Function() action,
    required String message,
    ValueListenable<String>? messageListenable,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: messageListenable == null
                    ? Text(message)
                    : ValueListenableBuilder<String>(
                        valueListenable: messageListenable,
                        builder: (context, value, child) => Text(value),
                      ),
              ),
            ],
          ),
          actions: secondaryActionLabel != null && onSecondaryAction != null
              ? [
                  TextButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryActionLabel),
                  ),
                ]
              : null,
        ),
      ),
    );

    // Let the loading dialog render before starting heavy async work.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    try {
      return await action();
    } finally {
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}