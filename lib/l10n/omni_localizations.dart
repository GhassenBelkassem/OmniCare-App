import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'omni_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of OmniLocalizations
/// returned by `OmniLocalizations.of(context)`.
///
/// Applications need to include `OmniLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/omni_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: OmniLocalizations.localizationsDelegates,
///   supportedLocales: OmniLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the OmniLocalizations.supportedLocales
/// property.
abstract class OmniLocalizations {
  OmniLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static OmniLocalizations of(BuildContext context) {
    return Localizations.of<OmniLocalizations>(context, OmniLocalizations)!;
  }

  static const LocalizationsDelegate<OmniLocalizations> delegate =
      _OmniLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// Old home screen (unreachable): specialty filter, all specialties.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les Spécialités'**
  String get allSpecialties;

  /// Old home screen (unreachable): doctor grid title.
  ///
  /// In fr, this message translates to:
  /// **'Médecins Disponibles'**
  String get availableDoctors;

  /// Old home screen (unreachable): demo pharmacy locality.
  ///
  /// In fr, this message translates to:
  /// **'Ben Arous'**
  String get benArous;

  /// Old home screen (unreachable): hero button.
  ///
  /// In fr, this message translates to:
  /// **'Appeler une Ambulance'**
  String get callAmbulance;

  /// Old home screen (unreachable): specialty filter.
  ///
  /// In fr, this message translates to:
  /// **'Cardiologie'**
  String get cardiology;

  /// Language selection screen (unreachable): title.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez Votre Langue'**
  String get chooseLanguage;

  /// Reset password screen: confirmation field is empty.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez confirmer votre mot de passe'**
  String get confirmPasswordRequired;

  /// Old home screen (unreachable): specialty filter.
  ///
  /// In fr, this message translates to:
  /// **'Dermatologie'**
  String get dermatology;

  /// Forgot password screen (unreachable): field label.
  ///
  /// In fr, this message translates to:
  /// **'Email ou Numéro de Téléphone'**
  String get emailOrPhone;

  /// Forgot password screen (unreachable): field hint.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre email ou numéro de téléphone'**
  String get emailOrPhoneHint;

  /// Forgot password screen (unreachable): field is empty.
  ///
  /// In fr, this message translates to:
  /// **'Email ou numéro de téléphone requis'**
  String get emailOrPhoneRequired;

  /// Old home screen (unreachable): search section title.
  ///
  /// In fr, this message translates to:
  /// **'Trouver un Médecin'**
  String get findDoctor;

  /// Old home screen (unreachable): specialty filter.
  ///
  /// In fr, this message translates to:
  /// **'Médecine Générale'**
  String get generalMedicine;

  /// Old home screen (unreachable): hero subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous avec des médecins vérifiés en Tunisie. Obtenez une assistance médicale urgente à tout moment, n\'importe où.'**
  String get heroSubtitle;

  /// Old home screen (unreachable): distance unit after a number.
  ///
  /// In fr, this message translates to:
  /// **'km'**
  String get kmAway;

  /// Old home screen (unreachable): demo pharmacy locality.
  ///
  /// In fr, this message translates to:
  /// **'Lac 2'**
  String get lac2;

  /// Old home screen (unreachable): hero title.
  ///
  /// In fr, this message translates to:
  /// **'Soins Médicaux à la Demande'**
  String get medicalCareOnDemand;

  /// Old home screen (unreachable): sidebar card title.
  ///
  /// In fr, this message translates to:
  /// **'Passeport Médical'**
  String get medicalPassport;

  /// Old home screen (unreachable): sidebar card subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre historique médical complet en un seul endroit'**
  String get medicalPassportDesc;

  /// Old home screen (unreachable): demo pharmacy opening hours.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert 24/7 - Aujourd\'hui'**
  String get open247Today;

  /// Old home screen (unreachable): specialty filter.
  ///
  /// In fr, this message translates to:
  /// **'Orthopédie'**
  String get orthopedics;

  /// Reset password screen: new password field is empty.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe est requis'**
  String get passwordRequired;

  /// Reset password screen: the two passwords differ.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get passwordsNotMatch;

  /// Old home screen (unreachable): specialty filter.
  ///
  /// In fr, this message translates to:
  /// **'Pédiatrie'**
  String get pediatrics;

  /// Old home screen (unreachable): demo pharmacy name.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie Ben Arous'**
  String get pharmacieBenArous;

  /// Old home screen (unreachable): demo pharmacy name.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie Centrale'**
  String get pharmacieCentrale;

  /// Old home screen (unreachable): on-duty pharmacy card title.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie de Garde'**
  String get pharmacieDeGarde;

  /// Old home screen (unreachable): demo pharmacy name.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie du Lac'**
  String get pharmacieDuLac;

  /// Old home screen (unreachable): hero button.
  ///
  /// In fr, this message translates to:
  /// **'Demander un Médecin Urgent'**
  String get requestUrgentDoctor;

  /// Old home screen (unreachable): doctor card button.
  ///
  /// In fr, this message translates to:
  /// **'Demander une Visite'**
  String get requestVisit;

  /// Forgot password screen (unreachable): title.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get resetPassword;

  /// Forgot password screen (unreachable): subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre email ou numéro de téléphone pour recevoir un code de vérification'**
  String get resetPasswordSubtitle;

  /// Old home screen (unreachable): search field hint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des médecins...'**
  String get searchDoctors;

  /// Language selection screen (unreachable): subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre langue préférée'**
  String get selectLanguage;

  /// Forgot password screen (unreachable): submit button.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get sendCode;

  /// Old home screen (unreachable): hero button.
  ///
  /// In fr, this message translates to:
  /// **'Parler à un Psychologue'**
  String get talkPsychologist;

  /// Old home screen (unreachable): demo pharmacy locality.
  ///
  /// In fr, this message translates to:
  /// **'Centre de Tunis'**
  String get tunisCenter;

  /// Old home screen (unreachable): medical passport card link.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'Historique Complet'**
  String get viewFullHistory;

  /// Old home screen (unreachable): pharmacy card button.
  ///
  /// In fr, this message translates to:
  /// **'Voir sur la Carte'**
  String get viewOnMap;

  /// Old home screen (unreachable): after the number of years on a doctor card.
  ///
  /// In fr, this message translates to:
  /// **'ans d\'expérience'**
  String get yearsExperience;

  /// Blood type choice when the patient does not know it (onboarding tiles, medical data). G2-1a-2.
  ///
  /// In fr, this message translates to:
  /// **'Je ne sais pas'**
  String get bloodTypeUnknown;

  /// Save failed: the server rejected the values (INVALID_INPUT / VALIDATION_ERROR). G2-1a-2.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations ne sont pas valides. Vérifiez et réessayez.'**
  String get saveInvalidInput;

  /// Save failed: no network. G2-1a-2.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Réessayez.'**
  String get saveNetwork;

  /// Save failed: the medical record service is down (MRS_UNAVAILABLE or 5xx). G2-1a-2.
  ///
  /// In fr, this message translates to:
  /// **'Service momentanément indisponible. Réessayez plus tard.'**
  String get saveServiceUnavailable;

  /// Save failed for any other reason. G2-1a-2.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible pour le moment. Réessayez.'**
  String get saveGeneric;

  /// Onboarding Continue could not save the page. G2-1a-6.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer. Vérifiez votre connexion et réessayez.'**
  String get onboardingSaveFailed;

