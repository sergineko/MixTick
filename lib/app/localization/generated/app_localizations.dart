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

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @repeatPassword.
  ///
  /// In es, this message translates to:
  /// **'Repite la contraseña'**
  String get repeatPassword;

  /// No description provided for @newPassword.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get newPassword;

  /// No description provided for @changePassword.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get changePassword;

  /// No description provided for @savePassword.
  ///
  /// In es, this message translates to:
  /// **'Guardar contraseña'**
  String get savePassword;

  /// No description provided for @showPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get hidePassword;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Introduce un correo electrónico válido.'**
  String get invalidEmail;

  /// No description provided for @invalidPassword.
  ///
  /// In es, this message translates to:
  /// **'Usa entre 8 y 128 caracteres.'**
  String get invalidPassword;

  /// No description provided for @passwordHint.
  ///
  /// In es, this message translates to:
  /// **'Al menos 8 caracteres. Evita contraseñas fáciles de adivinar.'**
  String get passwordHint;

  /// No description provided for @passwordMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get passwordMismatch;

  /// No description provided for @requiredField.
  ///
  /// In es, this message translates to:
  /// **'Completa este campo.'**
  String get requiredField;

  /// No description provided for @recoverPassword.
  ///
  /// In es, this message translates to:
  /// **'Recuperar contraseña'**
  String get recoverPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'He olvidado mi contraseña'**
  String get forgotPassword;

  /// No description provided for @sendRecovery.
  ///
  /// In es, this message translates to:
  /// **'Enviar instrucciones'**
  String get sendRecovery;

  /// No description provided for @recoveryDescription.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un enlace para elegir una nueva contraseña. Ábrelo en este mismo dispositivo.'**
  String get recoveryDescription;

  /// No description provided for @recoverySent.
  ///
  /// In es, this message translates to:
  /// **'Si el correo corresponde a una cuenta, recibirás las instrucciones. Revisa también el correo no deseado.'**
  String get recoverySent;

  /// No description provided for @recoveryLinkNeeded.
  ///
  /// In es, this message translates to:
  /// **'Abre el enlace de recuperación recibido en este dispositivo. Si ha caducado, solicita otro.'**
  String get recoveryLinkNeeded;

  /// No description provided for @registrationDescription.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta. Si la confirmación de correo está activada, tendrás que verificarlo antes de entrar.'**
  String get registrationDescription;

  /// No description provided for @confirmEmail.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo'**
  String get confirmEmail;

  /// No description provided for @confirmationSent.
  ///
  /// In es, this message translates to:
  /// **'Si el correo puede registrarse, recibirás un enlace de confirmación. Si ya tienes cuenta, inicia sesión o recupera la contraseña.'**
  String get confirmationSent;

  /// No description provided for @resendEmail.
  ///
  /// In es, this message translates to:
  /// **'Reenviar confirmación'**
  String get resendEmail;

  /// No description provided for @confirmationNeeded.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu correo antes de iniciar sesión. Puedes revisar o reenviar la confirmación desde Crear cuenta.'**
  String get confirmationNeeded;

  /// No description provided for @passwordUpdated.
  ///
  /// In es, this message translates to:
  /// **'Contraseña actualizada.'**
  String get passwordUpdated;

  /// No description provided for @processing.
  ///
  /// In es, this message translates to:
  /// **'Procesando…'**
  String get processing;

  /// No description provided for @networkError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectar. Comprueba tu conexión e inténtalo de nuevo.'**
  String get networkError;

  /// No description provided for @credentialsError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos iniciar sesión con esos datos. Revisa el correo y la contraseña.'**
  String get credentialsError;

  /// No description provided for @passwordPolicyError.
  ///
  /// In es, this message translates to:
  /// **'La contraseña no cumple la política del servicio. Elige una más segura.'**
  String get passwordPolicyError;

  /// No description provided for @rateLimitError.
  ///
  /// In es, this message translates to:
  /// **'Hay demasiadas solicitudes. Espera un momento antes de volver a intentarlo.'**
  String get rateLimitError;

  /// No description provided for @expiredSession.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión ha caducado. Vuelve a iniciar sesión.'**
  String get expiredSession;

  /// No description provided for @invalidAuthLink.
  ///
  /// In es, this message translates to:
  /// **'El enlace no es válido, ha caducado o pertenece a otro dispositivo. Solicita uno nuevo.'**
  String get invalidAuthLink;

  /// No description provided for @operationError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la operación. Vuelve a intentarlo.'**
  String get operationError;

  /// No description provided for @loadingProfile.
  ///
  /// In es, this message translates to:
  /// **'Cargando perfil…'**
  String get loadingProfile;

  /// No description provided for @completeProfile.
  ///
  /// In es, this message translates to:
  /// **'Completa tu perfil público'**
  String get completeProfile;

  /// No description provided for @createProfile.
  ///
  /// In es, this message translates to:
  /// **'Crear mi perfil'**
  String get createProfile;

  /// No description provided for @editProfile.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get editProfile;

  /// No description provided for @publicProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil público'**
  String get publicProfile;

  /// No description provided for @viewPublicProfile.
  ///
  /// In es, this message translates to:
  /// **'Ver mi perfil público'**
  String get viewPublicProfile;

  /// No description provided for @displayName.
  ///
  /// In es, this message translates to:
  /// **'Nombre visible'**
  String get displayName;

  /// No description provided for @username.
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In es, this message translates to:
  /// **'De 3 a 30 letras a–z, números o guion bajo. Se guarda en minúsculas.'**
  String get usernameHint;

  /// No description provided for @invalidUsername.
  ///
  /// In es, this message translates to:
  /// **'Usa de 3 a 30 letras a–z, números o guion bajo.'**
  String get invalidUsername;

  /// No description provided for @invalidDisplayName.
  ///
  /// In es, this message translates to:
  /// **'Introduce un nombre visible de 1 a 60 caracteres.'**
  String get invalidDisplayName;

  /// No description provided for @usernameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ese nombre de usuario no está disponible. Elige otro.'**
  String get usernameTaken;

  /// No description provided for @profileConflict.
  ///
  /// In es, this message translates to:
  /// **'El perfil ha cambiado en otra sesión. Recárgalo antes de guardar.'**
  String get profileConflict;

  /// No description provided for @profileForbidden.
  ///
  /// In es, this message translates to:
  /// **'No puedes editar este perfil. Comprueba tu sesión.'**
  String get profileForbidden;

  /// No description provided for @saveProfile.
  ///
  /// In es, this message translates to:
  /// **'Guardar perfil'**
  String get saveProfile;

  /// No description provided for @reloadProfile.
  ///
  /// In es, this message translates to:
  /// **'Recargar perfil'**
  String get reloadProfile;

  /// No description provided for @profileSaved.
  ///
  /// In es, this message translates to:
  /// **'Perfil guardado.'**
  String get profileSaved;

  /// No description provided for @profileNotFound.
  ///
  /// In es, this message translates to:
  /// **'Este perfil no está disponible.'**
  String get profileNotFound;

  /// No description provided for @profilePhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil'**
  String get profilePhoto;

  /// No description provided for @noPhoto.
  ///
  /// In es, this message translates to:
  /// **'Perfil sin foto'**
  String get noPhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In es, this message translates to:
  /// **'Elegir foto'**
  String get choosePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In es, this message translates to:
  /// **'Quitar foto'**
  String get removePhoto;

  /// No description provided for @photoAfterProfile.
  ///
  /// In es, this message translates to:
  /// **'Guarda primero tu perfil. Después podrás añadir una foto opcional.'**
  String get photoAfterProfile;

  /// No description provided for @invalidPhoto.
  ///
  /// In es, this message translates to:
  /// **'Elige una imagen JPEG, PNG o WebP de hasta 2 MB.'**
  String get invalidPhoto;

  /// No description provided for @photoUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar la foto.'**
  String get photoUnavailable;

  /// No description provided for @loadingPhoto.
  ///
  /// In es, this message translates to:
  /// **'Cargando foto…'**
  String get loadingPhoto;

  /// No description provided for @photoCleanupPending.
  ///
  /// In es, this message translates to:
  /// **'Perfil guardado. La foto anterior dejó de mostrarse; su eliminación está pendiente.'**
  String get photoCleanupPending;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @account.
  ///
  /// In es, this message translates to:
  /// **'Mi cuenta'**
  String get account;

  /// No description provided for @privateEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo de tu cuenta · solo visible para ti'**
  String get privateEmailLabel;

  /// No description provided for @emailUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Correo no disponible'**
  String get emailUnavailable;

  /// No description provided for @accessConfigured.
  ///
  /// In es, this message translates to:
  /// **'El acceso está configurado. Puedes iniciar sesión o crear una cuenta. Si falla, comprueba tu conexión y vuelve a intentarlo.'**
  String get accessConfigured;

  /// No description provided for @findProfile.
  ///
  /// In es, this message translates to:
  /// **'Consultar un perfil'**
  String get findProfile;

  /// No description provided for @findProfileDescription.
  ///
  /// In es, this message translates to:
  /// **'Introduce el nombre de usuario público de la persona que quieres consultar.'**
  String get findProfileDescription;

  /// No description provided for @viewProfile.
  ///
  /// In es, this message translates to:
  /// **'Ver perfil'**
  String get viewProfile;

  /// No description provided for @signOutAndRecover.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión y recuperar contraseña'**
  String get signOutAndRecover;

  /// No description provided for @recipeCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear receta'**
  String get recipeCreate;

  /// No description provided for @recipeEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar receta'**
  String get recipeEdit;

  /// No description provided for @recipeCreatedSection.
  ///
  /// In es, this message translates to:
  /// **'Creadas por mí'**
  String get recipeCreatedSection;

  /// No description provided for @recipeSavedSection.
  ///
  /// In es, this message translates to:
  /// **'Recetas públicas guardadas'**
  String get recipeSavedSection;

  /// No description provided for @recipeSavedLater.
  ///
  /// In es, this message translates to:
  /// **'Aquí aparecerán las recetas que guardes de Comunidad cuando esté disponible.'**
  String get recipeSavedLater;

  /// No description provided for @recipeSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar por título'**
  String get recipeSearch;

  /// No description provided for @recipeCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get recipeCategory;

  /// No description provided for @recipeVisibility.
  ///
  /// In es, this message translates to:
  /// **'Visibilidad'**
  String get recipeVisibility;

  /// No description provided for @recipeAllVisibility.
  ///
  /// In es, this message translates to:
  /// **'Privadas y públicas'**
  String get recipeAllVisibility;

  /// No description provided for @recipeAllCategories.
  ///
  /// In es, this message translates to:
  /// **'Todas las categorías'**
  String get recipeAllCategories;

  /// No description provided for @recipePrivate.
  ///
  /// In es, this message translates to:
  /// **'Privada'**
  String get recipePrivate;

  /// No description provided for @recipePublic.
  ///
  /// In es, this message translates to:
  /// **'Pública'**
  String get recipePublic;

  /// No description provided for @recipeOrderRecent.
  ///
  /// In es, this message translates to:
  /// **'Actualizadas más recientemente'**
  String get recipeOrderRecent;

  /// No description provided for @recipeLoadMore.
  ///
  /// In es, this message translates to:
  /// **'Cargar más recetas'**
  String get recipeLoadMore;

  /// No description provided for @recipeLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando recetas…'**
  String get recipeLoading;

  /// No description provided for @recipeEmpty.
  ///
  /// In es, this message translates to:
  /// **'Un recetario por descubrir'**
  String get recipeEmpty;

  /// No description provided for @recipeEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Crea tu primera receta o cambia los filtros de búsqueda.'**
  String get recipeEmptyHint;

  /// No description provided for @recipeBackendMissing.
  ///
  /// In es, this message translates to:
  /// **'Recetario sin conexión configurada'**
  String get recipeBackendMissing;

  /// No description provided for @recipeBackendMissingHint.
  ///
  /// In es, this message translates to:
  /// **'Configura el servicio de MixTick para gestionar tus recetas.'**
  String get recipeBackendMissingHint;

  /// No description provided for @recipeNeedsProfile.
  ///
  /// In es, this message translates to:
  /// **'Completa tu perfil antes de crear recetas.'**
  String get recipeNeedsProfile;

  /// No description provided for @recipeRetryCategories.
  ///
  /// In es, this message translates to:
  /// **'Reintentar categorías'**
  String get recipeRetryCategories;

  /// No description provided for @recipeNoPhoto.
  ///
  /// In es, this message translates to:
  /// **'Receta sin fotografía'**
  String get recipeNoPhoto;

  /// No description provided for @recipePhoto.
  ///
  /// In es, this message translates to:
  /// **'Fotografía de la receta'**
  String get recipePhoto;

  /// No description provided for @recipeMinutes.
  ///
  /// In es, this message translates to:
  /// **'min'**
  String get recipeMinutes;

  /// No description provided for @recipeTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get recipeTitle;

  /// No description provided for @recipeDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get recipeDescription;

  /// No description provided for @recipeServings.
  ///
  /// In es, this message translates to:
  /// **'Raciones'**
  String get recipeServings;

  /// No description provided for @recipePrep.
  ///
  /// In es, this message translates to:
  /// **'Preparación (min, opcional)'**
  String get recipePrep;

  /// No description provided for @recipeCook.
  ///
  /// In es, this message translates to:
  /// **'Cocción (min, opcional)'**
  String get recipeCook;

  /// No description provided for @recipeBasics.
  ///
  /// In es, this message translates to:
  /// **'Lo esencial'**
  String get recipeBasics;

  /// No description provided for @recipeIngredients.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes'**
  String get recipeIngredients;

  /// No description provided for @recipeSteps.
  ///
  /// In es, this message translates to:
  /// **'Preparación paso a paso'**
  String get recipeSteps;

  /// No description provided for @recipeAddIngredient.
  ///
  /// In es, this message translates to:
  /// **'Añadir ingrediente'**
  String get recipeAddIngredient;

  /// No description provided for @recipeIngredientName.
  ///
  /// In es, this message translates to:
  /// **'Buscar ingrediente o escribir otro'**
  String get recipeIngredientName;

  /// No description provided for @recipeCustomIngredient.
  ///
  /// In es, this message translates to:
  /// **'Usar este nombre fuera del catálogo'**
  String get recipeCustomIngredient;

  /// No description provided for @recipeQuantity.
  ///
  /// In es, this message translates to:
  /// **'Cantidad (opcional)'**
  String get recipeQuantity;

  /// No description provided for @recipeUnit.
  ///
  /// In es, this message translates to:
  /// **'Unidad (opcional)'**
  String get recipeUnit;

  /// No description provided for @recipeUnitHint.
  ///
  /// In es, this message translates to:
  /// **'g, kg, ml, l, ud, cucharada…'**
  String get recipeUnitHint;

  /// No description provided for @recipeOptional.
  ///
  /// In es, this message translates to:
  /// **'Ingrediente opcional'**
  String get recipeOptional;

  /// No description provided for @recipeDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Este ingrediente ya está incluido. Edita su cantidad en la lista.'**
  String get recipeDuplicate;

  /// No description provided for @recipeAddStep.
  ///
  /// In es, this message translates to:
  /// **'Añadir paso'**
  String get recipeAddStep;

  /// No description provided for @recipeStepInstruction.
  ///
  /// In es, this message translates to:
  /// **'Instrucción'**
  String get recipeStepInstruction;

  /// No description provided for @recipeStepUp.
  ///
  /// In es, this message translates to:
  /// **'Subir paso'**
  String get recipeStepUp;

  /// No description provided for @recipeStepDown.
  ///
  /// In es, this message translates to:
  /// **'Bajar paso'**
  String get recipeStepDown;

  /// No description provided for @recipeRemoveIngredient.
  ///
  /// In es, this message translates to:
  /// **'Quitar ingrediente'**
  String get recipeRemoveIngredient;

  /// No description provided for @recipeRemoveStep.
  ///
  /// In es, this message translates to:
  /// **'Eliminar paso'**
  String get recipeRemoveStep;

  /// No description provided for @recipeEditIngredient.
  ///
  /// In es, this message translates to:
  /// **'Editar ingrediente'**
  String get recipeEditIngredient;

  /// No description provided for @recipeCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get recipeCancel;

  /// No description provided for @recipeAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get recipeAdd;

  /// No description provided for @recipeSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar receta'**
  String get recipeSave;

  /// No description provided for @recipeSaving.
  ///
  /// In es, this message translates to:
  /// **'Guardando receta…'**
  String get recipeSaving;

  /// No description provided for @recipeUploading.
  ///
  /// In es, this message translates to:
  /// **'Subiendo fotografía…'**
  String get recipeUploading;

  /// No description provided for @recipeLinking.
  ///
  /// In es, this message translates to:
  /// **'Actualizando fotografía…'**
  String get recipeLinking;

  /// No description provided for @recipeCancelUpload.
  ///
  /// In es, this message translates to:
  /// **'Cancelar subida'**
  String get recipeCancelUpload;

  /// No description provided for @recipeCancelling.
  ///
  /// In es, this message translates to:
  /// **'Cancelando; comprobando el resultado…'**
  String get recipeCancelling;

  /// No description provided for @recipePhotoCancelled.
  ///
  /// In es, this message translates to:
  /// **'Subida cancelada. Los datos de la receta se conservaron.'**
  String get recipePhotoCancelled;

  /// No description provided for @recipeFieldsSaved.
  ///
  /// In es, this message translates to:
  /// **'Los datos se guardaron. Revisa la fotografía y vuelve a guardar para completar el cambio.'**
  String get recipeFieldsSaved;

  /// No description provided for @recipeInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los campos: se necesita al menos un ingrediente y un paso válidos.'**
  String get recipeInvalid;

  /// No description provided for @recipeInvalidText.
  ///
  /// In es, this message translates to:
  /// **'Completa el campo respetando su límite de longitud.'**
  String get recipeInvalidText;

  /// No description provided for @recipeInvalidServings.
  ///
  /// In es, this message translates to:
  /// **'Introduce entre 0,01 y 10.000 raciones, con hasta dos decimales.'**
  String get recipeInvalidServings;

  /// No description provided for @recipeInvalidQuantity.
  ///
  /// In es, this message translates to:
  /// **'Introduce una cantidad positiva de hasta 1.000.000, con hasta tres decimales.'**
  String get recipeInvalidQuantity;

  /// No description provided for @recipeInvalidTime.
  ///
  /// In es, this message translates to:
  /// **'Introduce un número entero entre 0 y 10.080, o deja el campo vacío.'**
  String get recipeInvalidTime;

  /// No description provided for @recipeNetworkError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la operación. Comprueba la conexión; tus cambios siguen en el formulario.'**
  String get recipeNetworkError;

  /// No description provided for @recipeForbidden.
  ///
  /// In es, this message translates to:
  /// **'Esta receta no está disponible para tu cuenta.'**
  String get recipeForbidden;

  /// No description provided for @recipeConflict.
  ///
  /// In es, this message translates to:
  /// **'La receta cambió en otra sesión. Revisa la versión actual antes de guardar tus cambios.'**
  String get recipeConflict;

  /// No description provided for @recipeQuota.
  ///
  /// In es, this message translates to:
  /// **'Has creado varias recetas seguidas. Espera un minuto y vuelve a intentarlo.'**
  String get recipeQuota;

  /// No description provided for @recipeUnexpected.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la operación. Inténtalo de nuevo.'**
  String get recipeUnexpected;

  /// No description provided for @recipeReload.
  ///
  /// In es, this message translates to:
  /// **'Recargar receta'**
  String get recipeReload;

  /// No description provided for @recipeReloadWarning.
  ///
  /// In es, this message translates to:
  /// **'Se cargarán los datos actuales y se descartarán los cambios de este formulario.'**
  String get recipeReloadWarning;

  /// No description provided for @recipeDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar los cambios?'**
  String get recipeDiscardTitle;

  /// No description provided for @recipeDiscardMessage.
  ///
  /// In es, this message translates to:
  /// **'Los cambios que no has guardado se perderán.'**
  String get recipeDiscardMessage;

  /// No description provided for @recipeDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get recipeDiscard;

  /// No description provided for @recipePublish.
  ///
  /// In es, this message translates to:
  /// **'Publicar receta'**
  String get recipePublish;

  /// No description provided for @recipeMakePrivate.
  ///
  /// In es, this message translates to:
  /// **'Hacer privada'**
  String get recipeMakePrivate;

  /// No description provided for @recipePublishInfo.
  ///
  /// In es, this message translates to:
  /// **'Las personas que accedan a MixTick podrán ver la receta, sus ingredientes, pasos y fotografía. Puedes volver a hacerla privada después.'**
  String get recipePublishInfo;

  /// No description provided for @recipePrivateInfo.
  ///
  /// In es, this message translates to:
  /// **'Solo tú podrás consultar la receta. Los accesos nuevos de otras personas se denegarán. Una foto ya descargada o una URL firmada todavía vigente puede conservarse.'**
  String get recipePrivateInfo;

  /// No description provided for @recipeDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar receta'**
  String get recipeDelete;

  /// No description provided for @recipeDeleteInfo.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán la receta y sus relaciones. La fotografía dejará de ser accesible; su limpieza física queda pendiente. Esta acción no se puede deshacer.'**
  String get recipeDeleteInfo;

  /// No description provided for @recipePhotoLifecycle.
  ///
  /// In es, this message translates to:
  /// **'Al sustituir o retirar una foto deja de mostrarse. La limpieza del archivo anterior se procesa por separado.'**
  String get recipePhotoLifecycle;

  /// No description provided for @recipeView.
  ///
  /// In es, this message translates to:
  /// **'Ver receta'**
  String get recipeView;

  /// No description provided for @recipeCatalogLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando catálogo…'**
  String get recipeCatalogLoading;

  /// No description provided for @recipeCatalogError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar el catálogo. Reintenta para seleccionar ingredientes normalizados.'**
  String get recipeCatalogError;

  /// No description provided for @recipeAtLeastOneIngredient.
  ///
  /// In es, this message translates to:
  /// **'Añade al menos un ingrediente.'**
  String get recipeAtLeastOneIngredient;

  /// No description provided for @recipeAtLeastOneStep.
  ///
  /// In es, this message translates to:
  /// **'Añade al menos un paso.'**
  String get recipeAtLeastOneStep;

  /// No description provided for @recipeLimitReached.
  ///
  /// In es, this message translates to:
  /// **'Puedes incluir hasta 100 ingredientes y 100 pasos.'**
  String get recipeLimitReached;

  /// No description provided for @communityChronological.
  ///
  /// In es, this message translates to:
  /// **'Recetas de nuestra comunidad, por orden de publicación.'**
  String get communityChronological;

  /// No description provided for @communitySearch.
  ///
  /// In es, this message translates to:
  /// **'Busca por título, categoría o ingrediente'**
  String get communitySearch;

  /// No description provided for @communitySearchCoverage.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes: nombre completo del catálogo o sus alias; texto libre por nombre exacto, sin distinguir tildes o mayúsculas.'**
  String get communitySearchCoverage;

  /// No description provided for @communityLikes.
  ///
  /// In es, this message translates to:
  /// **'me gusta'**
  String get communityLikes;

  /// No description provided for @communityComments.
  ///
  /// In es, this message translates to:
  /// **'Comentarios'**
  String get communityComments;

  /// No description provided for @communitySave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get communitySave;

  /// No description provided for @communitySaved.
  ///
  /// In es, this message translates to:
  /// **'Guardada'**
  String get communitySaved;

  /// No description provided for @communitySavedInfo.
  ///
  /// In es, this message translates to:
  /// **'Referencias a las recetas originales. Su autoría y sus permisos se conservan.'**
  String get communitySavedInfo;

  /// No description provided for @communitySavedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Guarda recetas de otros autores desde Comunidad. Solo aparecerán las que sigan siendo públicas y accesibles.'**
  String get communitySavedEmpty;

  /// No description provided for @communityLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando comunidad…'**
  String get communityLoading;

  /// No description provided for @communityEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay recetas para mostrar'**
  String get communityEmpty;

  /// No description provided for @communityEmptyInfo.
  ///
  /// In es, this message translates to:
  /// **'Prueba otra búsqueda o vuelve más adelante para descubrir recetas publicadas.'**
  String get communityEmptyInfo;

  /// No description provided for @communityUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Este contenido ya no está disponible o no tienes permiso para consultarlo.'**
  String get communityUnavailable;

  /// No description provided for @communityInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos antes de volver a intentarlo.'**
  String get communityInvalid;

  /// No description provided for @communityQuota.
  ///
  /// In es, this message translates to:
  /// **'Has enviado varias solicitudes. Espera un minuto antes de intentarlo de nuevo.'**
  String get communityQuota;

  /// No description provided for @communityConflict.
  ///
  /// In es, this message translates to:
  /// **'La solicitud tiene otro contenido. Recarga para comprobar lo que se ha guardado.'**
  String get communityConflict;

  /// No description provided for @communityFollow.
  ///
  /// In es, this message translates to:
  /// **'Seguir autor'**
  String get communityFollow;

  /// No description provided for @communityUnfollow.
  ///
  /// In es, this message translates to:
  /// **'Dejar de seguir'**
  String get communityUnfollow;

  /// No description provided for @communityFollowers.
  ///
  /// In es, this message translates to:
  /// **'seguidores'**
  String get communityFollowers;

  /// No description provided for @communityFollowing.
  ///
  /// In es, this message translates to:
  /// **'seguidos'**
  String get communityFollowing;

  /// No description provided for @communityAuthorRecipes.
  ///
  /// In es, this message translates to:
  /// **'Recetas públicas'**
  String get communityAuthorRecipes;

  /// No description provided for @communityWriteComment.
  ///
  /// In es, this message translates to:
  /// **'Escribe un comentario'**
  String get communityWriteComment;

  /// No description provided for @communityCommentInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe entre 1 y 2000 caracteres, además de espacios.'**
  String get communityCommentInvalid;

  /// No description provided for @communitySendComment.
  ///
  /// In es, this message translates to:
  /// **'Publicar comentario'**
  String get communitySendComment;

  /// No description provided for @communityNoComments.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay comentarios. Puedes ser la primera persona en comentar.'**
  String get communityNoComments;

  /// No description provided for @communityDeleteComment.
  ///
  /// In es, this message translates to:
  /// **'Eliminar comentario'**
  String get communityDeleteComment;

  /// No description provided for @communityDeleteCommentInfo.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará tu comentario. Esta acción no se puede deshacer.'**
  String get communityDeleteCommentInfo;

  /// No description provided for @communityReport.
  ///
  /// In es, this message translates to:
  /// **'Denunciar'**
  String get communityReport;

  /// No description provided for @communityReportRecipe.
  ///
  /// In es, this message translates to:
  /// **'Denunciar receta'**
  String get communityReportRecipe;

  /// No description provided for @communityReportReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo de la denuncia'**
  String get communityReportReason;

  /// No description provided for @communityReasonSpam.
  ///
  /// In es, this message translates to:
  /// **'Publicidad o spam repetido'**
  String get communityReasonSpam;

  /// No description provided for @communityReasonAbuse.
  ///
  /// In es, this message translates to:
  /// **'Acoso o contenido ofensivo'**
  String get communityReasonAbuse;

  /// No description provided for @communityReasonDanger.
  ///
  /// In es, this message translates to:
  /// **'Contenido peligroso o engañoso'**
  String get communityReasonDanger;

  /// No description provided for @communityReasonRights.
  ///
  /// In es, this message translates to:
  /// **'Vulneración de derechos de autor'**
  String get communityReasonRights;

  /// No description provided for @communitySendReport.
  ///
  /// In es, this message translates to:
  /// **'Enviar denuncia'**
  String get communitySendReport;

  /// No description provided for @communityReportSent.
  ///
  /// In es, this message translates to:
  /// **'Denuncia enviada'**
  String get communityReportSent;

  /// No description provided for @communityReportSentInfo.
  ///
  /// In es, this message translates to:
  /// **'Tu denuncia se ha registrado. Gracias por ayudarnos a cuidar la comunidad.'**
  String get communityReportSentInfo;

  /// No description provided for @communityClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get communityClose;

  /// No description provided for @communityBlock.
  ///
  /// In es, this message translates to:
  /// **'Bloquear cuenta'**
  String get communityBlock;

  /// No description provided for @communityBlockInfo.
  ///
  /// In es, this message translates to:
  /// **'Sus recetas, perfil e interacciones dejarán de ser accesibles entre ambas cuentas. Puedes desbloquearla desde Comunidad.'**
  String get communityBlockInfo;

  /// No description provided for @communityUnblock.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear cuenta'**
  String get communityUnblock;

  /// No description provided for @communityBlocked.
  ///
  /// In es, this message translates to:
  /// **'Cuentas bloqueadas'**
  String get communityBlocked;

  /// No description provided for @communityNoBlocks.
  ///
  /// In es, this message translates to:
  /// **'No tienes cuentas bloqueadas'**
  String get communityNoBlocks;

  /// No description provided for @communityBlockedAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta bloqueada'**
  String get communityBlockedAccount;

  /// No description provided for @communityBlockPrivacy.
  ///
  /// In es, this message translates to:
  /// **'El perfil está oculto por el bloqueo. Puedes retirar tu bloqueo aquí.'**
  String get communityBlockPrivacy;

  /// No description provided for @communitySavedOpen.
  ///
  /// In es, this message translates to:
  /// **'Ver recetas guardadas'**
  String get communitySavedOpen;

  /// No description provided for @communitySavedTab.
  ///
  /// In es, this message translates to:
  /// **'Guardadas'**
  String get communitySavedTab;

  /// No description provided for @communityNeedsProfile.
  ///
  /// In es, this message translates to:
  /// **'Completa tu perfil para guardar recetas y participar en la comunidad.'**
  String get communityNeedsProfile;

  /// No description provided for @communityCommentsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 comentario} other{{count} comentarios}}'**
  String communityCommentsCount(int count);
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
