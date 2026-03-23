import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const _kAgentLogPath =
    '/Users/basamismaeel/podcast_Summerizer/.cursor/debug-1f97d9.log';

/// Debug NDJSON: console + append to session log file (VM/desktop/mobile host paths may vary).
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
  final line = '${jsonEncode(entry)}\n';
  debugPrint('[AGENT_DEBUG] ${line.trim()}');
  try {
    File(_kAgentLogPath).writeAsStringSync(line, mode: FileMode.append);
  } catch (_) {}
  // #endregion
}
