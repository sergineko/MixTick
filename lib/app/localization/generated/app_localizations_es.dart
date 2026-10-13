// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'MixTick';

  @override
  String get tagline => 'Cocina, comparte y marca tu compra.';

  @override
  String get accessTitle => 'Tu cocina, en un solo lugar';

  @override
  String get accessDescription =>
      'Descubre recetas, reúne tus favoritas y organiza la compra con las personas que tú elijas.';

  @override
  String get accessRequired =>
      'Necesitas una cuenta para acceder a tus cuatro espacios.';

  @override
  String get accessPending =>
      'El acceso con tu cuenta estará disponible próximamente.';

  @override
  String get accessStatusAction => 'Consultar estado del acceso';

  @override
  String get accessStatusTitle => 'Acceso a MixTick';

  @override
  String get serviceUnavailable =>
      'El servicio de acceso todavía no está disponible. Vuelve a intentarlo más adelante.';

  @override
  String get accessNotEnabled =>
      'Todavía no puedes iniciar sesión. Vuelve a intentarlo más adelante.';

  @override
  String get sessionError =>
      'No pudimos comprobar tu sesión. Vuelve al acceso e inténtalo de nuevo.';

  @override
  String get checkingSession => 'Comprobando tu sesión…';

  @override
  String get backToAccess => 'Volver al acceso';

  @override
  String get community => 'Comunidad';

  @override
  String get recipes => 'Mi recetario';

  @override
  String get cookToday => '¿Qué cocino hoy?';

  @override
  String get cookTodayNav => '¿Qué cocino?';

  @override
  String get shopping => 'Lista de compra';

  @override
  String get shoppingNav => 'Compra';

  @override
  String get profile => 'Mi perfil';

  @override
  String get profileDescription =>
      'Aquí podrás gestionar tu perfil y los ajustes de tu cuenta.';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get communityTitle => 'Recetas para compartir';

  @override
  String get communityDescription =>
      'Aquí podrás descubrir las recetas públicas de la comunidad.';

  @override
  String get recipesTitle => 'Tus recetas, a tu manera';

  @override
  String get recipesDescription =>
      'Aquí reunirás las recetas creadas por ti y tus recetas públicas guardadas.';

  @override
  String get recipesPrivacy =>
      'Tus nuevas recetas serán privadas. Publicarlas será siempre una decisión tuya.';

  @override
  String get cookTodayTitle => 'Empieza por tus ingredientes';

  @override
  String get cookTodayDescription =>
      'Elige ingredientes durante la consulta para encontrar recetas que coincidan.';

  @override
  String get cookTodayNotice =>
      'La selección será temporal. No se comprobarán cantidades disponibles.';

  @override
  String get shoppingTitle => 'La compra, bien organizada';

  @override
  String get shoppingDescription =>
      'Aquí podrás organizar tus listas y compartirlas mediante invitación aceptada.';

  @override
  String get routeNotFound => 'No encontramos esa pantalla.';

  @override
  String get goHome => 'Ir a Comunidad';
}

/// The translations for Spanish Castilian, as used in Spain (`es_ES`).
class AppLocalizationsEsEs extends AppLocalizationsEs {
  AppLocalizationsEsEs() : super('es_ES');
}
