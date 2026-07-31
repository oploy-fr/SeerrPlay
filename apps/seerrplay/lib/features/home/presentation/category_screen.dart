import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/home/application/home_state.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_catalog_view.dart';
import 'package:seerrplay/features/media/presentation/media_detail_screen.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({required this.category, super.key});

  final HomeCategory category;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  Timer? _debounce;
  CancelToken? _cancelToken;
  List<MediaViewModel> _items = const [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = value.trim();
      if (query == _query) return;
      _query = query;
      unawaited(_load(query));
    });
  }

  Future<void> _load(String query) async {
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final client = ref.read(seerrClientProvider);
      final pages = <SeerrPage<SeerrMedia>>[];
      if (query.isEmpty) {
        pages.addAll(
          await Future.wait([
            for (var page = 1; page <= 3; page++)
              widget.category.type == SeerrMediaType.movie
                  ? client.discoverMovies(
                      page: page,
                      genreId: widget.category.id,
                    )
                  : client.discoverTv(page: page, genreId: widget.category.id),
          ]),
        );
      } else {
        final language =
            ref.read(localeControllerProvider).value?.languageCode ?? 'en';
        final firstPage = await client.search(
          query: query,
          page: 1,
          language: language,
          cancelToken: cancelToken,
        );
        pages.add(firstPage);
        final lastPage = firstPage.totalPages.clamp(1, 3);
        if (lastPage > 1) {
          pages.addAll(
            await Future.wait([
              for (var page = 2; page <= lastPage; page++)
                client.search(
                  query: query,
                  page: page,
                  language: language,
                  cancelToken: cancelToken,
                ),
            ]),
          );
        }
      }

      final seen = <String>{};
      final unfilteredResults = pages
          .expand((page) => page.results)
          .where(
            (media) =>
                media.type == widget.category.type &&
                media.genreIds.contains(widget.category.id),
          )
          .where((media) => seen.add('${media.type.apiValue}:${media.id}'))
          .map(mediaFromSeerr)
          .toList(growable: false);
      final results = await filterMediaForChildProfile(
        profile: ref.read(appSessionControllerProvider).requireValue.profile!,
        client: client,
        language:
            ref.read(localeControllerProvider).value?.languageCode ?? 'en',
        items: unfilteredResults,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = results;
        _loading = false;
      });
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || !mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? Center(child: Text(context.tr('Unable to load this category.')))
          : MediaCatalogView(
              items: _items,
              showStatusFilters: true,
              searchLoading: _loading,
              searchHint: context.tr('Search this category'),
              onSearchChanged: _search,
              onRefresh: () {
                ref.read(seerrClientProvider).clearCache();
                return _load(_query);
              },
              onSelected: (media) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MediaDetailScreen(media: media),
                ),
              ),
              bottomPadding: 32,
            ),
    );
  }
}
