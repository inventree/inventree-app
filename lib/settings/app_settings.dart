import "package:flutter/material.dart";
import "package:inventree/api.dart";
import "package:one_context/one_context.dart";

import "package:adaptive_theme/adaptive_theme.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:flutter_localized_locales/flutter_localized_locales.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";
import "package:inventree/l10n/supported_locales.dart";
import "package:inventree/main.dart";
import "package:inventree/preferences.dart";

import "package:inventree/widget/dialogs.dart";
import "package:inventree/widget/progress.dart";


class InvenTreeAppSettingsWidget extends StatefulWidget {
  @override
  _InvenTreeAppSettingsState createState() => _InvenTreeAppSettingsState();
}

class _InvenTreeAppSettingsState extends State<InvenTreeAppSettingsWidget> {

  _InvenTreeAppSettingsState();

  final GlobalKey<_InvenTreeAppSettingsState> _settingsKey = GlobalKey<_InvenTreeAppSettingsState>();

  // Sound settings
  bool barcodeSounds = true;
  bool serverSounds = true;

  bool reportErrors = true;
  bool strictHttps = false;
  bool enableLabelPrinting = true;
  bool darkMode = false;

  int screenOrientation = SCREEN_ORIENTATION_SYSTEM;

  Locale? locale;

  @override
  void initState() {
    super.initState();

    loadSettings(OneContext().context!);
  }

