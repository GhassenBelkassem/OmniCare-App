import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

String p4Copy(BuildContext context, String key) =>
    (AppLocalizations.of(context) ??
            AppLocalizations(Localizations.localeOf(context)))
        .translate(key);
