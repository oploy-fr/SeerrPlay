Uri mediaBrowserImageUrl({
  required Uri baseUrl,
  required String itemId,
  String imageType = 'Primary',
  String? tag,
  int? index,
  int? maxWidth,
  int quality = 90,
}) {
  final baseSegments = baseUrl.pathSegments.where(
    (segment) => segment.isNotEmpty,
  );
  final query = <String, String>{
    if (tag != null && tag.isNotEmpty) 'tag': tag,
    if (index != null) 'index': '$index',
    if (maxWidth != null) 'maxWidth': '$maxWidth',
    'quality': '${quality.clamp(0, 100)}',
  };

  return baseUrl.replace(
    pathSegments: [...baseSegments, 'Items', itemId, 'Images', imageType],
    queryParameters: query,
  );
}