  /// Urgent cabinet request not available to this patient: title on doctor search and doctor detail. G2-1a-3 (C9).
  ///
  /// In fr, this message translates to:
  /// **'Service indisponible'**
  String get urgentCabinetUnavailableTitle;

  /// Urgent cabinet request not available to this patient: message. G2-1a-3 (C9).
  ///
  /// In fr, this message translates to:
  /// **'La demande urgente au cabinet n’est pas disponible pour le moment.'**
  String get urgentCabinetUnavailableMessage;

  /// Request status NO_SHOW: status chip, status card title and end of the journey. G2-1a-4 (C10).
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous manqué'**
  String get requestNoShowLabel;

  /// Request status NO_SHOW: status card description. G2-1a-4 (C10).
  ///
  /// In fr, this message translates to:
  /// **'La clinique a indiqué que ce rendez-vous n’a pas eu lieu.'**
  String get requestNoShowDescription;

  /// Request status NO_SHOW: status card action line. G2-1a-4 (C10).
  ///
  /// In fr, this message translates to:
  /// **'Demande terminée'**
  String get requestNoShowActionMessage;

  /// Onboarding: Continue on an already-saved page that was changed; nothing is sent. G2-1a-4.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations sont déjà enregistrées. Vous pourrez les modifier plus tard depuis votre profil.'**
  String get onboardingPageAlreadySaved;

  /// Any backend call: no network connection. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre connexion et réessayez.'**
  String get apiErrorNetwork;

  /// Any backend call: the request timed out. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur met trop de temps à répondre. Réessayez.'**
  String get apiErrorTimeout;

  /// Any backend call: HTTP 401, the session is no longer valid. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré. Reconnectez-vous.'**
  String get apiErrorUnauthorized;

  /// Any backend call: HTTP 403 with no clearer code. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’avez pas accès à cette action.'**
  String get apiErrorForbidden;

  /// Any backend call: HTTP 404/410 with no clearer code. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément est introuvable ou n’est plus disponible.'**
  String get apiErrorNotFound;

  /// Any backend call: HTTP 409/412 with no clearer code. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Les informations ont changé entre-temps. Actualisez et réessayez.'**
  String get apiErrorConflict;

  /// Any backend call: HTTP 400/422 (input rejected) with no clearer code. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations ne sont pas valides. Vérifiez et réessayez.'**
  String get apiErrorValidation;

  /// Any backend call: HTTP 429, too many attempts. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Patientez avant de réessayer.'**
  String get apiErrorRateLimited;

  /// Any backend call: HTTP 5xx. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Service momentanément indisponible. Réessayez plus tard.'**
  String get apiErrorServer;

  /// Any backend call: unreadable or unexpected error. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get apiErrorUnknown;

  /// Form field rejected by the server: required (NotBlank/NotNull/NotEmpty). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est obligatoire.'**
  String get fieldErrorRequired;

  /// Form field rejected by the server: too long. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce texte est trop long.'**
  String get fieldErrorTooLong;

  /// Form field rejected by the server: too short. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce texte est trop court.'**
  String get fieldErrorTooShort;

  /// Form field rejected by the server: wrong length (Size, direction unknown). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'La longueur de ce champ n’est pas valide.'**
  String get fieldErrorInvalidLength;

  /// Form field rejected by the server: format (Pattern/Email). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Format invalide.'**
  String get fieldErrorInvalidFormat;

  /// Form field rejected by the server: out of range (Min/Max/Past/Future…). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Valeur hors limites.'**
  String get fieldErrorOutOfRange;

  /// Form field rejected by the server with no field code (today’s patient endpoints). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez ce champ.'**
  String get fieldErrorInvalid;

  /// Security, set password on web: use the Google button shown. Moved from AccountSecurityProvider. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez le bouton Google affiché pour confirmer votre identité.'**
  String get securityGoogleUseWebButton;

  /// Security, set password: the Google re-authentication was cancelled. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Réauthentification Google annulée.'**
  String get securityGoogleCancelled;

  /// Security, set password: Google returned no ID token. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Google n’a pas fourni de preuve de réauthentification.'**
  String get securityGoogleNoProof;

  /// Security, phone change: another action is running. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Une opération est déjà en cours.'**
  String get securityActionInProgress;

  /// Security screens: AUTH_INVALID_OTP. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Le code est incorrect ou a expiré.'**
  String get securityInvalidOtp;

  /// Security, phone change: AUTH_PHONE_ALREADY_USED. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est déjà associé à un autre compte.'**
  String get securityPhoneAlreadyUsed;

  /// Security, phone change: CONFLICT. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Un changement de numéro est déjà en cours.'**
  String get securityPhoneChangeInProgress;

  /// Security, phone change: INVALID_STATE. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Cette étape a expiré. Recommencez la vérification.'**
  String get securityStepExpired;

  /// Security, phone-change reversal link: AUTH_INVALID_TOKEN. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien est invalide, expiré ou a déjà été utilisé.'**
  String get securityLinkInvalid;

  /// Profile could not be loaded (fallback when no clearer reason). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le profil.'**
  String get profileLoadFailed;

  /// Profile changes could not be saved (fallback). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer les modifications.'**
  String get profileSaveFailed;

  /// Profile photo upload/removal failed (fallback). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier la photo de profil.'**
  String get avatarUpdateFailed;

  /// The picked profile photo could not be read on the device. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’accéder à cette image.'**
  String get avatarSelectionFailed;

  /// Family members could not be loaded (fallback). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les membres.'**
  String get familyLoadFailed;

  /// Family member could not be saved (fallback). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer le membre.'**
  String get familySaveFailed;

  /// Family member could not be removed (fallback). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de retirer ce membre.'**
  String get familyRemoveFailed;

  /// Professional access request form: sending failed (fallback). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’envoyer la demande.'**
  String get professionalAccessSendFailed;

  /// Backend code MRS_UNAVAILABLE (503): the medical record service is down. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Le dossier médical est temporairement indisponible. Réessayez plus tard.'**
  String get apiCodeMrsUnavailable;

  /// Backend code OBJECT_STORAGE_UNAVAILABLE (503): file storage is down. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Le stockage des fichiers est temporairement indisponible. Réessayez plus tard.'**
  String get apiCodeObjectStorageUnavailable;

  /// Backend code FILE_TOO_LARGE (413): file over the size limit. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier est trop volumineux.'**
  String get apiCodeFileTooLarge;

  /// Backend code UNSUPPORTED_FILE_TYPE (415): file type not allowed. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce type de fichier n’est pas accepté.'**
  String get apiCodeUnsupportedFileType;

  /// Backend code PROFESSIONAL_ACCESS_REQUEST_ALREADY_PENDING (409). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Une demande est déjà en cours pour cette adresse e-mail ou cet identifiant professionnel.'**
  String get apiCodeProfessionalAccessAlreadyPending;

  /// Backend code AUTH_PASSWORD_COMPROMISED (400): password found in a known breach. Same wording as the auth screens. G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Ce mot de passe est compromis. Choisissez-en un autre.'**
  String get apiCodePasswordCompromised;

  /// Backend code AUTH_INVALID_CREDENTIALS (401): wrong password (login, or current password on change/set). G2-1b-2.
  ///
  /// In fr, this message translates to:
  /// **'Les identifiants sont incorrects.'**
  String get apiCodeInvalidCredentials;

