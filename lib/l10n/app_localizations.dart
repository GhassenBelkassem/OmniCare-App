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

      // P4 synthetic urgent setup
      'p4_triage_title': 'Urgent care details',
      'p4_triage_intro':
          'Select affected areas and pain intensity. This does not replace emergency services.',
      'p4_body_front': 'Front view',
      'p4_body_back': 'Back view',
      'p4_body_instruction': 'Tap each affected area',
      'p4_selected_areas': 'Selected areas',
      'p4_reset': 'Reset',
      'p4_pain_title': 'Pain intensity',
      'p4_pain_low': 'Mild',
      'p4_pain_medium': 'Moderate',
      'p4_pain_severe': 'Severe',
      'p4_private_note': 'Optional private note',
      'p4_private_note_policy':
          'Patient-private synthetic note. Storage and disclosure remain pending policy approval.',
      'p4_voice_disabled': 'Voice is disabled pending approval.',
      'p4_validation': 'Select at least one body area.',
      'p4_continue': 'Continue',
      'p4_retry': 'Retry',
      'p4_triage_unavailable': 'Structured triage is temporarily unavailable.',
      'p4_home_destination': 'Confirm HOME destination',
      'p4_location_private':
          'Exact location remains Patient-owned and is not shown before commitment.',
      'p4_permission_request': 'Use synthetic current location',
      'p4_permission_denied':
          'Location permission is denied. Choose an address manually.',
      'p4_permission_forever':
          'Location permission is permanently denied. Open settings or choose manually.',
      'p4_gps_unavailable': 'Location service is unavailable.',
      'p4_acquiring': 'Acquiring a synthetic location…',
      'p4_low_accuracy': 'Location accuracy is low. Review before continuing.',
      'p4_stale': 'This location is stale. Refresh or choose manually.',
      'p4_manual_address': 'Choose synthetic address manually',
      'p4_map_unavailable':
          'Map/search is unavailable; manual confirmation remains available.',
      'p4_confirm_destination': 'Confirm destination',
      'p4_offline_unsent':
          'Saved locally but not submitted. Reconnect to continue.',
      'p4_cabinet_title': 'Choose an urgent Doctor and cabinet',
      'p4_cabinet_intro':
          'Your target choice comes before the Doctor can accept.',
      'p4_search': 'Search Doctor, cabinet, or specialty',
      'p4_directory_empty': 'No synthetic urgent cabinet matches this search.',
      'p4_directory_failure': 'The synthetic directory is unavailable.',
      'p4_fee_version': 'Fee version',
      'p4_select_target': 'Select this Doctor and cabinet',
      'p4_review_title': 'Review urgent attempt',
      'p4_edit_triage': 'Edit triage',
      'p4_edit_destination': 'Edit destination',
      'p4_edit_target': 'Edit target',
      'p4_confirm_setup': 'Confirm setup',
      'p4_setup_complete': 'Static setup complete',
      'p4_setup_stop':
          'This milestone stops before matching or Doctor acceptance.',
      'p4_feature_unavailable': 'Urgent demo unavailable',
      'p4_feature_unavailable_body':
          'The synthetic P4 experience is disabled in this build.',
      'p4_pain_pending': 'Pending approval',

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

      // P4 synthetic urgent setup
      'p4_triage_title': 'Détails des soins urgents',
      'p4_triage_intro':
          'Sélectionnez les zones atteintes et l’intensité. Ceci ne remplace pas les services d’urgence.',
      'p4_body_front': 'Vue de face',
      'p4_body_back': 'Vue de dos',
      'p4_body_instruction': 'Touchez chaque zone atteinte',
      'p4_selected_areas': 'Zones sélectionnées',
      'p4_reset': 'Réinitialiser',
      'p4_pain_title': 'Intensité de la douleur',
      'p4_pain_low': 'Légère',
      'p4_pain_medium': 'Modérée',
      'p4_pain_severe': 'Sévère',
      'p4_private_note': 'Note privée facultative',
      'p4_private_note_policy':
          'Note synthétique privée du Patient. Conservation et divulgation restent en attente d’approbation.',
      'p4_voice_disabled': 'La voix est désactivée en attente d’approbation.',
      'p4_validation': 'Sélectionnez au moins une zone du corps.',
      'p4_continue': 'Continuer',
      'p4_retry': 'Réessayer',
      'p4_triage_unavailable':
          'Le triage structuré est temporairement indisponible.',
      'p4_home_destination': 'Confirmer la destination HOME',
      'p4_location_private':
          'La position exacte reste contrôlée par le Patient et n’est pas affichée avant engagement.',
      'p4_permission_request': 'Utiliser la position synthétique actuelle',
      'p4_permission_denied':
          'Permission de localisation refusée. Choisissez une adresse manuellement.',
      'p4_permission_forever':
          'Permission refusée définitivement. Ouvrez les réglages ou choisissez manuellement.',
      'p4_gps_unavailable': 'Le service de localisation est indisponible.',
      'p4_acquiring': 'Acquisition d’une position synthétique…',
      'p4_low_accuracy': 'Précision faible. Vérifiez avant de continuer.',
      'p4_stale':
          'Cette position est ancienne. Actualisez ou choisissez manuellement.',
      'p4_manual_address': 'Choisir une adresse synthétique manuellement',
      'p4_map_unavailable':
          'Carte/recherche indisponible ; la confirmation manuelle reste possible.',
      'p4_confirm_destination': 'Confirmer la destination',
      'p4_offline_unsent':
          'Enregistré localement mais non envoyé. Reconnectez-vous.',
      'p4_cabinet_title': 'Choisir un médecin et un cabinet urgents',
      'p4_cabinet_intro':
          'Votre choix de cible précède l’acceptation du médecin.',
      'p4_search': 'Rechercher médecin, cabinet ou spécialité',
      'p4_directory_empty': 'Aucun cabinet urgent synthétique ne correspond.',
      'p4_directory_failure': 'L’annuaire synthétique est indisponible.',
      'p4_fee_version': 'Version du tarif',
      'p4_select_target': 'Choisir ce médecin et ce cabinet',
      'p4_review_title': 'Vérifier la tentative urgente',
      'p4_edit_triage': 'Modifier le triage',
      'p4_edit_destination': 'Modifier la destination',
      'p4_edit_target': 'Modifier la cible',
      'p4_confirm_setup': 'Confirmer la préparation',
      'p4_setup_complete': 'Préparation statique terminée',
      'p4_setup_stop':
          'Ce jalon s’arrête avant le matching ou l’acceptation du médecin.',
      'p4_feature_unavailable': 'Démo urgente indisponible',
      'p4_feature_unavailable_body':
          'L’expérience synthétique P4 est désactivée dans cette version.',
      'p4_pain_pending': 'En attente d’approbation',

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

      // P4 synthetic urgent setup
      'p4_triage_title': 'تفاصيل الرعاية العاجلة',
      'p4_triage_intro':
          'حدّد المناطق المتأثرة وشدة الألم. هذا لا يحل محل خدمات الطوارئ.',
      'p4_body_front': 'الواجهة الأمامية',
      'p4_body_back': 'الواجهة الخلفية',
      'p4_body_instruction': 'المس كل منطقة متأثرة',
      'p4_selected_areas': 'المناطق المحددة',
      'p4_reset': 'إعادة تعيين',
      'p4_pain_title': 'شدة الألم',
      'p4_pain_low': 'خفيف',
      'p4_pain_medium': 'متوسط',
      'p4_pain_severe': 'شديد',
      'p4_private_note': 'ملاحظة خاصة اختيارية',
      'p4_private_note_policy':
          'ملاحظة اصطناعية خاصة بالمريض. التخزين والكشف بانتظار الموافقة.',
      'p4_voice_disabled': 'الإدخال الصوتي معطل بانتظار الموافقة.',
      'p4_validation': 'حدد منطقة واحدة على الأقل من الجسم.',
      'p4_continue': 'متابعة',
      'p4_retry': 'إعادة المحاولة',
      'p4_triage_unavailable': 'الفرز المنظم غير متاح مؤقتاً.',
      'p4_home_destination': 'تأكيد وجهة المنزل',
      'p4_location_private':
          'يبقى الموقع الدقيق تحت تحكم المريض ولا يظهر قبل الالتزام.',
      'p4_permission_request': 'استخدام الموقع الاصطناعي الحالي',
      'p4_permission_denied': 'تم رفض إذن الموقع. اختر عنواناً يدوياً.',
      'p4_permission_forever':
          'تم رفض الإذن نهائياً. افتح الإعدادات أو اختر يدوياً.',
      'p4_gps_unavailable': 'خدمة الموقع غير متاحة.',
      'p4_acquiring': 'جارٍ الحصول على موقع اصطناعي…',
      'p4_low_accuracy': 'دقة الموقع منخفضة. راجعه قبل المتابعة.',
      'p4_stale': 'هذا الموقع قديم. حدّثه أو اختر يدوياً.',
      'p4_manual_address': 'اختيار عنوان اصطناعي يدوياً',
      'p4_map_unavailable':
          'الخريطة/البحث غير متاح؛ يبقى التأكيد اليدوي متاحاً.',
      'p4_confirm_destination': 'تأكيد الوجهة',
      'p4_offline_unsent': 'محفوظ محلياً ولم يُرسل. أعد الاتصال للمتابعة.',
      'p4_cabinet_title': 'اختر طبيباً وعيادة للحالة العاجلة',
      'p4_cabinet_intro': 'اختيارك للطبيب والعيادة يسبق قبول الطبيب.',
      'p4_search': 'البحث عن طبيب أو عيادة أو تخصص',
      'p4_directory_empty': 'لا توجد عيادة عاجلة اصطناعية مطابقة.',
      'p4_directory_failure': 'الدليل الاصطناعي غير متاح.',
      'p4_fee_version': 'إصدار السعر',
      'p4_select_target': 'اختيار هذا الطبيب والعيادة',
      'p4_review_title': 'مراجعة المحاولة العاجلة',
      'p4_edit_triage': 'تعديل الفرز',
      'p4_edit_destination': 'تعديل الوجهة',
      'p4_edit_target': 'تعديل الاختيار',
      'p4_confirm_setup': 'تأكيد الإعداد',
      'p4_setup_complete': 'اكتمل الإعداد الثابت',
      'p4_setup_stop': 'تتوقف هذه المرحلة قبل المطابقة أو قبول الطبيب.',
      'p4_feature_unavailable': 'العرض العاجل غير متاح',
      'p4_feature_unavailable_body':
          'تجربة P4 الاصطناعية معطلة في هذا الإصدار.',
      'p4_pain_pending': 'بانتظار الموافقة',

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
