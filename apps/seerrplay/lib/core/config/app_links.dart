class AppLinks {
  const AppLinks._();

  static final source = Uri.parse(
    const String.fromEnvironment(
      'SEERRPLAY_GITHUB_URL',
      defaultValue: 'https://github.com/oploy-fr/SeerrPlay',
    ),
  );

  static final privacy = Uri.parse(
    const String.fromEnvironment(
      'SEERRPLAY_PRIVACY_URL',
      defaultValue: 'https://oploy-fr.github.io/SeerrPlay/privacy.html',
    ),
  );

  static final support = Uri.parse(
    const String.fromEnvironment(
      'SEERRPLAY_SUPPORT_URL',
      defaultValue: 'https://oploy-fr.github.io/SeerrPlay/support.html',
    ),
  );
}
