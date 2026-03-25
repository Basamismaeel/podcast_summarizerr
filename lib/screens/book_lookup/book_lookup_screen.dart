import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tokens.dart';
import '../../services/open_library_book_service.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/psn_text_field.dart';

/// Search Open Library by title/author, then use ISBN + Audible share link for chapters.
class BookLookupScreen extends StatefulWidget {
  const BookLookupScreen({super.key});

  @override
  State<BookLookupScreen> createState() => _BookLookupScreenState();
}

class _BookLookupScreenState extends State<BookLookupScreen> {
  final _queryController = TextEditingController();
  var _loading = false;
  String? _error;
  List<OpenLibraryBookHit> _hits = const [];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.length < 2) {
      setState(() {
        _error = 'Enter at least 2 characters.';
        _hits = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final hits = await OpenLibraryBookService.search(q);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hits = hits;
        if (hits.isEmpty) _error = 'No matches. Try another spelling or keyword.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hits = const [];
        _error = 'Search failed. Check your connection and try again.';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showHitSheet(OpenLibraryBookHit hit) {
    final tt = Theme.of(context).textTheme;
    final isbns = hit.isbns.toSet().toList()..sort();
    final showIsbns = isbns.take(12).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            final sheetRows = <Widget Function()>[
              () => Text(
                    hit.title,
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
              () => const SizedBox(height: 4),
              () => Text(hit.authorsLabel, style: tt.bodyMedium),
              if (hit.firstPublishYear != null)
                () => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'First published: ${hit.firstPublishYear}',
                        style: tt.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
              () => const SizedBox(height: Tokens.spaceMd),
              () => Text(
                    'Audible chapters in this app use Audnexus and need the book’s '
                    'ASIN from an Audible product link. Open Library gives you the '
                    'correct title/ISBN so you can find the same audiobook in the Audible app.',
                    style: tt.bodySmall,
                  ),
              () => const SizedBox(height: Tokens.spaceMd),
              () => Text('ISBNs (tap to copy)', style: tt.titleSmall),
              () => const SizedBox(height: Tokens.spaceSm),
              () => showIsbns.isEmpty
                  ? Text(
                      'No ISBNs listed for this work — still use the title to search in Audible.',
                      style: tt.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: showIsbns.map((isbn) {
                        return ActionChip(
                          label: Text(
                            isbn,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: isbn),
                            );
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Copied $isbn'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
              if (isbns.length > showIsbns.length)
                () => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${isbns.length - showIsbns.length} more on Open Library',
                        style: tt.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
              () => const SizedBox(height: Tokens.spaceMd),
              () => OutlinedButton.icon(
                    onPressed: () => _openUrl(hit.openLibraryUrl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open Library page'),
                  ),
              () => const SizedBox(height: Tokens.spaceSm),
              () => const Text(
                    'Next: In Audible, search by title or ISBN, open the audiobook, '
                    'then Share → Copy link and paste from Home (clipboard) to save a moment. '
                    'Chapter timestamps then load from Audnexus for that ASIN.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
            ];
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                Tokens.spaceMd,
                Tokens.spaceMd,
                Tokens.spaceMd,
                Tokens.spaceLg,
              ),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              cacheExtent: 500,
              itemCount: sheetRows.length,
              itemBuilder: (context, index) => sheetRows[index](),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Look up a book'),
        leading: const BackButton(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        cacheExtent: 500,
        itemCount: 7 + (_error != null ? 2 : 0) + _hits.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              'Find editions & ISBNs',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            );
          }
          if (index == 1) return const SizedBox(height: 8);
          if (index == 2) {
            return Text(
              'Open Library lists print and digital editions. Your app still needs an '
              'Audible share URL (contains ASIN) so timed audiobook chapters can load.',
              style: tt.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }
          if (index == 3) {
            return const SizedBox(height: Tokens.spaceMd);
          }
          if (index == 4) {
            return PSNTextField(
              placeholder: 'Title, author, or ISBN',
              controller: _queryController,
            );
          }
          if (index == 5) {
            return const SizedBox(height: Tokens.spaceSm);
          }
          if (index == 6) {
            return PSNButton(
              label: 'Search',
              fullWidth: true,
              isLoading: _loading,
              onTap: _loading ? null : _search,
            );
          }
          var k = index - 7;
          if (_error != null) {
            if (k == 0) return const SizedBox(height: Tokens.spaceMd);
            if (k == 1) {
              return Text(
                _error!,
                style: tt.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              );
            }
            k -= 2;
          }
          if (k == 0) return const SizedBox(height: Tokens.spaceLg);
          final h = _hits[k - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: Tokens.spaceSm),
            child: ListTile(
              title: Text(
                h.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  h.authorsLabel,
                  if (h.firstPublishYear != null) '${h.firstPublishYear}',
                  if (h.isbns.isNotEmpty) '${h.isbns.length} ISBN(s)',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showHitSheet(h),
            ),
          );
        },
      ),
    );
  }
}
