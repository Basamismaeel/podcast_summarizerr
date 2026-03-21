import 'package:flutter/material.dart';

import '../core/tokens.dart';

class PSNBottomSheet extends StatelessWidget {
  const PSNBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
  });

  final Widget child;
  final String? title;
  final bool showHandle;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool showHandle = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (_) => PSNBottomSheet(
        title: title,
        showHandle: showHandle,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tokens.bgSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Tokens.radiusLg),
        ),
        border: Border(
          top: BorderSide(color: Tokens.borderLight),
          left: BorderSide(color: Tokens.borderLight),
          right: BorderSide(color: Tokens.borderLight),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Tokens.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.spaceMd,
                Tokens.spaceMd,
                Tokens.spaceMd,
                Tokens.spaceSm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title!, style: Tokens.headingM),
              ),
            ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Tokens.spaceMd,
                title == null ? Tokens.spaceMd : 0,
                Tokens.spaceMd,
                MediaQuery.of(context).viewPadding.bottom + Tokens.spaceMd,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
