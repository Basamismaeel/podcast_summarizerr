import 'package:flutter/material.dart';

import '../core/summary_theme_colors.dart';
import '../core/tokens.dart';
import '../services/content_chat_service.dart';

const Color _kChatCyan = Color(0xFF00D4FF);

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
  }

  @override
  void didUpdateWidget(ContentChat oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      final reply =
          await ContentChatService.instance.sendChat(List.of(_thread));
      if (!mounted) return;
      setState(() {
        _thread = [
          ..._thread,
          ContentChatMessage(
            role: ContentChatRole.assistant,
            content: reply,
          ),
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

  @override
  Widget build(BuildContext context) {
    final turns =
        _thread.where((m) => m.role != ContentChatRole.system).toList();
    final onBody = SummaryThemeColors.onBody(context);
    final onSoft = SummaryThemeColors.onBodySoft(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  color: SummaryThemeColors.textMuted(context),
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
                    color: busy
                        ? _kChatCyan
                        : SummaryThemeColors.bgElevated(context),
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
                            color: _kChatCyan.withValues(
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
                            color: busy
                                ? const Color(0xFF0A1628)
                                : onBody,
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
            height: 300,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: SummaryThemeColors.bgSurface(context),
                    borderRadius: BorderRadius.circular(Tokens.radiusLg),
                    border: Border.all(
                      color: SummaryThemeColors.borderLight(context),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusLg),
                    child: turns.isEmpty && !_loading
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
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
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: SummaryThemeColors.textMuted(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 72),
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
                                          color: _kChatCyan,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Thinking…',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: onSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final m = turns[i];
                              final isUser = m.role == ContentChatRole.user;
                              return RepaintBoundary(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Align(
                                    alignment: isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.sizeOf(context).width *
                                                0.82,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: isUser
                                              ? _kChatCyan
                                                  .withValues(alpha: 0.22)
                                              : SummaryThemeColors.bgElevated(
                                                  context,
                                                ),
                                          borderRadius: BorderRadius.only(
                                            topLeft:
                                                const Radius.circular(14),
                                            topRight:
                                                const Radius.circular(14),
                                            bottomLeft: Radius.circular(
                                              isUser ? 14 : 4,
                                            ),
                                            bottomRight: Radius.circular(
                                              isUser ? 4 : 14,
                                            ),
                                          ),
                                          border: Border.all(
                                            color: isUser
                                                ? _kChatCyan.withValues(
                                                    alpha: 0.45,
                                                  )
                                                : SummaryThemeColors
                                                    .borderLight(context),
                                          ),
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
                                                      ? Colors.white
                                                          .withValues(
                                                              alpha: 0.95,
                                                          )
                                                      : const Color(
                                                          0xFF0A1628,
                                                        ))
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
                            SummaryThemeColors.bgSurface(context)
                                .withValues(alpha: 0),
                            SummaryThemeColors.bgSurface(context),
                          ],
                        ),
                      ),
                    ),
                  ),
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: SummaryThemeColors.bgElevated(context),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _kChatCyan.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _input,
                    enabled: !_loading,
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(color: onBody),
                    cursorColor: _kChatCyan,
                    decoration: InputDecoration(
                      hintText: 'Ask a question…',
                      hintStyle: TextStyle(
                        color: onSoft.withValues(alpha: 0.65),
                      ),
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
                  backgroundColor: _kChatCyan,
                  foregroundColor: const Color(0xFF061018),
                  disabledBackgroundColor:
                      _kChatCyan.withValues(alpha: 0.35),
                  disabledForegroundColor:
                      const Color(0xFF061018).withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
