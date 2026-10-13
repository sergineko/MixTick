import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('es', 'ES'),
  ];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'MixTick'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'Cocina, comparte y marca tu compra.'**
  String get tagline;

  /// No description provided for @accessTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cocina, en un solo lugar'**
  String get accessTitle;

  /// No description provided for @accessDescription.
  ///
  /// In es, this message translates to:
  /// **'Descubre recetas, reúne tus favoritas y organiza la compra con las personas que tú elijas.'**
  String get accessDescription;

  /// No description provided for @accessRequired.
  ///
  /// In es, this message translates to:
  /// **'Necesitas una cuenta para acceder a tus cuatro espacios.'**
  String get accessRequired;

  /// No description provided for @accessPending.
  ///
  /// In es, this message translates to:
  /// **'El acceso con tu cuenta estará disponible próximamente.'**
  String get accessPending;

  /// No description provided for @accessStatusAction.
  ///
  /// In es, this message translates to:
  /// **'Consultar estado del acceso'**
  String get accessStatusAction;

  /// No description provided for @accessStatusTitle.
  ///
  /// In es, this message translates to:
  /// **'Acceso a MixTick'**
  String get accessStatusTitle;

  /// No description provided for @serviceUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El servicio de acceso todavía no está disponible. Vuelve a intentarlo más adelante.'**
  String get serviceUnavailable;

  /// No description provided for @accessNotEnabled.
  ///
  /// In es, this message translates to:
  /// **'Todavía no puedes iniciar sesión. Vuelve a intentarlo más adelante.'**
  String get accessNotEnabled;

  /// No description provided for @sessionError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos comprobar tu sesión. Vuelve al acceso e inténtalo de nuevo.'**
  String get sessionError;

  /// No description provided for @checkingSession.
  ///
  /// In es, this message translates to:
  /// **'Comprobando tu sesión…'**
  String get checkingSession;

  /// No description provided for @backToAccess.
  ///
  /// In es, this message translates to:
  /// **'Volver al acceso'**
  String get backToAccess;

  /// No description provided for @community.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get community;

  /// No description provided for @recipes.
  ///
  /// In es, this message translates to:
  /// **'Mi recetario'**
  String get recipes;

  /// No description provided for @cookToday.
  ///
  /// In es, this message translates to:
  /// **'¿Qué cocino hoy?'**
  String get cookToday;

  /// No description provided for @cookTodayNav.
  ///
  /// In es, this message translates to:
  /// **'¿Qué cocino?'**
  String get cookTodayNav;

  /// No description provided for @shopping.
  ///
  /// In es, this message translates to:
  /// **'Lista de compra'**
  String get shopping;

  /// No description provided for @shoppingNav.
  ///
  /// In es, this message translates to:
  /// **'Compra'**
  String get shoppingNav;

  /// No description provided for @profile.
  ///
  /// In es, this message translates to:
  /// **'Mi perfil'**
  String get profile;

  /// No description provided for @profileDescription.
  ///
  /// In es, this message translates to:
  /// **'Aquí podrás gestionar tu perfil y los ajustes de tu cuenta.'**
  String get profileDescription;

  /// No description provided for @comingSoon.
  ///
  /// In es, this message translates to:
  /// **'Próximamente'**
  String get comingSoon;

  /// No description provided for @communityTitle.
  ///
  /// In es, this message translates to:
  /// **'Recetas para compartir'**
  String get communityTitle;

  /// No description provided for @communityDescription.
  ///
  /// In es, this message translates to:
  /// **'Aquí podrás descubrir las recetas públicas de la comunidad.'**
  String get communityDescription;

  /// No description provided for @recipesTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus recetas, a tu manera'**
  String get recipesTitle;

  /// No description provided for @recipesDescription.
  ///
  /// In es, this message translates to:
  /// **'Aquí reunirás las recetas creadas por ti y tus recetas públicas guardadas.'**
  String get recipesDescription;

  /// No description provided for @recipesPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Tus nuevas recetas serán privadas. Publicarlas será siempre una decisión tuya.'**
  String get recipesPrivacy;

  /// No description provided for @cookTodayTitle.
  ///
  /// In es, this message translates to:
  /// **'Empieza por tus ingredientes'**
  String get cookTodayTitle;

  /// No description provided for @cookTodayDescription.
  ///
  /// In es, this message translates to:
  /// **'Elige ingredientes durante la consulta para encontrar recetas que coincidan.'**
  String get cookTodayDescription;

  /// No description provided for @cookTodayNotice.
  ///
  /// In es, this message translates to:
  /// **'La selección será temporal. No se comprobarán cantidades disponibles.'**
  String get cookTodayNotice;

  /// No description provided for @shoppingTitle.
  ///
  /// In es, this message translates to:
  /// **'La compra, bien organizada'**
  String get shoppingTitle;

  /// No description provided for @shoppingDescription.
  ///
  /// In es, this message translates to:
  /// **'Aquí podrás organizar tus listas y compartirlas mediante invitación aceptada.'**
  String get shoppingDescription;

  /// No description provided for @routeNotFound.
  ///
  /// In es, this message translates to:
  /// **'No encontramos esa pantalla.'**
  String get routeNotFound;

  /// No description provided for @goHome.
  ///
  /// In es, this message translates to:
  /// **'Ir a Comunidad'**
  String get goHome;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case 'ES':
            return AppLocalizationsEsEs();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
