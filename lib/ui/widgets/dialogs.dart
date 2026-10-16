import 'package:flutter/material.dart';

/// Shows a generic confirmation dialog.
///
/// Returns true when the user taps the confirm button, false on cancel or
/// when the dialog is dismissed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Result of [confirmDeleteDialog]: whether the user confirmed, and whether
/// they ticked the "also delete downloaded files" checkbox.
typedef DeleteConfirmation = ({bool confirmed, bool deleteFiles});

/// Confirmation dialog used when removing a download from the list.
///
/// The checkbox lets the user also delete the downloaded file(s) from disk.
/// The caller is responsible for honouring the user's settings (e.g. skipping
/// this dialog entirely when confirm-before-delete is disabled).
Future<DeleteConfirmation> confirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
  String checkboxLabel = 'Also delete downloaded files from disk',
}) async {
  var deleteFiles = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (v) => setState(() => deleteFiles = v ?? false),
                title: Text(checkboxLabel),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    },
  );
  return (confirmed: confirmed ?? false, deleteFiles: deleteFiles);
}
