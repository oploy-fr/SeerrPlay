import 'package:flutter/material.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/core/widgets/app_page_layout.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_poster_card.dart';

enum MediaCatalogFilter { all, movies, series }

enum MediaCatalogSort { relevance, newest, oldest, alphabetical }

enum MediaStatusFilter { all, available, inProgress, requested, failed }

class MediaCatalogView extends StatefulWidget {
  const MediaCatalogView({
    required this.items,
    required this.onSelected,
    this.showSearch = true,
    this.onRefresh,
    this.onSearchChanged,
    this.searchHint,
    this.searchLoading = false,
    this.bottomPadding = 32,
    this.showStatusFilters = false,
    super.key,
  });

  final List<MediaViewModel> items;
  final ValueChanged<MediaViewModel> onSelected;
  final bool showSearch;
  final Future<void> Function()? onRefresh;
  final ValueChanged<String>? onSearchChanged;
  final String? searchHint;
  final bool searchLoading;
  final double bottomPadding;
  final bool showStatusFilters;

  @override
  State<MediaCatalogView> createState() => _MediaCatalogViewState();
}

class _MediaCatalogViewState extends State<MediaCatalogView> {
  final _searchController = TextEditingController();
  MediaCatalogFilter _filter = MediaCatalogFilter.all;
  MediaCatalogSort _sort = MediaCatalogSort.newest;
  MediaStatusFilter _statusFilter = MediaStatusFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MediaViewModel> get _visibleItems {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = widget.items
        .where((media) {
          final matchesQuery =
              widget.onSearchChanged != null ||
              normalizedQuery.isEmpty ||
              media.title.toLowerCase().contains(normalizedQuery) ||
              (media.subtitle?.toLowerCase().contains(normalizedQuery) ??
                  false);
          final matchesType = switch (_filter) {
            MediaCatalogFilter.all => true,
            MediaCatalogFilter.movies => media.kind == MediaKind.movie,
            MediaCatalogFilter.series =>
              media.kind == MediaKind.series || media.kind == MediaKind.episode,
          };
          final matchesStatus = switch (_statusFilter) {
            MediaStatusFilter.all => true,
            MediaStatusFilter.available =>
              media.lifecycleStatus == MediaLifecycleStatus.available,
            MediaStatusFilter.inProgress =>
              media.lifecycleStatus == MediaLifecycleStatus.downloading ||
                  media.lifecycleStatus ==
                      MediaLifecycleStatus.partiallyAvailable,
            MediaStatusFilter.requested =>
              media.lifecycleStatus == MediaLifecycleStatus.requested ||
                  media.lifecycleStatus == MediaLifecycleStatus.pendingApproval,
            MediaStatusFilter.failed =>
              media.lifecycleStatus == MediaLifecycleStatus.failed ||
                  media.lifecycleStatus == MediaLifecycleStatus.declined,
          };
          return matchesQuery && matchesType && matchesStatus;
        })
        .toList(growable: false);
    return switch (_sort) {
      MediaCatalogSort.relevance => filtered,
      MediaCatalogSort.newest => [
        ...filtered,
      ]..sort((left, right) => _dateValue(right).compareTo(_dateValue(left))),
      MediaCatalogSort.oldest => [
        ...filtered,
      ]..sort((left, right) => _dateValue(left).compareTo(_dateValue(right))),
      MediaCatalogSort.alphabetical =>
        [...filtered]..sort(
          (left, right) =>
              left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final desktop =
        isDesktopPlatform && MediaQuery.sizeOf(context).width >= 1000;
    final grid = GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppPageLayout.horizontalInset(context),
        desktop ? 24 : 14,
        AppPageLayout.horizontalInset(context),
        widget.bottomPadding,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: desktop ? 190 : 148,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: desktop ? 20 : 10,
        mainAxisSpacing: desktop ? 22 : 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => MediaPosterCard(
        media: items[index],
        showDetails: false,
        onTap: () => widget.onSelected(items[index]),
      ),
    );
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppPageLayout.horizontalInset(context),
            desktop ? 20 : 8,
            AppPageLayout.horizontalInset(context),
            0,
          ),
          child: Column(
            children: [
              if (widget.showSearch) ...[
                _CatalogSearchField(
                  controller: _searchController,
                  hintText: widget.searchHint,
                  onChanged: (value) {
                    setState(() => _query = value);
                    widget.onSearchChanged?.call(value);
                  },
                ),
                const SizedBox(height: 12),
              ],
              _CatalogControls(
                filter: _filter,
                statusFilter: _statusFilter,
                sort: _sort,
                showStatusFilter: widget.showStatusFilters,
                onFilterChanged: (value) => setState(() => _filter = value),
                onStatusFilterChanged: (value) =>
                    setState(() => _statusFilter = value),
                onSortChanged: (value) => setState(() => _sort = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (widget.searchLoading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(context.tr('No media matches these filters.')),
                )
              : widget.onRefresh == null
              ? grid
              : RefreshIndicator(onRefresh: widget.onRefresh!, child: grid),
        ),
      ],
    );
  }
}

class _CatalogSearchField extends StatelessWidget {
  const _CatalogSearchField({
    required this.controller,
    required this.onChanged,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText ?? context.tr('Search this list'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.tr('Clear'),
                onPressed: () {
                  controller.clear();
                  onChanged('');
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
          borderSide: const BorderSide(color: AppColors.violet, width: 1.4),
        ),
      ),
    );
  }
}

class _CatalogControls extends StatelessWidget {
  const _CatalogControls({
    required this.filter,
    required this.statusFilter,
    required this.sort,
    required this.showStatusFilter,
    required this.onFilterChanged,
    required this.onStatusFilterChanged,
    required this.onSortChanged,
  });

