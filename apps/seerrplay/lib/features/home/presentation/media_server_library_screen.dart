import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_catalog_view.dart';
import 'package:seerrplay/features/media/presentation/media_detail_screen.dart';

class MediaServerLibraryScreen extends ConsumerStatefulWidget {
  const MediaServerLibraryScreen({super.key});

  @override
  ConsumerState<MediaServerLibraryScreen> createState() =>
      _MediaServerLibraryScreenState();
}

class _MediaServerLibraryScreenState
    extends ConsumerState<MediaServerLibraryScreen> {
  static const _pageSize = 200;

  Timer? _debounce;
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
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _items = const [];
      });
    }
    try {
      final client = ref.read(mediaServerClientProvider);
      var startIndex = 0;
      var total = 1;
      final loaded = <MediaViewModel>[];
      while (startIndex < total) {
        final page = await client.getLibraryItems(
          startIndex: startIndex,
          limit: _pageSize,
          searchTerm: query,
        );
        if (!mounted || requestId != _requestId) return;
        total = page.totalRecordCount;
        loaded.addAll(page.items.map((item) => mediaFromServer(item, client)));
        startIndex += page.items.length;
        setState(() => _items = List.unmodifiable(loaded));
        if (page.items.isEmpty) break;
      }
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            '${ref.watch(appSessionControllerProvider).value?.profile?.mediaServerType.displayName ?? 'Media'} library',
          ),
        ),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? Center(child: Text(context.tr('Unable to load the media library.')))
          : MediaCatalogView(
              items: _items,
              searchLoading: _loading,
              searchHint: context.tr('Search the media library'),
              onSearchChanged: _search,
              onRefresh: () => _load(_query),
              onSelected: (media) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MediaDetailScreen(media: media),
                ),
              ),
            ),
    );
  }
}
