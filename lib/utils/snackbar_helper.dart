import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

void showSuccessSnackBar(BuildContext context, String message) {
  _showSnackBar(
    context,
    message: message,
    icon: Icons.check_circle_outline_rounded,
    iconColor: Theme.of(context).colorScheme.secondary,
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  _showSnackBar(
    context,
    message: message,
    icon: Icons.error_outline_rounded,
    iconColor: Theme.of(context).colorScheme.error,
  );
}

void _showSnackBar(
  BuildContext context, {
  required String message,
  required IconData icon,
  required Color iconColor,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(icon, size: AppSpacing.iconSmall, color: iconColor),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
