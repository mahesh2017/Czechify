import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'settings_providers.dart';

/// Strings for messages a provider puts into state for a screen to show.
///
/// Providers have no BuildContext, so their error messages were written in
/// English and showed as English in the Czech interface. This resolves the
/// same locale the app is displaying: the learner's choice, else the device's.
AppLocalizations providerL10n(Ref ref) =>
    lookupAppLocalizations(ref.read(settingsProvider).locale ?? deviceLocale());

/// The device locale, narrowed to one the app has strings for.
Locale deviceLocale() {
  final device = PlatformDispatcher.instance.locale;
  return AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == device.languageCode,
      )
      ? Locale(device.languageCode)
      : const Locale('en');
}
