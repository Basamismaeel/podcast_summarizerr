import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;

import 'package:flutter/material.dart';

import '../core/summary_theme_colors.dart';
import '../core/tokens.dart';
import '../services/content_chat_service.dart';
import 'summary_episode_chrome.dart';

const Color _kChatCyan = Color(0xFF00D4FF);
const Color _kOnAccentFg = Color(0xFF0D0F0A);

// #region agent log
const String _kChatDebugLogPath =
    '/Users/basamismaeel/podcast_Summerizer/.cursor/debug-1f97d9.log';

void _chatDebugLog(
  String hypothesisId,
  String location,
  String message, [
  Map<String, Object?>? data,
]) {
  try {
    final payload = <String, Object?>{
      'sessionId': '1f97d9',
      'runId': 'post-fix',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? <String, Object?>{},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final line = jsonEncode(payload);
    File(
      _kChatDebugLogPath,
    ).writeAsStringSync('$line\n', mode: FileMode.append);
  } catch (_) {}
}
// #endregion

/// Bottom-of-summary chat: same widget for books and podcasts; [systemPrompt] carries context.
class ContentChat extends StatefulWidget {
  const ContentChat({
    super.key,
    required this.systemPrompt,
    required this.title,
    required this.starterChips,
    this.embedInTab = false,
  });

  final String systemPrompt;
  final String title;
  final List<String> starterChips;

  /// When true, omits the outer “Chat with this content” title (e.g. section tabs).
  final bool embedInTab;

  @override
  State<ContentChat> createState() => _ContentChatState();
}

class _ContentChatState extends State<ContentChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _loading = false;
  String? _errorText;
  late List<ContentChatMessage> _thread;
  int? _chipBusyIndex;

  @override
  void initState() {
    super.initState();
    _thread = [
      ContentChatMessage(
        role: ContentChatRole.system,
        content: widget.systemPrompt,
      ),
    ];
    // #region agent log
    _chatDebugLog('H1', 'ContentChat:initState', 'mounted', {
      'turnsLen': 0,
      'loading': _loading,
    });
    // #endregion
  }

  @override
  void didUpdateWidget(ContentChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    final systemPromptChanged = oldWidget.systemPrompt != widget.systemPrompt;
    // #region agent log
    _chatDebugLog('H2', 'ContentChat:didUpdateWidget', 'systemPromptChanged', {
      'systemPromptChanged': systemPromptChanged,
      'oldPromptLen': oldWidget.systemPrompt.length,
      'newPromptLen': widget.systemPrompt.length,
      'turnsLen': _thread.where((m) => m.role != ContentChatRole.system).length,
    });
    // #endregion
    if (oldWidget.systemPrompt != widget.systemPrompt) {
      setState(() {
        _thread = [
          ContentChatMessage(
            role: ContentChatRole.system,
            content: widget.systemPrompt,
          ),
        ];
        _errorText = null;
        _loading = false;
        _chipBusyIndex = null;
      });
    }
  }

  @override
  void dispose() {
    // #region agent log
    _chatDebugLog('H1', 'ContentChat:dispose', 'unmounted', {
      'turnsLen': _thread.where((m) => m.role != ContentChatRole.system).length,
    });
    // #endregion
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send(String raw, {int? chipIndex}) async {
    final text = raw.trim();
    if (text.isEmpty || _loading) return;

    final previousThread = List<ContentChatMessage>.from(_thread);
    setState(() {
      _errorText = null;
      if (chipIndex != null) _chipBusyIndex = chipIndex;
      _thread = [
        ..._thread,
        ContentChatMessage(role: ContentChatRole.user, content: text),
      ];
      _loading = true;
    });
    _input.clear();
    _scrollToEnd();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final reply = await ContentChatService.instance.sendChat(
        List.of(_thread),
      );
      if (!mounted) return;
      setState(() {
        _thread = [
          ..._thread,
          ContentChatMessage(role: ContentChatRole.assistant, content: reply),
        ];
        _loading = false;
        _chipBusyIndex = null;
      });
      _scrollToEnd();
    } on ContentChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _thread = previousThread;
        _loading = false;
        _chipBusyIndex = null;
        _errorText = e.message;
        _input.text = text;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _thread = previousThread;
        _loading = false;
        _chipBusyIndex = null;
        _errorText = 'Too many requests, please wait a moment';
        _input.text = text;
      });
    }
  }

  bool get _showChips =>
      _thread.length == 1 && !_loading && widget.starterChips.isNotEmpty;

  /// Centered empty state (standalone / message list before scroll).
  Widget _buildEmptyIntro(
    BuildContext context, {
    required Color onSoft,
    required Color mutedLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: onSoft.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              'Ask me anything about this content',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: onSoft,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your conversation will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.35, color: mutedLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// Top-aligned prompt when opening embedded chat (before first assistant reply).
  Widget _buildEmptyIntroTop(
    BuildContext context, {
    required Color onSoft,
    required Color mutedLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 36,
          color: onSoft.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 12),
        Text(
          'Ask me anything about this content',
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: onSoft,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your conversation will appear here',
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 13, height: 1.4, color: mutedLabel),
        ),
      ],
    );
  }

  Widget _buildChatInputRow(
    BuildContext context, {
    required bool blend,
    required Color chipIdleBg,
    required Color chatAccent,
    required Color onBody,
    required Color onSoft,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: blend ? Colors.white.withValues(alpha: 0.06) : chipIdleBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: blend
                    ? Colors.white.withValues(alpha: 0.12)
                    : chatAccent.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _input,
              enabled: !_loading,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: onBody),
              cursorColor: chatAccent,
              decoration: InputDecoration(
                hintText: 'Ask a question…',
                hintStyle: TextStyle(color: onSoft.withValues(alpha: 0.65)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: _send,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _loading ? null : () => _send(_input.text),
          icon: const Icon(Icons.send_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: chatAccent,
            foregroundColor: _kOnAccentFg,
            disabledBackgroundColor: chatAccent.withValues(alpha: 0.35),
            disabledForegroundColor: _kOnAccentFg.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesScroll(
    BuildContext context, {
    required List<ContentChatMessage> turns,
    required Color onSoft,
    required Color mutedLabel,
    required Color chatAccent,
    required bool isDark,
    required Color onBody,
    required bool blend,
  }) {
    final art = EpisodeArtworkThemeScope.maybeOf(context);
    if (turns.isEmpty && !_loading) {
      return _buildEmptyIntro(context, onSoft: onSoft, mutedLabel: mutedLabel);
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 72),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      cacheExtent: 500,
      itemCount: turns.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (_loading && i == turns.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: chatAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Thinking…',
                  style: TextStyle(fontSize: 13, color: onSoft),
                ),
              ],
            ),
          );
        }
        final m = turns[i];
        final isUser = m.role == ContentChatRole.user;
        final userFill = blend
            ? chatAccent.withValues(alpha: 0.14)
            : chatAccent.withValues(alpha: 0.22);
        final asstFill = blend
            ? Colors.white.withValues(alpha: 0.05)
            : (art?.chipFill ?? SummaryThemeColors.bgElevated(context));
        final userBorder = blend
            ? Border.all(color: chatAccent.withValues(alpha: 0.22), width: 1)
            : Border.all(color: chatAccent.withValues(alpha: 0.45), width: 1);
        final asstBorder = blend
            ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1)
            : Border.all(
                color: art != null
                    ? Colors.white.withValues(alpha: 0.12)
                    : SummaryThemeColors.borderLight(context),
                width: 1,
              );
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.88,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isUser ? userFill : asstFill,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isUser ? 14 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 14),
                    ),
                    border: isUser ? userBorder : asstBorder,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      m.content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isUser
                            ? (isDark
                                  ? Colors.white.withValues(alpha: 0.95)
                                  : _kOnAccentFg)
                            : onBody,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final turns = _thread
        .where((m) => m.role != ContentChatRole.system)
        .toList();
    final onBody = SummaryThemeColors.onBody(context);
    final onSoft = SummaryThemeColors.onBodySoft(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final art = EpisodeArtworkThemeScope.maybeOf(context);
    final chatAccent = art?.accent ?? _kChatCyan;
    final pageBlend = art?.pageBg ?? SummaryThemeColors.bgPrimary(context);
    final panelBg = art?.cardRaised ?? SummaryThemeColors.bgSurface(context);
    final chipIdleBg = art?.chipFill ?? SummaryThemeColors.bgElevated(context);
    final panelBorder = art != null
        ? Colors.white.withValues(alpha: 0.12)
        : SummaryThemeColors.borderLight(context);
    final fadeBottom = pageBlend;
    final mutedLabel = art?.meta ?? SummaryThemeColors.textMuted(context);
    final blend = widget.embedInTab;
    final mq = MediaQuery.sizeOf(context);
    // Embedded tab: tall message stack + no outer “card” — same plane as summary page.
    final messagesPaneHeight = blend
        ? (mq.height * 0.58).clamp(360.0, 720.0)
        : 300.0;
    final hasAssistantReply = turns.any(
      (m) => m.role == ContentChatRole.assistant,
    );
    // Embedded tab: intro + composer in pane until the first answer; then transcript + composer below.
    final dockInputBelowMessages = !blend || hasAssistantReply;

    return Padding(
      padding: EdgeInsets.only(top: widget.embedInTab ? 0 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedInTab) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chat with this content',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: mutedLabel,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: onBody,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_showChips)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                cacheExtent: 500,
                itemCount: widget.starterChips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = widget.starterChips[i];
                  final busy = _chipBusyIndex == i;
                  return Material(
                    color: busy ? chatAccent : chipIdleBg,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: _loading ? null : () => _send(c, chipIndex: i),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: chatAccent.withValues(
                              alpha: busy ? 0.85 : 0.4,
                            ),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: busy ? _kOnAccentFg : onBody,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_showChips) const SizedBox(height: 14),
          SizedBox(
            height: messagesPaneHeight,
            child: dockInputBelowMessages
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      blend
                          ? _buildMessagesScroll(
                              context,
                              turns: turns,
                              onSoft: onSoft,
                              mutedLabel: mutedLabel,
                              chatAccent: chatAccent,
                              isDark: isDark,
                              onBody: onBody,
                              blend: true,
                            )
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                color: panelBg,
                                borderRadius: BorderRadius.circular(
                                  Tokens.radiusLg,
                                ),
                                border: Border.all(color: panelBorder),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  Tokens.radiusLg,
                                ),
                                child: _buildMessagesScroll(
                                  context,
                                  turns: turns,
                                  onSoft: onSoft,
                                  mutedLabel: mutedLabel,
                                  chatAccent: chatAccent,
                                  isDark: isDark,
                                  onBody: onBody,
                                  blend: false,
                                ),
                              ),
                            ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 60,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  fadeBottom.withValues(alpha: 0),
                                  fadeBottom,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: _buildEmptyIntroTop(
                          context,
                          onSoft: onSoft,
                          mutedLabel: mutedLabel,
                        ),
                      ),
                      Expanded(
                        child: _loading && !hasAssistantReply
                            ? Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: chatAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Thinking…',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: onSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      _buildChatInputRow(
                        context,
                        blend: blend,
                        chipIdleBg: chipIdleBg,
                        chatAccent: chatAccent,
                        onBody: onBody,
                        onSoft: onSoft,
                      ),
                    ],
                  ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(
                fontSize: 13,
                color: Tokens.error,
                height: 1.35,
              ),
            ),
          ],
          if (dockInputBelowMessages) ...[
            const SizedBox(height: 12),
            _buildChatInputRow(
              context,
              blend: blend,
              chipIdleBg: chipIdleBg,
              chatAccent: chatAccent,
              onBody: onBody,
              onSoft: onSoft,
            ),
          ],
        ],
      ),
    );
  }
}
