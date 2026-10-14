import '../../l10n/app_localizations.dart';
import 'preferences/client_preferences.dart';

extension LocalizedControlPage on ControlPage {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ControlPage.mouse => l10n.mouse,
    ControlPage.media => l10n.media,
    ControlPage.keyboard => l10n.keyboard,
  };
}
