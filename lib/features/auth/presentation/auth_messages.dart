import '../../../app/localization/generated/app_localizations.dart';
import '../domain/auth_failure.dart';

String authFailureMessage(AppLocalizations s, AuthFailureCode code) =>
    switch (code) {
      AuthFailureCode.network => s.networkError,
      AuthFailureCode.credentials => s.credentialsError,
      AuthFailureCode.confirmationRequired => s.confirmationNeeded,
      AuthFailureCode.weakPassword => s.passwordPolicyError,
      AuthFailureCode.rateLimited => s.rateLimitError,
      AuthFailureCode.sessionExpired => s.expiredSession,
      AuthFailureCode.invalidLink => s.invalidAuthLink,
      AuthFailureCode.unavailable => s.serviceUnavailable,
      AuthFailureCode.unexpected => s.operationError,
    };