  /// Backend code AUTH_PROVIDER_UNAVAILABLE (503): the SMS, Google or password-check provider is down. Same text on every screen. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Service de connexion momentanément indisponible. Réessayez plus tard.'**
  String get apiCodeAuthProviderUnavailable;

  /// Care request: a submission was in flight when the app stopped. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Votre dernière demande a été interrompue. Réessayez.'**
  String get requestInterrupted;

  /// Care request: the server answer could not be read safely. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'La réponse reçue ne peut pas être vérifiée. Réessayez.'**
  String get requestResponseInvalid;

  /// Care request: the call was cancelled locally. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'La demande a été interrompue. Réessayez.'**
  String get requestCancelled;

  /// Care request: server error (5xx). G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Les demandes de soins sont momentanément indisponibles. Réessayez.'**
  String get requestServerUnavailable;

  /// Care request: REQUEST_SUBJECT_FORBIDDEN / 403. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande ne peut pas être envoyée pour la personne choisie.'**
  String get requestSubjectForbidden;

  /// Care request: REQUEST_TARGET_UNAVAILABLE / 422. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette clinique ne peut pas recevoir de demandes pour le moment.'**
  String get requestTargetUnavailable;

  /// Care request: REQUEST_INVALID / 400. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations ne sont pas valides. Vérifiez-les puis réessayez.'**
  String get requestInvalid;

  /// Care request: REQUEST_VERSION_CONFLICT / 409. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande a changé. Actualisez pour voir son dernier état.'**
  String get requestVersionConflict;

  /// Care request: REQUEST_TRANSITION_INVALID. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette modification n’est plus possible pour cette demande.'**
  String get requestTransitionInvalid;

  /// Care request: REQUEST_IDEMPOTENCY_CONFLICT. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande a déjà servi à un autre envoi. Commencez une nouvelle demande.'**
  String get requestIdempotencyConflict;

  /// Care request: REQUEST_NOT_FOUND / 404. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande n’est plus disponible.'**
  String get requestNotFound;

  /// Care request: local guard, no clinic chosen yet. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une clinique avant d’envoyer votre demande.'**
  String get requestIntentIncomplete;

  /// Care request: local guard, the account scope is unavailable. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Reconnectez-vous avant d’envoyer cette demande.'**
  String get requestSignInAgain;

  /// Care request: local guard, the recovery store is unavailable. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande ne peut pas être envoyée en toute sécurité pour le moment. Réessayez.'**
  String get requestCannotSendSafely;

  /// Clinic directory: timeout. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'La liste des cliniques met trop de temps à répondre. Réessayez.'**
  String get clinicListTimeout;

  /// Clinic directory: unreadable answer or rejected call. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'La liste des cliniques n’a pas pu être lue. Réessayez.'**
  String get clinicListInvalid;

  /// Clinic directory: server error (5xx). G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'L’annuaire des cliniques est momentanément indisponible. Réessayez.'**
  String get clinicListUnavailable;

  /// Clinic directory screen: fallback when no failure is known. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les cliniques.'**
  String get clinicListLoadFailed;

  /// Clinic detail screen: fallback when no failure is known. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger cette clinique.'**
  String get clinicDetailLoadFailed;

  /// Doctor directory: timeout. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le répertoire des médecins met trop de temps à répondre. Réessayez.'**
  String get doctorDirectoryTimeout;

  /// Doctor directory: unreadable answer or rejected call. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le répertoire des médecins n’a pas pu être lu. Réessayez.'**
  String get doctorDirectoryInvalid;

  /// Doctor directory: 404, the doctor is gone. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Ce médecin n’existe plus ou n’est plus disponible.'**
  String get doctorDirectoryNotFound;

  /// Doctor directory: server error (5xx). G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le répertoire des médecins est momentanément indisponible. Réessayez.'**
  String get doctorDirectoryUnavailable;

  /// Medical documents snackbar: local PROFILE_NOT_READY. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil patient n’est pas encore prêt.'**
  String get documentProfileNotReady;

  /// Medical documents snackbar: local OPERATION_IN_PROGRESS. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Une opération sur les documents est déjà en cours.'**
  String get documentOperationInProgress;

  /// Medical documents snackbar: local EMPTY_FILE. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier choisi est vide.'**
  String get documentFileEmpty;

  /// Medical documents snackbar: FILE_TOO_LARGE (local check or 413). G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier dépasse la limite de 20 Mo.'**
  String get documentFileTooLarge;

  /// Medical documents snackbar: local FILE_SOURCE_INVALID / FILE_READ_FAILED. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier choisi n’a pas pu être lu.'**
  String get documentFileUnreadable;

  /// Medical documents snackbar: local FILE_SIZE_MISMATCH. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier choisi a changé avant l’envoi.'**
  String get documentFileChanged;

  /// Medical documents snackbar: UNSUPPORTED_FILE_TYPE (415). G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un fichier PDF, PNG, JPG ou JPEG.'**
  String get documentFileTypeUnsupported;

  /// Medical documents snackbar: local UPLOAD_OWNER_CHANGED. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le compte a changé pendant l’envoi. Actualisez la liste des documents avant de réessayer.'**
  String get documentAccountChanged;

  /// Medical documents snackbar: local UPLOAD_OWNER_UNAVAILABLE / UPLOAD_RECOVERY_IDENTITY_INVALID. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le titulaire des documents n’est pas disponible. Reconnectez-vous puis réessayez.'**
  String get documentOwnerUnavailable;

  /// Medical documents snackbar: local UPLOAD_RECEIPT_STORAGE_FAILED. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi n’a pas pu démarrer en toute sécurité. Réessayez.'**
  String get documentUploadNotStarted;

  /// Medical documents snackbar: DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND / _EXPIRED. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi précédent ne peut plus être récupéré. Recommencez l’envoi si nécessaire.'**
  String get documentRecoveryGone;

  /// Medical documents snackbar: local DOCUMENT_UPLOAD_FAILED. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi précédent n’a pas abouti. Recommencez l’envoi si nécessaire.'**
  String get documentUploadFailed;

  /// Medical documents snackbar: local UPLOAD_RECOVERY_REQUIRED. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le résultat de l’envoi précédent doit d’abord être récupéré. Actualisez quand la connexion est disponible.'**
  String get documentRecoveryRequired;

  /// Medical documents snackbar: DOCUMENT_UPLOAD_COMMAND_IN_PROGRESS. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi du document est encore en cours de traitement.'**
  String get documentUploadInProgress;

  /// Medical documents snackbar: DOCUMENT_UPLOAD_IDEMPOTENCY_CONFLICT / IDEMPOTENCY_KEY_REUSED / CONFLICT. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette opération entre en conflit avec une demande précédente. Actualisez puis réessayez.'**
  String get documentConflict;

  /// Medical documents snackbar: local UPLOAD_CANCELLED_LOCAL. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le transfert s’est arrêté. Actualisez la liste des documents avant de réessayer : le résultat est incertain.'**
  String get documentTransferStopped;

  /// Medical documents snackbar: local AUTH_REFRESH_TEMPORARILY_UNAVAILABLE. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Votre session n’a pas pu être renouvelée. Vérifiez votre connexion et réessayez.'**
  String get documentSessionRefreshFailed;

  /// Medical documents snackbar: local AUTH_REPLAY_REQUIRED. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a été renouvelée. Relancez l’envoi pour le reprendre en toute sécurité.'**
  String get documentRetryAfterRefresh;

