import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('es'),
    Locale('it'),
    Locale('de'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static Set<String> translationKeys(String languageCode) =>
      Set.unmodifiable(_translations[languageCode]?.keys ?? const {});

  String translate(String key, {Map<String, Object> arguments = const {}}) {
    var value =
        (_translations[locale.languageCode] ?? _translations['en'])![key] ??
        key;
    for (final entry in arguments.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  String results(int count) => translate(
    count == 1 ? '{count} result' : '{count} results',
    arguments: {'count': count},
  );

  String episodes(int count) => translate(
    count == 1 ? '{count} episode' : '{count} episodes',
    arguments: {'count': count},
  );

  String status(String value) {
    final download = RegExp(r'^Download (.+)$').firstMatch(value);
    if (download != null) {
      return translate(
        'Download {progression}',
        arguments: {'progression': download.group(1)!},
      );
    }
    var translated = translate(value);
    translated = translated.replaceAllMapped(
      RegExp(r'(\d+) channels'),
      (match) =>
          translate('{count} channels', arguments: {'count': match.group(1)!}),
    );
    final track = RegExp(r'^Track (\d+)$').firstMatch(translated);
    if (track != null) {
      return translate(
        'Track {number}',
        arguments: {'number': track.group(1)!},
      );
    }
    return translated;
  }
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String key, {Map<String, Object> arguments = const {}}) =>
      l10n.translate(key, arguments: arguments);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _translations = <String, Map<String, String>>{
  'fr': {
    'Choose your language': 'Choisissez votre langue',
    'Your phone language is shown first. You can change it later in Settings.':
        'La langue du téléphone est proposée en premier. Vous pourrez la modifier plus tard dans les réglages.',
    'Phone language': 'Langue du téléphone',
    'Language': 'Langue',
    'Request notifications': 'Notifications des demandes',
    'Periodically checks Seerr for approval and availability updates. Your device may delay background checks.':
        'Vérifie périodiquement Seerr pour les approbations et les disponibilités. Votre appareil peut retarder les vérifications en arrière-plan.',
    'Notifications are disabled in system settings.':
        'Les notifications sont désactivées dans les réglages système.',
    'Your request was approved.': 'Votre demande a été approuvée.',
    'Your request was declined.': 'Votre demande a été refusée.',
    'Your request could not be processed.':
        'Votre demande n’a pas pu être traitée.',
    'Partially available on Jellyfin.':
        'Partiellement disponible sur Jellyfin.',
    'Available now on Jellyfin.': 'Disponible maintenant sur Jellyfin.',
    'French': 'Français',
    'English': 'Anglais',
    'Spanish': 'Espagnol',
    'Italian': 'Italien',
    'German': 'Allemand',
    'Media server': 'Serveur multimédia',
    'Media server username': 'Identifiant du serveur multimédia',
    '{service} account': 'Compte {service}',
    'Linked {service} account': 'Compte {service} lié',
    '{service} username': 'Identifiant {service}',
    '{service} password': 'Mot de passe {service}',
    '{service} server': 'Serveur {service}',
    'These credentials sign in to Seerr and {service}.':
        'Ces identifiants permettent de se connecter à Seerr et à {service}.',
    'Plex account connected': 'Compte Plex connecté',
    'Authentication was approved securely through Plex.':
        'L’authentification a été approuvée de manière sécurisée via Plex.',
    'Secure Plex authentication': 'Authentification Plex sécurisée',
    'The Plex website opens to approve SeerrPlay.':
        'Le site Plex s’ouvre pour autoriser SeerrPlay.',
    'Approve the connection in Plex…': 'Approuvez la connexion dans Plex…',
    'Approve SeerrPlay in Plex, then return to the app…':
        'Approuvez SeerrPlay dans Plex, puis revenez dans l’application…',
    'Looking for your media server automatically…':
        'Recherche automatique de votre serveur multimédia…',
    '{service} server found automatically.':
        'Serveur {service} trouvé automatiquement.',
    'Seerr does not publish the {service} address. Enter it manually.':
        'Seerr ne publie pas l’adresse {service}. Saisissez-la manuellement.',
    '{service} server found. Checking the connection…':
        'Serveur {service} trouvé. Vérification de la connexion…',
    'Signing in to {service}…': 'Connexion à {service}…',
    '{service} server found and connected.':
        'Serveur {service} trouvé et connecté.',
    'The media server account selected for Seerr is reused automatically.':
        'Le compte du serveur multimédia sélectionné pour Seerr est réutilisé automatiquement.',
    '{service} rejected these credentials.':
        '{service} a refusé ces identifiants.',
    '{service} took too long to respond.':
        '{service} a mis trop de temps à répondre.',
    '{service} is unreachable. Check the domain, port, and network.':
        '{service} est inaccessible. Vérifiez le domaine, le port et le réseau.',
    'This address does not appear to be a {service} server.':
        'Cette adresse ne semble pas être un serveur {service}.',
    'Used only to reach the Seerr and media servers you configure.':
        'Utilisé uniquement pour joindre les serveurs Seerr et multimédias que vous configurez.',
    'SeerrPlay is an independent client. It is not an official Seerr, Plex, Jellyfin or Emby application and does not host a media catalog.':
        'SeerrPlay est un client indépendant. Ce n’est pas une application officielle de Seerr, Plex, Jellyfin ou Emby et elle n’héberge aucun catalogue multimédia.',
    'The application connects directly to the Seerr and media server addresses configured in each profile, without a SeerrPlay intermediary server.':
        'L’application se connecte directement aux adresses des serveurs Seerr et multimédias configurées dans chaque profil, sans serveur intermédiaire SeerrPlay.',
    'Requests, searches and playback information are exchanged directly with the Seerr and media servers configured by the user.':
        'Les demandes, recherches et informations de lecture sont échangées directement avec les serveurs Seerr et multimédias configurés par l’utilisateur.',
    'Availability and operation depend on the Seerr and media servers configured by the user and on their respective administrators.':
        'La disponibilité et le fonctionnement dépendent des serveurs Seerr et multimédias configurés par l’utilisateur ainsi que de leurs administrateurs respectifs.',
    'Available now on your media server.':
        'Disponible maintenant sur votre serveur multimédia.',
    'Partially available on your media server.':
        'Partiellement disponible sur votre serveur multimédia.',
    'This media is not linked to the media server.':
        'Ce média n’est pas associé au serveur multimédia.',
    'Unable to connect to the media server or Seerr. Check your connection or contact your media server administrator.':
        'Impossible de se connecter au serveur multimédia ou à Seerr. Vérifiez votre connexion ou contactez l’administrateur de votre serveur multimédia.',
    'Continue': 'Continuer',
    'Home navigation': 'Accueil',
    'Search': 'Recherche',
    'Requests': 'Demandes',
    'Settings': 'Réglages',
    'Your media space': 'Votre espace multimédia',
    'Choose the servers and account currently in use.':
        'Choisissez les serveurs et le compte actuellement utilisés.',
    'Application': 'Application',
    'Language and notification preferences.':
        'Préférences de langue et de notifications.',
    'Direct connections': 'Connexions directes',
    'SeerrPlay communicates directly with the servers in this profile.':
        'SeerrPlay communique directement avec les serveurs de ce profil.',
    'Privacy and data': 'Confidentialité et données',
    'Your data stays under your control.':
        'Vos données restent sous votre contrôle.',
    'Privacy policy': 'Politique de confidentialité',
    'How SeerrPlay handles your data.': 'Comment SeerrPlay traite vos données.',
    'Local network access': 'Accès au réseau local',
    'Used only to reach the Seerr and Jellyfin servers you configure.':
        'Utilisé uniquement pour joindre les serveurs Seerr et Jellyfin que vous configurez.',
    'No SeerrPlay cloud': 'Aucun cloud SeerrPlay',
    'Credentials and preferences are stored on this device.':
        'Les identifiants et préférences sont stockés sur cet appareil.',
    'Delete local profile data': 'Supprimer les données locales du profil',
    'Removes this profile and its credentials from this device.':
        'Supprime ce profil et ses identifiants de cet appareil.',
    'About': 'À propos',
    'Information, legal documents and diagnostics.':
        'Informations, documents légaux et diagnostics.',
    'About SeerrPlay': 'À propos de SeerrPlay',
    'Independent client for your personal media servers.':
        'Client indépendant pour vos serveurs multimédias personnels.',
    'Terms of use': 'Conditions d’utilisation',
    'Rules for using SeerrPlay responsibly.':
        'Règles pour utiliser SeerrPlay de manière responsable.',
    'Open-source licenses': 'Licences open source',
    'Libraries used to build the application.':
        'Bibliothèques utilisées pour créer l’application.',
    'Credits': 'Crédits',
    'Projects, services and data sources used by SeerrPlay.':
        'Projets, services et sources de données utilisés par SeerrPlay.',
    'Projects and services': 'Projets et services',
    'SeerrPlay interoperates with these independent projects and services.':
        'SeerrPlay interagit avec ces projets et services indépendants.',
    'Media discovery and request management for personal media servers.':
        'Découverte de médias et gestion des demandes pour les serveurs multimédias personnels.',
    'Open-source media server and playback APIs.':
        'Serveur multimédia open source et API de lecture.',
    'Personal media server and playback platform.':
        'Serveur multimédia personnel et plateforme de lecture.',
    'Cross-platform application framework.':
        'Framework de développement d’applications multiplateformes.',
    'View SeerrPlay on GitHub': 'Voir SeerrPlay sur GitHub',
    'Unable to open this link.': 'Impossible d’ouvrir ce lien.',
    'Public privacy policy': 'Politique de confidentialité publique',
    'Open the policy published on the web.':
        'Ouvrir la politique publiée sur le web.',
    'Support': 'Assistance',
    'Help, contact and issue reporting.':
        'Aide, contact et signalement de problèmes.',
    'Version {version} ({build})': 'Version {version} ({build})',
    'Copy diagnostics without credentials.':
        'Copier les diagnostics sans les identifiants.',
    'Diagnostics copied.': 'Diagnostics copiés.',
    'One application to discover, request, watch and download media from your own servers.':
        'Une seule application pour découvrir, demander, regarder et télécharger les médias de vos propres serveurs.',
    'Independent application': 'Application indépendante',
    'SeerrPlay is an independent client. It is not an official Seerr or Jellyfin application and does not host a media catalog.':
        'SeerrPlay est un client indépendant. Ce n’est pas une application officielle de Seerr ou Jellyfin et elle n’héberge aucun catalogue multimédia.',
    'Direct architecture': 'Architecture directe',
    'The application connects directly to the Seerr and Jellyfin addresses configured in each profile, without a SeerrPlay intermediary server.':
        'L’application se connecte directement aux adresses Seerr et Jellyfin configurées dans chaque profil, sans serveur intermédiaire SeerrPlay.',
    'Designed for personal libraries':
        'Conçu pour les bibliothèques personnelles',
    'SeerrPlay is intended for media servers and libraries that you own or are authorized to access.':
        'SeerrPlay est destiné aux serveurs et bibliothèques multimédias que vous possédez ou auxquels vous êtes autorisé à accéder.',
    'SeerrPlay is designed to minimize data collection and keep control with the user.':
        'SeerrPlay est conçu pour minimiser la collecte de données et laisser le contrôle à l’utilisateur.',
    'No tracking or advertising': 'Aucun suivi ni publicité',
    'SeerrPlay does not include advertising, analytics or cross-application tracking.':
        'SeerrPlay n’intègre aucune publicité, analyse d’utilisation ou suivi entre applications.',
    'Google Cast': 'Google Cast',
    'Unable to open the Google Cast selector.':
        'Impossible d’ouvrir le sélecteur Google Cast.',
    'When Google Cast is available, the Google Cast SDK may send technical application, device discovery and cast session information to Google. Media server credentials are not included.':
        'Lorsque Google Cast est disponible, son SDK peut transmettre à Google des informations techniques sur l’application, la détection des appareils et les sessions de diffusion. Les identifiants des serveurs multimédias ne sont pas inclus.',
    'Direct server communication': 'Communication directe avec les serveurs',
    'Requests, searches and playback information are exchanged directly with the Seerr and Jellyfin servers configured by the user.':
        'Les demandes, recherches et informations de lecture sont échangées directement avec les serveurs Seerr et Jellyfin configurés par l’utilisateur.',
    'On-device storage': 'Stockage sur l’appareil',
    'Profiles and preferences are stored on the device. Authentication secrets are stored using the secure storage provided by the operating system.':
        'Les profils et préférences sont stockés sur l’appareil. Les secrets d’authentification utilisent le stockage sécurisé du système d’exploitation.',
    'Downloads and notifications': 'Téléchargements et notifications',
    'Offline media is stored on the device. Request notifications are generated from periodic checks performed by the application.':
        'Les médias hors ligne sont stockés sur l’appareil. Les notifications de demandes proviennent de vérifications périodiques effectuées par l’application.',
    'Data deletion': 'Suppression des données',
    'Deleting a profile removes its local connection information and credentials. Offline downloads can be removed from the Downloads page.':
        'La suppression d’un profil retire ses informations de connexion et identifiants locaux. Les téléchargements hors ligne peuvent être supprimés depuis la page Téléchargements.',
    'Use of SeerrPlay requires access to compatible servers supplied by the user.':
        'L’utilisation de SeerrPlay nécessite l’accès à des serveurs compatibles fournis par l’utilisateur.',
    'Authorized access only': 'Accès autorisé uniquement',
    'You must only connect to servers, libraries and media that you own or are authorized to use.':
        'Vous devez uniquement vous connecter à des serveurs, bibliothèques et médias que vous possédez ou êtes autorisé à utiliser.',
    'No media service': 'Aucun service multimédia',
    'SeerrPlay does not sell, provide or host films, series, subscriptions or download sources.':
        'SeerrPlay ne vend, ne fournit et n’héberge aucun film, série, abonnement ou source de téléchargement.',
    'Third-party services': 'Services tiers',
    'Availability and operation depend on the Seerr and Jellyfin servers configured by the user and on their respective administrators.':
        'La disponibilité et le fonctionnement dépendent des serveurs Seerr et Jellyfin configurés par l’utilisateur et de leurs administrateurs respectifs.',
    'User responsibility': 'Responsabilité de l’utilisateur',
    'The user is responsible for server security, content rights, network configuration and compliance with applicable laws.':
        'L’utilisateur est responsable de la sécurité des serveurs, des droits sur les contenus, de la configuration réseau et du respect des lois applicables.',
    'Connected': 'Connecté',
    'Unable to load Home': 'Impossible de charger l’accueil',
    'Pull down to try again. If the session expired, reconnect the services in Settings.':
        'Tire vers le bas pour réessayer. Si la session a expiré, reconnecte les services dans Réglages.',
    'Continue watching': 'Continuez à regarder',
    'Your available requests': 'Vos demandes disponibles',
    'Trending': 'Tendances',
    'Popular movies': 'Films populaires',
    'Popular series': 'Séries populaires',
    'No media to display.': 'Aucun média à afficher.',
    'Unable to reach your media services':
        'Impossible de joindre vos services multimédias',
    'Unable to connect to Jellyfin or Seerr, or both. Check your connection or contact your media server administrator.':
        'Impossible de se connecter à Jellyfin ou Seerr, ou aux deux. Vérifiez votre connexion ou contactez le gestionnaire de votre serveur multimédia.',
    'The {service} session has expired.': 'La session {service} a expiré.',
    'Access was forbidden by {service}.': 'L’accès a été refusé par {service}.',
    '{service} did not respond in time.': '{service} n’a pas répondu à temps.',
    'No response from {service}.': 'Aucune réponse de {service}.',
    '{service} returned a server error.':
        '{service} a renvoyé une erreur serveur.',
    'Unexpected {service} error.': 'Erreur {service} inattendue.',
    'Unwatched requests': 'Demandes non visionnées',
    'Unable to load requests.': 'Impossible de charger les demandes.',
    'All requests have been watched.': 'Toutes les demandes ont été vues.',
    'Providers · {region}': 'Diffuseurs · {region}',
    'Media library': 'Bibliothèque multimédia',
    'Search the media library': 'Rechercher dans la bibliothèque multimédia',
    'Unable to load the media library.':
        'Impossible de charger la bibliothèque multimédia.',
    'Search Seerr': 'Recherche Seerr',
    'What do you want to watch?': 'Que veux-tu regarder ?',
    'Search the localized or original titles in the Seerr catalog.':
        'Recherche les titres français ou originaux du catalogue Seerr.',
    'E.g. Law Abiding Citizen': 'Ex. Que justice soit faite',
    'Clear': 'Effacer',
    'Search unavailable.': 'Recherche indisponible.',
    'Try again': 'Réessayer',
    'No results for “{query}”.': 'Aucun résultat pour « {query} ».',
    '{count} result': '{count} résultat',
    '{count} results': '{count} résultats',
    'Movies and series': 'Films et séries',
    'Enter a localized title or its original title.':
        'Saisis un titre français ou son titre original.',
    'New profile': 'Nouveau profil',
    "Who's watching?": 'Qui regarde ?',
    'Choose a profile to continue.': 'Choisissez un profil pour continuer.',
    'Choose an avatar': 'Choisissez un avatar',
    'Switch profile': 'Changer de profil',
    'Trending rank': 'Tendance n° {rank}',
    'Create and connect': 'Créer et connecter',
    'Back': 'Retour',
    'Profile name': 'Nom du profil',
    'Home, Travel, Family…': 'Maison, Voyage, Famille…',
    'Name': 'Nom',
    'Home profile name': 'Maison',
    'Seerr server': 'Serveur Seerr',
    'Request server address and account': 'Adresse et compte de demande',
    'Seerr email': 'E-mail Seerr',
    'Jellyfin username': 'Utilisateur Jellyfin',
    'Password': 'Mot de passe',
    'Jellyfin server': 'Serveur Jellyfin',
    'Playback server address': 'Adresse de lecture',
    'Credentials already entered': 'Identifiants déjà renseignés',
    'The Jellyfin account selected for Seerr is reused automatically.':
        'Le compte Jellyfin choisi pour Seerr est réutilisé automatiquement.',
    'Jellyfin password': 'Mot de passe Jellyfin',
    'Required field': 'Champ obligatoire',
    'Port between 1 and 65535': 'Port entre 1 et 65535',
    'Invalid URL, example: http://192.168.1.10':
        'URL invalide, exemple : http://192.168.1.10',
    'HTTP does not encrypt your credentials. Use it only for a trusted local network; HTTPS is recommended.':
        'HTTP ne chiffre pas vos identifiants. Utilisez-le uniquement sur un réseau local de confiance ; HTTPS est recommandé.',
    'URL': 'URL',
    'Port': 'Port',
    'Domain or IP address': 'Domaine ou adresse IP',
    'Custom port (optional)': 'Port personnalisé (facultatif)',
    'Invalid domain, example: jellyfin.example.com':
        'Domaine invalide, exemple : jellyfin.exemple.fr',
    'Checking the Seerr server…': 'Vérification du serveur Seerr…',
    'Signing in to Seerr…': 'Connexion à Seerr…',
    'Looking for your Jellyfin server automatically…':
        'Nous recherchons automatiquement votre serveur Jellyfin…',
    'Jellyfin server found. Checking the connection…':
        'Serveur Jellyfin trouvé. Vérification de la connexion…',
    'Jellyfin server found and connected.':
        'Serveur Jellyfin trouvé et connecté.',
    'Signing in to Jellyfin…': 'Connexion à Jellyfin…',
    'Jellyfin address found in Seerr settings.':
        'Adresse Jellyfin trouvée dans les réglages Seerr.',
    'Jellyfin address found from an available media.':
        'Adresse Jellyfin trouvée depuis un média disponible.',
    'Seerr does not publish a Jellyfin address and no available media contains one. Enter it manually.':
        'Seerr ne publie aucune adresse Jellyfin et aucun média disponible n’en contient. Saisissez-la manuellement.',
    'Seerr rejected these credentials.': 'Seerr a refusé ces identifiants.',
    'Jellyfin rejected these credentials.':
        'Jellyfin a refusé ces identifiants.',
    'Your account is not allowed to perform this action.':
        'Votre compte n’est pas autorisé à effectuer cette action.',
    'Seerr took too long to respond.': 'Seerr a mis trop de temps à répondre.',
    'Jellyfin took too long to respond.':
        'Jellyfin a mis trop de temps à répondre.',
    'The server domain could not be found.':
        'Le domaine du serveur est introuvable.',
    'The secure connection certificate is invalid.':
        'Le certificat de connexion sécurisée est invalide.',
    'Seerr is unreachable. Check the domain, port, and network.':
        'Seerr est inaccessible. Vérifiez le domaine, le port et le réseau.',
    'Jellyfin is unreachable. Check the domain, port, and network.':
        'Jellyfin est inaccessible. Vérifiez le domaine, le port et le réseau.',
    'This address does not appear to be a Seerr server.':
        'Cette adresse ne semble pas être un serveur Seerr.',
    'This address does not appear to be a Jellyfin server.':
        'Cette adresse ne semble pas être un serveur Jellyfin.',
    'The server returned an internal error.':
        'Le serveur a renvoyé une erreur interne.',
    'The server returned an invalid response.':
        'Le serveur a renvoyé une réponse invalide.',
    'Unable to load profiles.\n{error}':
        'Impossible de charger les profils.\n{error}',
    'Reconnect services': 'Reconnecter les services',
    'Jellyfin account': 'Compte Jellyfin',
    'Seerr account': 'Compte Seerr',
    'Linked Jellyfin account': 'Compte Jellyfin lié',
    'These credentials sign in to Seerr and Jellyfin.':
        'Ces identifiants ouvrent Seerr et Jellyfin.',
    'Sign in': 'Se connecter',
    'Delete this profile?': 'Supprimer ce profil ?',
    'The “{name}” profile and its sign-in information will be removed from this device.':
        'Le profil « {name} » et ses informations de connexion seront supprimés de cet appareil.',
    'Cancel': 'Annuler',
    'Delete': 'Supprimer',
    'Profile': 'Profil',
    'Active profile': 'Profil actif',
    'Add profile': 'Ajouter un profil',
    'Profiles': 'Profils',
    'Connection': 'Connexion',
    'Secure connection (HTTPS)': 'Connexion sécurisée (HTTPS)',
    'Unencrypted connection (HTTP)': 'Connexion non chiffrée (HTTP)',
    'Delete profile': 'Supprimer le profil',
    'Remove this profile and its credentials from this device.':
        'Retire ce profil et ses identifiants de cet appareil.',
    'Unable to load this category.': 'Impossible de charger cette catégorie.',
    'Unable to load this provider.': 'Impossible de charger cette plateforme.',
    'Request sent to Seerr.': 'Demande envoyée à Seerr.',
    'This media has already been requested.': 'Ce média a déjà été demandé.',
    'Unable to send the request.': 'Impossible d’envoyer la demande.',
    'New attempt sent.': 'Nouvelle tentative envoyée.',
    'Unable to retry the request.': 'Impossible de relancer la demande.',
    'Delete this request?': 'Supprimer cette demande ?',
    'The pending request for “{title}” will be removed from Seerr.':
        'La demande en attente pour « {title} » sera supprimée de Seerr.',
    'Delete request': 'Supprimer la demande',
    'Request deleted.': 'Demande supprimée.',
    'Unable to delete the request.': 'Impossible de supprimer la demande.',
    'Resume playback': 'Reprendre la lecture',
    'Play action': 'Regarder',
    'Downloading': 'Téléchargement en cours',
    'No summary available.': 'Aucun résumé disponible.',
    'Recommendations': 'Recommandations',
    'Similar titles': 'Titres similaires',
    'Detailed Seerr information is unavailable.':
        'Les informations Seerr détaillées sont indisponibles.',
    '{progress}% watched': '{progress} % lu',
    'Retry request': 'Réessayer la demande',
    'Requested media': 'Demandé',
    'Request on Seerr': 'Demander sur Seerr',
    'Directed by': 'Réalisation',
    'Production': 'Production',
    'Original language': 'Langue originale',
    'Votes': 'Votes',
    'Budget': 'Budget',
    'Information': 'Informations',
    'Trailers': 'Bandes-annonces',
    'Watch trailer': 'Voir la bande-annonce',
    'Featured trailer': 'Bande-annonce',
    'Overview': 'Résumé',
    'Creative team': 'Équipe créative',
    'Technical details': 'Détails techniques',
    'Tomatometer': 'Tomatomètre',
    'Rotten audience': 'Public Rotten Tomatoes',
    'Learn more': 'En savoir plus',
    'Crew, technical details and studios':
        'Équipe, informations techniques et studios',
    'Video release date': 'Sortie vidéo',
    'Age rating': 'Limite d’âge',
    'Revenue': 'Recettes',
    'Studios': 'Studios',
    'Original title': 'Titre original',
    'Status': 'Statut',
    'Release date': 'Date de sortie',
    'Video': 'Vidéo',
    'Cast': 'Acteurs',
    'Seasons': 'Saisons',
    'Available': 'Disponible',
    'Partial': 'Partielle',
    'Requested season': 'Demandée',
    'Unavailable': 'Indisponible',
    '{count} episode': '{count} épisode',
    '{count} episodes': '{count} épisodes',
    'Season requested on Seerr.': 'Saison demandée à Seerr.',
    'Season unavailable.': 'Saison indisponible.',
    'Requesting…': 'Demande en cours…',
    'Request this season': 'Demander cette saison',
    'Episodes': 'Épisodes',
    'Watched': 'Vu',
    'Currently watching': 'En cours de visionnage',
    'More playback options': 'Plus d’options de lecture',
    'Play from beginning': 'Revoir depuis le début',
    'Mark as watched': 'Marquer comme vu',
    'Mark as unwatched': 'Marquer comme non vu',
    'Marked as watched.': 'Marqué comme vu.',
    'Marked as unwatched.': 'Marqué comme non vu.',
    'Unable to update watched status.':
        'Impossible de modifier le statut de visionnage.',
    'Choose a season': 'Choisir une saison',
    'No unwatched episode remains.': 'Il ne reste aucun épisode non visionné.',
    'Unable to load the next episode.':
        'Impossible de charger l’épisode suivant.',
    'Season available': 'Saison disponible',
    'Season partially available': 'Saison partiellement disponible',
    'Season requested': 'Saison demandée',
    'Season unavailable': 'Saison indisponible',
    'This media is not linked to Jellyfin.':
        'Ce média n’est pas associé à Jellyfin.',
    'No video source available.': 'Aucune source vidéo disponible.',
    'Hide volume': 'Masquer le volume',
    'Volume': 'Volume',
    'Picture in Picture': 'Image dans l’image',
    'Playing with AirPlay': 'Lecture avec AirPlay',
    'Use the AirPlay button to change or stop playback on the TV.':
        'Utilisez le bouton AirPlay pour changer de téléviseur ou arrêter la diffusion.',
    'Playback settings': 'Paramètres de lecture',
    'Enter full screen': 'Passer en plein écran',
    'Exit full screen': 'Quitter le plein écran',
    'Pause': 'Pause',
    'Play state': 'Lecture',
    'Rewind 10 seconds': 'Reculer de 10 secondes',
    'Forward 10 seconds': 'Avancer de 10 secondes',
    'Quality': 'Qualité',
    'Speed': 'Vitesse',
    'Picture format': 'Format de l’image',
    'Audio': 'Audio',
    'No other audio track available': 'Aucune autre piste audio disponible',
    'Subtitles': 'Sous-titres',
    'Subtitle size': 'Taille des sous-titres',
    'Subtitle color': 'Couleur des sous-titres',
    'Subtitle background': 'Fond des sous-titres',
    'Subtitle appearance': 'Apparence des sous-titres',
    'Size, color and background used during playback.':
        'Taille, couleur et fond utilisés pendant la lecture.',
    'Subtitle preview': 'Aperçu des sous-titres',
    'Save': 'Enregistrer',
    'Small': 'Petite',
    'Medium': 'Moyenne',
    'Large': 'Grande',
    'White': 'Blanc',
    'Yellow': 'Jaune',
    'Cyan': 'Cyan',
    'None': 'Aucun',
    'Subtle': 'Discret',
    'Solid': 'Opaque',
    'Off': 'Désactivés',
    'Forced': 'Forcé',
    'Default': 'Défaut',
    'Fill screen': 'Plein écran',
    'Fit image': 'Image complète',
    'Auto · Jellyfin': 'Auto · Jellyfin',
    'Stream selected by {service}': 'Flux sélectionné par {service}',
    'Direct play': 'Lecture directe',
    'Direct stream': 'Flux direct',
    'Mobile · 2 Mb/s': 'Mobile · 2 Mb/s',
    'Unable to play': 'Lecture impossible',
    'Available to watch': 'Disponible à regarder',
    'Partially available': 'Partiellement disponible',
    'Pending': 'En attente',
    'Declined': 'Refusée',
    'Failed': 'Échec',
    'Download {progression}': 'Download {progression}',
    'Downloaded': 'Téléchargé',
    '{count} channels': '{count} channels',
    'Track {number}': 'Track {number}',
    'Credentials rejected by Seerr or Jellyfin.':
        'Identifiants refusés par Seerr ou Jellyfin.',
    'Server unreachable. Check the URL, port, and network.':
        'Serveur inaccessible. Vérifie l’URL, le port et le réseau.',
    'Seerr did not return a session.': 'Seerr n’a pas renvoyé de session.',
    'Invalid Jellyfin authentication response':
        'Réponse d’authentification Jellyfin invalide',
    'No episode is available for this series.':
        'Aucun épisode disponible pour cette série.',
    'Age {rating}': 'Âge {rating}',
    'Unable to load this person.': 'Impossible de charger cette personne.',
    'Biography': 'Biographie',
    'Born': 'Naissance',
    'Died': 'Décès',
    'Place of birth': 'Lieu de naissance',
    'Known for': 'Connu pour',
    'Also known as': 'Aussi connu sous',
    'Appearances': 'Apparitions',
    'Behind the camera': 'Derrière la caméra',
    'No biography available.': 'Aucune biographie disponible.',
    'Search this list': 'Rechercher dans cette liste',
    'Search this category': 'Rechercher dans cette catégorie',
    'No media matches these filters.':
        'Aucun média ne correspond à ces filtres.',
    'All': 'Tout',
    'Media type': 'Type de média',
    'Movies': 'Films',
    'Series': 'Séries',
    'Requested': 'Demandé',
    'Sort': 'Trier',
    'Relevance': 'Pertinence',
    'Newest first': 'Plus récents',
    'Oldest first': 'Plus anciens',
    'A–Z': 'A–Z',
    'All statuses': 'Tous les statuts',
    'In progress': 'En cours',
    'Downloads': 'Téléchargements',
    'Unable to load offline downloads.':
        'Impossible de charger les téléchargements hors-ligne.',
    'Delete this download?': 'Supprimer ce téléchargement ?',
    'The offline copy of “{title}” will be removed from this device.':
        'La copie hors-ligne de « {title} » sera supprimée de cet appareil.',
    '{count} offline · {size}': '{count} hors-ligne · {size}',
    'Play offline': 'Lire hors-ligne',
    'Delete download': 'Supprimer le téléchargement',
    'Downloading · {progress}%': 'Téléchargement · {progress} %',
    'Downloading · {progress}% · {time} left':
        'Téléchargement · {progress} % · reste {time}',
    'Child mode': 'Mode enfant',
    'Only shows content whose age rating is known and allowed.':
        'Affiche uniquement les contenus dont la classification d’âge est connue et autorisée.',
    'Maximum age rating': 'Classification d’âge maximale',
    'Up to age {age}': 'Jusqu’à {age} ans',
    'Preparing download…': 'Préparation du téléchargement…',
    'Available offline · {size}': 'Disponible hors-ligne · {size}',
    'Available offline': 'Disponible hors-ligne',
    'No offline downloads': 'Aucun téléchargement hors-ligne',
    'Download an available movie or episode to watch it without a connection.':
        'Télécharge un film ou un épisode disponible pour le regarder sans connexion.',
    'Download interrupted.': 'Téléchargement interrompu.',
    'The media server does not allow this account to download media.':
        'Le serveur multimédia n’autorise pas ce compte à télécharger des médias.',
    'Unable to download this media.': 'Impossible de télécharger ce média.',
    'The downloaded file is unavailable.':
        'Le fichier téléchargé est indisponible.',
    'Download started.': 'Téléchargement démarré.',
    'Unable to start the download.':
        'Impossible de démarrer le téléchargement.',
    'Retry download': 'Réessayer le téléchargement',
    'Download': 'Télécharger',
    'Download offline': 'Télécharger hors ligne',
    'Choose download quality': 'Choisir la qualité du téléchargement',
    'The size is an estimate. Compatible copies are transcoded by your media server before offline playback.':
        'La taille est une estimation. Les copies compatibles sont transcodées par votre serveur multimédia avant la lecture hors-ligne.',
    'Up to 1080p': 'Jusqu’à 1080p',
    'Up to 720p': 'Jusqu’à 720p',
    'Up to 480p': 'Jusqu’à 480p',
    'Original quality': 'Qualité originale',
    'MP4': 'MP4',
    'H.264/AAC': 'H.264/AAC',
    'Transcoded by {service}': 'Transcodé par {service}',
    'No transcoding': 'Sans transcodage',
    'Recommended': 'Recommandé',
    'This original format may not play on this device.':
        'Ce format original peut ne pas être lisible sur cet appareil.',
    'Unknown size': 'Taille inconnue',
    'Download · about {size}': 'Télécharger · environ {size}',
    'Invalid Jellyfin response': 'Réponse Jellyfin invalide',
  },
  'en': {
    'Choose your language': 'Choose your language',
    'Your phone language is shown first. You can change it later in Settings.':
        'Your phone language is shown first. You can change it later in Settings.',
    'Phone language': 'Phone language',
    'Language': 'Language',
    'Request notifications': 'Request notifications',
    'Periodically checks Seerr for approval and availability updates. Your device may delay background checks.':
        'Periodically checks Seerr for approval and availability updates. Your device may delay background checks.',
    'Notifications are disabled in system settings.':
        'Notifications are disabled in system settings.',
    'Your request was approved.': 'Your request was approved.',
    'Your request was declined.': 'Your request was declined.',
    'Your request could not be processed.':
        'Your request could not be processed.',
    'Partially available on Jellyfin.': 'Partially available on Jellyfin.',
    'Available now on Jellyfin.': 'Available now on Jellyfin.',
    'French': 'French',
    'English': 'English',
    'Spanish': 'Spanish',
    'Italian': 'Italian',
    'German': 'German',
    'Media server': 'Media server',
    'Media server username': 'Media server username',
    '{service} account': '{service} account',
    'Linked {service} account': 'Linked {service} account',
    '{service} username': '{service} username',
    '{service} password': '{service} password',
    '{service} server': '{service} server',
    'These credentials sign in to Seerr and {service}.':
        'These credentials sign in to Seerr and {service}.',
    'Plex account connected': 'Plex account connected',
    'Authentication was approved securely through Plex.':
        'Authentication was approved securely through Plex.',
    'Secure Plex authentication': 'Secure Plex authentication',
    'The Plex website opens to approve SeerrPlay.':
        'The Plex website opens to approve SeerrPlay.',
    'Approve the connection in Plex…': 'Approve the connection in Plex…',
    'Approve SeerrPlay in Plex, then return to the app…':
        'Approve SeerrPlay in Plex, then return to the app…',
    'Looking for your media server automatically…':
        'Looking for your media server automatically…',
    '{service} server found automatically.':
        '{service} server found automatically.',
    'Seerr does not publish the {service} address. Enter it manually.':
        'Seerr does not publish the {service} address. Enter it manually.',
    '{service} server found. Checking the connection…':
        '{service} server found. Checking the connection…',
    'Signing in to {service}…': 'Signing in to {service}…',
    '{service} server found and connected.':
        '{service} server found and connected.',
    'The media server account selected for Seerr is reused automatically.':
        'The media server account selected for Seerr is reused automatically.',
    '{service} rejected these credentials.':
        '{service} rejected these credentials.',
    '{service} took too long to respond.':
        '{service} took too long to respond.',
    '{service} is unreachable. Check the domain, port, and network.':
        '{service} is unreachable. Check the domain, port, and network.',
    'This address does not appear to be a {service} server.':
        'This address does not appear to be a {service} server.',
    'Used only to reach the Seerr and media servers you configure.':
        'Used only to reach the Seerr and media servers you configure.',
    'SeerrPlay is an independent client. It is not an official Seerr, Plex, Jellyfin or Emby application and does not host a media catalog.':
        'SeerrPlay is an independent client. It is not an official Seerr, Plex, Jellyfin or Emby application and does not host a media catalog.',
    'The application connects directly to the Seerr and media server addresses configured in each profile, without a SeerrPlay intermediary server.':
        'The application connects directly to the Seerr and media server addresses configured in each profile, without a SeerrPlay intermediary server.',
    'Requests, searches and playback information are exchanged directly with the Seerr and media servers configured by the user.':
        'Requests, searches and playback information are exchanged directly with the Seerr and media servers configured by the user.',
    'Availability and operation depend on the Seerr and media servers configured by the user and on their respective administrators.':
        'Availability and operation depend on the Seerr and media servers configured by the user and on their respective administrators.',
    'Available now on your media server.':
        'Available now on your media server.',
    'Partially available on your media server.':
        'Partially available on your media server.',
    'This media is not linked to the media server.':
        'This media is not linked to the media server.',
    'Unable to connect to the media server or Seerr. Check your connection or contact your media server administrator.':
        'Unable to connect to the media server or Seerr. Check your connection or contact your media server administrator.',
    'Continue': 'Continue',
    'Home navigation': 'Home',
    'Search': 'Search',
    'Requests': 'Requests',
    'Settings': 'Settings',
    'Your media space': 'Your media space',
    'Choose the servers and account currently in use.':
        'Choose the servers and account currently in use.',
    'Application': 'Application',
    'Language and notification preferences.':
        'Language and notification preferences.',
    'Direct connections': 'Direct connections',
    'SeerrPlay communicates directly with the servers in this profile.':
        'SeerrPlay communicates directly with the servers in this profile.',
    'Privacy and data': 'Privacy and data',
    'Your data stays under your control.':
        'Your data stays under your control.',
    'Privacy policy': 'Privacy policy',
    'How SeerrPlay handles your data.': 'How SeerrPlay handles your data.',
    'Local network access': 'Local network access',
    'Used only to reach the Seerr and Jellyfin servers you configure.':
        'Used only to reach the Seerr and Jellyfin servers you configure.',
    'No SeerrPlay cloud': 'No SeerrPlay cloud',
    'Credentials and preferences are stored on this device.':
        'Credentials and preferences are stored on this device.',
    'Delete local profile data': 'Delete local profile data',
    'Removes this profile and its credentials from this device.':
        'Removes this profile and its credentials from this device.',
    'About': 'About',
    'Information, legal documents and diagnostics.':
        'Information, legal documents and diagnostics.',
    'About SeerrPlay': 'About SeerrPlay',
    'Independent client for your personal media servers.':
        'Independent client for your personal media servers.',
    'Terms of use': 'Terms of use',
    'Rules for using SeerrPlay responsibly.':
        'Rules for using SeerrPlay responsibly.',
    'Open-source licenses': 'Open-source licenses',
    'Libraries used to build the application.':
        'Libraries used to build the application.',
    'Credits': 'Credits',
    'Projects, services and data sources used by SeerrPlay.':
        'Projects, services and data sources used by SeerrPlay.',
    'Projects and services': 'Projects and services',
    'SeerrPlay interoperates with these independent projects and services.':
        'SeerrPlay interoperates with these independent projects and services.',
    'Media discovery and request management for personal media servers.':
        'Media discovery and request management for personal media servers.',
    'Open-source media server and playback APIs.':
        'Open-source media server and playback APIs.',
    'Personal media server and playback platform.':
        'Personal media server and playback platform.',
    'Cross-platform application framework.':
        'Cross-platform application framework.',
    'View SeerrPlay on GitHub': 'View SeerrPlay on GitHub',
    'Unable to open this link.': 'Unable to open this link.',
    'Public privacy policy': 'Public privacy policy',
    'Open the policy published on the web.':
        'Open the policy published on the web.',
    'Support': 'Support',
    'Help, contact and issue reporting.': 'Help, contact and issue reporting.',
    'Version {version} ({build})': 'Version {version} ({build})',
    'Copy diagnostics without credentials.':
        'Copy diagnostics without credentials.',
    'Diagnostics copied.': 'Diagnostics copied.',
    'One application to discover, request, watch and download media from your own servers.':
        'One application to discover, request, watch and download media from your own servers.',
    'Independent application': 'Independent application',
    'SeerrPlay is an independent client. It is not an official Seerr or Jellyfin application and does not host a media catalog.':
        'SeerrPlay is an independent client. It is not an official Seerr or Jellyfin application and does not host a media catalog.',
    'Direct architecture': 'Direct architecture',
    'The application connects directly to the Seerr and Jellyfin addresses configured in each profile, without a SeerrPlay intermediary server.':
        'The application connects directly to the Seerr and Jellyfin addresses configured in each profile, without a SeerrPlay intermediary server.',
    'Designed for personal libraries': 'Designed for personal libraries',
    'SeerrPlay is intended for media servers and libraries that you own or are authorized to access.':
        'SeerrPlay is intended for media servers and libraries that you own or are authorized to access.',
    'SeerrPlay is designed to minimize data collection and keep control with the user.':
        'SeerrPlay is designed to minimize data collection and keep control with the user.',
    'No tracking or advertising': 'No tracking or advertising',
    'SeerrPlay does not include advertising, analytics or cross-application tracking.':
        'SeerrPlay does not include advertising, analytics or cross-application tracking.',
    'Google Cast': 'Google Cast',
    'Unable to open the Google Cast selector.':
        'Unable to open the Google Cast selector.',
    'When Google Cast is available, the Google Cast SDK may send technical application, device discovery and cast session information to Google. Media server credentials are not included.':
        'When Google Cast is available, the Google Cast SDK may send technical application, device discovery and cast session information to Google. Media server credentials are not included.',
    'Direct server communication': 'Direct server communication',
    'Requests, searches and playback information are exchanged directly with the Seerr and Jellyfin servers configured by the user.':
        'Requests, searches and playback information are exchanged directly with the Seerr and Jellyfin servers configured by the user.',
    'On-device storage': 'On-device storage',
    'Profiles and preferences are stored on the device. Authentication secrets are stored using the secure storage provided by the operating system.':
        'Profiles and preferences are stored on the device. Authentication secrets are stored using the secure storage provided by the operating system.',
    'Downloads and notifications': 'Downloads and notifications',
    'Offline media is stored on the device. Request notifications are generated from periodic checks performed by the application.':
        'Offline media is stored on the device. Request notifications are generated from periodic checks performed by the application.',
    'Data deletion': 'Data deletion',
    'Deleting a profile removes its local connection information and credentials. Offline downloads can be removed from the Downloads page.':
        'Deleting a profile removes its local connection information and credentials. Offline downloads can be removed from the Downloads page.',
    'Use of SeerrPlay requires access to compatible servers supplied by the user.':
        'Use of SeerrPlay requires access to compatible servers supplied by the user.',
    'Authorized access only': 'Authorized access only',
    'You must only connect to servers, libraries and media that you own or are authorized to use.':
        'You must only connect to servers, libraries and media that you own or are authorized to use.',
    'No media service': 'No media service',
    'SeerrPlay does not sell, provide or host films, series, subscriptions or download sources.':
        'SeerrPlay does not sell, provide or host films, series, subscriptions or download sources.',
    'Third-party services': 'Third-party services',
    'Availability and operation depend on the Seerr and Jellyfin servers configured by the user and on their respective administrators.':
        'Availability and operation depend on the Seerr and Jellyfin servers configured by the user and on their respective administrators.',
    'User responsibility': 'User responsibility',
    'The user is responsible for server security, content rights, network configuration and compliance with applicable laws.':
        'The user is responsible for server security, content rights, network configuration and compliance with applicable laws.',
    'Connected': 'Connected',
    'Unable to load Home': 'Unable to load Home',
    'Pull down to try again. If the session expired, reconnect the services in Settings.':
        'Pull down to try again. If the session expired, reconnect the services in Settings.',
    'Continue watching': 'Continue watching',
    'Your available requests': 'Your available requests',
    'Trending': 'Trending',
    'Popular movies': 'Popular movies',
    'Popular series': 'Popular series',
    'No media to display.': 'No media to display.',
    'Unable to reach your media services':
        'Unable to reach your media services',
    'Unable to connect to Jellyfin or Seerr, or both. Check your connection or contact your media server administrator.':
        'Unable to connect to Jellyfin or Seerr, or both. Check your connection or contact your media server administrator.',
    'The {service} session has expired.': 'The {service} session has expired.',
    'Access was forbidden by {service}.': 'Access was forbidden by {service}.',
    '{service} did not respond in time.': '{service} did not respond in time.',
    'No response from {service}.': 'No response from {service}.',
    '{service} returned a server error.': '{service} returned a server error.',
    'Unexpected {service} error.': 'Unexpected {service} error.',
    'Unwatched requests': 'Unwatched requests',
    'Unable to load requests.': 'Unable to load requests.',
    'All requests have been watched.': 'All requests have been watched.',
    'Providers · {region}': 'Providers · {region}',
    'Media library': 'Media library',
    'Search the media library': 'Search the media library',
    'Unable to load the media library.': 'Unable to load the media library.',
    'Search Seerr': 'Search Seerr',
    'What do you want to watch?': 'What do you want to watch?',
    'Search the localized or original titles in the Seerr catalog.':
        'Search the localized or original titles in the Seerr catalog.',
    'E.g. Law Abiding Citizen': 'E.g. Law Abiding Citizen',
    'Clear': 'Clear',
    'Search unavailable.': 'Search unavailable.',
    'Try again': 'Try again',
    'No results for “{query}”.': 'No results for “{query}”.',
    '{count} result': '{count} result',
    '{count} results': '{count} results',
    'Movies and series': 'Movies and series',
    'Enter a localized title or its original title.':
        'Enter a localized title or its original title.',
    'New profile': 'New profile',
    "Who's watching?": "Who's watching?",
    'Choose a profile to continue.': 'Choose a profile to continue.',
    'Choose an avatar': 'Choose an avatar',
    'Switch profile': 'Switch profile',
    'Trending rank': 'Trending #{rank}',
    'Create and connect': 'Create and connect',
    'Back': 'Back',
    'Profile name': 'Profile name',
    'Home, Travel, Family…': 'Home, Travel, Family…',
    'Name': 'Name',
    'Home profile name': 'Home',
    'Seerr server': 'Seerr server',
    'Request server address and account': 'Request server address and account',
    'Seerr email': 'Seerr email',
    'Jellyfin username': 'Jellyfin username',
    'Password': 'Password',
    'Jellyfin server': 'Jellyfin server',
    'Playback server address': 'Playback server address',
    'Credentials already entered': 'Credentials already entered',
    'The Jellyfin account selected for Seerr is reused automatically.':
        'The Jellyfin account selected for Seerr is reused automatically.',
    'Jellyfin password': 'Jellyfin password',
    'Required field': 'Required field',
    'Port between 1 and 65535': 'Port between 1 and 65535',
    'Invalid URL, example: http://192.168.1.10':
        'Invalid URL, example: http://192.168.1.10',
    'HTTP does not encrypt your credentials. Use it only for a trusted local network; HTTPS is recommended.':
        'HTTP does not encrypt your credentials. Use it only for a trusted local network; HTTPS is recommended.',
    'URL': 'URL',
    'Port': 'Port',
    'Domain or IP address': 'Domain or IP address',
    'Custom port (optional)': 'Custom port (optional)',
    'Invalid domain, example: jellyfin.example.com':
        'Invalid domain, example: jellyfin.example.com',
    'Checking the Seerr server…': 'Checking the Seerr server…',
    'Signing in to Seerr…': 'Signing in to Seerr…',
    'Looking for your Jellyfin server automatically…':
        'Looking for your Jellyfin server automatically…',
    'Jellyfin server found. Checking the connection…':
        'Jellyfin server found. Checking the connection…',
    'Jellyfin server found and connected.':
        'Jellyfin server found and connected.',
    'Signing in to Jellyfin…': 'Signing in to Jellyfin…',
    'Jellyfin address found in Seerr settings.':
        'Jellyfin address found in Seerr settings.',
    'Jellyfin address found from an available media.':
        'Jellyfin address found from an available media.',
    'Seerr does not publish a Jellyfin address and no available media contains one. Enter it manually.':
        'Seerr does not publish a Jellyfin address and no available media contains one. Enter it manually.',
    'Seerr rejected these credentials.': 'Seerr rejected these credentials.',
    'Jellyfin rejected these credentials.':
        'Jellyfin rejected these credentials.',
    'Your account is not allowed to perform this action.':
        'Your account is not allowed to perform this action.',
    'Seerr took too long to respond.': 'Seerr took too long to respond.',
    'Jellyfin took too long to respond.': 'Jellyfin took too long to respond.',
    'The server domain could not be found.':
        'The server domain could not be found.',
    'The secure connection certificate is invalid.':
        'The secure connection certificate is invalid.',
    'Seerr is unreachable. Check the domain, port, and network.':
        'Seerr is unreachable. Check the domain, port, and network.',
    'Jellyfin is unreachable. Check the domain, port, and network.':
        'Jellyfin is unreachable. Check the domain, port, and network.',
    'This address does not appear to be a Seerr server.':
        'This address does not appear to be a Seerr server.',
    'This address does not appear to be a Jellyfin server.':
        'This address does not appear to be a Jellyfin server.',
    'The server returned an internal error.':
        'The server returned an internal error.',
    'The server returned an invalid response.':
        'The server returned an invalid response.',
    'Unable to load profiles.\n{error}': 'Unable to load profiles.\n{error}',
    'Reconnect services': 'Reconnect services',
    'Jellyfin account': 'Jellyfin account',
    'Seerr account': 'Seerr account',
    'Linked Jellyfin account': 'Linked Jellyfin account',
    'These credentials sign in to Seerr and Jellyfin.':
        'These credentials sign in to Seerr and Jellyfin.',
    'Sign in': 'Sign in',
    'Delete this profile?': 'Delete this profile?',
    'The “{name}” profile and its sign-in information will be removed from this device.':
        'The “{name}” profile and its sign-in information will be removed from this device.',
    'Cancel': 'Cancel',
    'Delete': 'Delete',
    'Profile': 'Profile',
    'Active profile': 'Active profile',
    'Add profile': 'Add profile',
    'Profiles': 'Profiles',
    'Connection': 'Connection',
    'Secure connection (HTTPS)': 'Secure connection (HTTPS)',
    'Unencrypted connection (HTTP)': 'Unencrypted connection (HTTP)',
    'Delete profile': 'Delete profile',
    'Remove this profile and its credentials from this device.':
        'Remove this profile and its credentials from this device.',
    'Unable to load this category.': 'Unable to load this category.',
    'Unable to load this provider.': 'Unable to load this provider.',
    'Request sent to Seerr.': 'Request sent to Seerr.',
    'This media has already been requested.':
        'This media has already been requested.',
    'Unable to send the request.': 'Unable to send the request.',
    'New attempt sent.': 'New attempt sent.',
    'Unable to retry the request.': 'Unable to retry the request.',
    'Delete this request?': 'Delete this request?',
    'The pending request for “{title}” will be removed from Seerr.':
        'The pending request for “{title}” will be removed from Seerr.',
    'Delete request': 'Delete request',
    'Request deleted.': 'Request deleted.',
    'Unable to delete the request.': 'Unable to delete the request.',
    'Resume playback': 'Resume playback',
    'Play action': 'Watch',
    'Downloading': 'Downloading',
    'No summary available.': 'No summary available.',
    'Recommendations': 'Recommendations',
    'Similar titles': 'Similar titles',
    'Detailed Seerr information is unavailable.':
        'Detailed Seerr information is unavailable.',
    '{progress}% watched': '{progress}% watched',
    'Retry request': 'Retry request',
    'Requested media': 'Requested',
    'Request on Seerr': 'Request on Seerr',
    'Directed by': 'Directed by',
    'Production': 'Production',
    'Original language': 'Original language',
    'Votes': 'Votes',
    'Budget': 'Budget',
    'Information': 'Information',
    'Trailers': 'Trailers',
    'Watch trailer': 'Watch trailer',
    'Featured trailer': 'Featured trailer',
    'Overview': 'Overview',
    'Creative team': 'Creative team',
    'Technical details': 'Technical details',
    'Tomatometer': 'Tomatometer',
    'Rotten audience': 'Rotten audience',
    'Learn more': 'Learn more',
    'Crew, technical details and studios':
        'Crew, technical details and studios',
    'Video release date': 'Video release date',
    'Age rating': 'Age rating',
    'Revenue': 'Revenue',
    'Studios': 'Studios',
    'Original title': 'Original title',
    'Status': 'Status',
    'Release date': 'Release date',
    'Video': 'Video',
    'Cast': 'Cast',
    'Seasons': 'Seasons',
    'Available': 'Available',
    'Partial': 'Partial',
    'Requested season': 'Requested',
    'Unavailable': 'Unavailable',
    '{count} episode': '{count} episode',
    '{count} episodes': '{count} episodes',
    'Season requested on Seerr.': 'Season requested on Seerr.',
    'Season unavailable.': 'Season unavailable.',
    'Requesting…': 'Requesting…',
    'Request this season': 'Request this season',
    'Episodes': 'Episodes',
    'Watched': 'Watched',
    'Currently watching': 'Currently watching',
    'More playback options': 'More playback options',
    'Play from beginning': 'Play from beginning',
    'Mark as watched': 'Mark as watched',
    'Mark as unwatched': 'Mark as unwatched',
    'Marked as watched.': 'Marked as watched.',
    'Marked as unwatched.': 'Marked as unwatched.',
    'Unable to update watched status.': 'Unable to update watched status.',
    'Choose a season': 'Choose a season',
    'No unwatched episode remains.': 'No unwatched episode remains.',
    'Unable to load the next episode.': 'Unable to load the next episode.',
    'Season available': 'Season available',
    'Season partially available': 'Season partially available',
    'Season requested': 'Season requested',
    'Season unavailable': 'Season unavailable',
    'This media is not linked to Jellyfin.':
        'This media is not linked to Jellyfin.',
    'No video source available.': 'No video source available.',
    'Hide volume': 'Hide volume',
    'Volume': 'Volume',
    'Picture in Picture': 'Picture in Picture',
    'Playing with AirPlay': 'Playing with AirPlay',
    'Use the AirPlay button to change or stop playback on the TV.':
        'Use the AirPlay button to change or stop playback on the TV.',
    'Playback settings': 'Playback settings',
    'Enter full screen': 'Enter full screen',
    'Exit full screen': 'Exit full screen',
    'Pause': 'Pause',
    'Play state': 'Play',
    'Rewind 10 seconds': 'Rewind 10 seconds',
    'Forward 10 seconds': 'Forward 10 seconds',
    'Quality': 'Quality',
    'Speed': 'Speed',
    'Picture format': 'Picture format',
    'Audio': 'Audio',
    'No other audio track available': 'No other audio track available',
    'Subtitles': 'Subtitles',
    'Subtitle size': 'Subtitle size',
    'Subtitle color': 'Subtitle color',
    'Subtitle background': 'Subtitle background',
    'Subtitle appearance': 'Subtitle appearance',
    'Size, color and background used during playback.':
        'Size, color and background used during playback.',
    'Subtitle preview': 'Subtitle preview',
    'Save': 'Save',
    'Small': 'Small',
    'Medium': 'Medium',
    'Large': 'Large',
    'White': 'White',
    'Yellow': 'Yellow',
    'Cyan': 'Cyan',
    'None': 'None',
    'Subtle': 'Subtle',
    'Solid': 'Solid',
    'Off': 'Off',
    'Forced': 'Forced',
    'Default': 'Default',
    'Fill screen': 'Fill screen',
    'Fit image': 'Fit image',
    'Auto · Jellyfin': 'Auto · Jellyfin',
    'Stream selected by {service}': 'Stream selected by {service}',
    'Direct play': 'Direct play',
    'Direct stream': 'Direct stream',
    'Mobile · 2 Mb/s': 'Mobile · 2 Mb/s',
    'Unable to play': 'Unable to play',
    'Available to watch': 'Available to watch',
    'Partially available': 'Partially available',
    'Pending': 'Pending',
    'Declined': 'Declined',
    'Failed': 'Failed',
    'Download {progression}': 'Download {progression}',
    'Downloaded': 'Downloaded',
    '{count} channels': '{count} channels',
    'Track {number}': 'Track {number}',
    'Credentials rejected by Seerr or Jellyfin.':
        'Credentials rejected by Seerr or Jellyfin.',
    'Server unreachable. Check the URL, port, and network.':
        'Server unreachable. Check the URL, port, and network.',
    'Seerr did not return a session.': 'Seerr did not return a session.',
    'Invalid Jellyfin authentication response':
        'Invalid Jellyfin authentication response',
    'No episode is available for this series.':
        'No episode is available for this series.',
    'Age {rating}': 'Age {rating}',
    'Unable to load this person.': 'Unable to load this person.',
    'Biography': 'Biography',
    'Born': 'Born',
    'Died': 'Died',
    'Place of birth': 'Place of birth',
    'Known for': 'Known for',
    'Also known as': 'Also known as',
    'Appearances': 'Appearances',
    'Behind the camera': 'Behind the camera',
    'No biography available.': 'No biography available.',
    'Search this list': 'Search this list',
    'Search this category': 'Search this category',
    'No media matches these filters.': 'No media matches these filters.',
    'All': 'All',
    'Media type': 'Media type',
    'Movies': 'Movies',
    'Series': 'Series',
    'Requested': 'Requested',
    'Sort': 'Sort',
    'Relevance': 'Relevance',
    'Newest first': 'Newest first',
    'Oldest first': 'Oldest first',
    'A–Z': 'A–Z',
    'All statuses': 'All statuses',
    'In progress': 'In progress',
    'Downloads': 'Downloads',
    'Unable to load offline downloads.': 'Unable to load offline downloads.',
    'Delete this download?': 'Delete this download?',
    'The offline copy of “{title}” will be removed from this device.':
        'The offline copy of “{title}” will be removed from this device.',
    '{count} offline · {size}': '{count} offline · {size}',
    'Play offline': 'Play offline',
    'Delete download': 'Delete download',
    'Downloading · {progress}%': 'Downloading · {progress}%',
    'Downloading · {progress}% · {time} left':
        'Downloading · {progress}% · {time} left',
    'Child mode': 'Child mode',
    'Only shows content whose age rating is known and allowed.':
        'Only shows content whose age rating is known and allowed.',
    'Maximum age rating': 'Maximum age rating',
    'Up to age {age}': 'Up to age {age}',
    'Preparing download…': 'Preparing download…',
    'Available offline · {size}': 'Available offline · {size}',
    'Available offline': 'Available offline',
    'No offline downloads': 'No offline downloads',
    'Download an available movie or episode to watch it without a connection.':
        'Download an available movie or episode to watch it without a connection.',
    'Download interrupted.': 'Download interrupted.',
    'The media server does not allow this account to download media.':
        'The media server does not allow this account to download media.',
    'Unable to download this media.': 'Unable to download this media.',
    'The downloaded file is unavailable.':
        'The downloaded file is unavailable.',
    'Download started.': 'Download started.',
    'Unable to start the download.': 'Unable to start the download.',
    'Retry download': 'Retry download',
    'Download': 'Download',
    'Download offline': 'Download offline',
    'Choose download quality': 'Choose download quality',
    'The size is an estimate. Compatible copies are transcoded by your media server before offline playback.':
        'The size is an estimate. Compatible copies are transcoded by your media server before offline playback.',
    'Up to 1080p': 'Up to 1080p',
    'Up to 720p': 'Up to 720p',
    'Up to 480p': 'Up to 480p',
    'Original quality': 'Original quality',
    'MP4': 'MP4',
    'H.264/AAC': 'H.264/AAC',
    'Transcoded by {service}': 'Transcoded by {service}',
    'No transcoding': 'No transcoding',
    'Recommended': 'Recommended',
    'This original format may not play on this device.':
        'This original format may not play on this device.',
    'Unknown size': 'Unknown size',
    'Download · about {size}': 'Download · about {size}',
    'Invalid Jellyfin response': 'Invalid Jellyfin response',
  },
  'es': {
    'Choose your language': 'Elige tu idioma',
    'Your phone language is shown first. You can change it later in Settings.':
        'El idioma del teléfono aparece primero. Podrás cambiarlo más tarde en Ajustes.',
    'Phone language': 'Idioma del teléfono',
    'Language': 'Idioma',
    'Request notifications': 'Notificaciones de solicitudes',
    'Periodically checks Seerr for approval and availability updates. Your device may delay background checks.':
        'Comprueba periódicamente Seerr para detectar aprobaciones y cambios de disponibilidad. El dispositivo puede retrasar las comprobaciones en segundo plano.',
    'Notifications are disabled in system settings.':
        'Las notificaciones están desactivadas en los ajustes del sistema.',
    'Your request was approved.': 'Tu solicitud ha sido aprobada.',
    'Your request was declined.': 'Tu solicitud ha sido rechazada.',
    'Your request could not be processed.':
        'No se ha podido procesar tu solicitud.',
    'Partially available on Jellyfin.': 'Disponible parcialmente en Jellyfin.',
    'Available now on Jellyfin.': 'Ya está disponible en Jellyfin.',
    'French': 'Francés',
    'English': 'Inglés',
    'Spanish': 'Español',
    'Italian': 'Italiano',
    'German': 'Alemán',
    'Media server': 'Servidor multimedia',
    'Media server username': 'Usuario del servidor multimedia',
    '{service} account': 'Cuenta de {service}',
    'Linked {service} account': 'Cuenta de {service} vinculada',
    '{service} username': 'Usuario de {service}',
    '{service} password': 'Contraseña de {service}',
    '{service} server': 'Servidor {service}',
    'These credentials sign in to Seerr and {service}.':
        'Estas credenciales inician sesión en Seerr y {service}.',
    'Plex account connected': 'Cuenta de Plex conectada',
    'Authentication was approved securely through Plex.':
        'La autenticación se aprobó de forma segura mediante Plex.',
    'Secure Plex authentication': 'Autenticación segura de Plex',
    'The Plex website opens to approve SeerrPlay.':
        'El sitio web de Plex se abre para autorizar SeerrPlay.',
    'Approve the connection in Plex…': 'Aprueba la conexión en Plex…',
    'Approve SeerrPlay in Plex, then return to the app…':
        'Aprueba SeerrPlay en Plex y vuelve a la aplicación…',
    'Looking for your media server automatically…':
        'Buscando automáticamente tu servidor multimedia…',
    '{service} server found automatically.':
        'Servidor {service} encontrado automáticamente.',
    'Seerr does not publish the {service} address. Enter it manually.':
        'Seerr no publica la dirección de {service}. Introdúcela manualmente.',
    '{service} server found. Checking the connection…':
        'Servidor {service} encontrado. Comprobando la conexión…',
    'Signing in to {service}…': 'Iniciando sesión en {service}…',
    '{service} server found and connected.':
        'Servidor {service} encontrado y conectado.',
    'The media server account selected for Seerr is reused automatically.':
        'La cuenta del servidor multimedia seleccionada para Seerr se reutiliza automáticamente.',
    '{service} rejected these credentials.':
        '{service} rechazó estas credenciales.',
    '{service} took too long to respond.':
        '{service} tardó demasiado en responder.',
    '{service} is unreachable. Check the domain, port, and network.':
        'No se puede acceder a {service}. Comprueba el dominio, el puerto y la red.',
    'This address does not appear to be a {service} server.':
        'Esta dirección no parece ser un servidor {service}.',
    'Used only to reach the Seerr and media servers you configure.':
        'Se usa únicamente para acceder a los servidores Seerr y multimedia que configures.',
    'SeerrPlay is an independent client. It is not an official Seerr, Plex, Jellyfin or Emby application and does not host a media catalog.':
        'SeerrPlay es un cliente independiente. No es una aplicación oficial de Seerr, Plex, Jellyfin ni Emby y no aloja ningún catálogo multimedia.',
    'The application connects directly to the Seerr and media server addresses configured in each profile, without a SeerrPlay intermediary server.':
        'La aplicación se conecta directamente a las direcciones de Seerr y del servidor multimedia configuradas en cada perfil, sin un servidor intermediario de SeerrPlay.',
    'Requests, searches and playback information are exchanged directly with the Seerr and media servers configured by the user.':
        'Las solicitudes, búsquedas e información de reproducción se intercambian directamente con los servidores Seerr y multimedia configurados por el usuario.',
    'Availability and operation depend on the Seerr and media servers configured by the user and on their respective administrators.':
        'La disponibilidad y el funcionamiento dependen de los servidores Seerr y multimedia configurados por el usuario y de sus respectivos administradores.',
    'Available now on your media server.':
        'Disponible ahora en tu servidor multimedia.',
    'Partially available on your media server.':
        'Disponible parcialmente en tu servidor multimedia.',
    'This media is not linked to the media server.':
        'Este contenido no está vinculado al servidor multimedia.',
    'Unable to connect to the media server or Seerr. Check your connection or contact your media server administrator.':
        'No se puede conectar con el servidor multimedia o Seerr. Comprueba tu conexión o contacta con el administrador del servidor multimedia.',
    'Continue': 'Continuar',
    'Home navigation': 'Inicio',
    'Search': 'Buscar',
    'Requests': 'Solicitudes',
    'Settings': 'Ajustes',
    'Your media space': 'Tu espacio multimedia',
    'Choose the servers and account currently in use.':
        'Elige los servidores y la cuenta que se están utilizando.',
    'Application': 'Aplicación',
    'Language and notification preferences.':
        'Preferencias de idioma y notificaciones.',
    'Direct connections': 'Conexiones directas',
    'SeerrPlay communicates directly with the servers in this profile.':
        'SeerrPlay se comunica directamente con los servidores de este perfil.',
    'Privacy and data': 'Privacidad y datos',
    'Your data stays under your control.':
        'Tus datos permanecen bajo tu control.',
    'Privacy policy': 'Política de privacidad',
    'How SeerrPlay handles your data.': 'Cómo gestiona SeerrPlay tus datos.',
    'Local network access': 'Acceso a la red local',
    'Used only to reach the Seerr and Jellyfin servers you configure.':
        'Se utiliza únicamente para acceder a los servidores Seerr y Jellyfin que configures.',
    'No SeerrPlay cloud': 'Sin nube de SeerrPlay',
    'Credentials and preferences are stored on this device.':
        'Las credenciales y preferencias se guardan en este dispositivo.',
    'Delete local profile data': 'Eliminar los datos locales del perfil',
    'Removes this profile and its credentials from this device.':
        'Elimina este perfil y sus credenciales del dispositivo.',
    'About': 'Acerca de',
    'Information, legal documents and diagnostics.':
        'Información, documentos legales y diagnósticos.',
    'About SeerrPlay': 'Acerca de SeerrPlay',
    'Independent client for your personal media servers.':
        'Cliente independiente para tus servidores multimedia personales.',
    'Terms of use': 'Condiciones de uso',
    'Rules for using SeerrPlay responsibly.':
        'Reglas para utilizar SeerrPlay de forma responsable.',
    'Open-source licenses': 'Licencias de código abierto',
    'Libraries used to build the application.':
        'Bibliotecas utilizadas para crear la aplicación.',
    'Credits': 'Créditos',
    'Projects, services and data sources used by SeerrPlay.':
        'Proyectos, servicios y fuentes de datos utilizados por SeerrPlay.',
    'Projects and services': 'Proyectos y servicios',
    'SeerrPlay interoperates with these independent projects and services.':
        'SeerrPlay interactúa con estos proyectos y servicios independientes.',
    'Media discovery and request management for personal media servers.':
        'Descubrimiento de contenido y gestión de solicitudes para servidores multimedia personales.',
    'Open-source media server and playback APIs.':
        'Servidor multimedia de código abierto y API de reproducción.',
    'Personal media server and playback platform.':
        'Servidor multimedia personal y plataforma de reproducción.',
    'Cross-platform application framework.':
        'Framework de aplicaciones multiplataforma.',
    'View SeerrPlay on GitHub': 'Ver SeerrPlay en GitHub',
    'Unable to open this link.': 'No se puede abrir este enlace.',
    'Public privacy policy': 'Política de privacidad pública',
    'Open the policy published on the web.':
        'Abrir la política publicada en la web.',
    'Support': 'Soporte',
    'Help, contact and issue reporting.':
        'Ayuda, contacto e informe de problemas.',
    'Version {version} ({build})': 'Versión {version} ({build})',
    'Copy diagnostics without credentials.':
        'Copiar diagnósticos sin credenciales.',
    'Diagnostics copied.': 'Diagnósticos copiados.',
    'One application to discover, request, watch and download media from your own servers.':
        'Una aplicación para descubrir, solicitar, ver y descargar contenido de tus propios servidores.',
    'Independent application': 'Aplicación independiente',
    'SeerrPlay is an independent client. It is not an official Seerr or Jellyfin application and does not host a media catalog.':
        'SeerrPlay es un cliente independiente. No es una aplicación oficial de Seerr o Jellyfin y no aloja ningún catálogo multimedia.',
    'Direct architecture': 'Arquitectura directa',
    'The application connects directly to the Seerr and Jellyfin addresses configured in each profile, without a SeerrPlay intermediary server.':
        'La aplicación se conecta directamente a las direcciones de Seerr y Jellyfin configuradas en cada perfil, sin un servidor intermediario de SeerrPlay.',
    'Designed for personal libraries': 'Diseñado para bibliotecas personales',
    'SeerrPlay is intended for media servers and libraries that you own or are authorized to access.':
        'SeerrPlay está destinado a servidores y bibliotecas multimedia que posees o a los que tienes acceso autorizado.',
    'SeerrPlay is designed to minimize data collection and keep control with the user.':
        'SeerrPlay está diseñado para minimizar la recopilación de datos y mantener el control en manos del usuario.',
    'No tracking or advertising': 'Sin seguimiento ni publicidad',
    'SeerrPlay does not include advertising, analytics or cross-application tracking.':
        'SeerrPlay no incluye publicidad, analíticas ni seguimiento entre aplicaciones.',
    'Google Cast': 'Google Cast',
    'Unable to open the Google Cast selector.':
        'No se puede abrir el selector de Google Cast.',
    'When Google Cast is available, the Google Cast SDK may send technical application, device discovery and cast session information to Google. Media server credentials are not included.':
        'Cuando Google Cast está disponible, su SDK puede enviar a Google información técnica sobre la aplicación, la detección de dispositivos y las sesiones de transmisión. No se incluyen las credenciales del servidor multimedia.',
    'Direct server communication': 'Comunicación directa con los servidores',
    'Requests, searches and playback information are exchanged directly with the Seerr and Jellyfin servers configured by the user.':
        'Las solicitudes, búsquedas y datos de reproducción se intercambian directamente con los servidores Seerr y Jellyfin configurados por el usuario.',
    'On-device storage': 'Almacenamiento en el dispositivo',
    'Profiles and preferences are stored on the device. Authentication secrets are stored using the secure storage provided by the operating system.':
        'Los perfiles y preferencias se guardan en el dispositivo. Los secretos de autenticación utilizan el almacenamiento seguro del sistema operativo.',
    'Downloads and notifications': 'Descargas y notificaciones',
    'Offline media is stored on the device. Request notifications are generated from periodic checks performed by the application.':
        'El contenido sin conexión se guarda en el dispositivo. Las notificaciones de solicitudes se generan mediante comprobaciones periódicas de la aplicación.',
    'Data deletion': 'Eliminación de datos',
    'Deleting a profile removes its local connection information and credentials. Offline downloads can be removed from the Downloads page.':
        'Eliminar un perfil borra sus datos de conexión y credenciales locales. Las descargas sin conexión se pueden eliminar desde la página Descargas.',
    'Use of SeerrPlay requires access to compatible servers supplied by the user.':
        'El uso de SeerrPlay requiere acceso a servidores compatibles proporcionados por el usuario.',
    'Authorized access only': 'Solo acceso autorizado',
    'You must only connect to servers, libraries and media that you own or are authorized to use.':
        'Solo debes conectarte a servidores, bibliotecas y contenido que poseas o estés autorizado a utilizar.',
    'No media service': 'No es un servicio multimedia',
    'SeerrPlay does not sell, provide or host films, series, subscriptions or download sources.':
        'SeerrPlay no vende, proporciona ni aloja películas, series, suscripciones o fuentes de descarga.',
    'Third-party services': 'Servicios de terceros',
    'Availability and operation depend on the Seerr and Jellyfin servers configured by the user and on their respective administrators.':
        'La disponibilidad y el funcionamiento dependen de los servidores Seerr y Jellyfin configurados por el usuario y de sus respectivos administradores.',
    'User responsibility': 'Responsabilidad del usuario',
    'The user is responsible for server security, content rights, network configuration and compliance with applicable laws.':
        'El usuario es responsable de la seguridad de los servidores, los derechos del contenido, la configuración de red y el cumplimiento de las leyes aplicables.',
    'Connected': 'Conectado',
    'Unable to load Home': 'No se puede cargar el inicio',
    'Pull down to try again. If the session expired, reconnect the services in Settings.':
        'Desliza hacia abajo para reintentar. Si la sesión ha caducado, vuelve a conectar los servicios en Ajustes.',
    'Continue watching': 'Seguir viendo',
    'Your available requests': 'Tus solicitudes disponibles',
    'Trending': 'Tendencias',
    'Popular movies': 'Películas populares',
    'Popular series': 'Series populares',
    'No media to display.': 'No hay contenido para mostrar.',
    'Unable to reach your media services':
        'No se puede acceder a tus servicios multimedia',
    'Unable to connect to Jellyfin or Seerr, or both. Check your connection or contact your media server administrator.':
        'No se puede conectar con Jellyfin, Seerr o ambos. Comprueba tu conexión o contacta con el administrador de tu servidor multimedia.',
    'The {service} session has expired.': 'La sesión de {service} ha caducado.',
    'Access was forbidden by {service}.': '{service} ha denegado el acceso.',
    '{service} did not respond in time.': '{service} no respondió a tiempo.',
    'No response from {service}.': 'No hay respuesta de {service}.',
    '{service} returned a server error.':
        '{service} devolvió un error del servidor.',
    'Unexpected {service} error.': 'Error inesperado de {service}.',
    'Unwatched requests': 'Solicitudes no vistas',
    'Unable to load requests.': 'No se pueden cargar las solicitudes.',
    'All requests have been watched.': 'Todas las solicitudes han sido vistas.',
    'Providers · {region}': 'Plataformas · {region}',
    'Media library': 'Biblioteca multimedia',
    'Search the media library': 'Buscar en la biblioteca multimedia',
    'Unable to load the media library.':
        'No se puede cargar la biblioteca multimedia.',
    'Search Seerr': 'Buscar en Seerr',
    'What do you want to watch?': '¿Qué quieres ver?',
    'Search the localized or original titles in the Seerr catalog.':
        'Busca títulos localizados u originales en el catálogo de Seerr.',
    'E.g. Law Abiding Citizen': 'Ej. Un ciudadano ejemplar',
    'Clear': 'Borrar',
    'Search unavailable.': 'Búsqueda no disponible.',
    'Try again': 'Reintentar',
    'No results for “{query}”.': 'No hay resultados para «{query}».',
    '{count} result': '{count} resultado',
    '{count} results': '{count} resultados',
    'Movies and series': 'Películas y series',
    'Enter a localized title or its original title.':
        'Escribe un título localizado o su título original.',
    'New profile': 'Nuevo perfil',
    "Who's watching?": '¿Quién está viendo?',
    'Choose a profile to continue.': 'Elige un perfil para continuar.',
    'Choose an avatar': 'Elige un avatar',
    'Switch profile': 'Cambiar de perfil',
    'Trending rank': 'Tendencia n.º {rank}',
    'Create and connect': 'Crear y conectar',
    'Back': 'Atrás',
    'Profile name': 'Nombre del perfil',
    'Home, Travel, Family…': 'Casa, Viaje, Familia…',
    'Name': 'Nombre',
    'Home profile name': 'Casa',
    'Seerr server': 'Servidor Seerr',
    'Request server address and account':
        'Dirección y cuenta del servidor de solicitudes',
    'Seerr email': 'Correo de Seerr',
    'Jellyfin username': 'Usuario de Jellyfin',
    'Password': 'Contraseña',
    'Jellyfin server': 'Servidor Jellyfin',
    'Playback server address': 'Dirección del servidor de reproducción',
    'Credentials already entered': 'Credenciales ya introducidas',
    'The Jellyfin account selected for Seerr is reused automatically.':
        'La cuenta de Jellyfin elegida para Seerr se reutiliza automáticamente.',
    'Jellyfin password': 'Contraseña de Jellyfin',
    'Required field': 'Campo obligatorio',
    'Port between 1 and 65535': 'Puerto entre 1 y 65535',
    'Invalid URL, example: http://192.168.1.10':
        'URL no válida, ejemplo: http://192.168.1.10',
    'HTTP does not encrypt your credentials. Use it only for a trusted local network; HTTPS is recommended.':
        'HTTP no cifra tus credenciales. Úsalo solo en una red local de confianza; se recomienda HTTPS.',
    'URL': 'URL',
    'Port': 'Puerto',
    'Domain or IP address': 'Dominio o dirección IP',
    'Custom port (optional)': 'Puerto personalizado (opcional)',
    'Invalid domain, example: jellyfin.example.com':
        'Dominio no válido, ejemplo: jellyfin.example.com',
    'Checking the Seerr server…': 'Comprobando el servidor Seerr…',
    'Signing in to Seerr…': 'Iniciando sesión en Seerr…',
    'Looking for your Jellyfin server automatically…':
        'Buscando tu servidor Jellyfin automáticamente…',
    'Jellyfin server found. Checking the connection…':
        'Servidor Jellyfin encontrado. Comprobando la conexión…',
    'Jellyfin server found and connected.':
        'Servidor Jellyfin encontrado y conectado.',
    'Signing in to Jellyfin…': 'Iniciando sesión en Jellyfin…',
    'Jellyfin address found in Seerr settings.':
        'Dirección de Jellyfin encontrada en los ajustes de Seerr.',
    'Jellyfin address found from an available media.':
        'Dirección de Jellyfin encontrada desde un medio disponible.',
    'Seerr does not publish a Jellyfin address and no available media contains one. Enter it manually.':
        'Seerr no publica una dirección de Jellyfin y ningún medio disponible contiene una. Introdúcela manualmente.',
    'Seerr rejected these credentials.': 'Seerr rechazó estas credenciales.',
    'Jellyfin rejected these credentials.':
        'Jellyfin rechazó estas credenciales.',
    'Your account is not allowed to perform this action.':
        'Tu cuenta no puede realizar esta acción.',
    'Seerr took too long to respond.': 'Seerr tardó demasiado en responder.',
    'Jellyfin took too long to respond.':
        'Jellyfin tardó demasiado en responder.',
    'The server domain could not be found.':
        'No se pudo encontrar el dominio del servidor.',
    'The secure connection certificate is invalid.':
        'El certificado de conexión segura no es válido.',
    'Seerr is unreachable. Check the domain, port, and network.':
        'Seerr no está disponible. Comprueba el dominio, el puerto y la red.',
    'Jellyfin is unreachable. Check the domain, port, and network.':
        'Jellyfin no está disponible. Comprueba el dominio, el puerto y la red.',
    'This address does not appear to be a Seerr server.':
        'Esta dirección no parece ser un servidor Seerr.',
    'This address does not appear to be a Jellyfin server.':
        'Esta dirección no parece ser un servidor Jellyfin.',
    'The server returned an internal error.':
        'El servidor devolvió un error interno.',
    'The server returned an invalid response.':
        'El servidor devolvió una respuesta no válida.',
    'Unable to load profiles.\n{error}':
        'No se pueden cargar los perfiles.\n{error}',
    'Reconnect services': 'Volver a conectar los servicios',
    'Jellyfin account': 'Cuenta de Jellyfin',
    'Seerr account': 'Cuenta de Seerr',
    'Linked Jellyfin account': 'Cuenta de Jellyfin vinculada',
    'These credentials sign in to Seerr and Jellyfin.':
        'Estas credenciales inician sesión en Seerr y Jellyfin.',
    'Sign in': 'Iniciar sesión',
    'Delete this profile?': '¿Eliminar este perfil?',
    'The “{name}” profile and its sign-in information will be removed from this device.':
        'El perfil «{name}» y sus datos de acceso se eliminarán de este dispositivo.',
    'Cancel': 'Cancelar',
    'Delete': 'Eliminar',
    'Profile': 'Perfil',
    'Active profile': 'Perfil activo',
    'Add profile': 'Añadir un perfil',
    'Profiles': 'Perfiles',
    'Connection': 'Conexión',
    'Secure connection (HTTPS)': 'Conexión segura (HTTPS)',
    'Unencrypted connection (HTTP)': 'Conexión sin cifrar (HTTP)',
    'Delete profile': 'Eliminar perfil',
    'Remove this profile and its credentials from this device.':
        'Elimina este perfil y sus credenciales del dispositivo.',
    'Unable to load this category.': 'No se puede cargar esta categoría.',
    'Unable to load this provider.': 'No se puede cargar esta plataforma.',
    'Request sent to Seerr.': 'Solicitud enviada a Seerr.',
    'This media has already been requested.':
        'Este contenido ya ha sido solicitado.',
    'Unable to send the request.': 'No se puede enviar la solicitud.',
    'New attempt sent.': 'Nuevo intento enviado.',
    'Unable to retry the request.': 'No se puede reintentar la solicitud.',
    'Delete this request?': '¿Eliminar esta solicitud?',
    'The pending request for “{title}” will be removed from Seerr.':
        'La solicitud pendiente de «{title}» se eliminará de Seerr.',
    'Delete request': 'Eliminar solicitud',
    'Request deleted.': 'Solicitud eliminada.',
    'Unable to delete the request.': 'No se puede eliminar la solicitud.',
    'Resume playback': 'Reanudar',
    'Play action': 'Ver',
    'Downloading': 'Descargando',
    'No summary available.': 'No hay sinopsis disponible.',
    'Recommendations': 'Recomendaciones',
    'Similar titles': 'Títulos similares',
    'Detailed Seerr information is unavailable.':
        'La información detallada de Seerr no está disponible.',
    '{progress}% watched': '{progress}% visto',
    'Retry request': 'Reintentar solicitud',
    'Requested media': 'Solicitado',
    'Request on Seerr': 'Solicitar en Seerr',
    'Directed by': 'Dirección',
    'Production': 'Producción',
    'Original language': 'Idioma original',
    'Votes': 'Votos',
    'Budget': 'Presupuesto',
    'Information': 'Información',
    'Trailers': 'Tráilers',
    'Watch trailer': 'Ver tráiler',
    'Featured trailer': 'Tráiler destacado',
    'Overview': 'Resumen',
    'Creative team': 'Equipo creativo',
    'Technical details': 'Detalles técnicos',
    'Tomatometer': 'Tomatómetro',
    'Rotten audience': 'Público de Rotten Tomatoes',
    'Learn more': 'Saber más',
    'Crew, technical details and studios':
        'Equipo, detalles técnicos y estudios',
    'Video release date': 'Estreno en vídeo',
    'Age rating': 'Clasificación por edad',
    'Revenue': 'Recaudación',
    'Studios': 'Estudios',
    'Original title': 'Título original',
    'Status': 'Estado',
    'Release date': 'Fecha de estreno',
    'Video': 'Vídeo',
    'Cast': 'Actores',
    'Seasons': 'Temporadas',
    'Available': 'Disponible',
    'Partial': 'Parcial',
    'Requested season': 'Solicitada',
    'Unavailable': 'No disponible',
    '{count} episode': '{count} episodio',
    '{count} episodes': '{count} episodios',
    'Season requested on Seerr.': 'Temporada solicitada en Seerr.',
    'Season unavailable.': 'Temporada no disponible.',
    'Requesting…': 'Solicitando…',
    'Request this season': 'Solicitar esta temporada',
    'Episodes': 'Episodios',
    'Watched': 'Visto',
    'Currently watching': 'Viendo ahora',
    'More playback options': 'Más opciones de reproducción',
    'Play from beginning': 'Reproducir desde el principio',
    'Mark as watched': 'Marcar como visto',
    'Mark as unwatched': 'Marcar como no visto',
    'Marked as watched.': 'Marcado como visto.',
    'Marked as unwatched.': 'Marcado como no visto.',
    'Unable to update watched status.':
        'No se puede actualizar el estado de visualización.',
    'Choose a season': 'Elegir una temporada',
    'No unwatched episode remains.': 'No quedan episodios sin ver.',
    'Unable to load the next episode.':
        'No se puede cargar el siguiente episodio.',
    'Season available': 'Temporada disponible',
    'Season partially available': 'Temporada parcialmente disponible',
    'Season requested': 'Temporada solicitada',
    'Season unavailable': 'Temporada no disponible',
    'This media is not linked to Jellyfin.':
        'Este contenido no está vinculado a Jellyfin.',
    'No video source available.': 'No hay ninguna fuente de vídeo disponible.',
    'Hide volume': 'Ocultar volumen',
    'Volume': 'Volumen',
    'Picture in Picture': 'Imagen en imagen',
    'Playing with AirPlay': 'Reproduciendo con AirPlay',
    'Use the AirPlay button to change or stop playback on the TV.':
        'Usa el botón AirPlay para cambiar de televisor o detener la reproducción.',
    'Playback settings': 'Ajustes de reproducción',
    'Enter full screen': 'Entrar en pantalla completa',
    'Exit full screen': 'Salir de pantalla completa',
    'Pause': 'Pausa',
    'Play state': 'Reproducir',
    'Rewind 10 seconds': 'Retroceder 10 segundos',
    'Forward 10 seconds': 'Avanzar 10 segundos',
    'Quality': 'Calidad',
    'Speed': 'Velocidad',
    'Picture format': 'Formato de imagen',
    'Audio': 'Audio',
    'No other audio track available': 'No hay otra pista de audio disponible',
    'Subtitles': 'Subtítulos',
    'Subtitle size': 'Tamaño de los subtítulos',
    'Subtitle color': 'Color de los subtítulos',
    'Subtitle background': 'Fondo de los subtítulos',
    'Subtitle appearance': 'Apariencia de los subtítulos',
    'Size, color and background used during playback.':
        'Tamaño, color y fondo utilizados durante la reproducción.',
    'Subtitle preview': 'Vista previa de subtítulos',
    'Save': 'Guardar',
    'Small': 'Pequeño',
    'Medium': 'Mediano',
    'Large': 'Grande',
    'White': 'Blanco',
    'Yellow': 'Amarillo',
    'Cyan': 'Cian',
    'None': 'Ninguno',
    'Subtle': 'Discreto',
    'Solid': 'Opaco',
    'Off': 'Desactivados',
    'Forced': 'Forzado',
    'Default': 'Predeterminado',
    'Fill screen': 'Llenar pantalla',
    'Fit image': 'Imagen completa',
    'Auto · Jellyfin': 'Auto · Jellyfin',
    'Stream selected by {service}': 'Transmisión seleccionada por {service}',
    'Direct play': 'Reproducción directa',
    'Direct stream': 'Transmisión directa',
    'Mobile · 2 Mb/s': 'Móvil · 2 Mb/s',
    'Unable to play': 'No se puede reproducir',
    'Available to watch': 'Disponible para ver',
    'Partially available': 'Parcialmente disponible',
    'Pending': 'Pendiente',
    'Declined': 'Rechazada',
    'Failed': 'Error',
    'Download {progression}': 'Descarga {progression}',
    'Downloaded': 'Descargado',
    '{count} channels': '{count} canales',
    'Track {number}': 'Pista {number}',
    'Credentials rejected by Seerr or Jellyfin.':
        'Credenciales rechazadas por Seerr o Jellyfin.',
    'Server unreachable. Check the URL, port, and network.':
        'Servidor inaccesible. Comprueba la URL, el puerto y la red.',
    'Seerr did not return a session.': 'Seerr no ha devuelto ninguna sesión.',
    'Invalid Jellyfin authentication response':
        'Respuesta de autenticación de Jellyfin no válida',
    'No episode is available for this series.':
        'No hay episodios disponibles para esta serie.',
    'Age {rating}': 'Edad {rating}',
    'Unable to load this person.': 'No se puede cargar esta persona.',
    'Biography': 'Biografía',
    'Born': 'Nacimiento',
    'Died': 'Fallecimiento',
    'Place of birth': 'Lugar de nacimiento',
    'Known for': 'Conocido por',
    'Also known as': 'También conocido como',
    'Appearances': 'Apariciones',
    'Behind the camera': 'Detrás de la cámara',
    'No biography available.': 'No hay biografía disponible.',
    'Search this list': 'Buscar en esta lista',
    'Search this category': 'Buscar en esta categoría',
    'No media matches these filters.':
        'Ningún contenido coincide con estos filtros.',
    'All': 'Todo',
    'Media type': 'Tipo de contenido',
    'Movies': 'Películas',
    'Series': 'Series',
    'Requested': 'Solicitado',
    'Sort': 'Ordenar',
    'Relevance': 'Relevancia',
    'Newest first': 'Más recientes',
    'Oldest first': 'Más antiguos',
    'A–Z': 'A–Z',
    'All statuses': 'Todos los estados',
    'In progress': 'En curso',
    'Downloads': 'Descargas',
    'Unable to load offline downloads.':
        'No se pueden cargar las descargas sin conexión.',
    'Delete this download?': '¿Eliminar esta descarga?',
    'The offline copy of “{title}” will be removed from this device.':
        'La copia sin conexión de «{title}» se eliminará de este dispositivo.',
    '{count} offline · {size}': '{count} sin conexión · {size}',
    'Play offline': 'Reproducir sin conexión',
    'Delete download': 'Eliminar descarga',
    'Downloading · {progress}%': 'Descargando · {progress}%',
    'Downloading · {progress}% · {time} left':
        'Descargando · {progress}% · quedan {time}',
    'Child mode': 'Modo infantil',
    'Only shows content whose age rating is known and allowed.':
        'Solo muestra contenido con una clasificación de edad conocida y permitida.',
    'Maximum age rating': 'Clasificación de edad máxima',
    'Up to age {age}': 'Hasta {age} años',
    'Preparing download…': 'Preparando descarga…',
    'Available offline · {size}': 'Disponible sin conexión · {size}',
    'Available offline': 'Disponible sin conexión',
    'No offline downloads': 'No hay descargas sin conexión',
    'Download an available movie or episode to watch it without a connection.':
        'Descarga una película o episodio disponible para verlo sin conexión.',
    'Download interrupted.': 'Descarga interrumpida.',
    'The media server does not allow this account to download media.':
        'El servidor multimedia no permite que esta cuenta descargue contenido.',
    'Unable to download this media.': 'No se puede descargar este contenido.',
    'The downloaded file is unavailable.':
        'El archivo descargado no está disponible.',
    'Download started.': 'Descarga iniciada.',
    'Unable to start the download.': 'No se puede iniciar la descarga.',
    'Retry download': 'Reintentar descarga',
    'Download': 'Descargar',
    'Download offline': 'Descargar sin conexión',
    'Choose download quality': 'Elegir la calidad de descarga',
    'The size is an estimate. Compatible copies are transcoded by your media server before offline playback.':
        'El tamaño es una estimación. El servidor multimedia transcodifica las copias compatibles antes de la reproducción sin conexión.',
    'Up to 1080p': 'Hasta 1080p',
    'Up to 720p': 'Hasta 720p',
    'Up to 480p': 'Hasta 480p',
    'Original quality': 'Calidad original',
    'MP4': 'MP4',
    'H.264/AAC': 'H.264/AAC',
    'Transcoded by {service}': 'Transcodificado por {service}',
    'No transcoding': 'Sin transcodificación',
    'Recommended': 'Recomendado',
    'This original format may not play on this device.':
        'Es posible que este formato original no se reproduzca en este dispositivo.',
    'Unknown size': 'Tamaño desconocido',
    'Download · about {size}': 'Descargar · aprox. {size}',
    'Invalid Jellyfin response': 'Respuesta de Jellyfin no válida',
  },
  'it': {
    'Choose your language': 'Scegli la lingua',
    'Your phone language is shown first. You can change it later in Settings.':
        'La lingua del telefono viene mostrata per prima. Potrai cambiarla in seguito nelle Impostazioni.',
    'Phone language': 'Lingua del telefono',
    'Language': 'Lingua',
    'Request notifications': 'Notifiche delle richieste',
    'Periodically checks Seerr for approval and availability updates. Your device may delay background checks.':
        'Controlla periodicamente Seerr per approvazioni e disponibilità. Il dispositivo potrebbe ritardare i controlli in background.',
    'Notifications are disabled in system settings.':
        'Le notifiche sono disattivate nelle impostazioni di sistema.',
    'Your request was approved.': 'La tua richiesta è stata approvata.',
    'Your request was declined.': 'La tua richiesta è stata rifiutata.',
    'Your request could not be processed.':
        'Non è stato possibile elaborare la tua richiesta.',
    'Partially available on Jellyfin.': 'Parzialmente disponibile su Jellyfin.',
    'Available now on Jellyfin.': 'Ora disponibile su Jellyfin.',
    'French': 'Francese',
    'English': 'Inglese',
    'Spanish': 'Spagnolo',
    'Italian': 'Italiano',
    'German': 'Tedesco',
    'Media server': 'Server multimediale',
    'Media server username': 'Nome utente del server multimediale',
    '{service} account': 'Account {service}',
    'Linked {service} account': 'Account {service} collegato',
    '{service} username': 'Nome utente {service}',
    '{service} password': 'Password {service}',
    '{service} server': 'Server {service}',
    'These credentials sign in to Seerr and {service}.':
        'Queste credenziali consentono l’accesso a Seerr e {service}.',
    'Plex account connected': 'Account Plex collegato',
    'Authentication was approved securely through Plex.':
        'L’autenticazione è stata approvata in modo sicuro tramite Plex.',
    'Secure Plex authentication': 'Autenticazione Plex sicura',
    'The Plex website opens to approve SeerrPlay.':
        'Il sito Plex si apre per autorizzare SeerrPlay.',
    'Approve the connection in Plex…': 'Approva la connessione in Plex…',
    'Approve SeerrPlay in Plex, then return to the app…':
        'Approva SeerrPlay in Plex, quindi torna nell’app…',
    'Looking for your media server automatically…':
        'Ricerca automatica del server multimediale…',
    '{service} server found automatically.':
        'Server {service} trovato automaticamente.',
    'Seerr does not publish the {service} address. Enter it manually.':
        'Seerr non pubblica l’indirizzo di {service}. Inseriscilo manualmente.',
    '{service} server found. Checking the connection…':
        'Server {service} trovato. Verifica della connessione…',
    'Signing in to {service}…': 'Accesso a {service}…',
    '{service} server found and connected.':
        'Server {service} trovato e connesso.',
    'The media server account selected for Seerr is reused automatically.':
        'L’account del server multimediale selezionato per Seerr viene riutilizzato automaticamente.',
    '{service} rejected these credentials.':
        '{service} ha rifiutato queste credenziali.',
    '{service} took too long to respond.':
        '{service} ha impiegato troppo tempo a rispondere.',
    '{service} is unreachable. Check the domain, port, and network.':
        '{service} non è raggiungibile. Controlla dominio, porta e rete.',
    'This address does not appear to be a {service} server.':
        'Questo indirizzo non sembra appartenere a un server {service}.',
    'Used only to reach the Seerr and media servers you configure.':
        'Usato solo per raggiungere i server Seerr e multimediali configurati.',
    'SeerrPlay is an independent client. It is not an official Seerr, Plex, Jellyfin or Emby application and does not host a media catalog.':
        'SeerrPlay è un client indipendente. Non è un’applicazione ufficiale di Seerr, Plex, Jellyfin o Emby e non ospita alcun catalogo multimediale.',
    'The application connects directly to the Seerr and media server addresses configured in each profile, without a SeerrPlay intermediary server.':
        'L’applicazione si connette direttamente agli indirizzi di Seerr e del server multimediale configurati in ogni profilo, senza un server intermediario SeerrPlay.',
    'Requests, searches and playback information are exchanged directly with the Seerr and media servers configured by the user.':
        'Richieste, ricerche e informazioni di riproduzione vengono scambiate direttamente con i server Seerr e multimediali configurati dall’utente.',
    'Availability and operation depend on the Seerr and media servers configured by the user and on their respective administrators.':
        'Disponibilità e funzionamento dipendono dai server Seerr e multimediali configurati dall’utente e dai rispettivi amministratori.',
    'Available now on your media server.':
        'Ora disponibile sul tuo server multimediale.',
    'Partially available on your media server.':
        'Parzialmente disponibile sul tuo server multimediale.',
    'This media is not linked to the media server.':
        'Questo contenuto non è collegato al server multimediale.',
    'Unable to connect to the media server or Seerr. Check your connection or contact your media server administrator.':
        'Impossibile connettersi al server multimediale o a Seerr. Controlla la connessione o contatta l’amministratore del server multimediale.',
    'Continue': 'Continua',
    'Home navigation': 'Home',
    'Search': 'Cerca',
    'Requests': 'Richieste',
    'Settings': 'Impostazioni',
    'Your media space': 'Il tuo spazio multimediale',
    'Choose the servers and account currently in use.':
        'Scegli i server e l’account attualmente in uso.',
    'Application': 'Applicazione',
    'Language and notification preferences.':
        'Preferenze di lingua e notifiche.',
    'Direct connections': 'Connessioni dirette',
    'SeerrPlay communicates directly with the servers in this profile.':
        'SeerrPlay comunica direttamente con i server di questo profilo.',
    'Privacy and data': 'Privacy e dati',
    'Your data stays under your control.':
        'I tuoi dati rimangono sotto il tuo controllo.',
    'Privacy policy': 'Informativa sulla privacy',
    'How SeerrPlay handles your data.': 'Come SeerrPlay gestisce i tuoi dati.',
    'Local network access': 'Accesso alla rete locale',
    'Used only to reach the Seerr and Jellyfin servers you configure.':
        'Utilizzato solo per raggiungere i server Seerr e Jellyfin configurati.',
    'No SeerrPlay cloud': 'Nessun cloud SeerrPlay',
    'Credentials and preferences are stored on this device.':
        'Credenziali e preferenze sono archiviate su questo dispositivo.',
    'Delete local profile data': 'Elimina i dati locali del profilo',
    'Removes this profile and its credentials from this device.':
        'Rimuove questo profilo e le sue credenziali dal dispositivo.',
    'About': 'Informazioni',
    'Information, legal documents and diagnostics.':
        'Informazioni, documenti legali e diagnostica.',
    'About SeerrPlay': 'Informazioni su SeerrPlay',
    'Independent client for your personal media servers.':
        'Client indipendente per i tuoi server multimediali personali.',
    'Terms of use': 'Condizioni d’uso',
    'Rules for using SeerrPlay responsibly.':
        'Regole per utilizzare SeerrPlay responsabilmente.',
    'Open-source licenses': 'Licenze open source',
    'Libraries used to build the application.':
        'Librerie utilizzate per creare l’applicazione.',
    'Credits': 'Crediti',
    'Projects, services and data sources used by SeerrPlay.':
        'Progetti, servizi e fonti dati utilizzati da SeerrPlay.',
    'Projects and services': 'Progetti e servizi',
    'SeerrPlay interoperates with these independent projects and services.':
        'SeerrPlay interagisce con questi progetti e servizi indipendenti.',
    'Media discovery and request management for personal media servers.':
        'Scoperta dei contenuti e gestione delle richieste per server multimediali personali.',
    'Open-source media server and playback APIs.':
        'Server multimediale open source e API di riproduzione.',
    'Personal media server and playback platform.':
        'Server multimediale personale e piattaforma di riproduzione.',
    'Cross-platform application framework.':
        'Framework per applicazioni multipiattaforma.',
    'View SeerrPlay on GitHub': 'Visualizza SeerrPlay su GitHub',
    'Unable to open this link.': 'Impossibile aprire questo link.',
    'Public privacy policy': 'Informativa sulla privacy pubblica',
    'Open the policy published on the web.':
        'Apri l’informativa pubblicata sul web.',
    'Support': 'Supporto',
    'Help, contact and issue reporting.':
        'Aiuto, contatti e segnalazione dei problemi.',
    'Version {version} ({build})': 'Versione {version} ({build})',
    'Copy diagnostics without credentials.':
        'Copia la diagnostica senza credenziali.',
    'Diagnostics copied.': 'Diagnostica copiata.',
    'One application to discover, request, watch and download media from your own servers.':
        'Un’unica applicazione per scoprire, richiedere, guardare e scaricare contenuti dai tuoi server.',
    'Independent application': 'Applicazione indipendente',
    'SeerrPlay is an independent client. It is not an official Seerr or Jellyfin application and does not host a media catalog.':
        'SeerrPlay è un client indipendente. Non è un’applicazione ufficiale di Seerr o Jellyfin e non ospita alcun catalogo multimediale.',
    'Direct architecture': 'Architettura diretta',
    'The application connects directly to the Seerr and Jellyfin addresses configured in each profile, without a SeerrPlay intermediary server.':
        'L’applicazione si connette direttamente agli indirizzi Seerr e Jellyfin configurati in ogni profilo, senza un server intermediario SeerrPlay.',
    'Designed for personal libraries': 'Progettato per librerie personali',
    'SeerrPlay is intended for media servers and libraries that you own or are authorized to access.':
        'SeerrPlay è destinato a server e librerie multimediali di tua proprietà o a cui sei autorizzato ad accedere.',
    'SeerrPlay is designed to minimize data collection and keep control with the user.':
        'SeerrPlay è progettato per ridurre al minimo la raccolta dei dati e lasciare il controllo all’utente.',
    'No tracking or advertising': 'Nessun tracciamento o pubblicità',
    'SeerrPlay does not include advertising, analytics or cross-application tracking.':
        'SeerrPlay non include pubblicità, analisi o tracciamento tra applicazioni.',
    'Google Cast': 'Google Cast',
    'Unable to open the Google Cast selector.':
        'Impossibile aprire il selettore Google Cast.',
    'When Google Cast is available, the Google Cast SDK may send technical application, device discovery and cast session information to Google. Media server credentials are not included.':
        'Quando Google Cast è disponibile, il relativo SDK può inviare a Google informazioni tecniche sull’applicazione, sul rilevamento dei dispositivi e sulle sessioni di trasmissione. Le credenziali dei server multimediali non sono incluse.',
    'Direct server communication': 'Comunicazione diretta con i server',
    'Requests, searches and playback information are exchanged directly with the Seerr and Jellyfin servers configured by the user.':
        'Richieste, ricerche e informazioni di riproduzione vengono scambiate direttamente con i server Seerr e Jellyfin configurati dall’utente.',
    'On-device storage': 'Archiviazione sul dispositivo',
    'Profiles and preferences are stored on the device. Authentication secrets are stored using the secure storage provided by the operating system.':
        'Profili e preferenze sono archiviati sul dispositivo. I segreti di autenticazione utilizzano l’archiviazione sicura del sistema operativo.',
    'Downloads and notifications': 'Download e notifiche',
    'Offline media is stored on the device. Request notifications are generated from periodic checks performed by the application.':
        'I contenuti offline sono archiviati sul dispositivo. Le notifiche delle richieste vengono generate da controlli periodici dell’applicazione.',
    'Data deletion': 'Eliminazione dei dati',
    'Deleting a profile removes its local connection information and credentials. Offline downloads can be removed from the Downloads page.':
        'L’eliminazione di un profilo rimuove i dati di connessione e le credenziali locali. I download offline possono essere eliminati dalla pagina Download.',
    'Use of SeerrPlay requires access to compatible servers supplied by the user.':
        'L’uso di SeerrPlay richiede l’accesso a server compatibili forniti dall’utente.',
    'Authorized access only': 'Solo accesso autorizzato',
    'You must only connect to servers, libraries and media that you own or are authorized to use.':
        'Devi connetterti solo a server, librerie e contenuti di tua proprietà o che sei autorizzato a utilizzare.',
    'No media service': 'Nessun servizio multimediale',
    'SeerrPlay does not sell, provide or host films, series, subscriptions or download sources.':
        'SeerrPlay non vende, fornisce o ospita film, serie, abbonamenti o fonti di download.',
    'Third-party services': 'Servizi di terze parti',
    'Availability and operation depend on the Seerr and Jellyfin servers configured by the user and on their respective administrators.':
        'Disponibilità e funzionamento dipendono dai server Seerr e Jellyfin configurati dall’utente e dai rispettivi amministratori.',
    'User responsibility': 'Responsabilità dell’utente',
    'The user is responsible for server security, content rights, network configuration and compliance with applicable laws.':
        'L’utente è responsabile della sicurezza dei server, dei diritti sui contenuti, della configurazione di rete e del rispetto delle leggi applicabili.',
    'Connected': 'Connesso',
    'Unable to load Home': 'Impossibile caricare la Home',
    'Pull down to try again. If the session expired, reconnect the services in Settings.':
        'Trascina verso il basso per riprovare. Se la sessione è scaduta, riconnetti i servizi nelle Impostazioni.',
    'Continue watching': 'Continua a guardare',
    'Your available requests': 'Le tue richieste disponibili',
    'Trending': 'Di tendenza',
    'Popular movies': 'Film popolari',
    'Popular series': 'Serie popolari',
    'No media to display.': 'Nessun contenuto da mostrare.',
    'Unable to reach your media services':
        'Impossibile raggiungere i servizi multimediali',
    'Unable to connect to Jellyfin or Seerr, or both. Check your connection or contact your media server administrator.':
        'Impossibile connettersi a Jellyfin, Seerr o entrambi. Controlla la connessione o contatta il gestore del server multimediale.',
    'The {service} session has expired.': 'La sessione {service} è scaduta.',
    'Access was forbidden by {service}.': 'Accesso negato da {service}.',
    '{service} did not respond in time.': '{service} non ha risposto in tempo.',
    'No response from {service}.': 'Nessuna risposta da {service}.',
    '{service} returned a server error.':
        '{service} ha restituito un errore del server.',
    'Unexpected {service} error.': 'Errore {service} imprevisto.',
    'Unwatched requests': 'Richieste non viste',
    'Unable to load requests.': 'Impossibile caricare le richieste.',
    'All requests have been watched.': 'Tutte le richieste sono state viste.',
    'Providers · {region}': 'Piattaforme · {region}',
    'Media library': 'Libreria multimediale',
    'Search the media library': 'Cerca nella libreria multimediale',
    'Unable to load the media library.':
        'Impossibile caricare la libreria multimediale.',
    'Search Seerr': 'Cerca in Seerr',
    'What do you want to watch?': 'Cosa vuoi guardare?',
    'Search the localized or original titles in the Seerr catalog.':
        'Cerca i titoli localizzati o originali nel catalogo Seerr.',
    'E.g. Law Abiding Citizen': 'Es. Giustizia privata',
    'Clear': 'Cancella',
    'Search unavailable.': 'Ricerca non disponibile.',
    'Try again': 'Riprova',
    'No results for “{query}”.': 'Nessun risultato per «{query}».',
    '{count} result': '{count} risultato',
    '{count} results': '{count} risultati',
    'Movies and series': 'Film e serie',
    'Enter a localized title or its original title.':
        'Inserisci un titolo localizzato o il titolo originale.',
    'New profile': 'Nuovo profilo',
    "Who's watching?": 'Chi sta guardando?',
    'Choose a profile to continue.': 'Scegli un profilo per continuare.',
    'Choose an avatar': 'Scegli un avatar',
    'Switch profile': 'Cambia profilo',
    'Trending rank': 'In tendenza n. {rank}',
    'Create and connect': 'Crea e connetti',
    'Back': 'Indietro',
    'Profile name': 'Nome del profilo',
    'Home, Travel, Family…': 'Casa, Viaggio, Famiglia…',
    'Name': 'Nome',
    'Home profile name': 'Casa',
    'Seerr server': 'Server Seerr',
    'Request server address and account':
        'Indirizzo e account del server richieste',
    'Seerr email': 'E-mail Seerr',
    'Jellyfin username': 'Nome utente Jellyfin',
    'Password': 'Password',
    'Jellyfin server': 'Server Jellyfin',
    'Playback server address': 'Indirizzo del server di riproduzione',
    'Credentials already entered': 'Credenziali già inserite',
    'The Jellyfin account selected for Seerr is reused automatically.':
        'L’account Jellyfin scelto per Seerr viene riutilizzato automaticamente.',
    'Jellyfin password': 'Password Jellyfin',
    'Required field': 'Campo obbligatorio',
    'Port between 1 and 65535': 'Porta tra 1 e 65535',
    'Invalid URL, example: http://192.168.1.10':
        'URL non valido, esempio: http://192.168.1.10',
    'HTTP does not encrypt your credentials. Use it only for a trusted local network; HTTPS is recommended.':
        'HTTP non cifra le credenziali. Usalo solo su una rete locale attendibile; HTTPS è consigliato.',
    'URL': 'URL',
    'Port': 'Porta',
    'Domain or IP address': 'Dominio o indirizzo IP',
    'Custom port (optional)': 'Porta personalizzata (facoltativa)',
    'Invalid domain, example: jellyfin.example.com':
        'Dominio non valido, esempio: jellyfin.example.com',
    'Checking the Seerr server…': 'Verifica del server Seerr…',
    'Signing in to Seerr…': 'Accesso a Seerr…',
    'Looking for your Jellyfin server automatically…':
        'Ricerca automatica del server Jellyfin…',
    'Jellyfin server found. Checking the connection…':
        'Server Jellyfin trovato. Verifica della connessione…',
    'Jellyfin server found and connected.':
        'Server Jellyfin trovato e connesso.',
    'Signing in to Jellyfin…': 'Accesso a Jellyfin…',
    'Jellyfin address found in Seerr settings.':
        'Indirizzo Jellyfin trovato nelle impostazioni di Seerr.',
    'Jellyfin address found from an available media.':
        'Indirizzo Jellyfin trovato da un contenuto disponibile.',
    'Seerr does not publish a Jellyfin address and no available media contains one. Enter it manually.':
        'Seerr non pubblica un indirizzo Jellyfin e nessun contenuto disponibile ne contiene uno. Inseriscilo manualmente.',
    'Seerr rejected these credentials.':
        'Seerr ha rifiutato queste credenziali.',
    'Jellyfin rejected these credentials.':
        'Jellyfin ha rifiutato queste credenziali.',
    'Your account is not allowed to perform this action.':
        'Il tuo account non è autorizzato a eseguire questa azione.',
    'Seerr took too long to respond.':
        'Seerr ha impiegato troppo tempo a rispondere.',
    'Jellyfin took too long to respond.':
        'Jellyfin ha impiegato troppo tempo a rispondere.',
    'The server domain could not be found.':
        'Impossibile trovare il dominio del server.',
    'The secure connection certificate is invalid.':
        'Il certificato della connessione sicura non è valido.',
    'Seerr is unreachable. Check the domain, port, and network.':
        'Seerr non è raggiungibile. Controlla dominio, porta e rete.',
    'Jellyfin is unreachable. Check the domain, port, and network.':
        'Jellyfin non è raggiungibile. Controlla dominio, porta e rete.',
    'This address does not appear to be a Seerr server.':
        'Questo indirizzo non sembra essere un server Seerr.',
    'This address does not appear to be a Jellyfin server.':
        'Questo indirizzo non sembra essere un server Jellyfin.',
    'The server returned an internal error.':
        'Il server ha restituito un errore interno.',
    'The server returned an invalid response.':
        'Il server ha restituito una risposta non valida.',
    'Unable to load profiles.\n{error}':
        'Impossibile caricare i profili.\n{error}',
    'Reconnect services': 'Riconnetti i servizi',
    'Jellyfin account': 'Account Jellyfin',
    'Seerr account': 'Account Seerr',
    'Linked Jellyfin account': 'Account Jellyfin collegato',
    'These credentials sign in to Seerr and Jellyfin.':
        'Queste credenziali accedono a Seerr e Jellyfin.',
    'Sign in': 'Accedi',
    'Delete this profile?': 'Eliminare questo profilo?',
    'The “{name}” profile and its sign-in information will be removed from this device.':
        'Il profilo «{name}» e i relativi dati di accesso verranno rimossi da questo dispositivo.',
    'Cancel': 'Annulla',
    'Delete': 'Elimina',
    'Profile': 'Profilo',
    'Active profile': 'Profilo attivo',
    'Add profile': 'Aggiungi profilo',
    'Profiles': 'Profili',
    'Connection': 'Connessione',
    'Secure connection (HTTPS)': 'Connessione sicura (HTTPS)',
    'Unencrypted connection (HTTP)': 'Connessione non cifrata (HTTP)',
    'Delete profile': 'Elimina profilo',
    'Remove this profile and its credentials from this device.':
        'Rimuove questo profilo e le credenziali dal dispositivo.',
    'Unable to load this category.': 'Impossibile caricare questa categoria.',
    'Unable to load this provider.': 'Impossibile caricare questa piattaforma.',
    'Request sent to Seerr.': 'Richiesta inviata a Seerr.',
    'This media has already been requested.':
        'Questo contenuto è già stato richiesto.',
    'Unable to send the request.': 'Impossibile inviare la richiesta.',
    'New attempt sent.': 'Nuovo tentativo inviato.',
    'Unable to retry the request.': 'Impossibile riprovare la richiesta.',
    'Delete this request?': 'Eliminare questa richiesta?',
    'The pending request for “{title}” will be removed from Seerr.':
        'La richiesta in attesa per «{title}» verrà rimossa da Seerr.',
    'Delete request': 'Elimina richiesta',
    'Request deleted.': 'Richiesta eliminata.',
    'Unable to delete the request.': 'Impossibile eliminare la richiesta.',
    'Resume playback': 'Riprendi',
    'Play action': 'Guarda',
    'Downloading': 'Download in corso',
    'No summary available.': 'Nessuna trama disponibile.',
    'Recommendations': 'Consigliati',
    'Similar titles': 'Titoli simili',
    'Detailed Seerr information is unavailable.':
        'Le informazioni dettagliate di Seerr non sono disponibili.',
    '{progress}% watched': '{progress}% visto',
    'Retry request': 'Riprova richiesta',
    'Requested media': 'Richiesto',
    'Request on Seerr': 'Richiedi su Seerr',
    'Directed by': 'Regia',
    'Production': 'Produzione',
    'Original language': 'Lingua originale',
    'Votes': 'Voti',
    'Budget': 'Budget',
    'Information': 'Informazioni',
    'Trailers': 'Trailer',
    'Watch trailer': 'Guarda il trailer',
    'Featured trailer': 'Trailer in evidenza',
    'Overview': 'Trama',
    'Creative team': 'Team creativo',
    'Technical details': 'Dettagli tecnici',
    'Tomatometer': 'Tomatometro',
    'Rotten audience': 'Pubblico Rotten Tomatoes',
    'Learn more': 'Scopri di più',
    'Crew, technical details and studios': 'Team, dettagli tecnici e studi',
    'Video release date': 'Uscita home video',
    'Age rating': 'Limite di età',
    'Revenue': 'Incassi',
    'Studios': 'Studi',
    'Original title': 'Titolo originale',
    'Status': 'Stato',
    'Release date': 'Data di uscita',
    'Video': 'Video',
    'Cast': 'Attori',
    'Seasons': 'Stagioni',
    'Available': 'Disponibile',
    'Partial': 'Parziale',
    'Requested season': 'Richiesta',
    'Unavailable': 'Non disponibile',
    '{count} episode': '{count} episodio',
    '{count} episodes': '{count} episodi',
    'Season requested on Seerr.': 'Stagione richiesta su Seerr.',
    'Season unavailable.': 'Stagione non disponibile.',
    'Requesting…': 'Richiesta in corso…',
    'Request this season': 'Richiedi questa stagione',
    'Episodes': 'Episodi',
    'Watched': 'Visto',
    'Currently watching': 'In riproduzione',
    'More playback options': 'Altre opzioni di riproduzione',
    'Play from beginning': 'Riproduci dall’inizio',
    'Mark as watched': 'Segna come visto',
    'Mark as unwatched': 'Segna come non visto',
    'Marked as watched.': 'Segnato come visto.',
    'Marked as unwatched.': 'Segnato come non visto.',
    'Unable to update watched status.':
        'Impossibile aggiornare lo stato di visione.',
    'Choose a season': 'Scegli una stagione',
    'No unwatched episode remains.': 'Non rimangono episodi da vedere.',
    'Unable to load the next episode.':
        'Impossibile caricare l’episodio successivo.',
    'Season available': 'Stagione disponibile',
    'Season partially available': 'Stagione parzialmente disponibile',
    'Season requested': 'Stagione richiesta',
    'Season unavailable': 'Stagione non disponibile',
    'This media is not linked to Jellyfin.':
        'Questo contenuto non è collegato a Jellyfin.',
    'No video source available.': 'Nessuna sorgente video disponibile.',
    'Hide volume': 'Nascondi volume',
    'Volume': 'Volume',
    'Picture in Picture': 'Picture in Picture',
    'Playing with AirPlay': 'Riproduzione con AirPlay',
    'Use the AirPlay button to change or stop playback on the TV.':
        'Usa il pulsante AirPlay per cambiare TV o interrompere la riproduzione.',
    'Playback settings': 'Impostazioni di riproduzione',
    'Enter full screen': 'Passa a schermo intero',
    'Exit full screen': 'Esci da schermo intero',
    'Pause': 'Pausa',
    'Play state': 'Riproduci',
    'Rewind 10 seconds': 'Indietro di 10 secondi',
    'Forward 10 seconds': 'Avanti di 10 secondi',
    'Quality': 'Qualità',
    'Speed': 'Velocità',
    'Picture format': 'Formato immagine',
    'Audio': 'Audio',
    'No other audio track available': 'Nessun’altra traccia audio disponibile',
    'Subtitles': 'Sottotitoli',
    'Subtitle size': 'Dimensione dei sottotitoli',
    'Subtitle color': 'Colore dei sottotitoli',
    'Subtitle background': 'Sfondo dei sottotitoli',
    'Subtitle appearance': 'Aspetto dei sottotitoli',
    'Size, color and background used during playback.':
        'Dimensione, colore e sfondo usati durante la riproduzione.',
    'Subtitle preview': 'Anteprima dei sottotitoli',
    'Save': 'Salva',
    'Small': 'Piccola',
    'Medium': 'Media',
    'Large': 'Grande',
    'White': 'Bianco',
    'Yellow': 'Giallo',
    'Cyan': 'Ciano',
    'None': 'Nessuno',
    'Subtle': 'Discreto',
    'Solid': 'Opaco',
    'Off': 'Disattivati',
    'Forced': 'Forzato',
    'Default': 'Predefinito',
    'Fill screen': 'Riempi schermo',
    'Fit image': 'Immagine completa',
    'Auto · Jellyfin': 'Auto · Jellyfin',
    'Stream selected by {service}': 'Flusso selezionato da {service}',
    'Direct play': 'Riproduzione diretta',
    'Direct stream': 'Flusso diretto',
    'Mobile · 2 Mb/s': 'Mobile · 2 Mb/s',
    'Unable to play': 'Riproduzione impossibile',
    'Available to watch': 'Disponibile da guardare',
    'Partially available': 'Parzialmente disponibile',
    'Pending': 'In attesa',
    'Declined': 'Rifiutata',
    'Failed': 'Errore',
    'Download {progression}': 'Download {progression}',
    'Downloaded': 'Scaricato',
    '{count} channels': '{count} canali',
    'Track {number}': 'Traccia {number}',
    'Credentials rejected by Seerr or Jellyfin.':
        'Credenziali rifiutate da Seerr o Jellyfin.',
    'Server unreachable. Check the URL, port, and network.':
        'Server non raggiungibile. Controlla URL, porta e rete.',
    'Seerr did not return a session.': 'Seerr non ha restituito una sessione.',
    'Invalid Jellyfin authentication response':
        'Risposta di autenticazione Jellyfin non valida',
    'No episode is available for this series.':
        'Nessun episodio disponibile per questa serie.',
    'Age {rating}': 'Età {rating}',
    'Unable to load this person.': 'Impossibile caricare questa persona.',
    'Biography': 'Biografia',
    'Born': 'Nascita',
    'Died': 'Morte',
    'Place of birth': 'Luogo di nascita',
    'Known for': 'Conosciuto per',
    'Also known as': 'Conosciuto anche come',
    'Appearances': 'Apparizioni',
    'Behind the camera': 'Dietro la macchina da presa',
    'No biography available.': 'Nessuna biografia disponibile.',
    'Search this list': 'Cerca in questo elenco',
    'Search this category': 'Cerca in questa categoria',
    'No media matches these filters.':
        'Nessun contenuto corrisponde a questi filtri.',
    'All': 'Tutto',
    'Media type': 'Tipo di contenuto',
    'Movies': 'Film',
    'Series': 'Serie',
    'Requested': 'Richiesto',
    'Sort': 'Ordina',
    'Relevance': 'Pertinenza',
    'Newest first': 'Più recenti',
    'Oldest first': 'Meno recenti',
    'A–Z': 'A–Z',
    'All statuses': 'Tutti gli stati',
    'In progress': 'In corso',
    'Downloads': 'Download',
    'Unable to load offline downloads.':
        'Impossibile caricare i download offline.',
    'Delete this download?': 'Eliminare questo download?',
    'The offline copy of “{title}” will be removed from this device.':
        'La copia offline di «{title}» verrà rimossa da questo dispositivo.',
    '{count} offline · {size}': '{count} offline · {size}',
    'Play offline': 'Riproduci offline',
    'Delete download': 'Elimina download',
    'Downloading · {progress}%': 'Download · {progress}%',
    'Downloading · {progress}% · {time} left':
        'Download · {progress}% · {time} rimanenti',
    'Child mode': 'Modalità bambini',
    'Only shows content whose age rating is known and allowed.':
        'Mostra solo contenuti con una classificazione per età nota e consentita.',
    'Maximum age rating': 'Classificazione massima per età',
    'Up to age {age}': 'Fino a {age} anni',
    'Preparing download…': 'Preparazione download…',
    'Available offline · {size}': 'Disponibile offline · {size}',
    'Available offline': 'Disponibile offline',
    'No offline downloads': 'Nessun download offline',
    'Download an available movie or episode to watch it without a connection.':
        'Scarica un film o episodio disponibile per guardarlo senza connessione.',
    'Download interrupted.': 'Download interrotto.',
    'The media server does not allow this account to download media.':
        'Il server multimediale non consente a questo account di scaricare contenuti.',
    'Unable to download this media.': 'Impossibile scaricare questo contenuto.',
    'The downloaded file is unavailable.':
        'Il file scaricato non è disponibile.',
    'Download started.': 'Download avviato.',
    'Unable to start the download.': 'Impossibile avviare il download.',
    'Retry download': 'Riprova il download',
    'Download': 'Scarica',
    'Download offline': 'Scarica offline',
    'Choose download quality': 'Scegli la qualità del download',
    'The size is an estimate. Compatible copies are transcoded by your media server before offline playback.':
        'La dimensione è una stima. Il server multimediale transcodifica le copie compatibili prima della riproduzione offline.',
    'Up to 1080p': 'Fino a 1080p',
    'Up to 720p': 'Fino a 720p',
    'Up to 480p': 'Fino a 480p',
    'Original quality': 'Qualità originale',
    'MP4': 'MP4',
    'H.264/AAC': 'H.264/AAC',
    'Transcoded by {service}': 'Transcodificato da {service}',
    'No transcoding': 'Nessuna transcodifica',
    'Recommended': 'Consigliato',
    'This original format may not play on this device.':
        'Questo formato originale potrebbe non essere riprodotto su questo dispositivo.',
    'Unknown size': 'Dimensione sconosciuta',
    'Download · about {size}': 'Scarica · circa {size}',
    'Invalid Jellyfin response': 'Risposta Jellyfin non valida',
  },
  'de': {
    'Choose your language': 'Sprache auswählen',
    'Your phone language is shown first. You can change it later in Settings.':
        'Die Telefonsprache wird zuerst angezeigt. Du kannst sie später in den Einstellungen ändern.',
    'Phone language': 'Telefonsprache',
    'Language': 'Sprache',
    'Request notifications': 'Benachrichtigungen zu Anfragen',
    'Periodically checks Seerr for approval and availability updates. Your device may delay background checks.':
        'Prüft Seerr regelmäßig auf Freigaben und Verfügbarkeitsänderungen. Das Gerät kann Hintergrundprüfungen verzögern.',
    'Notifications are disabled in system settings.':
        'Benachrichtigungen sind in den Systemeinstellungen deaktiviert.',
    'Your request was approved.': 'Deine Anfrage wurde genehmigt.',
    'Your request was declined.': 'Deine Anfrage wurde abgelehnt.',
    'Your request could not be processed.':
        'Deine Anfrage konnte nicht verarbeitet werden.',
    'Partially available on Jellyfin.': 'Teilweise auf Jellyfin verfügbar.',
    'Available now on Jellyfin.': 'Jetzt auf Jellyfin verfügbar.',
    'French': 'Französisch',
    'English': 'Englisch',
    'Spanish': 'Spanisch',
    'Italian': 'Italienisch',
    'German': 'Deutsch',
    'Media server': 'Medienserver',
    'Media server username': 'Medienserver-Benutzername',
    '{service} account': '{service}-Konto',
    'Linked {service} account': 'Verknüpftes {service}-Konto',
    '{service} username': '{service}-Benutzername',
    '{service} password': '{service}-Passwort',
    '{service} server': '{service}-Server',
    'These credentials sign in to Seerr and {service}.':
        'Mit diesen Anmeldedaten erfolgt die Anmeldung bei Seerr und {service}.',
    'Plex account connected': 'Plex-Konto verbunden',
    'Authentication was approved securely through Plex.':
        'Die Authentifizierung wurde sicher über Plex bestätigt.',
    'Secure Plex authentication': 'Sichere Plex-Authentifizierung',
    'The Plex website opens to approve SeerrPlay.':
        'Die Plex-Website wird geöffnet, um SeerrPlay zu autorisieren.',
    'Approve the connection in Plex…': 'Bestätige die Verbindung in Plex…',
    'Approve SeerrPlay in Plex, then return to the app…':
        'Bestätige SeerrPlay in Plex und kehre dann zur App zurück…',
    'Looking for your media server automatically…':
        'Medienserver wird automatisch gesucht…',
    '{service} server found automatically.':
        '{service}-Server automatisch gefunden.',
    'Seerr does not publish the {service} address. Enter it manually.':
        'Seerr stellt die {service}-Adresse nicht bereit. Gib sie manuell ein.',
    '{service} server found. Checking the connection…':
        '{service}-Server gefunden. Verbindung wird geprüft…',
    'Signing in to {service}…': 'Anmeldung bei {service}…',
    '{service} server found and connected.':
        '{service}-Server gefunden und verbunden.',
    'The media server account selected for Seerr is reused automatically.':
        'Das für Seerr ausgewählte Medienserver-Konto wird automatisch wiederverwendet.',
    '{service} rejected these credentials.':
        '{service} hat diese Anmeldedaten abgelehnt.',
    '{service} took too long to respond.':
        '{service} hat zu lange für eine Antwort benötigt.',
    '{service} is unreachable. Check the domain, port, and network.':
        '{service} ist nicht erreichbar. Prüfe Domain, Port und Netzwerk.',
    'This address does not appear to be a {service} server.':
        'Diese Adresse scheint kein {service}-Server zu sein.',
    'Used only to reach the Seerr and media servers you configure.':
        'Wird nur verwendet, um die konfigurierten Seerr- und Medienserver zu erreichen.',
    'SeerrPlay is an independent client. It is not an official Seerr, Plex, Jellyfin or Emby application and does not host a media catalog.':
        'SeerrPlay ist ein unabhängiger Client. Es ist keine offizielle Anwendung von Seerr, Plex, Jellyfin oder Emby und hostet keinen Medienkatalog.',
    'The application connects directly to the Seerr and media server addresses configured in each profile, without a SeerrPlay intermediary server.':
        'Die Anwendung verbindet sich direkt mit den in jedem Profil konfigurierten Adressen von Seerr und dem Medienserver, ohne einen SeerrPlay-Zwischenserver.',
    'Requests, searches and playback information are exchanged directly with the Seerr and media servers configured by the user.':
        'Anfragen, Suchen und Wiedergabeinformationen werden direkt mit den vom Benutzer konfigurierten Seerr- und Medienservern ausgetauscht.',
    'Availability and operation depend on the Seerr and media servers configured by the user and on their respective administrators.':
        'Verfügbarkeit und Betrieb hängen von den konfigurierten Seerr- und Medienservern sowie deren jeweiligen Administratoren ab.',
    'Available now on your media server.':
        'Jetzt auf deinem Medienserver verfügbar.',
    'Partially available on your media server.':
        'Teilweise auf deinem Medienserver verfügbar.',
    'This media is not linked to the media server.':
        'Dieser Titel ist nicht mit dem Medienserver verknüpft.',
    'Unable to connect to the media server or Seerr. Check your connection or contact your media server administrator.':
        'Verbindung zum Medienserver oder zu Seerr nicht möglich. Prüfe deine Verbindung oder kontaktiere den Administrator deines Medienservers.',
    'Continue': 'Weiter',
    'Home navigation': 'Start',
    'Search': 'Suche',
    'Requests': 'Anfragen',
    'Settings': 'Einstellungen',
    'Your media space': 'Dein Medienbereich',
    'Choose the servers and account currently in use.':
        'Wähle die derzeit verwendeten Server und das Konto.',
    'Application': 'Anwendung',
    'Language and notification preferences.':
        'Sprach- und Benachrichtigungseinstellungen.',
    'Direct connections': 'Direkte Verbindungen',
    'SeerrPlay communicates directly with the servers in this profile.':
        'SeerrPlay kommuniziert direkt mit den Servern dieses Profils.',
    'Privacy and data': 'Datenschutz und Daten',
    'Your data stays under your control.':
        'Deine Daten bleiben unter deiner Kontrolle.',
    'Privacy policy': 'Datenschutzerklärung',
    'How SeerrPlay handles your data.':
        'Wie SeerrPlay mit deinen Daten umgeht.',
    'Local network access': 'Zugriff auf das lokale Netzwerk',
    'Used only to reach the Seerr and Jellyfin servers you configure.':
        'Wird nur verwendet, um die konfigurierten Seerr- und Jellyfin-Server zu erreichen.',
    'No SeerrPlay cloud': 'Keine SeerrPlay-Cloud',
    'Credentials and preferences are stored on this device.':
        'Zugangsdaten und Einstellungen werden auf diesem Gerät gespeichert.',
    'Delete local profile data': 'Lokale Profildaten löschen',
    'Removes this profile and its credentials from this device.':
        'Entfernt dieses Profil und seine Zugangsdaten von diesem Gerät.',
    'About': 'Über',
    'Information, legal documents and diagnostics.':
        'Informationen, rechtliche Dokumente und Diagnose.',
    'About SeerrPlay': 'Über SeerrPlay',
    'Independent client for your personal media servers.':
        'Unabhängiger Client für deine persönlichen Medienserver.',
    'Terms of use': 'Nutzungsbedingungen',
    'Rules for using SeerrPlay responsibly.':
        'Regeln für die verantwortungsvolle Nutzung von SeerrPlay.',
    'Open-source licenses': 'Open-Source-Lizenzen',
    'Libraries used to build the application.':
        'Bibliotheken, die für die Anwendung verwendet werden.',
    'Credits': 'Danksagungen',
    'Projects, services and data sources used by SeerrPlay.':
        'Projekte, Dienste und Datenquellen, die SeerrPlay verwendet.',
    'Projects and services': 'Projekte und Dienste',
    'SeerrPlay interoperates with these independent projects and services.':
        'SeerrPlay arbeitet mit diesen unabhängigen Projekten und Diensten zusammen.',
    'Media discovery and request management for personal media servers.':
        'Mediensuche und Anfrageverwaltung für persönliche Medienserver.',
    'Open-source media server and playback APIs.':
        'Open-Source-Medienserver und Wiedergabe-APIs.',
    'Personal media server and playback platform.':
        'Persönlicher Medienserver und Wiedergabeplattform.',
    'Cross-platform application framework.':
        'Plattformübergreifendes Anwendungsframework.',
    'View SeerrPlay on GitHub': 'SeerrPlay auf GitHub ansehen',
    'Unable to open this link.': 'Dieser Link kann nicht geöffnet werden.',
    'Public privacy policy': 'Öffentliche Datenschutzerklärung',
    'Open the policy published on the web.':
        'Die im Web veröffentlichte Erklärung öffnen.',
    'Support': 'Support',
    'Help, contact and issue reporting.': 'Hilfe, Kontakt und Problemmeldung.',
    'Version {version} ({build})': 'Version {version} ({build})',
    'Copy diagnostics without credentials.':
        'Diagnose ohne Zugangsdaten kopieren.',
    'Diagnostics copied.': 'Diagnose kopiert.',
    'One application to discover, request, watch and download media from your own servers.':
        'Eine Anwendung zum Entdecken, Anfragen, Ansehen und Herunterladen von Medien von deinen eigenen Servern.',
    'Independent application': 'Unabhängige Anwendung',
    'SeerrPlay is an independent client. It is not an official Seerr or Jellyfin application and does not host a media catalog.':
        'SeerrPlay ist ein unabhängiger Client. Es ist keine offizielle Seerr- oder Jellyfin-Anwendung und hostet keinen Medienkatalog.',
    'Direct architecture': 'Direkte Architektur',
    'The application connects directly to the Seerr and Jellyfin addresses configured in each profile, without a SeerrPlay intermediary server.':
        'Die Anwendung verbindet sich direkt mit den in jedem Profil konfigurierten Seerr- und Jellyfin-Adressen, ohne einen SeerrPlay-Zwischenserver.',
    'Designed for personal libraries':
        'Für persönliche Bibliotheken entwickelt',
    'SeerrPlay is intended for media servers and libraries that you own or are authorized to access.':
        'SeerrPlay ist für Medienserver und Bibliotheken bestimmt, die dir gehören oder auf die du zugreifen darfst.',
    'SeerrPlay is designed to minimize data collection and keep control with the user.':
        'SeerrPlay minimiert die Datenerfassung und lässt die Kontrolle beim Benutzer.',
    'No tracking or advertising': 'Kein Tracking und keine Werbung',
    'SeerrPlay does not include advertising, analytics or cross-application tracking.':
        'SeerrPlay enthält keine Werbung, Analysen oder anwendungsübergreifendes Tracking.',
    'Google Cast': 'Google Cast',
    'Unable to open the Google Cast selector.':
        'Die Google-Cast-Auswahl konnte nicht geöffnet werden.',
    'When Google Cast is available, the Google Cast SDK may send technical application, device discovery and cast session information to Google. Media server credentials are not included.':
        'Wenn Google Cast verfügbar ist, kann das Google Cast SDK technische Informationen zur Anwendung, Geräteerkennung und Cast-Sitzung an Google senden. Zugangsdaten der Medienserver sind nicht enthalten.',
    'Direct server communication': 'Direkte Serverkommunikation',
    'Requests, searches and playback information are exchanged directly with the Seerr and Jellyfin servers configured by the user.':
        'Anfragen, Suchen und Wiedergabeinformationen werden direkt mit den vom Benutzer konfigurierten Seerr- und Jellyfin-Servern ausgetauscht.',
    'On-device storage': 'Speicherung auf dem Gerät',
    'Profiles and preferences are stored on the device. Authentication secrets are stored using the secure storage provided by the operating system.':
        'Profile und Einstellungen werden auf dem Gerät gespeichert. Authentifizierungsdaten verwenden den sicheren Speicher des Betriebssystems.',
    'Downloads and notifications': 'Downloads und Benachrichtigungen',
    'Offline media is stored on the device. Request notifications are generated from periodic checks performed by the application.':
        'Offline-Medien werden auf dem Gerät gespeichert. Anfragebenachrichtigungen entstehen durch regelmäßige Prüfungen der Anwendung.',
    'Data deletion': 'Datenlöschung',
    'Deleting a profile removes its local connection information and credentials. Offline downloads can be removed from the Downloads page.':
        'Das Löschen eines Profils entfernt lokale Verbindungsdaten und Zugangsdaten. Offline-Downloads können auf der Download-Seite entfernt werden.',
    'Use of SeerrPlay requires access to compatible servers supplied by the user.':
        'Die Nutzung von SeerrPlay erfordert Zugriff auf kompatible, vom Benutzer bereitgestellte Server.',
    'Authorized access only': 'Nur autorisierter Zugriff',
    'You must only connect to servers, libraries and media that you own or are authorized to use.':
        'Du darfst dich nur mit Servern, Bibliotheken und Medien verbinden, die dir gehören oder die du verwenden darfst.',
    'No media service': 'Kein Mediendienst',
    'SeerrPlay does not sell, provide or host films, series, subscriptions or download sources.':
        'SeerrPlay verkauft, liefert oder hostet keine Filme, Serien, Abonnements oder Downloadquellen.',
    'Third-party services': 'Drittanbieterdienste',
    'Availability and operation depend on the Seerr and Jellyfin servers configured by the user and on their respective administrators.':
        'Verfügbarkeit und Betrieb hängen von den vom Benutzer konfigurierten Seerr- und Jellyfin-Servern und deren Administratoren ab.',
    'User responsibility': 'Verantwortung des Benutzers',
    'The user is responsible for server security, content rights, network configuration and compliance with applicable laws.':
        'Der Benutzer ist für Serversicherheit, Inhaltsrechte, Netzwerkkonfiguration und die Einhaltung geltender Gesetze verantwortlich.',
    'Connected': 'Verbunden',
    'Unable to load Home': 'Startseite konnte nicht geladen werden',
    'Pull down to try again. If the session expired, reconnect the services in Settings.':
        'Zum erneuten Laden nach unten ziehen. Falls die Sitzung abgelaufen ist, verbinde die Dienste in den Einstellungen erneut.',
    'Continue watching': 'Weiterschauen',
    'Your available requests': 'Deine verfügbaren Anfragen',
    'Trending': 'Trends',
    'Popular movies': 'Beliebte Filme',
    'Popular series': 'Beliebte Serien',
    'No media to display.': 'Keine Medien verfügbar.',
    'Unable to reach your media services':
        'Deine Mediendienste sind nicht erreichbar',
    'Unable to connect to Jellyfin or Seerr, or both. Check your connection or contact your media server administrator.':
        'Verbindung zu Jellyfin, Seerr oder beiden nicht möglich. Prüfe deine Verbindung oder kontaktiere die Verwaltung deines Medienservers.',
    'The {service} session has expired.':
        'Die {service}-Sitzung ist abgelaufen.',
    'Access was forbidden by {service}.':
        '{service} hat den Zugriff verweigert.',
    '{service} did not respond in time.':
        '{service} hat nicht rechtzeitig geantwortet.',
    'No response from {service}.': 'Keine Antwort von {service}.',
    '{service} returned a server error.':
        '{service} hat einen Serverfehler zurückgegeben.',
    'Unexpected {service} error.': 'Unerwarteter {service}-Fehler.',
    'Unwatched requests': 'Ungesehene Anfragen',
    'Unable to load requests.': 'Anfragen konnten nicht geladen werden.',
    'All requests have been watched.': 'Alle Anfragen wurden angesehen.',
    'Providers · {region}': 'Anbieter · {region}',
    'Media library': 'Medienbibliothek',
    'Search the media library': 'Medienbibliothek durchsuchen',
    'Unable to load the media library.':
        'Medienbibliothek konnte nicht geladen werden.',
    'Search Seerr': 'Seerr durchsuchen',
    'What do you want to watch?': 'Was möchtest du ansehen?',
    'Search the localized or original titles in the Seerr catalog.':
        'Suche nach lokalisierten oder originalen Titeln im Seerr-Katalog.',
    'E.g. Law Abiding Citizen': 'Z. B. Gesetz der Rache',
    'Clear': 'Löschen',
    'Search unavailable.': 'Suche nicht verfügbar.',
    'Try again': 'Erneut versuchen',
    'No results for “{query}”.': 'Keine Ergebnisse für „{query}“.',
    '{count} result': '{count} Ergebnis',
    '{count} results': '{count} Ergebnisse',
    'Movies and series': 'Filme und Serien',
    'Enter a localized title or its original title.':
        'Gib einen lokalisierten oder den originalen Titel ein.',
    'New profile': 'Neues Profil',
    "Who's watching?": 'Wer schaut gerade?',
    'Choose a profile to continue.': 'Wähle ein Profil aus, um fortzufahren.',
    'Choose an avatar': 'Wähle einen Avatar',
    'Switch profile': 'Profil wechseln',
    'Trending rank': 'Trend Nr. {rank}',
    'Create and connect': 'Erstellen und verbinden',
    'Back': 'Zurück',
    'Profile name': 'Profilname',
    'Home, Travel, Family…': 'Zuhause, Reise, Familie…',
    'Name': 'Name',
    'Home profile name': 'Zuhause',
    'Seerr server': 'Seerr-Server',
    'Request server address and account':
        'Adresse und Konto des Anfrageservers',
    'Seerr email': 'Seerr-E-Mail',
    'Jellyfin username': 'Jellyfin-Benutzername',
    'Password': 'Passwort',
    'Jellyfin server': 'Jellyfin-Server',
    'Playback server address': 'Adresse des Wiedergabeservers',
    'Credentials already entered': 'Zugangsdaten bereits eingegeben',
    'The Jellyfin account selected for Seerr is reused automatically.':
        'Das für Seerr gewählte Jellyfin-Konto wird automatisch wiederverwendet.',
    'Jellyfin password': 'Jellyfin-Passwort',
    'Required field': 'Pflichtfeld',
    'Port between 1 and 65535': 'Port zwischen 1 und 65535',
    'Invalid URL, example: http://192.168.1.10':
        'Ungültige URL, Beispiel: http://192.168.1.10',
    'HTTP does not encrypt your credentials. Use it only for a trusted local network; HTTPS is recommended.':
        'HTTP verschlüsselt deine Zugangsdaten nicht. Verwende es nur in einem vertrauenswürdigen lokalen Netzwerk; HTTPS wird empfohlen.',
    'URL': 'URL',
    'Port': 'Port',
    'Domain or IP address': 'Domain oder IP-Adresse',
    'Custom port (optional)': 'Eigener Port (optional)',
    'Invalid domain, example: jellyfin.example.com':
        'Ungültige Domain, Beispiel: jellyfin.example.com',
    'Checking the Seerr server…': 'Seerr-Server wird geprüft…',
    'Signing in to Seerr…': 'Anmeldung bei Seerr…',
    'Looking for your Jellyfin server automatically…':
        'Dein Jellyfin-Server wird automatisch gesucht…',
    'Jellyfin server found. Checking the connection…':
        'Jellyfin-Server gefunden. Verbindung wird geprüft…',
    'Jellyfin server found and connected.':
        'Jellyfin-Server gefunden und verbunden.',
    'Signing in to Jellyfin…': 'Anmeldung bei Jellyfin…',
    'Jellyfin address found in Seerr settings.':
        'Jellyfin-Adresse in den Seerr-Einstellungen gefunden.',
    'Jellyfin address found from an available media.':
        'Jellyfin-Adresse aus einem verfügbaren Medium gefunden.',
    'Seerr does not publish a Jellyfin address and no available media contains one. Enter it manually.':
        'Seerr veröffentlicht keine Jellyfin-Adresse und kein verfügbares Medium enthält eine. Gib sie manuell ein.',
    'Seerr rejected these credentials.':
        'Seerr hat diese Zugangsdaten abgelehnt.',
    'Jellyfin rejected these credentials.':
        'Jellyfin hat diese Zugangsdaten abgelehnt.',
    'Your account is not allowed to perform this action.':
        'Dein Konto darf diese Aktion nicht ausführen.',
    'Seerr took too long to respond.':
        'Seerr hat zu lange für eine Antwort gebraucht.',
    'Jellyfin took too long to respond.':
        'Jellyfin hat zu lange für eine Antwort gebraucht.',
    'The server domain could not be found.':
        'Die Server-Domain wurde nicht gefunden.',
    'The secure connection certificate is invalid.':
        'Das Zertifikat der sicheren Verbindung ist ungültig.',
    'Seerr is unreachable. Check the domain, port, and network.':
        'Seerr ist nicht erreichbar. Prüfe Domain, Port und Netzwerk.',
    'Jellyfin is unreachable. Check the domain, port, and network.':
        'Jellyfin ist nicht erreichbar. Prüfe Domain, Port und Netzwerk.',
    'This address does not appear to be a Seerr server.':
        'Diese Adresse scheint kein Seerr-Server zu sein.',
    'This address does not appear to be a Jellyfin server.':
        'Diese Adresse scheint kein Jellyfin-Server zu sein.',
    'The server returned an internal error.':
        'Der Server hat einen internen Fehler zurückgegeben.',
    'The server returned an invalid response.':
        'Der Server hat eine ungültige Antwort zurückgegeben.',
    'Unable to load profiles.\n{error}':
        'Profile konnten nicht geladen werden.\n{error}',
    'Reconnect services': 'Dienste erneut verbinden',
    'Jellyfin account': 'Jellyfin-Konto',
    'Seerr account': 'Seerr-Konto',
    'Linked Jellyfin account': 'Verknüpftes Jellyfin-Konto',
    'These credentials sign in to Seerr and Jellyfin.':
        'Diese Zugangsdaten melden dich bei Seerr und Jellyfin an.',
    'Sign in': 'Anmelden',
    'Delete this profile?': 'Dieses Profil löschen?',
    'The “{name}” profile and its sign-in information will be removed from this device.':
        'Das Profil „{name}“ und seine Anmeldedaten werden von diesem Gerät entfernt.',
    'Cancel': 'Abbrechen',
    'Delete': 'Löschen',
    'Profile': 'Profil',
    'Active profile': 'Aktives Profil',
    'Add profile': 'Profil hinzufügen',
    'Profiles': 'Profile',
    'Connection': 'Verbindung',
    'Secure connection (HTTPS)': 'Sichere Verbindung (HTTPS)',
    'Unencrypted connection (HTTP)': 'Unverschlüsselte Verbindung (HTTP)',
    'Delete profile': 'Profil löschen',
    'Remove this profile and its credentials from this device.':
        'Entfernt dieses Profil und seine Zugangsdaten vom Gerät.',
    'Unable to load this category.':
        'Diese Kategorie konnte nicht geladen werden.',
    'Unable to load this provider.':
        'Dieser Anbieter konnte nicht geladen werden.',
    'Request sent to Seerr.': 'Anfrage an Seerr gesendet.',
    'This media has already been requested.':
        'Dieser Titel wurde bereits angefragt.',
    'Unable to send the request.': 'Die Anfrage konnte nicht gesendet werden.',
    'New attempt sent.': 'Neuer Versuch gesendet.',
    'Unable to retry the request.':
        'Die Anfrage konnte nicht erneut versucht werden.',
    'Delete this request?': 'Diese Anfrage löschen?',
    'The pending request for “{title}” will be removed from Seerr.':
        'Die ausstehende Anfrage für „{title}“ wird aus Seerr entfernt.',
    'Delete request': 'Anfrage löschen',
    'Request deleted.': 'Anfrage gelöscht.',
    'Unable to delete the request.':
        'Die Anfrage konnte nicht gelöscht werden.',
    'Resume playback': 'Fortsetzen',
    'Play action': 'Ansehen',
    'Downloading': 'Wird heruntergeladen',
    'No summary available.': 'Keine Zusammenfassung verfügbar.',
    'Recommendations': 'Empfehlungen',
    'Similar titles': 'Ähnliche Titel',
    'Detailed Seerr information is unavailable.':
        'Detaillierte Seerr-Informationen sind nicht verfügbar.',
    '{progress}% watched': '{progress}% angesehen',
    'Retry request': 'Anfrage erneut versuchen',
    'Requested media': 'Angefragt',
    'Request on Seerr': 'Auf Seerr anfragen',
    'Directed by': 'Regie',
    'Production': 'Produktion',
    'Original language': 'Originalsprache',
    'Votes': 'Stimmen',
    'Budget': 'Budget',
    'Information': 'Informationen',
    'Trailers': 'Trailer',
    'Watch trailer': 'Trailer ansehen',
    'Featured trailer': 'Empfohlener Trailer',
    'Overview': 'Übersicht',
    'Creative team': 'Kreativteam',
    'Technical details': 'Technische Details',
    'Tomatometer': 'Tomatometer',
    'Rotten audience': 'Rotten-Tomatoes-Publikum',
    'Learn more': 'Mehr erfahren',
    'Crew, technical details and studios':
        'Team, technische Details und Studios',
    'Video release date': 'Videoveröffentlichung',
    'Age rating': 'Altersfreigabe',
    'Revenue': 'Einspielergebnis',
    'Studios': 'Studios',
    'Original title': 'Originaltitel',
    'Status': 'Status',
    'Release date': 'Veröffentlichungsdatum',
    'Video': 'Video',
    'Cast': 'Schauspieler',
    'Seasons': 'Staffeln',
    'Available': 'Verfügbar',
    'Partial': 'Teilweise',
    'Requested season': 'Angefragt',
    'Unavailable': 'Nicht verfügbar',
    '{count} episode': '{count} Folge',
    '{count} episodes': '{count} Folgen',
    'Season requested on Seerr.': 'Staffel bei Seerr angefragt.',
    'Season unavailable.': 'Staffel nicht verfügbar.',
    'Requesting…': 'Anfrage läuft…',
    'Request this season': 'Diese Staffel anfragen',
    'Episodes': 'Folgen',
    'Watched': 'Gesehen',
    'Currently watching': 'Wird gerade angesehen',
    'More playback options': 'Weitere Wiedergabeoptionen',
    'Play from beginning': 'Von Anfang an abspielen',
    'Mark as watched': 'Als gesehen markieren',
    'Mark as unwatched': 'Als ungesehen markieren',
    'Marked as watched.': 'Als gesehen markiert.',
    'Marked as unwatched.': 'Als ungesehen markiert.',
    'Unable to update watched status.':
        'Der Wiedergabestatus konnte nicht aktualisiert werden.',
    'Choose a season': 'Staffel auswählen',
    'No unwatched episode remains.':
        'Es sind keine ungesehenen Folgen mehr übrig.',
    'Unable to load the next episode.':
        'Die nächste Folge konnte nicht geladen werden.',
    'Season available': 'Staffel verfügbar',
    'Season partially available': 'Staffel teilweise verfügbar',
    'Season requested': 'Staffel angefragt',
    'Season unavailable': 'Staffel nicht verfügbar',
    'This media is not linked to Jellyfin.':
        'Dieser Titel ist nicht mit Jellyfin verknüpft.',
    'No video source available.': 'Keine Videoquelle verfügbar.',
    'Hide volume': 'Lautstärke ausblenden',
    'Volume': 'Lautstärke',
    'Picture in Picture': 'Bild-in-Bild',
    'Playing with AirPlay': 'Wiedergabe mit AirPlay',
    'Use the AirPlay button to change or stop playback on the TV.':
        'Verwende die AirPlay-Taste, um den Fernseher zu wechseln oder die Wiedergabe zu beenden.',
    'Playback settings': 'Wiedergabeeinstellungen',
    'Enter full screen': 'Vollbildmodus aktivieren',
    'Exit full screen': 'Vollbildmodus beenden',
    'Pause': 'Pause',
    'Play state': 'Abspielen',
    'Rewind 10 seconds': '10 Sekunden zurück',
    'Forward 10 seconds': '10 Sekunden vor',
    'Quality': 'Qualität',
    'Speed': 'Geschwindigkeit',
    'Picture format': 'Bildformat',
    'Audio': 'Audio',
    'No other audio track available': 'Keine weitere Audiospur verfügbar',
    'Subtitles': 'Untertitel',
    'Subtitle size': 'Untertitelgröße',
    'Subtitle color': 'Untertitelfarbe',
    'Subtitle background': 'Untertitelhintergrund',
    'Subtitle appearance': 'Untertiteldarstellung',
    'Size, color and background used during playback.':
        'Größe, Farbe und Hintergrund während der Wiedergabe.',
    'Subtitle preview': 'Untertitelvorschau',
    'Save': 'Speichern',
    'Small': 'Klein',
    'Medium': 'Mittel',
    'Large': 'Groß',
    'White': 'Weiß',
    'Yellow': 'Gelb',
    'Cyan': 'Cyan',
    'None': 'Keiner',
    'Subtle': 'Dezent',
    'Solid': 'Deckend',
    'Off': 'Aus',
    'Forced': 'Erzwungen',
    'Default': 'Standard',
    'Fill screen': 'Bildschirm füllen',
    'Fit image': 'Gesamtes Bild',
    'Auto · Jellyfin': 'Auto · Jellyfin',
    'Stream selected by {service}': 'Von {service} ausgewählter Stream',
    'Direct play': 'Direkte Wiedergabe',
    'Direct stream': 'Direkter Stream',
    'Mobile · 2 Mb/s': 'Mobil · 2 Mb/s',
    'Unable to play': 'Wiedergabe nicht möglich',
    'Available to watch': 'Zum Ansehen verfügbar',
    'Partially available': 'Teilweise verfügbar',
    'Pending': 'Ausstehend',
    'Declined': 'Abgelehnt',
    'Failed': 'Fehlgeschlagen',
    'Download {progression}': 'Download {progression}',
    'Downloaded': 'Heruntergeladen',
    '{count} channels': '{count} Kanäle',
    'Track {number}': 'Spur {number}',
    'Credentials rejected by Seerr or Jellyfin.':
        'Zugangsdaten von Seerr oder Jellyfin abgelehnt.',
    'Server unreachable. Check the URL, port, and network.':
        'Server nicht erreichbar. Prüfe URL, Port und Netzwerk.',
    'Seerr did not return a session.': 'Seerr hat keine Sitzung zurückgegeben.',
    'Invalid Jellyfin authentication response':
        'Ungültige Jellyfin-Authentifizierungsantwort',
    'No episode is available for this series.':
        'Für diese Serie ist keine Folge verfügbar.',
    'Age {rating}': 'Alter {rating}',
    'Unable to load this person.': 'Diese Person konnte nicht geladen werden.',
    'Biography': 'Biografie',
    'Born': 'Geboren',
    'Died': 'Gestorben',
    'Place of birth': 'Geburtsort',
    'Known for': 'Bekannt für',
    'Also known as': 'Auch bekannt als',
    'Appearances': 'Auftritte',
    'Behind the camera': 'Hinter der Kamera',
    'No biography available.': 'Keine Biografie verfügbar.',
    'Search this list': 'Diese Liste durchsuchen',
    'Search this category': 'Diese Kategorie durchsuchen',
    'No media matches these filters.':
        'Keine Medien entsprechen diesen Filtern.',
    'All': 'Alle',
    'Media type': 'Medientyp',
    'Movies': 'Filme',
    'Series': 'Serien',
    'Requested': 'Angefragt',
    'Sort': 'Sortieren',
    'Relevance': 'Relevanz',
    'Newest first': 'Neueste zuerst',
    'Oldest first': 'Älteste zuerst',
    'A–Z': 'A–Z',
    'All statuses': 'Alle Status',
    'In progress': 'In Bearbeitung',
    'Downloads': 'Downloads',
    'Unable to load offline downloads.':
        'Offline-Downloads konnten nicht geladen werden.',
    'Delete this download?': 'Diesen Download löschen?',
    'The offline copy of “{title}” will be removed from this device.':
        'Die Offline-Kopie von „{title}“ wird von diesem Gerät entfernt.',
    '{count} offline · {size}': '{count} offline · {size}',
    'Play offline': 'Offline abspielen',
    'Delete download': 'Download löschen',
    'Downloading · {progress}%': 'Download · {progress} %',
    'Downloading · {progress}% · {time} left':
        'Download · {progress} % · noch {time}',
    'Child mode': 'Kindermodus',
    'Only shows content whose age rating is known and allowed.':
        'Zeigt nur Inhalte mit bekannter und erlaubter Altersfreigabe.',
    'Maximum age rating': 'Maximale Altersfreigabe',
    'Up to age {age}': 'Bis {age} Jahre',
    'Preparing download…': 'Download wird vorbereitet…',
    'Available offline · {size}': 'Offline verfügbar · {size}',
    'Available offline': 'Offline verfügbar',
    'No offline downloads': 'Keine Offline-Downloads',
    'Download an available movie or episode to watch it without a connection.':
        'Lade einen verfügbaren Film oder eine Folge herunter, um sie offline anzusehen.',
    'Download interrupted.': 'Download unterbrochen.',
    'The media server does not allow this account to download media.':
        'Der Medienserver erlaubt diesem Konto keine Medien-Downloads.',
    'Unable to download this media.':
        'Dieses Medium konnte nicht heruntergeladen werden.',
    'The downloaded file is unavailable.':
        'Die heruntergeladene Datei ist nicht verfügbar.',
    'Download started.': 'Download gestartet.',
    'Unable to start the download.':
        'Der Download konnte nicht gestartet werden.',
    'Retry download': 'Download erneut versuchen',
    'Download': 'Herunterladen',
    'Download offline': 'Offline herunterladen',
    'Choose download quality': 'Downloadqualität auswählen',
    'The size is an estimate. Compatible copies are transcoded by your media server before offline playback.':
        'Die Größe ist eine Schätzung. Der Medienserver transkodiert kompatible Kopien vor der Offline-Wiedergabe.',
    'Up to 1080p': 'Bis zu 1080p',
    'Up to 720p': 'Bis zu 720p',
    'Up to 480p': 'Bis zu 480p',
    'Original quality': 'Originalqualität',
    'MP4': 'MP4',
    'H.264/AAC': 'H.264/AAC',
    'Transcoded by {service}': 'Von {service} transkodiert',
    'No transcoding': 'Keine Transkodierung',
    'Recommended': 'Empfohlen',
    'This original format may not play on this device.':
        'Dieses Originalformat kann auf diesem Gerät möglicherweise nicht wiedergegeben werden.',
    'Unknown size': 'Unbekannte Größe',
    'Download · about {size}': 'Herunterladen · ca. {size}',
    'Invalid Jellyfin response': 'Ungültige Jellyfin-Antwort',
  },
};
