import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/core/widgets/app_page_layout.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_catalog_view.dart';
import 'package:seerrplay/features/media/presentation/media_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _open(MediaViewModel media) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MediaDetailScreen(media: media)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider(_query));
    return Scaffold(
      appBar: AppPageAppBar(title: Text(context.tr('Search Seerr'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppPageLayout.horizontalInset(context),
                8,
                AppPageLayout.horizontalInset(context),
                10,
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.tr('E.g. Law Abiding Citizen'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr('Clear'),
                          onPressed: () {
                            _debounce?.cancel();
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  fillColor: AppColors.white.withValues(alpha: 0.075),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: AppColors.violet,
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: (value) {
                  _debounce?.cancel();
                  setState(() => _query = value.trim());
                },
                onChanged: (value) {
                  setState(() {});
                  _search(value);
                },
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? const _SearchEmptyState()
                  : results.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48),
                            const SizedBox(height: 12),
                            Text(context.tr('Search unavailable.')),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () =>
                                  ref.invalidate(searchResultsProvider(_query)),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(context.tr('Try again')),
                            ),
                          ],
                        ),
                      ),
                      data: (items) => items.isEmpty
                          ? Center(
                              child: Text(
                                context.tr(
                                  'No results for “{query}”.',
                                  arguments: {'query': _query},
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : MediaCatalogView(
                              items: items,
                              showSearch: false,
                              showStatusFilters: true,
                              bottomPadding: 118,
                              onSelected: _open,
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search_rounded, size: 64, color: AppColors.violet),
          const SizedBox(height: 14),
          Text(
            context.tr('Movies and series'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Enter a localized title or its original title.'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