  /// Medical documents snackbar: MRS_UNAVAILABLE / OBJECT_STORAGE_UNAVAILABLE. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le traitement des documents est momentanément indisponible. Réessayez plus tard.'**
  String get documentProcessingUnavailable;

  /// Medical documents snackbar: INVALID_INPUT / VALIDATION_ERROR. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le document n’a pas pu être accepté. Vérifiez le fichier puis réessayez.'**
  String get documentNotAccepted;

  /// Medical documents snackbar: local MALFORMED_RESPONSE. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'La réponse du serveur est inattendue. Réessayez.'**
  String get documentResponseInvalid;

  /// Medical documents snackbar: local SSE_CONNECTION_LOST. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Le suivi du document a été interrompu. Actualisez la liste.'**
  String get documentStatusInterrupted;

  /// Medical documents snackbar: FORBIDDEN / 403. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’avez pas accès à ces documents.'**
  String get documentForbidden;

  /// Medical documents snackbar: fallback for any other failure. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'L’opération sur le document n’a pas pu aboutir. Réessayez.'**
  String get documentOperationFailed;

  /// Auth screens (login, signup, OTP, Google): AUTH_INVALID_OTP. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Code invalide ou expiré.'**
  String get authInvalidOtp;

  /// Auth screens (login, signup, OTP, Google): AUTH_SESSION_INVALID / AUTH_REFRESH_TOKEN_INVALID. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée. Veuillez vous reconnecter.'**
  String get authSessionExpired;

  /// Auth screens (login, signup, OTP, Google): AUTH_ACCOUNT_NOT_ALLOWED. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte ne peut pas utiliser cette application.'**
  String get authAccountNotAllowed;

  /// Auth screens (login, signup, OTP, Google): OTP_NOT_VERIFIED. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez vérifier le code envoyé avant de continuer.'**
  String get authOtpNotVerified;

  /// Auth screens (login, signup, OTP, Google): USER_NOT_FOUND. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte patient trouvé pour ce numéro.'**
  String get authUserNotFound;

  /// Auth screens (login, signup, OTP, Google): TOO_MANY_REQUESTS. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez plus tard.'**
  String get authTooManyAttempts;

  /// Auth screens (login, signup, OTP, Google): VALIDATION_ERROR. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez vérifier les informations saisies.'**
  String get authCheckDetails;

  /// Auth screens (login, signup, OTP, Google): AUTH_PHONE_ALREADY_USED. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est déjà utilisé.'**
  String get authPhoneAlreadyUsed;

  /// Auth screens (login, signup, OTP, Google): AUTH_EMAIL_ALREADY_USED. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Un compte OmniCare existe déjà avec cette adresse. Connectez-vous avec votre mot de passe.'**
  String get authEmailAlreadyUsed;

  /// Auth screens (login, signup, OTP, Google): INVALID_INPUT (password change). Accent fixed (différent). G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez choisir un nouveau mot de passe différent.'**
  String get authChooseDifferentPassword;

  /// Auth screens (login, signup, OTP, Google): AUTH_GOOGLE_SIGNUP_EXPIRED. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Session Google expirée. Recommencez avec Google.'**
  String get authGoogleSignupExpired;

  /// Auth screens (login, signup, OTP, Google): AUTH_GOOGLE_SIGNUP_INVALID. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Session Google invalide. Recommencez avec Google.'**
  String get authGoogleSignupInvalid;

  /// Auth screens (login, signup, OTP, Google): AUTH_GOOGLE_LINK_EXPIRED. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette tentative d’association a expiré.'**
  String get authGoogleLinkExpired;

  /// Auth screens (login, signup, OTP, Google): AUTH_GOOGLE_LINK_INVALID. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Cette tentative d’association n’est plus valide.'**
  String get authGoogleLinkInvalid;

  /// Auth screens (login, signup, OTP, Google): AUTH_GOOGLE_LINK_PASSWORD_INVALID. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get authGoogleLinkPasswordInvalid;

  /// Auth screens (login, signup, OTP, Google): AUTH_GOOGLE_LINK_PASSWORD_UNAVAILABLE. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte ne peut pas être associé avec un mot de passe pour le moment.'**
  String get authGoogleLinkPasswordUnavailable;

  /// Auth screens (login, signup, OTP, Google): AUTH_GOOGLE_IDENTITY_CONFLICT. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte Google est déjà associé à un autre compte.'**
  String get authGoogleIdentityConflict;

  /// Auth screens (login, signup, OTP, Google): DUPLICATE_IDENTITY. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Un compte existe déjà avec ces informations.'**
  String get authDuplicateIdentity;

  /// Auth screens (login, signup, OTP, Google): local MALFORMED_RESPONSE. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Réponse serveur invalide.'**
  String get authMalformedResponse;

  /// Auth screens (login, signup, OTP, Google): UNSUPPORTED_ROLE. Same text as before. G2-1b-2c.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte ne correspond pas à un compte patient.'**
  String get authUnsupportedRole;

  /// A feature with no real data source yet (formerly mock-backed, cut off in G2-1b-3). Generic text of ApiFailureKind.featureUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Cette fonctionnalité est indisponible pour le moment.'**
  String get apiErrorFeatureUnavailable;

  /// « Dossier médical » family selector and header: the account holder's own entry (G2-1b-3b). Same text as the former fixture.
  ///
  /// In fr, this message translates to:
  /// **'Mon passeport'**
  String get passportSelfRelationship;

  /// « Dossier médical »: a value the record does not hold (blood type, measurements, unknown allergies or conditions, missing identity field, unknown doctor or reason). G2-1b-3b / FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get medicalRecordNotRecorded;

  /// « Dossier médical » allergies row: the record says the patient has no known allergy (status NONE_KNOWN). G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Aucune allergie connue'**
  String get passportAllergiesNoneKnown;

  /// « Dossier médical » chronic conditions: the record says the patient has no known condition (status NONE_KNOWN). G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Aucun antécédent connu'**
  String get passportConditionsNoneKnown;

  /// « Dossier médical » medications card, current tab, empty list. Text set by the CTO. G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Aucun traitement en cours prescrit sur OmniCare.'**
  String get passportNoCurrentMedications;

  /// « Dossier médical » medications card, past tab, empty list. Text set by the CTO. G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ancien traitement prescrit sur OmniCare.'**
  String get passportNoPastMedications;

  /// « Dossier médical »: button that reloads one card after a failed request. G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get passportRetry;

  /// « Dossier médical »: fallback text of a card whose request failed, when the failure has no more precise message. G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ces informations.'**
  String get passportSectionLoadFailed;

  /// « Dossier médical » history card: the doctor of a completed consultation. G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'Dr {name}'**
  String passportDoctorName(String name);

  /// « Dossier médical » medications card: frequency when the prescription gives only a number of intakes per day. Same form as the former fixture. G2-FT-3.
  ///
  /// In fr, this message translates to:
  /// **'{count}× par jour'**
  String passportTimesPerDay(int count);

  /// Trusted-device switch title (login / sign-up). Same text as the current checkbox. G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'Faire confiance à cet appareil'**
  String get authTrustDeviceTitle;

  /// Trusted-device switch subtitle. Same text as the current sign-up checkbox. G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'À utiliser uniquement sur un appareil personnel.'**
  String get authTrustDeviceSubtitle;

  /// Label of the Google button on Android/iOS. Same text as today. G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get authContinueWithGoogle;

  /// Title of the birth-date wheel picker sheet. G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get birthDatePickerTitle;

