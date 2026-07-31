import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/widgets/app_page_layout.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_catalog_view.dart';
import 'package:seerrplay/features/media/presentation/media_detail_screen.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(userRequestsProvider);
    return Scaffold(
      appBar: AppPageAppBar(title: Text(context.tr('Unwatched requests'))),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Center(child: Text(context.tr('Unable to load requests.'))),
          ],
        ),
        data: (items) => items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  const Icon(Icons.done_all_rounded, size: 52),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(context.tr('All requests have been watched.')),
                  ),
                ],
              )
            : MediaCatalogView(
                items: items,
                bottomPadding: 118,
                showStatusFilters: true,
                onRefresh: () => ref.refresh(userRequestsProvider.future),
                onSelected: (media) => _open(context, media),
              ),
      ),
    );
  }

  void _open(BuildContext context, MediaViewModel media) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MediaDetailScreen(media: media)),
    );
  }
}
