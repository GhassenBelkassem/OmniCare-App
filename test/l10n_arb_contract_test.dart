// G-2 1b-1: French default and ARB (gen-l10n). Logic only (CTO testing
// rule): reads the ARB, the generated class and the Dart sources; no widget.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/l10n/app_locale.dart';
import 'package:omnicare_mobile/core/l10n/blood_type_label.dart';
import 'package:omnicare_mobile/core/models/blood_type.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/save_error_message.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_progress.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_history/presentation/request_status_copy.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

const _arbPath = 'lib/l10n/app_fr.arb';
const _generatedPath = 'lib/l10n/omni_localizations.dart';

/// Messages are read through a variable named `l10n` or
/// `OmniLocalizations.of(context)` (checked below), so this finds every use.
final _use = RegExp(
  r'(?:\bl10n|OmniLocalizations\.of\(\s*context\s*,?\s*\))\s*\.\s*([a-zA-Z_]\w*)',
);
final _otherName = RegExp(
  r'(?:OmniLocalizations\s+(\w+)\b|(\w+)\s*=\s*OmniLocalizations\.of)',
);

Map<String, dynamic> _arb() =>
    jsonDecode(File(_arbPath).readAsStringSync()) as Map<String, dynamic>;

Set<String> _arbKeys() => _arb().keys.where((k) => !k.startsWith('@')).toSet();

/// Every app source except the generated localizations.
Iterable<File> _appSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.startsWith('lib/l10n/omni_localizations'));

