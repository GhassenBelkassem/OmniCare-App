import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Language Selection
      'choose_language': 'Choose Your Language',
      'select_language': 'Select your preferred language',

      // Login/Signup
      'welcome_back': 'Welcome Back',
      'sign_in_continue': 'Sign in to continue to OmniCare',
      'create_account': 'Create Account',
      'sign_up_get_started': 'Sign up to get started with OmniCare',
      'continue_with_google': 'Sign in with Google',
      'or': 'OR',
      'email': 'Email',
      'email_hint': 'Enter your email',
      'password': 'Password',
      'password_hint': 'Enter your password',
      'confirm_password': 'Confirm Password',
      'confirm_password_hint': 'Re-enter your password',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'dont_have_account': "Don't have an account?",
      'already_have_account': 'Already have an account?',
      'email_required': 'Email is required',
      'valid_email': 'Please enter a valid email',
      'password_required': 'Password is required',
      'password_min_length': 'Password must be at least 6 characters',
      'confirm_password_required': 'Please confirm your password',
      'passwords_not_match': 'Passwords do not match',
      'forgot_password': 'Forgot Password?',

      // Forgot Password
      'reset_password': 'Reset Password',
      'reset_password_subtitle':
          'Enter your email or phone number to receive a verification code',
      'email_or_phone': 'Email or Phone Number',
      'email_or_phone_hint': 'Enter your email or phone number',
      'send_code': 'Send Code',
      'email_or_phone_required': 'Email or phone number is required',
      'create_new_password': 'Create New Password',
      'create_new_password_subtitle':
          'Your new password must be different from previous passwords',
      'new_password': 'New Password',
      'new_password_hint': 'Enter new password',
      'confirm_new_password': 'Confirm New Password',
      'confirm_new_password_hint': 'Re-enter new password',
      'reset_password_btn': 'Reset Password',
      'password_reset_success': 'Password reset successfully!',

      // OTP Verification
      'verify_email': 'Verify Email',
      'verify_phone': 'Verify Phone',
      'code_sent_to': 'We sent a code to',
      'resend_code_in': 'Resend code in',
      'resend_code': 'Resend code',
      'verify': 'Verify',
      'enter_all_digits': 'Please enter all 6 digits',

      // Phone Input
      'phone_verification': 'Phone Verification',
      'enter_phone_verification':
          'Enter your phone number to receive a verification code',
      'phone_number': 'Phone Number',
      'phone_required': 'Phone number is required',
      'valid_phone': 'Please enter a valid phone number',
      'continue': 'Continue',

      // Conversational Onboarding
      'blood_type_question': 'What is your blood type?',
      'blood_type_subtitle':
          'This helps our emergency team prepare the right blood supply for you.',
      'chronic_conditions_question': 'Any chronic conditions?',
      'chronic_conditions_subtitle':
          'Doctors use this to ensure your treatment plan is 100% safe.',
      'current_medications': 'Current Medications',
      'medications_subtitle':
          'Knowing your current meds prevents dangerous drug-to-drug interactions.',
      'search_conditions': 'Search conditions...',
      'medicine_name': 'Medicine Name',
      'dosage': 'Dosage',
      'add_another_medication': 'Add Another Medication',
      'medication': 'Medication',
      'complete': 'Complete',
      'skip': 'Skip',

      // Home Page - Hero Section
      'medical_care_on_demand': 'Medical Care On Demand',
      'hero_subtitle':
          'Connect with verified doctors in Tunisia. Get urgent medical assistance anytime, anywhere.',
      'request_urgent_doctor': 'Request Urgent Doctor',
      'talk_psychologist': 'Talk to Psychologist',
      'call_ambulance': 'Call Ambulance',

      // Home Page - Search & Filter
      'find_doctor': 'Find a Doctor',
      'search_doctors': 'Search doctors...',
      'all_specialties': 'All Specialties',
      'general_medicine': 'General Medicine',
      'cardiology': 'Cardiology',
      'pediatrics': 'Pediatrics',
      'dermatology': 'Dermatology',
      'orthopedics': 'Orthopedics',

      // Home Page - Doctor Grid
      'available_doctors': 'Available Doctors',
      'verified': 'Verified',
      'years_experience': 'years experience',
      'request_visit': 'Request Visit',
      'km_away': 'km',
      'reviews': 'reviews',

      // Home Page - Sidebar
      'medical_passport': 'Medical Passport',
      'medical_passport_desc': 'Your complete medical history in one place',
      'recent_visit': 'Recent Visit',
      'view_full_history': 'View Full History',
      'pharmacie_de_garde': 'Pharmacie de Garde',
      'open_24_7_today': 'Open 24/7 - Today',
      'view_on_map': 'View on Map',
      'call': 'Call',
      'pharmacie_centrale': 'Pharmacie Centrale',
      'pharmacie_du_lac': 'Pharmacie du Lac',
      'pharmacie_ben_arous': 'Pharmacie Ben Arous',
      'tunis_center': 'Tunis Center',
      'lac_2': 'Lac 2',
      'ben_arous': 'Ben Arous',

      // Common
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
    },
    'fr': {
      // Language Selection
      'choose_language': 'Choisissez Votre Langue',
      'select_language': 'Sélectionnez votre langue préférée',

      // Login/Signup
      'welcome_back': 'Bon Retour',
      'sign_in_continue': 'Connectez-vous pour continuer sur OmniCare',
      'create_account': 'Créer un Compte',
      'sign_up_get_started': 'Inscrivez-vous pour commencer avec OmniCare',
      'continue_with_google': 'Se connecter avec Google',
      'or': 'OU',
      'email': 'Email',
      'email_hint': 'Entrez votre email',
      'password': 'Mot de passe',
      'password_hint': 'Entrez votre mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'confirm_password_hint': 'Ressaisissez votre mot de passe',
      'sign_in': 'Se connecter',
      'sign_up': "S'inscrire",
      'dont_have_account': "Vous n'avez pas de compte?",
      'already_have_account': 'Vous avez déjà un compte?',
      'email_required': "L'email est requis",
      'valid_email': 'Veuillez entrer un email valide',
      'password_required': 'Le mot de passe est requis',
      'password_min_length':
          'Le mot de passe doit contenir au moins 6 caractères',
      'confirm_password_required': 'Veuillez confirmer votre mot de passe',
      'passwords_not_match': 'Les mots de passe ne correspondent pas',
      'forgot_password': 'Mot de passe oublié?',

      // Forgot Password
      'reset_password': 'Réinitialiser le mot de passe',
      'reset_password_subtitle':
          'Entrez votre email ou numéro de téléphone pour recevoir un code de vérification',
      'email_or_phone': 'Email ou Numéro de Téléphone',
      'email_or_phone_hint': 'Entrez votre email ou numéro de téléphone',
      'send_code': 'Envoyer le code',
      'email_or_phone_required': 'Email ou numéro de téléphone requis',
      'create_new_password': 'Créer un nouveau mot de passe',
      'create_new_password_subtitle':
          'Votre nouveau mot de passe doit être différent des précédents',
      'new_password': 'Nouveau mot de passe',
      'new_password_hint': 'Entrez le nouveau mot de passe',
      'confirm_new_password': 'Confirmer le nouveau mot de passe',
      'confirm_new_password_hint': 'Ressaisissez le nouveau mot de passe',
      'reset_password_btn': 'Réinitialiser le mot de passe',
      'password_reset_success': 'Mot de passe réinitialisé avec succès!',

      // OTP Verification
      'verify_email': 'Vérifier Email',
      'verify_phone': 'Vérifier Téléphone',
      'code_sent_to': 'Nous avons envoyé un code à',
      'resend_code_in': 'Renvoyer le code dans',
      'resend_code': 'Renvoyer le code',
      'verify': 'Vérifier',
      'enter_all_digits': 'Veuillez entrer les 6 chiffres',

      // Phone Input
      'phone_verification': 'Vérification du Téléphone',
      'enter_phone_verification':
          'Entrez votre numéro de téléphone pour recevoir un code de vérification',
      'phone_number': 'Numéro de Téléphone',
      'phone_required': 'Le numéro de téléphone est requis',
      'valid_phone': 'Veuillez entrer un numéro de téléphone valide',
      'continue': 'Continuer',

      // Conversational Onboarding
      'blood_type_question': 'Quel est votre groupe sanguin?',
      'blood_type_subtitle':
          "Cela aide notre équipe d'urgence à préparer le bon approvisionnement en sang pour vous.",
      'chronic_conditions_question': 'Des maladies chroniques?',
      'chronic_conditions_subtitle':
          'Les médecins utilisent cela pour garantir que votre plan de traitement est 100% sûr.',
      'current_medications': 'Médicaments Actuels',
      'medications_subtitle':
          'Connaître vos médicaments actuels évite les interactions médicamenteuses dangereuses.',
      'search_conditions': 'Rechercher des conditions...',
      'medicine_name': 'Nom du Médicament',
      'dosage': 'Dosage',
      'add_another_medication': 'Ajouter un Autre Médicament',
      'medication': 'Médicament',
      'complete': 'Terminer',
      'skip': 'Passer',

      // Home Page - Hero Section
      'medical_care_on_demand': 'Soins Médicaux à la Demande',
      'hero_subtitle':
          'Connectez-vous avec des médecins vérifiés en Tunisie. Obtenez une assistance médicale urgente à tout moment, n\'importe où.',
      'request_urgent_doctor': 'Demander un Médecin Urgent',
      'talk_psychologist': 'Parler à un Psychologue',
      'call_ambulance': 'Appeler une Ambulance',

      // Home Page - Search & Filter
      'find_doctor': 'Trouver un Médecin',
      'search_doctors': 'Rechercher des médecins...',
      'all_specialties': 'Toutes les Spécialités',
      'general_medicine': 'Médecine Générale',
      'cardiology': 'Cardiologie',
      'pediatrics': 'Pédiatrie',
      'dermatology': 'Dermatologie',
      'orthopedics': 'Orthopédie',

      // Home Page - Doctor Grid
      'available_doctors': 'Médecins Disponibles',
      'verified': 'Vérifié',
      'years_experience': 'ans d\'expérience',
      'request_visit': 'Demander une Visite',
      'km_away': 'km',
      'reviews': 'avis',

      // Home Page - Sidebar
      'medical_passport': 'Passeport Médical',
      'medical_passport_desc':
          'Votre historique médical complet en un seul endroit',
      'recent_visit': 'Visite Récente',
      'view_full_history': 'Voir l\'Historique Complet',
      'pharmacie_de_garde': 'Pharmacie de Garde',
      'open_24_7_today': 'Ouvert 24/7 - Aujourd\'hui',
      'view_on_map': 'Voir sur la Carte',
      'call': 'Appeler',
      'pharmacie_centrale': 'Pharmacie Centrale',
      'pharmacie_du_lac': 'Pharmacie du Lac',
      'pharmacie_ben_arous': 'Pharmacie Ben Arous',
      'tunis_center': 'Centre de Tunis',
      'lac_2': 'Lac 2',
      'ben_arous': 'Ben Arous',

      // Common
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
    },
    'ar': {
      // Language Selection
      'choose_language': 'اختر لغتك',
      'select_language': 'اختر لغتك المفضلة',

      // Login/Signup
      'welcome_back': 'مرحباً بعودتك',
      'sign_in_continue': 'سجل الدخول للمتابعة إلى OmniCare',
      'create_account': 'إنشاء حساب',
      'sign_up_get_started': 'سجل للبدء مع OmniCare',
      'continue_with_google': 'تسجيل الدخول باستخدام Google',
      'or': 'أو',
      'email': 'البريد الإلكتروني',
      'email_hint': 'أدخل بريدك الإلكتروني',
      'password': 'كلمة المرور',
      'password_hint': 'أدخل كلمة المرور',
      'confirm_password': 'تأكيد كلمة المرور',
      'confirm_password_hint': 'أعد إدخال كلمة المرور',
      'sign_in': 'تسجيل الدخول',
      'sign_up': 'التسجيل',
      'dont_have_account': 'ليس لديك حساب؟',
      'already_have_account': 'هل لديك حساب بالفعل؟',
      'email_required': 'البريد الإلكتروني مطلوب',
      'valid_email': 'يرجى إدخال بريد إلكتروني صالح',
      'password_required': 'كلمة المرور مطلوبة',
      'password_min_length': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
      'confirm_password_required': 'يرجى تأكيد كلمة المرور',
      'passwords_not_match': 'كلمات المرور غير متطابقة',
      'forgot_password': 'هل نسيت كلمة المرور؟',

      // Forgot Password
      'reset_password': 'إعادة تعيين كلمة المرور',
      'reset_password_subtitle':
          'أدخل بريدك الإلكتروني أو رقم هاتفك لتلقي رمز التحقق',
      'email_or_phone': 'البريد الإلكتروني أو رقم الهاتف',
      'email_or_phone_hint': 'أدخل بريدك الإلكتروني أو رقم هاتفك',
      'send_code': 'إرسال الرمز',
      'email_or_phone_required': 'البريد الإلكتروني أو رقم الهاتف مطلوب',
      'create_new_password': 'إنشاء كلمة مرور جديدة',
      'create_new_password_subtitle':
          'يجب أن تكون كلمة المرور الجديدة مختلفة عن كلمات المرور السابقة',
      'new_password': 'كلمة المرور الجديدة',
      'new_password_hint': 'أدخل كلمة المرور الجديدة',
      'confirm_new_password': 'تأكيد كلمة المرور الجديدة',
      'confirm_new_password_hint': 'أعد إدخال كلمة المرور الجديدة',
      'reset_password_btn': 'إعادة تعيين كلمة المرور',
      'password_reset_success': 'تم إعادة تعيين كلمة المرور بنجاح!',

      // OTP Verification
      'verify_email': 'تحقق من البريد الإلكتروني',
      'verify_phone': 'تحقق من الهاتف',
      'code_sent_to': 'لقد أرسلنا رمزاً إلى',
      'resend_code_in': 'إعادة إرسال الرمز في',
      'resend_code': 'إعادة إرسال الرمز',
      'verify': 'تحقق',
      'enter_all_digits': 'يرجى إدخال جميع الأرقام الستة',

      // Phone Input
      'phone_verification': 'التحقق من الهاتف',
      'enter_phone_verification': 'أدخل رقم هاتفك لتلقي رمز التحقق',
      'phone_number': 'رقم الهاتف',
      'phone_required': 'رقم الهاتف مطلوب',
      'valid_phone': 'يرجى إدخال رقم هاتف صالح',
      'continue': 'متابعة',

      // Conversational Onboarding
      'blood_type_question': 'ما هي فصيلة دمك؟',
      'blood_type_subtitle':
          'يساعد هذا فريق الطوارئ لدينا على تحضير إمدادات الدم المناسبة لك.',
      'chronic_conditions_question': 'هل لديك أي أمراض مزمنة؟',
      'chronic_conditions_subtitle':
          'يستخدم الأطباء هذا لضمان أن خطة العلاج الخاصة بك آمنة بنسبة 100٪.',
      'current_medications': 'الأدوية الحالية',
      'medications_subtitle':
          'معرفة أدويتك الحالية تمنع التفاعلات الدوائية الخطيرة.',
      'search_conditions': 'البحث عن الحالات...',
      'medicine_name': 'اسم الدواء',
      'dosage': 'الجرعة',
      'add_another_medication': 'إضافة دواء آخر',
      'medication': 'دواء',
      'complete': 'إكمال',
      'skip': 'تخطي',

      // Home Page - Hero Section
      'medical_care_on_demand': 'الرعاية الطبية عند الطلب',
      'hero_subtitle':
          'تواصل مع أطباء معتمدين في تونس. احصل على المساعدة الطبية العاجلة في أي وقت وفي أي مكان.',
      'request_urgent_doctor': 'طلب طبيب عاجل',
      'talk_psychologist': 'التحدث إلى طبيب نفسي',
      'call_ambulance': 'اتصل بسيارة إسعاف',

      // Home Page - Search & Filter
      'find_doctor': 'ابحث عن طبيب',
      'search_doctors': 'البحث عن الأطباء...',
      'all_specialties': 'جميع التخصصات',
      'general_medicine': 'الطب العام',
      'cardiology': 'أمراض القلب',
      'pediatrics': 'طب الأطفال',
      'dermatology': 'الأمراض الجلدية',
      'orthopedics': 'جراحة العظام',

      // Home Page - Doctor Grid
      'available_doctors': 'الأطباء المتاحون',
      'verified': 'معتمد',
      'years_experience': 'سنوات من الخبرة',
      'request_visit': 'طلب زيارة',
      'km_away': 'كم',
      'reviews': 'تقييمات',

      // Home Page - Sidebar
      'medical_passport': 'جواز السفر الطبي',
      'medical_passport_desc': 'تاريخك الطبي الكامل في مكان واحد',
      'recent_visit': 'زيارة حديثة',
      'view_full_history': 'عرض السجل الكامل',
      'pharmacie_de_garde': 'صيدلية الحراسة',
      'open_24_7_today': 'مفتوح 24/7 - اليوم',
      'view_on_map': 'عرض على الخريطة',
      'call': 'اتصل',
      'pharmacie_centrale': 'الصيدلية المركزية',
      'pharmacie_du_lac': 'صيدلية البحيرة',
      'pharmacie_ben_arous': 'صيدلية بن عروس',
      'tunis_center': 'مركز تونس',
      'lac_2': 'البحيرة 2',
      'ben_arous': 'بن عروس',

      // Common
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Convenience getters
  String get chooseLanguage => translate('choose_language');
  String get selectLanguage => translate('select_language');
  String get welcomeBack => translate('welcome_back');
  String get signInContinue => translate('sign_in_continue');
  String get createAccount => translate('create_account');
  String get signUpGetStarted => translate('sign_up_get_started');
  String get continueWithGoogle => translate('continue_with_google');
  String get or => translate('or');
  String get email => translate('email');
  String get emailHint => translate('email_hint');
  String get password => translate('password');
  String get passwordHint => translate('password_hint');
  String get confirmPassword => translate('confirm_password');
  String get confirmPasswordHint => translate('confirm_password_hint');
  String get signIn => translate('sign_in');
  String get signUp => translate('sign_up');
  String get dontHaveAccount => translate('dont_have_account');
  String get alreadyHaveAccount => translate('already_have_account');
  String get emailRequired => translate('email_required');
  String get validEmail => translate('valid_email');
  String get passwordRequired => translate('password_required');
  String get passwordMinLength => translate('password_min_length');
  String get confirmPasswordRequired => translate('confirm_password_required');
  String get passwordsNotMatch => translate('passwords_not_match');
  String get forgotPassword => translate('forgot_password');
  String get resetPassword => translate('reset_password');
  String get resetPasswordSubtitle => translate('reset_password_subtitle');
  String get emailOrPhone => translate('email_or_phone');
  String get emailOrPhoneHint => translate('email_or_phone_hint');
  String get sendCode => translate('send_code');
  String get emailOrPhoneRequired => translate('email_or_phone_required');
  String get createNewPassword => translate('create_new_password');
  String get createNewPasswordSubtitle =>
      translate('create_new_password_subtitle');
  String get newPassword => translate('new_password');
  String get newPasswordHint => translate('new_password_hint');
  String get confirmNewPassword => translate('confirm_new_password');
  String get confirmNewPasswordHint => translate('confirm_new_password_hint');
  String get resetPasswordBtn => translate('reset_password_btn');
  String get passwordResetSuccess => translate('password_reset_success');
  String get verifyEmail => translate('verify_email');
  String get verifyPhone => translate('verify_phone');
  String get codeSentTo => translate('code_sent_to');
  String get resendCodeIn => translate('resend_code_in');
  String get resendCode => translate('resend_code');
  String get verify => translate('verify');
  String get enterAllDigits => translate('enter_all_digits');
  String get phoneVerification => translate('phone_verification');
  String get enterPhoneVerification => translate('enter_phone_verification');
  String get phoneNumber => translate('phone_number');
  String get phoneRequired => translate('phone_required');
  String get validPhone => translate('valid_phone');
  String get continueBtn => translate('continue');
  String get bloodTypeQuestion => translate('blood_type_question');
  String get bloodTypeSubtitle => translate('blood_type_subtitle');
  String get chronicConditionsQuestion =>
      translate('chronic_conditions_question');
  String get chronicConditionsSubtitle =>
      translate('chronic_conditions_subtitle');
  String get currentMedications => translate('current_medications');
  String get medicationsSubtitle => translate('medications_subtitle');
  String get searchConditions => translate('search_conditions');
  String get medicineName => translate('medicine_name');
  String get dosage => translate('dosage');
  String get addAnotherMedication => translate('add_another_medication');
  String get medication => translate('medication');
  String get complete => translate('complete');
  String get skip => translate('skip');

  // Home Page getters
  String get medicalCareOnDemand => translate('medical_care_on_demand');
  String get heroSubtitle => translate('hero_subtitle');
  String get requestUrgentDoctor => translate('request_urgent_doctor');
  String get talkPsychologist => translate('talk_psychologist');
  String get callAmbulance => translate('call_ambulance');
  String get findDoctor => translate('find_doctor');
  String get searchDoctors => translate('search_doctors');
  String get allSpecialties => translate('all_specialties');
  String get generalMedicine => translate('general_medicine');
  String get cardiology => translate('cardiology');
  String get pediatrics => translate('pediatrics');
  String get dermatology => translate('dermatology');
  String get orthopedics => translate('orthopedics');
  String get availableDoctors => translate('available_doctors');
  String get verified => translate('verified');
  String get yearsExperience => translate('years_experience');
  String get requestVisit => translate('request_visit');
  String get kmAway => translate('km_away');
  String get reviews => translate('reviews');
  String get medicalPassport => translate('medical_passport');
  String get medicalPassportDesc => translate('medical_passport_desc');
  String get recentVisit => translate('recent_visit');
  String get viewFullHistory => translate('view_full_history');
  String get pharmacieDeGarde => translate('pharmacie_de_garde');
  String get open247Today => translate('open_24_7_today');
  String get viewOnMap => translate('view_on_map');
  String get call => translate('call');
  String get pharmacieCentrale => translate('pharmacie_centrale');
  String get pharmacieDuLac => translate('pharmacie_du_lac');
  String get pharmacieBenArous => translate('pharmacie_ben_arous');
  String get tunisCenter => translate('tunis_center');
  String get lac2 => translate('lac_2');
  String get benArous => translate('ben_arous');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
