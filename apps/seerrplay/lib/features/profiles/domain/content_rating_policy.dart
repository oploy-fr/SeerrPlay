class ContentRatingPolicy {
  const ContentRatingPolicy._();

  static bool allows(String? rating, int maximumAge) {
    final minimumAge = minimumAgeFor(rating);
    return minimumAge != null && minimumAge <= maximumAge;
  }

  static int? minimumAgeFor(String? rating) {
    if (rating == null) return null;
    final normalized = rating.trim().toUpperCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (normalized.isEmpty || normalized == 'NR' || normalized == 'UNRATED') {
      return null;
    }
    const ratings = <String, int>{
      'TP': 0,
      'TOUSPUBLICS': 0,
      'U': 0,
      'G': 0,
      'TV-Y': 0,
      'TV-G': 0,
      'FSK0': 0,
      '0': 0,
      'PG': 8,
      'TV-Y7': 7,
      'FSK6': 6,
      '6': 6,
      '7': 7,
      '-10': 10,
      '10': 10,
      'TV-PG': 10,
      'PG-13': 13,
      '12A': 12,
      '-12': 12,
      '12': 12,
      'FSK12': 12,
      'TV-14': 14,
      '14': 14,
      '15': 15,
      '-16': 16,
      '16': 16,
      'FSK16': 16,
      'R': 17,
      'NC-17': 18,
      'TV-MA': 18,
      '-18': 18,
      '18': 18,
      'FSK18': 18,
    };
    final exact = ratings[normalized];
    if (exact != null) return exact;
    final digits = RegExp(r'\d{1,2}').firstMatch(normalized)?.group(0);
    return digits == null ? null : int.tryParse(digits);
  }
}
