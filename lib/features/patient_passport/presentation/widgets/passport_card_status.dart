import 'package:flutter/material.dart';

import '../../../../l10n/omni_localizations.dart';

/// What a « Dossier médical » card shows in place of its content while its
/// request runs, or after it failed (G2-FT-3). Null on a card means "show the
/// content", which keeps every existing caller unchanged.
sealed class PassportCardStatus {
  const PassportCardStatus();
}

final class PassportCardLoading extends PassportCardStatus {
  const PassportCardLoading();
}

/// A failed request: the French [message] and a retry of this card only.
final class PassportCardFailed extends PassportCardStatus {
  const PassportCardFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;
}

/// The body of a card in [status]: the theme's default progress indicator,
/// or the failure text in the body text style with a default « Réessayer »
/// text button. Never an empty list.
class PassportCardStatusBody extends StatelessWidget {
  const PassportCardStatusBody({super.key, required this.status});

  final PassportCardStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PassportCardLoading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      PassportCardFailed(:final message, :final onRetry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onRetry,
            child: Text(OmniLocalizations.of(context).passportRetry),
          ),
        ],
      ),
    };
  }
}
