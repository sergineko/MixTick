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

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Crear cuenta';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get repeatPassword => 'Repite la contraseña';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get savePassword => 'Guardar contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get invalidEmail => 'Introduce un correo electrónico válido.';

  @override
  String get invalidPassword => 'Usa entre 8 y 128 caracteres.';

  @override
  String get passwordHint =>
      'Al menos 8 caracteres. Evita contraseñas fáciles de adivinar.';

  @override
  String get passwordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get requiredField => 'Completa este campo.';

  @override
  String get recoverPassword => 'Recuperar contraseña';

  @override
  String get forgotPassword => 'He olvidado mi contraseña';

  @override
  String get sendRecovery => 'Enviar instrucciones';

  @override
  String get recoveryDescription =>
      'Te enviaremos un enlace para elegir una nueva contraseña. Ábrelo en este mismo dispositivo.';

  @override
  String get recoverySent =>
      'Si el correo corresponde a una cuenta, recibirás las instrucciones. Revisa también el correo no deseado.';

  @override
  String get recoveryLinkNeeded =>
      'Abre el enlace de recuperación recibido en este dispositivo. Si ha caducado, solicita otro.';

  @override
  String get registrationDescription =>
      'Crea tu cuenta. Si la confirmación de correo está activada, tendrás que verificarlo antes de entrar.';

  @override
  String get confirmEmail => 'Revisa tu correo';

  @override
  String get confirmationSent =>
      'Si el correo puede registrarse, recibirás un enlace de confirmación. Si ya tienes cuenta, inicia sesión o recupera la contraseña.';

  @override
  String get resendEmail => 'Reenviar confirmación';

  @override
  String get confirmationNeeded =>
      'Confirma tu correo antes de iniciar sesión. Puedes revisar o reenviar la confirmación desde Crear cuenta.';

  @override
  String get passwordUpdated => 'Contraseña actualizada.';

  @override
  String get processing => 'Procesando…';

  @override
  String get networkError =>
      'No pudimos conectar. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get credentialsError =>
      'No pudimos iniciar sesión con esos datos. Revisa el correo y la contraseña.';

  @override
  String get passwordPolicyError =>
      'La contraseña no cumple la política del servicio. Elige una más segura.';

  @override
  String get rateLimitError =>
      'Hay demasiadas solicitudes. Espera un momento antes de volver a intentarlo.';

  @override
  String get expiredSession =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión.';

  @override
  String get invalidAuthLink =>
      'El enlace no es válido, ha caducado o pertenece a otro dispositivo. Solicita uno nuevo.';

  @override
  String get operationError =>
      'No pudimos completar la operación. Vuelve a intentarlo.';

  @override
  String get loadingProfile => 'Cargando perfil…';

  @override
  String get completeProfile => 'Completa tu perfil público';

  @override
  String get createProfile => 'Crear mi perfil';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get publicProfile => 'Perfil público';

  @override
  String get viewPublicProfile => 'Ver mi perfil público';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get usernameHint =>
      'De 3 a 30 letras a–z, números o guion bajo. Se guarda en minúsculas.';

  @override
  String get invalidUsername =>
      'Usa de 3 a 30 letras a–z, números o guion bajo.';

  @override
  String get invalidDisplayName =>
      'Introduce un nombre visible de 1 a 60 caracteres.';

  @override
  String get usernameTaken =>
      'Ese nombre de usuario no está disponible. Elige otro.';

  @override
  String get profileConflict =>
      'El perfil ha cambiado en otra sesión. Recárgalo antes de guardar.';

  @override
  String get profileForbidden =>
      'No puedes editar este perfil. Comprueba tu sesión.';

  @override
  String get saveProfile => 'Guardar perfil';

  @override
  String get reloadProfile => 'Recargar perfil';

  @override
  String get profileSaved => 'Perfil guardado.';

  @override
  String get profileNotFound => 'Este perfil no está disponible.';

  @override
  String get profilePhoto => 'Foto de perfil';

  @override
  String get noPhoto => 'Perfil sin foto';

  @override
  String get choosePhoto => 'Elegir foto';

  @override
  String get removePhoto => 'Quitar foto';

  @override
  String get photoAfterProfile =>
      'Guarda primero tu perfil. Después podrás añadir una foto opcional.';

  @override
  String get invalidPhoto => 'Elige una imagen JPEG, PNG o WebP de hasta 2 MB.';

  @override
  String get photoUnavailable => 'No pudimos cargar la foto.';

  @override
  String get loadingPhoto => 'Cargando foto…';

  @override
  String get photoCleanupPending =>
      'Perfil guardado. La foto anterior dejó de mostrarse; su eliminación está pendiente.';

  @override
  String get retry => 'Reintentar';

  @override
  String get account => 'Mi cuenta';

  @override
  String get privateEmailLabel => 'Correo de tu cuenta · solo visible para ti';

  @override
  String get emailUnavailable => 'Correo no disponible';

  @override
  String get accessConfigured =>
      'El acceso está configurado. Puedes iniciar sesión o crear una cuenta. Si falla, comprueba tu conexión y vuelve a intentarlo.';

  @override
  String get findProfile => 'Consultar un perfil';

  @override
  String get findProfileDescription =>
      'Introduce el nombre de usuario público de la persona que quieres consultar.';

  @override
  String get viewProfile => 'Ver perfil';

  @override
  String get signOutAndRecover => 'Cerrar sesión y recuperar contraseña';
}

/// The translations for Spanish Castilian, as used in Spain (`es_ES`).
class AppLocalizationsEsEs extends AppLocalizationsEs {
  AppLocalizationsEsEs() : super('es_ES');
}
