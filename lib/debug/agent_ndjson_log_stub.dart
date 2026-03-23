import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug NDJSON (stub: console only when `dart:io` unavailable).
void agentNdjsonLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  // #region agent log
  final entry = <String, Object?>{
    'sessionId': '1f97d9',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'runId': runId,
  };
  debugPrint('[AGENT_DEBUG] ${jsonEncode(entry)}');
  // #endregion
}
