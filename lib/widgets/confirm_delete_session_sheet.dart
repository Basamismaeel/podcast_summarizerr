import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'psn_bottom_sheet.dart';
import 'psn_button.dart';

/// Confirms permanent deletion of a saved moment and its summary.
Future<bool?> showConfirmDeleteSessionSheet(
  BuildContext context,
  String episodeTitle, {
  String sheetTitle = 'Delete this moment?',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    enableDrag: true,
    builder: (ctx) {
      return PSNBottomSheet(
        title: sheetTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently remove “$episodeTitle” and its summary.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: Tokens.spaceLg),
            PSNButton(
              label: 'Delete',
              variant: ButtonVariant.danger,
              fullWidth: true,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Tokens.spaceSm),
            PSNButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              fullWidth: true,
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
    },
  );
}

/// Confirms deleting multiple moments at once.
Future<bool?> showConfirmDeleteMultipleSessionsSheet(
  BuildContext context, {
  required int count,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    enableDrag: true,
    builder: (ctx) {
      return PSNBottomSheet(
        title: 'Delete $count moments?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 1
                  ? 'This will permanently remove the selected moment and its summary.'
                  : 'This will permanently remove $count moments and their summaries. This cannot be undone.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: Tokens.spaceLg),
            PSNButton(
              label: 'Delete all',
              variant: ButtonVariant.danger,
              fullWidth: true,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Tokens.spaceSm),
            PSNButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              fullWidth: true,
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
    },
  );
}