  Future <void> loadSettings(BuildContext context) async {

    showLoadingOverlay(context);

    barcodeSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;
    serverSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_SERVER, true) as bool;
    reportErrors = await InvenTreeSettingsManager().getValue(INV_REPORT_ERRORS, true) as bool;
    strictHttps = await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false) as bool;
    screenOrientation = await InvenTreeSettingsManager().getValue(INV_SCREEN_ORIENTATION, SCREEN_ORIENTATION_SYSTEM) as int;
    enableLabelPrinting = await InvenTreeSettingsManager().getValue(INV_ENABLE_LABEL_PRINTING, true) as bool;

    darkMode = AdaptiveTheme.of(context).mode.isDark;

    locale = await InvenTreeSettingsManager().getSelectedLocale();

    hideLoadingOverlay();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectLocale(BuildContext context) async {

    List<Map<String, dynamic>> options = [
      {
        "display_name": L10().languageDefault,
        "value": null,
      }
    ];

    // Construct a list of available locales
    for (var locale in supported_locales) {
      options.add({
        "display_name": LocaleNames.of(context)!.nameOf(locale.toString()),
        "value": locale.toString()
      });
    }

    Map<String, dynamic> fields = {
      "locale": {
        "label": L10().language,
        "type": "choice",
        "choices": options,
        "value": locale?.toString(),
      }
    };

    launchApiForm(
      context,
      L10().languageSelect,
      "",
      fields,
      icon: FontAwesomeIcons.circleCheck,
      onSuccess: (Map<String, dynamic> data) async {

        String locale_name = (data["locale"] ?? "") as String;
        Locale? selected_locale;

        for (var locale in supported_locales) {
          if (locale.toString() == locale_name) {
            selected_locale = locale;
          }
        }

        await InvenTreeSettingsManager().setSelectedLocale(selected_locale);

        setState(() {
          locale = selected_locale;
        });

        // Refresh the entire app locale
        InvenTreeApp.of(context)?.setLocale(locale);

        // Clear the cached status label information
        InvenTreeAPI().clearStatusCodeData();
      }
    );
  }


  @override
  Widget build(BuildContext context) {

    String languageName = L10().languageDefault;

    if (locale != null) {
      languageName = LocaleNames.of(context)!.nameOf(locale.toString()) ?? L10().languageDefault;
    }

    IconData orientationIcon = Icons.screen_rotation;

    switch (screenOrientation) {
      case SCREEN_ORIENTATION_PORTRAIT:
        orientationIcon = Icons.screen_lock_portrait;
        break;
      case SCREEN_ORIENTATION_LANDSCAPE:
        orientationIcon = Icons.screen_lock_landscape;
        break;
      case SCREEN_ORIENTATION_SYSTEM:
      default:
        orientationIcon = Icons.screen_rotation;
        break;
    }

    return Scaffold(
      key: _settingsKey,
      appBar: AppBar(
        title: Text(L10().appSettings),
      ),
      body: Container(
        child: ListView(
          children: [
            /* Sound Settings */
            Divider(height: 3),
            ListTile(
              title: Text(
                L10().appSettings,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.mobile),
            ),
            ListTile(
              title: Text(L10().darkMode),
              subtitle: Text(L10().darkModeEnable),
              leading: FaIcon(FontAwesomeIcons.moon),
              trailing: Switch(
                value: darkMode,
                onChanged: (bool value) {
                  if (value) {
                    AdaptiveTheme.of(context).setDark();
                  } else {
                    AdaptiveTheme.of(context).setLight();
                  }
                  setState(() {
                    darkMode = value;
                  });
                }
              )
            ),
            GestureDetector(
              child: ListTile(
                title: Text(L10().orientation),
                subtitle: Text(L10().orientationDetail),
                leading: Icon(Icons.screen_rotation_alt),
                trailing: Icon(orientationIcon),
              ),
              onTap: () async {
                choiceDialog(
                  L10().orientation,
                  [
                    ListTile(
                      leading: Icon(Icons.screen_rotation, color: screenOrientation == SCREEN_ORIENTATION_SYSTEM ? COLOR_ACTION : null),
                      title: Text(L10().orientationSystem),
                    ),
                    ListTile(
                      leading: Icon(Icons.screen_lock_portrait, color: screenOrientation == SCREEN_ORIENTATION_PORTRAIT ? COLOR_ACTION : null),
                      title: Text(L10().orientationPortrait),
                    ),
                    ListTile(
                      leading: Icon(Icons.screen_lock_landscape, color: screenOrientation == SCREEN_ORIENTATION_LANDSCAPE ? COLOR_ACTION : null),
                      title: Text(L10().orientationLandscape),
                    )
                  ],
                  onSelected: (idx) async {
                    screenOrientation = idx as int;

                    InvenTreeSettingsManager().setValue(INV_SCREEN_ORIENTATION, screenOrientation);

                    setState(() {
                    });
                  }
                );
              },
            ),
            ListTile(
              title: Text(L10().labelPrinting),
              subtitle: Text(L10().labelPrintingDetail),
              leading: FaIcon(FontAwesomeIcons.print),
              trailing: Switch(
                value: enableLabelPrinting,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_ENABLE_LABEL_PRINTING, value);
                  setState(() {
                    enableLabelPrinting = value;
                  });
                }
              ),
            ),
            ListTile(
              title: Text(L10().strictHttps),
              subtitle: Text(L10().strictHttpsDetails),
              leading: FaIcon(FontAwesomeIcons.lock),
              trailing: Switch(
                value: strictHttps,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_STRICT_HTTPS, value);
                  setState(() {
                    strictHttps = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().language),
              subtitle: Text(languageName),
              leading: FaIcon(FontAwesomeIcons.language),
              onTap: () async {
                _selectLocale(context);
              },
            ),
            ListTile(
              title: Text(L10().errorReportUpload),
              subtitle: Text(L10().errorReportUploadDetails),
              leading: FaIcon(FontAwesomeIcons.bug),
              trailing: Switch(
                value: reportErrors,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_REPORT_ERRORS, value);
                  setState(() {
                    reportErrors = value;
                  });
                },
              ),
            ),
                        ListTile(
              title: Text(
                L10().sounds,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.volumeHigh),
            ),
            Divider(),
            ListTile(
              title: Text(L10().serverError),
              subtitle: Text(L10().soundOnServerError),
              leading: FaIcon(FontAwesomeIcons.server),
              trailing: Switch(
                value: serverSounds,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_SOUNDS_SERVER, value);
                  setState(() {
                    serverSounds = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(L10().barcodeTones),
              subtitle: Text(L10().soundOnBarcodeAction),
              leading: Icon(Icons.qr_code),
              trailing: Switch(
                value: barcodeSounds,
                onChanged: (bool value) {
                  InvenTreeSettingsManager().setValue(INV_SOUNDS_BARCODE, value);
                  setState(() {
                    barcodeSounds = value;
                  });
                },
              ),
            ),
            Divider(height: 1),
          ]
        )
      )
    );
  }
}