  /// Birth-date picker: day column label (uppercase). G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'JOUR'**
  String get birthDatePickerDay;

  /// Birth-date picker: month column label (uppercase). G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'MOIS'**
  String get birthDatePickerMonth;

  /// Birth-date picker: year column label (uppercase). G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'ANNÉE'**
  String get birthDatePickerYear;

  /// Birth-date picker: confirm button. G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get birthDatePickerConfirm;

  /// Step progress bar label, e.g. « Étape 2 sur 3 · Identité ». G3-P1.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total} · {name}'**
  String stepProgressLabel(int current, int total, String name);

  /// Screen-reader label of the OmniCare logo (welcome screen, login sheet). G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Logo OmniCare'**
  String get authLogoLabel;

  /// Brand name next to the logo on the welcome screen. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'OmniCare'**
  String get welcomeBrandName;

  /// Welcome screen chip above the title. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Médecins · Infirmiers · Kinés'**
  String get welcomeAudienceChip;

  /// Welcome title, first line (white). G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Votre santé,'**
  String get welcomeTitleLine1;

  /// Welcome title, second line (mint). G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'au même endroit.'**
  String get welcomeTitleLine2;

  /// Welcome screen subtitle. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez un professionnel près de chez vous, prenez rendez-vous et gardez votre dossier médical en sécurité.'**
  String get welcomeSubtitle;

  /// Opens the patient sign-up (welcome button, login-sheet footer). G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authCreateAccount;

  /// Welcome button that opens the login sheet, and the login sheet submit button. Same text as today. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSignIn;

  /// Welcome footer prompt before the professional request link. Same text as today (tests pin the full sentence). G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Professionnel de santé ?'**
  String get authProfessionalPrompt;

  /// Welcome footer link to the professional access request. Same text as today. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Demander à rejoindre OmniCare'**
  String get authProfessionalAction;

  /// Login sheet title. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Bon retour'**
  String get loginSheetTitle;

  /// Login sheet subtitle. Same text as the former login screen. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour retrouver votre espace OmniCare.'**
  String get loginSheetSubtitle;

  /// Label above the e-mail field (login sheet). G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get authEmailLabel;

  /// Label above the password field (login sheet). G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPasswordLabel;

  /// Tooltip / screen-reader label of the eye button when the password is hidden. Same text as today. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get authShowPassword;

  /// Tooltip / screen-reader label of the eye button when the password is visible. Same text as today. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get authHidePassword;

  /// Word in the « ou » divider between password login and Google. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get authOrDivider;

  /// Phone login button, shown only when phone verification is enabled. Same text as today. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec un numéro de téléphone'**
  String get authPhoneLogin;

  /// Login sheet footer prompt before « Créer un compte ». Same text as today. G3-P2a.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau sur OmniCare ?'**
  String get authNewToOmniCare;

  /// Login sheet fallback when a password login fails without a mapped message. Same text as before (was hardcoded). G3-P2a-fix.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible.'**
  String get authLoginFailed;

  /// Login sheet fallback when Google sign-in fails. Same text as before (was hardcoded). G3-P2a-fix.
  ///
  /// In fr, this message translates to:
  /// **'Connexion Google impossible.'**
  String get authGoogleLoginFailed;

  /// Web only: neutral hint after « Réessayer avec Google » in the account-link sheet. Same text as before (was hardcoded). G3-P2a-fix.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez à nouveau « Continuer avec Google ».'**
  String get authGoogleRetryHint;

  /// Login e-mail validator: empty field. Same text and rule as before. G3-P2a-fix.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail requise'**
  String get authEmailRequired;

  /// Login e-mail validator: wrong format. Same text and rule as before. G3-P2a-fix.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une adresse e-mail valide'**
  String get authEmailInvalid;

  /// Login password validator: empty field. Same text and rule as before. G3-P2a-fix.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe requis'**
  String get authPasswordMissing;

  /// Generic close button tooltip / screen-reader label (auth: login sheet, sign-up, phone, birth-date picker). G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// Back button tooltip in the auth flow frame (sign-up, phone). Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get authBack;

  /// Screen-reader state of a password rule chip when the rule is met. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'respecté'**
  String get passwordRuleMet;

  /// Screen-reader state of a password rule chip when the rule is not (yet) met. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'non respecté'**
  String get passwordRuleNotMet;

  /// Header title of the sign-up flow (sign-up steps, phone step of the e-mail sign-up). Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte patient'**
  String get signupTitle;

  /// Sign-up step 1 name in the step progress. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get signupStepAccount;

  /// Sign-up step 2 name in the step progress. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get signupStepIdentity;

  /// Sign-up step 3 name in the step progress. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get signupStepPhone;

  /// Sign-up step 1 title. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Vos identifiants'**
  String get signupAccountTitle;

  /// Sign-up step 1 subtitle. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Ils vous serviront à vous connecter à OmniCare.'**
  String get signupAccountSubtitle;

  /// Divider between Google and the e-mail form on sign-up step 1. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'ou avec votre e-mail'**
  String get signupOrWithEmail;

  /// Label of the confirm-password field. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get signupConfirmPasswordLabel;

  /// Password rule chip label (server rule: 12–128 characters). G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'12 caractères minimum'**
  String get signupPasswordRuleMinLength;

  /// Success message under the confirm-password field when both passwords match. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe correspondent'**
  String get signupPasswordsMatch;

  /// Sign-up validators: empty field. Same text and rule as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Champ requis'**
  String get signupFieldRequired;

  /// Sign-up e-mail validator: wrong format. Same text and rule as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide'**
  String get signupEmailInvalid;

  /// Sign-up password validator: shorter than 12. Same text and rule as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez au moins 12 caractères'**
  String get signupPasswordTooShort;

  /// Sign-up password validator: longer than 128. Same text and rule as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez 128 caractères maximum'**
  String get signupPasswordTooLong;

  /// Sign-up step 2 title. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Qui êtes-vous ?'**
  String get signupIdentityTitle;

  /// Sign-up step 2 subtitle. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations permettent à vos professionnels de santé de vous identifier.'**
  String get signupIdentitySubtitle;

  /// First-name field label. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get signupFirstNameLabel;

  /// Last-name field label. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get signupLastNameLabel;

  /// 18+ rule text: birth-date helper, picker error and submit check. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez avoir au moins 18 ans pour créer un compte.'**
  String get signupAgeRequirement;

  /// Birth-date field validator: under 18. Same text and rule as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez avoir au moins 18 ans'**
  String get signupAgeTooYoung;

  /// Gender control label and screen-reader group name. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Genre'**
  String get signupGenderLabel;

  /// Gender option (value M). Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get signupGenderMale;

  /// Gender option (value F). Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get signupGenderFemale;

  /// Inline error when no gender is chosen (was a SnackBar). Same text. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre genre.'**
  String get signupSelectGender;

  /// Inline error when no birth date is chosen (was a SnackBar). Same text. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre date de naissance.'**
  String get signupSelectBirthDate;

  /// Sign-up fallback when Google sign-up fails. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Inscription avec Google impossible.'**
  String get signupGoogleFailed;

  /// Primary button: sign-up steps 1–2, phone step when phone verification is off. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get authContinue;

  /// Sign-up step 1 footer prompt before « Se connecter ». Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un compte ?'**
  String get signupHaveAccount;

  /// Terms sentence, part 1 (before « conditions »). Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'En créant un compte, vous acceptez nos'**
  String get signupTermsIntro;

