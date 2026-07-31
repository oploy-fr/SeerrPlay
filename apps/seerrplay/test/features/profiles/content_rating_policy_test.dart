import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/profiles/domain/content_rating_policy.dart';

void main() {
  test('normalizes common international age ratings', () {
    expect(ContentRatingPolicy.minimumAgeFor('Tous publics'), 0);
    expect(ContentRatingPolicy.minimumAgeFor('FSK 12'), 12);
    expect(ContentRatingPolicy.minimumAgeFor('TV-14'), 14);
    expect(ContentRatingPolicy.minimumAgeFor('PG-13'), 13);
  });

  test('blocks unknown and over-age content', () {
    expect(ContentRatingPolicy.allows(null, 12), isFalse);
    expect(ContentRatingPolicy.allows('NR', 12), isFalse);
    expect(ContentRatingPolicy.allows('-16', 12), isFalse);
    expect(ContentRatingPolicy.allows('PG', 12), isTrue);
  });
}