  final MediaCatalogFilter filter;
  final MediaStatusFilter statusFilter;
  final MediaCatalogSort sort;
  final bool showStatusFilter;
  final ValueChanged<MediaCatalogFilter> onFilterChanged;
  final ValueChanged<MediaStatusFilter> onStatusFilterChanged;
  final ValueChanged<MediaCatalogSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactFilterMenu<MediaCatalogFilter>(
            value: filter,
            values: MediaCatalogFilter.values,
            tooltip: context.tr('Media type'),
            leadingIcon: Icons.movie_filter_outlined,
            isActive: filter != MediaCatalogFilter.all,
            labelBuilder: (value) => _filterLabel(context, value),
            iconBuilder: _mediaFilterIcon,
            onSelected: onFilterChanged,
          ),
        ),
        if (showStatusFilter) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _CompactFilterMenu<MediaStatusFilter>(
              value: statusFilter,
              values: MediaStatusFilter.values,
              tooltip: context.tr('Status'),
              leadingIcon: Icons.tune_rounded,
              isActive: statusFilter != MediaStatusFilter.all,
              selectedLabelBuilder: (value) => value == MediaStatusFilter.all
                  ? context.tr('All')
                  : _statusFilterLabel(context, value),
              labelBuilder: (value) => _statusFilterLabel(context, value),
              iconBuilder: _statusFilterIcon,
              onSelected: onStatusFilterChanged,
            ),
          ),
        ],
        const SizedBox(width: 6),
        PopupMenuButton<MediaCatalogSort>(
          initialValue: sort,
          tooltip: context.tr('Sort'),
          onSelected: onSortChanged,
          itemBuilder: (context) => [
            for (final value in MediaCatalogSort.values)
              PopupMenuItem(
                value: value,
                child: Row(
                  children: [
                    if (sort == value) ...[
                      const Icon(Icons.check_rounded, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(_sortLabel(context, value)),
                  ],
                ),
              ),
          ],
          icon: Icon(
            Icons.swap_vert_rounded,
            color: sort == MediaCatalogSort.newest ? null : AppColors.violet,
          ),
        ),
      ],
    );
  }
}

class _CompactFilterMenu<T> extends StatelessWidget {
  const _CompactFilterMenu({
    required this.value,
    required this.values,
    required this.tooltip,
    required this.leadingIcon,
    required this.isActive,
    required this.labelBuilder,
    required this.iconBuilder,
    required this.onSelected,
    this.selectedLabelBuilder,
  });

  final T value;
  final List<T> values;
  final String tooltip;
  final IconData leadingIcon;
  final bool isActive;
  final String Function(T value) labelBuilder;
  final String Function(T value)? selectedLabelBuilder;
  final IconData Function(T value) iconBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppColors.violet
        : AppColors.white.withValues(alpha: 0.16);
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in values)
          PopupMenuItem<T>(
            value: item,
            child: Row(
              children: [
                Icon(
                  iconBuilder(item),
                  size: 19,
                  color: item == value ? AppColors.violet : null,
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(labelBuilder(item))),
                if (item == value) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.violet,
                  ),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.violet.withValues(alpha: 0.12)
              : AppColors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              leadingIcon,
              size: 18,
              color: isActive ? AppColors.violet : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedLabelBuilder?.call(value) ?? labelBuilder(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

String _filterLabel(BuildContext context, MediaCatalogFilter filter) =>
    switch (filter) {
      MediaCatalogFilter.all => context.tr('All'),
      MediaCatalogFilter.movies => context.tr('Movies'),
      MediaCatalogFilter.series => context.tr('Series'),
    };

String _sortLabel(BuildContext context, MediaCatalogSort sort) =>
    switch (sort) {
      MediaCatalogSort.relevance => context.tr('Relevance'),
      MediaCatalogSort.newest => context.tr('Newest first'),
      MediaCatalogSort.oldest => context.tr('Oldest first'),
      MediaCatalogSort.alphabetical => context.tr('A–Z'),
    };

String _statusFilterLabel(BuildContext context, MediaStatusFilter filter) =>
    switch (filter) {
      MediaStatusFilter.all => context.tr('All statuses'),
      MediaStatusFilter.available => context.tr('Available'),
      MediaStatusFilter.inProgress => context.tr('In progress'),
      MediaStatusFilter.requested => context.tr('Requested'),
      MediaStatusFilter.failed => context.tr('Failed'),
    };

IconData _mediaFilterIcon(MediaCatalogFilter filter) => switch (filter) {
  MediaCatalogFilter.all => Icons.apps_rounded,
  MediaCatalogFilter.movies => Icons.movie_outlined,
  MediaCatalogFilter.series => Icons.tv_outlined,
};

IconData _statusFilterIcon(MediaStatusFilter filter) => switch (filter) {
  MediaStatusFilter.all => Icons.list_alt_rounded,
  MediaStatusFilter.available => Icons.check_circle_outline_rounded,
  MediaStatusFilter.inProgress => Icons.downloading_rounded,
  MediaStatusFilter.requested => Icons.schedule_rounded,
  MediaStatusFilter.failed => Icons.error_outline_rounded,
};

int _dateValue(MediaViewModel media) {
  final releaseDate = media.releaseDate;
  if (releaseDate != null) return releaseDate.millisecondsSinceEpoch;
  final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(media.subtitle ?? '');
  final year = int.tryParse(match?.group(0) ?? '');
  return year == null ? 0 : DateTime(year).millisecondsSinceEpoch;
}