  /// Terms sentence, highlighted « conditions ». Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'conditions'**
  String get signupTermsConditions;

  /// Terms sentence, part between the two highlighted words. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'et notre'**
  String get signupTermsAnd;

  /// Terms sentence, highlighted « politique de confidentialité ». Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'politique de confidentialité'**
  String get signupTermsPrivacy;

  /// Title of the summary card on the sign-up phone step. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get signupSummaryTitle;

  /// Visible text of the summary « Modifier » links. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get signupEdit;

  /// Screen-reader label of the summary link back to step 1. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Modifier vos identifiants'**
  String get signupEditAccount;

  /// Screen-reader label of the summary link back to step 2. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Modifier votre identité'**
  String get signupEditIdentity;

  /// Primary button of the sign-up phone step (e-mail sign-up only). G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get signupCreateAccount;

  /// Phone screen header title and phone field label. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneScreenTitle;

  /// Phone screen title in the phone-login flow. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par téléphone'**
  String get phoneLoginTitle;

  /// Phone screen title in sign-up when phone verification is on. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre téléphone'**
  String get phoneVerifyTitle;

  /// Phone screen title in sign-up when phone verification is off. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Votre numéro de téléphone'**
  String get phoneContactTitle;

  /// Phone screen subtitle, phone-login flow. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre numéro pour recevoir un code de connexion.'**
  String get phoneLoginSubtitle;

  /// Phone screen subtitle, sign-up with verification. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Nous devons vérifier votre numéro avant de continuer.'**
  String get phoneVerifySubtitle;

  /// Phone screen subtitle, sign-up without verification. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un numéro de contact pour finaliser votre compte.'**
  String get phoneContactSubtitle;

  /// Phone field hint. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'12 345 678'**
  String get phoneHint;

  /// Phone field helper. Same text as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Format tunisien à 8 chiffres'**
  String get phoneFormatHelper;

  /// Phone field country prefix segment. Same as before. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'+216'**
  String get phonePrefix;

  /// Phone validator: empty field (was English « Phone number is required »). G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone requis'**
  String get phoneRequired;

  /// Phone validator: not 8 Tunisian digits (was the English normalizer message). Same rule. G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez les 8 chiffres de votre numéro.'**
  String get phoneDigitsInvalid;

  /// Phone screen fallback when the controller returns no message (was English « Unable to continue. »). G3-P2b.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de continuer.'**
  String get phoneUnableToContinue;

  /// E-mail sign-up, phone step: main button when phone verification is on (the button sends the SMS code). G3-P2b-fix.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le code'**
  String get signupReceiveCode;

  /// Splash: saved session could not be checked (was English « We could not verify your saved session. Check your connection and try again. »). G3-P2c.
  ///
  /// In fr, this message translates to:
  /// **'Nous n\'avons pas pu vérifier votre session. Vérifiez votre connexion et réessayez.'**
  String get splashSessionError;

  /// Splash: retry button of the session error card (was English « Try again »). G3-P2c.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get splashRetry;

  /// Forced password change (/change-password-required): page title. G3-P2c.
  ///
  /// In fr, this message translates to:
  /// **'Changez votre mot de passe'**
  String get forcedPasswordTitle;

  /// Forced password change: one-line reason under the title. G3-P2c.
  ///
  /// In fr, this message translates to:
  /// **'Pour la sécurité de votre compte, choisissez un nouveau mot de passe avant de continuer.'**
  String get forcedPasswordReason;

  /// Onboarding frame: skip text button at the top right. G3-ONB1.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get onboardingSkip;

  /// Onboarding frame: screen-reader name of the thin progress bar (its value is a percentage). G3-ONB1.
  ///
  /// In fr, this message translates to:
  /// **'Progression'**
  String get onboardingProgressLabel;

  /// Generic « Modifier » action (profile summary card, summary list rows). G3-ONB1.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// Screen-reader label of a « Modifier » action, naming what it edits. G3-ONB1.
  ///
  /// In fr, this message translates to:
  /// **'Modifier : {item}'**
  String commonEditItem(String item);

  /// Number wheel / weight ruler: screen-reader value while nothing is chosen yet (the readout shows « — »). G3-ONB1.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get pickerNoValue;

  /// Onboarding intro: label chip on the dark header. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Groupe sanguin'**
  String get onboardingIntroChipBlood;

  /// Onboarding intro: label chip on the dark header. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Allergies'**
  String get onboardingIntroChipAllergies;

  /// Onboarding intro: label chip on the dark header. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Médicaments'**
  String get onboardingIntroChipMedications;

  /// Onboarding intro: label chip on the dark header. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get onboardingIntroChipFollowUp;

  /// Onboarding intro: card title. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Préparons votre dossier médical'**
  String get onboardingIntroTitle;

  /// Onboarding intro: card text. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Quelques questions pour que vos soignants disposent des bonnes informations.'**
  String get onboardingIntroBody;

  /// Onboarding intro: duration line. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Environ 1 minute'**
  String get onboardingIntroDuration;

  /// Onboarding intro: reassurance line. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez les modifier à tout moment'**
  String get onboardingIntroEditable;

  /// Onboarding intro: main button, shows the first page. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingIntroStart;

  /// Onboarding intro: secondary button, same action as « Passer » (go home). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get onboardingIntroLater;

  /// Onboarding: main button (was English « Continue »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get onboardingContinue;

  /// Onboarding: main button of the last page (was English « Complete »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get onboardingFinish;

  /// Onboarding page 1 « Profil »: title (was « Confirm your profile »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'C’est bien vous ?'**
  String get onboardingProfileTitle;

  /// Onboarding « Profil »: subtitle. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez les informations de votre compte.'**
  String get onboardingProfileSubtitle;

  /// Onboarding « Profil »: main button while the summary card is shown (same save as « Continuer »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'C’est bien moi'**
  String get onboardingProfileConfirm;

  /// Onboarding « Profil »: field label (was « First name »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get onboardingFirstName;

  /// Onboarding « Profil »: field label (was « Last name »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get onboardingLastName;

  /// Onboarding « Profil » field label and summary row (was « Birth date »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get onboardingBirthDate;

  /// Onboarding « Profil » field label and summary row (was « Gender »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Genre'**
  String get onboardingGender;

  /// Onboarding gender option, stored value M (was « Male »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get onboardingGenderMale;

  /// Onboarding gender option, stored value F (was « Female »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get onboardingGenderFemale;

  /// Onboarding gender option, stored value autre (was « Other »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get onboardingGenderOther;

  /// Onboarding validation (was « Please enter your first name. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre prénom.'**
  String get onboardingErrorFirstName;

  /// Onboarding validation (was « Please enter your last name. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre nom.'**
  String get onboardingErrorLastName;

  /// Onboarding validation (was « Please select your birth date. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre date de naissance.'**
  String get onboardingErrorBirthDate;

  /// Onboarding validation (was « Please select a birth date in the past. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une date de naissance dans le passé.'**
  String get onboardingErrorBirthDatePast;

  /// Onboarding validation (was « Please select your gender. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre genre.'**
  String get onboardingErrorGender;

  /// Onboarding validation (was « Please enter your height. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez votre taille.'**
  String get onboardingErrorHeight;

  /// Onboarding validation (was « Please enter your weight. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez votre poids.'**
  String get onboardingErrorWeight;

  /// Onboarding validation (was « Please enter the allergy name. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le nom de l’allergie.'**
  String get onboardingErrorAllergyName;