void main() {
  final fr = lookupOmniLocalizations(const Locale('fr'));

  group('ARB ↔ code drift', () {
    test('every ARB key is used and every used key exists', () {
      final keys = _arbKeys();
      final used = <String>{};
      for (final file in _appSources()) {
        used.addAll(
          _use.allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
        );
      }
      expect(used.difference(keys), isEmpty, reason: 'used but not in ARB');
      expect(keys.difference(used), isEmpty, reason: 'in ARB but unused');
    });

    test('messages are only read as l10n / OmniLocalizations.of(context)', () {
      final offenders = <String>[];
      for (final file in _appSources()) {
        final source = file.readAsStringSync();
        for (final match in _otherName.allMatches(source)) {
          final name = match.group(1) ?? match.group(2);
          if (name != 'l10n') offenders.add('${file.path}: $name');
        }
        // No hidden global lookup: the screen passes its l10n down.
        if (source.contains('lookupOmniLocalizations(')) {
          offenders.add('${file.path}: lookupOmniLocalizations');
        }
      }
      expect(offenders, isEmpty);
    });

    test('every key has a description (Flutter guide, @key metadata)', () {
      final arb = _arb();
      expect(arb['@@locale'], 'fr');
      for (final key in _arbKeys()) {
        final meta = arb['@$key'];
        expect(meta, isA<Map<String, dynamic>>(), reason: key);
        expect(
          ((meta as Map)['description'] as String? ?? '').trim(),
          isNotEmpty,
          reason: key,
        );
      }
    });

    test('generated class matches the ARB (run flutter gen-l10n)', () {
      final generated = File(_generatedPath).readAsStringSync();
      // A message with placeholders is generated as a method (G2-FT-3).
      final getters = RegExp(
        r'String (?:get (\w+);|(\w+)\()',
      ).allMatches(generated).map((m) => m.group(1) ?? m.group(2)!).toSet();
      expect(getters, _arbKeys());
    });

    test('the old string sources are gone', () {
      expect(
        File('lib/core/l10n/pending_fr_strings.dart').existsSync(),
        isFalse,
      );
      expect(File('lib/l10n/app_localizations.dart').existsSync(), isFalse);
      for (final file in _appSources()) {
        final source = file.readAsStringSync();
        expect(source.contains('PendingFrStrings'), isFalse, reason: file.path);
        expect(
          source.contains('l10n/app_localizations.dart'),
          isFalse,
          reason: file.path,
        );
      }
    });
  });

  group('French is the default and only language (V1)', () {
    test('supported locales are French only', () {
      expect(appLocale, const Locale('fr'));
      expect(OmniLocalizations.supportedLocales, [const Locale('fr')]);
      expect(
        OmniLocalizations.delegate.isSupported(const Locale('en')),
        isFalse,
      );
      expect(
        OmniLocalizations.delegate.isSupported(const Locale('ar')),
        isFalse,
      );
    });

    test('any device locale resolves to French', () {
      for (final device in const [
        [Locale('en', 'US')],
        [Locale('ar', 'TN'), Locale('en')],
        [Locale('fr', 'TN')],
        <Locale>[],
      ]) {
        expect(
          basicLocaleListResolution(device, OmniLocalizations.supportedLocales),
          const Locale('fr'),
          reason: '$device',
        );
      }
    });

    test('main.dart fixes the locale; the profile language does not', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('locale: appLocale'));
      expect(
        main,
        contains('supportedLocales: OmniLocalizations.supportedLocales'),
      );
      expect(
        main,
        contains(
          'localizationsDelegates: OmniLocalizations.localizationsDelegates',
        ),
      );
      expect(main.contains('preferredLanguage'), isFalse);
      expect(main.contains('onboarding.language'), isFalse);
    });
  });

  group('same French text as before the move (1a-2, 1a-3, 1a-4, 1a-6)', () {
    // The values pending_fr_strings.dart held, copied verbatim.
    const before = <String, String>{
      'bloodTypeUnknown': 'Je ne sais pas',
      'saveInvalidInput':
          'Certaines informations ne sont pas valides. Vérifiez et réessayez.',
      'saveNetwork': 'Connexion impossible. Réessayez.',
      'saveServiceUnavailable':
          'Service momentanément indisponible. Réessayez plus tard.',
      'saveGeneric': 'Enregistrement impossible pour le moment. Réessayez.',
      'onboardingSaveFailed':
          "Impossible d'enregistrer. Vérifiez votre connexion et réessayez.",
      'urgentCabinetUnavailableTitle': 'Service indisponible',
      'urgentCabinetUnavailableMessage':
          'La demande urgente au cabinet n’est pas disponible pour le moment.',
      'conditionsAndTreatmentsNotSaved':
          'Les antécédents et traitements ne peuvent pas encore être enregistrés.',
      'requestNoShowLabel': 'Rendez-vous manqué',
      'requestNoShowDescription':
          'La clinique a indiqué que ce rendez-vous n’a pas eu lieu.',
      'requestNoShowActionMessage': 'Demande terminée',
      'onboardingPageAlreadySaved':
          'Ces informations sont déjà enregistrées. Vous pourrez les modifier '
          'plus tard depuis votre profil.',
      // Reachable legacy keys (reset password screen), French map values.
      'passwordRequired': 'Le mot de passe est requis',
      'confirmPasswordRequired': 'Veuillez confirmer votre mot de passe',
      'passwordsNotMatch': 'Les mots de passe ne correspondent pas',
    };

    test('ARB values', () {
      final arb = _arb();
      for (final entry in before.entries) {
        expect(arb[entry.key], entry.value, reason: entry.key);
      }
    });

    test('the logic that uses them returns the same text', () {
      // 1a-2 save errors.
      expect(
        saveErrorMessage(
          const ApiException('x', code: 'INVALID_INPUT', statusCode: 400),
          fr,
        ),
        before['saveInvalidInput'],
      );
      expect(
        saveErrorMessage(
          const ApiException('x', code: 'MRS_UNAVAILABLE', statusCode: 503),
          fr,
        ),
        before['saveServiceUnavailable'],
      );
      expect(
        saveErrorMessage(
          DioException(
            requestOptions: RequestOptions(path: '/p'),
            type: DioExceptionType.connectionError,
          ),
          fr,
        ),
        before['saveNetwork'],
      );
      expect(saveErrorMessage(StateError('x'), fr), before['saveGeneric']);
      // 1a-2b blood type.
      expect(BloodType.unknown.label(fr), before['bloodTypeUnknown']);
      expect(BloodType.abNegative.label(fr), 'AB-');
      // 1a-6 onboarding.
      expect(
        onboardingSaveErrorMessage(StateError('x'), fr),
        before['onboardingSaveFailed'],
      );
      // 1a-4 NO_SHOW.
      final copy = RequestStatusCopy.of(PatientRequestStatus.noShow, fr);
      expect(copy.label, before['requestNoShowLabel']);
      expect(copy.description, before['requestNoShowDescription']);
      expect(copy.actionMessage, before['requestNoShowActionMessage']);
      // 1a-3 and 1a-4 onboarding notice: read straight from the generated
      // class (shown by widgets).
      expect(
        fr.urgentCabinetUnavailableTitle,
        before['urgentCabinetUnavailableTitle'],
      );
      expect(
        fr.urgentCabinetUnavailableMessage,
        before['urgentCabinetUnavailableMessage'],
      );
      expect(
        fr.conditionsAndTreatmentsNotSaved,
        before['conditionsAndTreatmentsNotSaved'],
      );
      expect(
        fr.onboardingPageAlreadySaved,
        before['onboardingPageAlreadySaved'],
      );
    });
  });
}
