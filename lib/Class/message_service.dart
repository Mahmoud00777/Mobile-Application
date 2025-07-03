import 'package:flutter/material.dart';

class MessageService {
  static void showTopMessage({
    required BuildContext context, // إضافة context كمُعامل مطلوب
    required String message,
    String? title,
    bool isSuccess = true,
    int durationSeconds = 4,
    bool showCloseButton = true,
  }) {
    late OverlayEntry overlayEntry;
    // 1. الحصول على OverlayState من context
    final overlayState = Overlay.of(context);

    // 2. حساب الموضع العلوي
    final topPosition = MediaQuery.of(context).padding.top + 20;

    // 3. إنشاء OverlayEntry
    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: topPosition,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: _buildMessageCard(
                context: context, // تمرير context هنا
                message: message,
                title: title,
                isSuccess: isSuccess,
                showCloseButton: showCloseButton,
                onClose:
                    () =>
                        overlayEntry
                            .remove(), // استخدام overlayEntry بعد تعريفه
              ),
            ),
          ),
    );

    // 4. إدراج الرسالة في الـ Overlay
    overlayState.insert(overlayEntry);

    // 5. إزالة الرسالة بعد المدة المحددة
    Future.delayed(Duration(seconds: durationSeconds), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  static Widget _buildMessageCard({
    required BuildContext context, // إضافة context هنا
    required String message,
    String? title,
    required bool isSuccess,
    required bool showCloseButton,
    required VoidCallback onClose,
  }) {
    final backgroundColor =
        isSuccess ? Colors.green.shade700 : Colors.red.shade700;
    final icon = isSuccess ? Icons.check_circle : Icons.error_outline;

    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ],
              ),
            ),
            if (showCloseButton)
              IconButton(
                icon: const Icon(Icons.close, size: 24),
                color: Colors.white,
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }

  // الدوال المختصرة المعدلة
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    showTopMessage(
      context: context, // إضافة context هنا
      message: message,
      title: title ?? 'نجاح',
      isSuccess: true,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    showTopMessage(
      context: context, // إضافة context هنا
      message: message,
      title: title ?? 'خطأ',
      isSuccess: false,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) {
    showTopMessage(
      context: context, // إضافة context هنا
      message: message,
      title: title ?? 'تحذير',
      isSuccess: false,
    );
  }
}