  /// Onboarding validation (was « Please select allergy severity. »), same rule. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la gravité de l’allergie.'**
  String get onboardingErrorAllergySeverity;

  /// Onboarding « Groupe sanguin »: title (was « What is your blood type? »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Quel est votre groupe sanguin ?'**
  String get onboardingBloodTitle;

  /// Onboarding « Groupe sanguin »: subtitle (replaces the « blood supply » claim). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez le modifier plus tard dans votre dossier.'**
  String get onboardingBloodSubtitle;

  /// Onboarding « Taille »: title. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Quelle est votre taille ?'**
  String get onboardingHeightTitle;

  /// Onboarding: height wheel name for screen readers and summary row (was « Height »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get onboardingHeightLabel;

  /// Onboarding « Poids »: title. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Quel est votre poids ?'**
  String get onboardingWeightTitle;

  /// Onboarding: weight ruler name for screen readers and summary row (was « Weight »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get onboardingWeightLabel;

  /// Onboarding « Poids »: opens the type-in weight field. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Saisir au clavier'**
  String get onboardingWeightTypeIn;

  /// Onboarding « Poids »: type-in field label (decimals allowed as before). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Poids (kg)'**
  String get onboardingWeightFieldLabel;

  /// Unit after a height value. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'cm'**
  String get onboardingUnitCm;

  /// Unit after a weight value. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'kg'**
  String get onboardingUnitKg;

  /// Onboarding « Poids »: screen-reader label of the BMI card, final value with one French decimal (G3-ONB2 « IMC {value} », reworded in G3-ONB3a).
  ///
  /// In fr, this message translates to:
  /// **'Votre IMC : {value}'**
  String onboardingBmi(String value);

  /// Onboarding « Poids »: BMI preview before both values exist (was English). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'L’IMC sera calculé à partir de votre taille et de votre poids.'**
  String get onboardingBmiPending;

  /// Onboarding yes/no question: « Oui ». G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get onboardingYes;

  /// Onboarding yes/no question: « Non » (chronic conditions). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get onboardingNo;

  /// Onboarding « Allergies »: title (was « Any allergies? »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Avez-vous des allergies ?'**
  String get onboardingAllergiesTitle;

  /// Onboarding « Allergies »: subtitle. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Médicaments, aliments ou autres (ex. latex).'**
  String get onboardingAllergiesSubtitle;

  /// Onboarding « Allergies »: « Non » option = the existing clear action (noKnownAllergies). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Non, aucune allergie connue'**
  String get onboardingAllergiesNo;

  /// Onboarding allergy card title (was « Allergy n »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Allergie {index}'**
  String onboardingAllergyCardTitle(int index);

  /// Onboarding allergy card: remove button tooltip (was « Remove allergy »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l’allergie {index}'**
  String onboardingAllergyRemove(int index);

  /// Onboarding allergy card: name field (was « Allergy name »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l’allergie'**
  String get onboardingAllergyName;

  /// Onboarding allergy card: severity label (was « Severity »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Gravité'**
  String get onboardingAllergySeverity;

  /// Allergy severity, stored value « légère » (was « Mild »). REQUIRES MEDICAL VALIDATION. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Légère'**
  String get onboardingSeverityMild;

  /// Allergy severity, stored value « modérée », default (was « Moderate »). REQUIRES MEDICAL VALIDATION. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Modérée'**
  String get onboardingSeverityModerate;

  /// Allergy severity, stored value « sévère » (was « Severe »). REQUIRES MEDICAL VALIDATION. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Sévère'**
  String get onboardingSeveritySevere;

  /// Onboarding allergy card: life-threatening switch (was « Life-threatening »). REQUIRES MEDICAL VALIDATION. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Risque vital'**
  String get onboardingAllergyLifeThreatening;

  /// Onboarding allergy card: switch subtitle (was « Highlight this allergy for emergency care. »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Elle sera mise en évidence pour les soignants.'**
  String get onboardingAllergyLifeThreateningHint;

  /// Onboarding « Allergies »: add-card button (was « Add Another Allergy »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une allergie'**
  String get onboardingAllergyAdd;

  /// Onboarding « Maladies »: title (was « Any chronic conditions? »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Avez-vous une maladie chronique ?'**
  String get onboardingConditionsTitle;

  /// Onboarding « Maladies »: subtitle (replaces the « 100% safe » claim). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Vos médecins en tiennent compte pour votre suivi.'**
  String get onboardingConditionsSubtitle;

  /// Onboarding « Maladies »: search field (was « Search conditions... »); matches the French labels. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une maladie…'**
  String get onboardingConditionsSearch;

  /// Onboarding « Maladies »: shown when the search matches nothing. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Aucune maladie ne correspond à votre recherche.'**
  String get onboardingConditionsNoMatch;

  /// Onboarding « Maladies »: screen-reader label of a selected chip (tap removes it). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Retirer : {name}'**
  String onboardingConditionRemove(String name);

  /// Label of the stored condition « Diabetes » (value sent unchanged). REQUIRES MEDICAL VALIDATION. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Diabète'**
  String get onboardingConditionDiabetes;

  /// Label of the stored condition « Hypertension » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Hypertension artérielle'**
  String get onboardingConditionHypertension;

  /// Label of the stored condition « Asthma » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Asthme'**
  String get onboardingConditionAsthma;

  /// Label of the stored condition « Heart Disease » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Maladie cardiaque'**
  String get onboardingConditionHeartDisease;

  /// Label of the stored condition « Arthritis » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Arthrite'**
  String get onboardingConditionArthritis;

  /// Label of the stored condition « Thyroid Disorder » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Trouble de la thyroïde'**
  String get onboardingConditionThyroid;

  /// Label of the stored condition « Kidney Disease » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Maladie rénale'**
  String get onboardingConditionKidney;

  /// Label of the stored condition « Liver Disease » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Maladie du foie'**
  String get onboardingConditionLiver;

  /// Label of the stored condition « Cancer » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Cancer'**
  String get onboardingConditionCancer;

  /// Label of the stored condition « Epilepsy » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Épilepsie'**
  String get onboardingConditionEpilepsy;

  /// Label of the stored condition « COPD » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'BPCO'**
  String get onboardingConditionCopd;

  /// Label of the stored condition « Depression » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Dépression'**
  String get onboardingConditionDepression;

  /// Label of the stored condition « Anxiety » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Anxiété'**
  String get onboardingConditionAnxiety;

  /// Label of the stored condition « Migraine » (value sent unchanged). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Migraine'**
  String get onboardingConditionMigraine;

  /// Onboarding « Médicaments »: title (was « Current Medications »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Prenez-vous des médicaments ?'**
  String get onboardingMedicationsTitle;

  /// Onboarding « Médicaments »: subtitle. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez ceux que vous prenez en ce moment.'**
  String get onboardingMedicationsSubtitle;

  /// Onboarding « Médicaments »: « Non » option = the existing « not taking any » action (noKnownMedications). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Non, aucun médicament'**
  String get onboardingMedicationsNo;

  /// Onboarding « Médicaments »: note shown for « Oui »; no medication field in V1, nothing is saved for medications (CTO 2026-11-13). G2.1-A3b.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez ajouter vos médicaments dans votre dossier médical.'**
  String get onboardingMedicationsInRecord;

  /// Onboarding final screen: title (was « Thank You! »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Vos informations sont enregistrées'**
  String get onboardingDoneTitle;

