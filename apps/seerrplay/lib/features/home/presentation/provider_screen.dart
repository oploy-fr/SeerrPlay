import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/home/application/home_state.dart';
import 'package:seerrplay/features/media/presentation/media_catalog_view.dart';
import 'package:seerrplay/features/media/presentation/media_detail_screen.dart';

class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({
    required this.provider,
    required this.region,
    super.key,
  });

  final HomeProvider provider;
  final String region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(providerResultsProvider((provider.id, region)));
    return Scaffold(
      appBar: AppBar(title: Text(provider.name)),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(context.tr('Unable to load this provider.'))),
        data: (items) => MediaCatalogView(
          items: items,
          showStatusFilters: true,
          onRefresh: () {
            ref.read(seerrClientProvider).clearCache();
            return ref.refresh(
              providerResultsProvider((provider.id, region)).future,
            );
          },
          onSelected: (media) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaDetailScreen(media: media),
            ),
          ),
          bottomPadding: 32,
        ),
      ),
    );
  }
}
