import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/env_value.dart';

/// Gemini chat completions for [ContentChat], using the same key as the pipeline.
class ContentChatService {
  ContentChatService._();
  static final instance = ContentChatService._();

  static const _geminiKeyFromDefine =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const _modelFallbacks = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-001',
    'gemini-flash-latest',
  ];

  String get _apiKey {
    final raw = _geminiKeyFromDefine.isNotEmpty
        ? normalizeDotenvValue(_geminiKeyFromDefine)
        : normalizeDotenvValue(dotenv.env['GEMINI_API_KEY']);
    return normalizeGeminiApiKey(raw);
  }

  String get _apiVersion {
    final v =
        normalizeDotenvValue(dotenv.env['GEMINI_API_VERSION']).toLowerCase();
    if (v == 'v1' || v == 'v1beta') return v;
    return 'v1beta';
  }

  /// [messages] must include `system` first, then alternating `user` / `assistant`.
  Future<String> sendChat(List<ContentChatMessage> messages) async {
    if (_apiKey.isEmpty || _apiKey == 'placeholder') {
      throw ContentChatException(
        'Missing GEMINI_API_KEY. Add your key to .env and restart the app.',
      );
    }
    if (messages.isEmpty || messages.first.role != ContentChatRole.system) {
      throw ContentChatException('Invalid message history.');
    }

    final systemText = messages.first.content;
    final turns = messages.skip(1).toList();

    final contents = <Map<String, dynamic>>[];
    for (final m in turns) {
      final role = m.role == ContentChatRole.user ? 'user' : 'model';
      contents.add({
        'role': role,
        'parts': [
          {'text': m.content},
        ],
      });
    }

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemText},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.45,
        'maxOutputTokens': 2048,
      },
    };

    ContentChatException? lastError;
    for (final model in _modelFallbacks) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/$_apiVersion/models/$model:generateContent',
      );
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final text = _parseText(response.body);
        if (text.trim().isEmpty) {
          throw ContentChatException('The model returned an empty reply.');
        }
        return text.trim();
      }

      if (response.statusCode == 429) {
        lastError = ContentChatException.rateLimited();
        continue;
      }

      final detail = _errorDetail(response.body);
      lastError = ContentChatException(
        detail.isNotEmpty ? detail : 'Request failed (${response.statusCode})',
      );
      if (response.statusCode == 403 || response.statusCode == 404) {
        continue;
      }
      throw lastError;
    }

    if (lastError != null) throw lastError;
    throw ContentChatException('AI service unavailable. Try again later.');
  }

  static String _parseText(String responseBody) {
    try {
      final map = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = map['candidates'] as List<dynamic>?;
      final first = candidates != null && candidates.isNotEmpty
          ? candidates.first as Map<String, dynamic>?
          : null;
      final content = first?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final part0 = parts != null && parts.isNotEmpty
          ? parts.first as Map<String, dynamic>?
          : null;
      return part0?['text'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _errorDetail(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>?;
      final err = map?['error'] as Map<String, dynamic>?;
      final m = err?['message'] as String?;
      if (m != null && m.trim().isNotEmpty) return m.trim();
    } catch (_) {}
    return '';
  }
}

enum ContentChatRole { system, user, assistant }

class ContentChatMessage {
  const ContentChatMessage({required this.role, required this.content});

  final ContentChatRole role;
  final String content;
}

class ContentChatException implements Exception {
  ContentChatException(this.message, {this.isRateLimited = false});

  factory ContentChatException.rateLimited() => ContentChatException(
        'Too many requests, please wait a moment',
        isRateLimited: true,
      );

  final String message;
  final bool isRateLimited;

  @override
  String toString() => message;
}
