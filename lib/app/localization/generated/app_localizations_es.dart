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

  @override
  String get recipeCreate => 'Crear receta';

  @override
  String get recipeEdit => 'Editar receta';

  @override
  String get recipeCreatedSection => 'Creadas por mí';

  @override
  String get recipeSavedSection => 'Recetas públicas guardadas';

  @override
  String get recipeSavedLater =>
      'Aquí aparecerán las recetas que guardes de Comunidad cuando esté disponible.';

  @override
  String get recipeSearch => 'Buscar por título';

  @override
  String get recipeCategory => 'Categoría';

  @override
  String get recipeVisibility => 'Visibilidad';

  @override
  String get recipeAllVisibility => 'Privadas y públicas';

  @override
  String get recipeAllCategories => 'Todas las categorías';

  @override
  String get recipePrivate => 'Privada';

  @override
  String get recipePublic => 'Pública';

  @override
  String get recipeOrderRecent => 'Actualizadas más recientemente';

  @override
  String get recipeLoadMore => 'Cargar más recetas';

  @override
  String get recipeLoading => 'Cargando recetas…';

  @override
  String get recipeEmpty => 'Un recetario por descubrir';

  @override
  String get recipeEmptyHint =>
      'Crea tu primera receta o cambia los filtros de búsqueda.';

  @override
  String get recipeBackendMissing => 'Recetario sin conexión configurada';

  @override
  String get recipeBackendMissingHint =>
      'Configura el servicio de MixTick para gestionar tus recetas.';

  @override
  String get recipeNeedsProfile => 'Completa tu perfil antes de crear recetas.';

  @override
  String get recipeRetryCategories => 'Reintentar categorías';

  @override
  String get recipeNoPhoto => 'Receta sin fotografía';

  @override
  String get recipePhoto => 'Fotografía de la receta';

  @override
  String get recipeMinutes => 'min';

  @override
  String get recipeTitle => 'Título';

  @override
  String get recipeDescription => 'Descripción (opcional)';

  @override
  String get recipeServings => 'Raciones';

  @override
  String get recipePrep => 'Preparación (min, opcional)';

  @override
  String get recipeCook => 'Cocción (min, opcional)';

  @override
  String get recipeBasics => 'Lo esencial';

  @override
  String get recipeIngredients => 'Ingredientes';

  @override
  String get recipeSteps => 'Preparación paso a paso';

  @override
  String get recipeAddIngredient => 'Añadir ingrediente';

  @override
  String get recipeIngredientName => 'Buscar ingrediente o escribir otro';

  @override
  String get recipeCustomIngredient => 'Usar este nombre fuera del catálogo';

  @override
  String get recipeQuantity => 'Cantidad (opcional)';

  @override
  String get recipeUnit => 'Unidad (opcional)';

  @override
  String get recipeUnitHint => 'g, kg, ml, l, ud, cucharada…';

  @override
  String get recipeOptional => 'Ingrediente opcional';

  @override
  String get recipeDuplicate =>
      'Este ingrediente ya está incluido. Edita su cantidad en la lista.';

  @override
  String get recipeAddStep => 'Añadir paso';

  @override
  String get recipeStepInstruction => 'Instrucción';

  @override
  String get recipeStepUp => 'Subir paso';

  @override
  String get recipeStepDown => 'Bajar paso';

  @override
  String get recipeRemoveIngredient => 'Quitar ingrediente';

  @override
  String get recipeRemoveStep => 'Eliminar paso';

  @override
  String get recipeEditIngredient => 'Editar ingrediente';

  @override
  String get recipeCancel => 'Cancelar';

  @override
  String get recipeAdd => 'Añadir';

  @override
  String get recipeSave => 'Guardar receta';

  @override
  String get recipeSaving => 'Guardando receta…';

  @override
  String get recipeUploading => 'Subiendo fotografía…';

  @override
  String get recipeLinking => 'Actualizando fotografía…';

  @override
  String get recipeCancelUpload => 'Cancelar subida';

  @override
  String get recipeCancelling => 'Cancelando; comprobando el resultado…';

  @override
  String get recipePhotoCancelled =>
      'Subida cancelada. Los datos de la receta se conservaron.';

  @override
  String get recipeFieldsSaved =>
      'Los datos se guardaron. Revisa la fotografía y vuelve a guardar para completar el cambio.';

  @override
  String get recipeInvalid =>
      'Revisa los campos: se necesita al menos un ingrediente y un paso válidos.';

  @override
  String get recipeInvalidText =>
      'Completa el campo respetando su límite de longitud.';

  @override
  String get recipeInvalidServings =>
      'Introduce entre 0,01 y 10.000 raciones, con hasta dos decimales.';

  @override
  String get recipeInvalidQuantity =>
      'Introduce una cantidad positiva de hasta 1.000.000, con hasta tres decimales.';

  @override
  String get recipeInvalidTime =>
      'Introduce un número entero entre 0 y 10.080, o deja el campo vacío.';

  @override
  String get recipeNetworkError =>
      'No pudimos completar la operación. Comprueba la conexión; tus cambios siguen en el formulario.';

  @override
  String get recipeForbidden =>
      'Esta receta no está disponible para tu cuenta.';

  @override
  String get recipeConflict =>
      'La receta cambió en otra sesión. Revisa la versión actual antes de guardar tus cambios.';

  @override
  String get recipeQuota =>
      'Has creado varias recetas seguidas. Espera un minuto y vuelve a intentarlo.';

  @override
  String get recipeUnexpected =>
      'No pudimos completar la operación. Inténtalo de nuevo.';

  @override
  String get recipeReload => 'Recargar receta';

  @override
  String get recipeReloadWarning =>
      'Se cargarán los datos actuales y se descartarán los cambios de este formulario.';

  @override
  String get recipeDiscardTitle => '¿Descartar los cambios?';

  @override
  String get recipeDiscardMessage =>
      'Los cambios que no has guardado se perderán.';

  @override
  String get recipeDiscard => 'Descartar';

  @override
  String get recipePublish => 'Publicar receta';

  @override
  String get recipeMakePrivate => 'Hacer privada';

  @override
  String get recipePublishInfo =>
      'Las personas que accedan a MixTick podrán ver la receta, sus ingredientes, pasos y fotografía. Puedes volver a hacerla privada después.';

  @override
  String get recipePrivateInfo =>
      'Solo tú podrás consultar la receta. Los accesos nuevos de otras personas se denegarán. Una foto ya descargada o una URL firmada todavía vigente puede conservarse.';

  @override
  String get recipeDelete => 'Eliminar receta';

  @override
  String get recipeDeleteInfo =>
      'Se eliminarán la receta y sus relaciones. La fotografía dejará de ser accesible; su limpieza física queda pendiente. Esta acción no se puede deshacer.';

  @override
  String get recipePhotoLifecycle =>
      'Al sustituir o retirar una foto deja de mostrarse. La limpieza del archivo anterior se procesa por separado.';

  @override
  String get recipeView => 'Ver receta';

  @override
  String get recipeCatalogLoading => 'Cargando catálogo…';

  @override
  String get recipeCatalogError =>
      'No pudimos cargar el catálogo. Reintenta para seleccionar ingredientes normalizados.';

  @override
  String get recipeAtLeastOneIngredient => 'Añade al menos un ingrediente.';

  @override
  String get recipeAtLeastOneStep => 'Añade al menos un paso.';

  @override
  String get recipeLimitReached =>
      'Puedes incluir hasta 100 ingredientes y 100 pasos.';

  @override
  String get communityChronological =>
      'Recetas de nuestra comunidad, por orden de publicación.';

  @override
  String get communitySearch => 'Busca por título, categoría o ingrediente';

  @override
  String get communitySearchCoverage =>
      'Ingredientes: nombre completo del catálogo o sus alias; texto libre por nombre exacto, sin distinguir tildes o mayúsculas.';

  @override
  String get communityLikes => 'me gusta';

  @override
  String get communityComments => 'Comentarios';

  @override
  String get communitySave => 'Guardar';

  @override
  String get communitySaved => 'Guardada';

  @override
  String get communitySavedInfo =>
      'Referencias a las recetas originales. Su autoría y sus permisos se conservan.';

  @override
  String get communitySavedEmpty =>
      'Guarda recetas de otros autores desde Comunidad. Solo aparecerán las que sigan siendo públicas y accesibles.';

  @override
  String get communityLoading => 'Cargando comunidad…';

  @override
  String get communityEmpty => 'No hay recetas para mostrar';

  @override
  String get communityEmptyInfo =>
      'Prueba otra búsqueda o vuelve más adelante para descubrir recetas publicadas.';

  @override
  String get communityUnavailable =>
      'Este contenido ya no está disponible o no tienes permiso para consultarlo.';

  @override
  String get communityInvalid =>
      'Revisa los datos antes de volver a intentarlo.';

  @override
  String get communityQuota =>
      'Has enviado varias solicitudes. Espera un minuto antes de intentarlo de nuevo.';

  @override
  String get communityConflict =>
      'La solicitud tiene otro contenido. Recarga para comprobar lo que se ha guardado.';

  @override
  String get communityFollow => 'Seguir autor';

  @override
  String get communityUnfollow => 'Dejar de seguir';

  @override
  String get communityFollowers => 'seguidores';

  @override
  String get communityFollowing => 'seguidos';

  @override
  String get communityAuthorRecipes => 'Recetas públicas';

  @override
  String get communityWriteComment => 'Escribe un comentario';

  @override
  String get communityCommentInvalid =>
      'Escribe entre 1 y 2000 caracteres, además de espacios.';

  @override
  String get communitySendComment => 'Publicar comentario';

  @override
  String get communityNoComments =>
      'Todavía no hay comentarios. Puedes ser la primera persona en comentar.';

  @override
  String get communityDeleteComment => 'Eliminar comentario';

  @override
  String get communityDeleteCommentInfo =>
      'Se eliminará tu comentario. Esta acción no se puede deshacer.';

  @override
  String get communityReport => 'Denunciar';

  @override
  String get communityReportRecipe => 'Denunciar receta';

  @override
  String get communityReportReason => 'Motivo de la denuncia';

  @override
  String get communityReasonSpam => 'Publicidad o spam repetido';

  @override
  String get communityReasonAbuse => 'Acoso o contenido ofensivo';

  @override
  String get communityReasonDanger => 'Contenido peligroso o engañoso';

  @override
  String get communityReasonRights => 'Vulneración de derechos de autor';

  @override
  String get communitySendReport => 'Enviar denuncia';

  @override
  String get communityReportSent => 'Denuncia enviada';

  @override
  String get communityReportSentInfo =>
      'Tu denuncia se ha registrado. Gracias por ayudarnos a cuidar la comunidad.';

  @override
  String get communityClose => 'Cerrar';

  @override
  String get communityBlock => 'Bloquear cuenta';

  @override
  String get communityBlockInfo =>
      'Sus recetas, perfil e interacciones dejarán de ser accesibles entre ambas cuentas. Puedes desbloquearla desde Comunidad.';

  @override
  String get communityUnblock => 'Desbloquear cuenta';

  @override
  String get communityBlocked => 'Cuentas bloqueadas';

  @override
  String get communityNoBlocks => 'No tienes cuentas bloqueadas';

  @override
  String get communityBlockedAccount => 'Cuenta bloqueada';

  @override
  String get communityBlockPrivacy =>
      'El perfil está oculto por el bloqueo. Puedes retirar tu bloqueo aquí.';

  @override
  String get communitySavedOpen => 'Ver recetas guardadas';

  @override
  String get communitySavedTab => 'Guardadas';

  @override
  String get communityNeedsProfile =>
      'Completa tu perfil para guardar recetas y participar en la comunidad.';

  @override
  String communityCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentarios',
      one: '1 comentario',
    );
    return '$_temp0';
  }
}

/// The translations for Spanish Castilian, as used in Spain (`es_ES`).
class AppLocalizationsEsEs extends AppLocalizationsEs {
  AppLocalizationsEsEs() : super('es_ES');
}