  /// Onboarding final screen: text. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez les compléter à tout moment depuis « Dossier médical ».'**
  String get onboardingDoneBody;

  /// Onboarding final screen: main button, goes to /home as before (was « Go to Dashboard »). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Accéder à mon espace'**
  String get onboardingDoneCta;

  /// Onboarding final screen: summary row, full name. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get onboardingSummaryName;

  /// Onboarding final screen: summary row. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Groupe sanguin'**
  String get onboardingSummaryBlood;

  /// Onboarding final screen: summary row (shown only when allergies were entered). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Allergies'**
  String get onboardingSummaryAllergies;

  /// Onboarding final screen: summary row (shown only when conditions were selected). G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Maladies chroniques'**
  String get onboardingSummaryConditions;

  /// Onboarding: screen-reader label of the initial-load spinner. G3-ONB2.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de votre profil'**
  String get onboardingLoading;

  /// Onboarding « Poids »: BMI card heading (display only, no category). G3-ONB3a.
  ///
  /// In fr, this message translates to:
  /// **'Votre IMC'**
  String get onboardingBmiTitle;

  /// Onboarding « Poids »: BMI card footnote with the height used. G3-ONB3a.
  ///
  /// In fr, this message translates to:
  /// **'Calculé avec votre taille ({height} cm)'**
  String onboardingBmiHeightNote(int height);

  /// Generic field error: the same value twice in one list (DUPLICATE). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément figure déjà dans la liste.'**
  String get fieldErrorDuplicate;

  /// Dossier médical: a label, medication name or document title over 160 characters. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'160 caractères maximum.'**
  String get recordFieldTooLong160;

  /// Dossier médical: a medication dosage text over 80 characters. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'80 caractères maximum.'**
  String get recordFieldTooLong80;

  /// Dossier médical: a list (allergies, conditions, medications) over 50 items. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'50 éléments maximum.'**
  String get recordFieldTooManyItems;

  /// Dossier médical: a text with a control or direction character (INVALID). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Ce texte contient des caractères non autorisés.'**
  String get recordFieldForbiddenCharacters;

  /// Dossier médical: blood type not in the accepted list. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Groupe sanguin non valide.'**
  String get recordFieldBloodTypeInvalid;

  /// Dossier médical: height out of range. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'La taille doit être comprise entre 30 et 300 cm.'**
  String get recordFieldHeightRange;

  /// Dossier médical: weight out of range. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Le poids doit être compris entre 0 et 500 kg.'**
  String get recordFieldWeightRange;

  /// Dossier médical: medication intakes per day out of range. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 6 prises par jour.'**
  String get recordFieldTimesPerDayRange;

  /// Dossier médical: medication duration value out of range. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 365.'**
  String get recordFieldDurationRange;

  /// Dossier médical: a medication start date or document date after today. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'La date ne peut pas être dans le futur.'**
  String get recordFieldDateInFuture;

  /// Dossier médical: a date that is not a valid calendar date. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Date non valide.'**
  String get recordFieldDateInvalid;

  /// Dossier médical documents: file over 15 MB. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Fichier trop volumineux (15 Mo maximum).'**
  String get recordFieldFileTooLarge;

  /// Dossier médical documents: file is not PDF, JPG or PNG. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Format non accepté : PDF, JPG ou PNG.'**
  String get recordFieldFileFormat;

  /// Dossier médical: the patient tried to change an item a professional recorded (ITEM_LOCKED). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément a été ajouté par un professionnel de santé et ne peut pas être modifié.'**
  String get recordCodeItemLocked;

  /// Dossier médical: blood type set by a professional (BLOOD_TYPE_LOCKED). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Votre groupe sanguin a été renseigné par un professionnel de santé.'**
  String get recordCodeBloodTypeLocked;

  /// Dossier médical: the section changed since it was read (RECORD_VERSION_CONFLICT). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Votre dossier a été modifié ailleurs. Rechargez pour voir la dernière version ; vos saisies sont conservées.'**
  String get recordCodeVersionConflict;

  /// Dossier médical: the same save is still running (IDEMPOTENCY_IN_PROGRESS). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement en cours, patientez un instant.'**
  String get recordCodeSaveInProgress;

  /// Dossier médical documents: the document is still being scanned (DOCUMENT_NOT_READY). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Document en cours d\'analyse. Réessayez dans quelques instants.'**
  String get recordCodeDocumentNotReady;

  /// Dossier médical: too many requests (TOO_MANY_REQUESTS). G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes. Patientez une minute.'**
  String get recordCodeTooManyRequests;

  /// Dossier médical: a saved measurement looks unusual (HEIGHT_UNUSUAL / WEIGHT_UNUSUAL); never blocks the save. G2.1-A1.
  ///
  /// In fr, this message translates to:
  /// **'Valeur inhabituelle : vérifiez-la.'**
  String get recordWarningUnusualValue;

  /// Dossier médical editor: blood type choice for « I don't know » (sends UNKNOWN). G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Je ne sais pas'**
  String get recordBloodTypeDontKnow;

  /// Dossier médical: label of a medication the patient declared (outside OmniCare), ADR-012 rule 5. G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Déclaré par le patient'**
  String get passportDeclaredByPatient;

  /// Dossier médical editor: title of the allergies chip section (ADR-012 D2). G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Allergies'**
  String get recordAllergiesTitle;

  /// Dossier médical editor: hint under the allergies title. G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez toutes les allergies connues'**
  String get recordAllergiesSubtitle;

  /// Dossier médical editor: placeholder of the free-text allergy field. G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Autre allergie...'**
  String get recordAllergiesOtherHint;

  /// Dossier médical editor: BMI category below 18.5 (REQUIRES MEDICAL VALIDATION). G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Insuffisance pondérale'**
  String get bmiCategoryUnderweight;

  /// Dossier médical editor: BMI category 18.5 to under 25 (REQUIRES MEDICAL VALIDATION). G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get bmiCategoryNormal;

  /// Dossier médical editor: BMI category 25 to under 30 (REQUIRES MEDICAL VALIDATION). G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Surpoids'**
  String get bmiCategoryOverweight;

  /// Dossier médical editor: BMI category 30 and above (REQUIRES MEDICAL VALIDATION). G2.1-A2.
  ///
  /// In fr, this message translates to:
  /// **'Obésité'**
  String get bmiCategoryObese;

  /// Onboarding conditions page: « Oui » with no condition chosen (it would otherwise be saved as none). G2.1-A3.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez au moins une maladie, ou répondez « Non ».'**
  String get onboardingErrorConditionRequired;

  /// « Documents » tab: the number of the person's documents (the whole list fits on one page). G2.1-A4.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 documents enregistrés} =1{1 document enregistré} other{{count} documents enregistrés}}'**
  String passportDocumentsCount(int count);

  /// « Documents » tab: the server has more than the loaded page and gives no total, so the count reads « 20+ ». G2.1-A4.
  ///
  /// In fr, this message translates to:
  /// **'{count}+ documents enregistrés'**
  String passportDocumentsCountMore(int count);
}

class _OmniLocalizationsDelegate
    extends LocalizationsDelegate<OmniLocalizations> {
  const _OmniLocalizationsDelegate();

  @override
  Future<OmniLocalizations> load(Locale locale) {
    return SynchronousFuture<OmniLocalizations>(
      lookupOmniLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_OmniLocalizationsDelegate old) => false;
}

OmniLocalizations lookupOmniLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return OmniLocalizationsFr();
  }

  throw FlutterError(
    'OmniLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
