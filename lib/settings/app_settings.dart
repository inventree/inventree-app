
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:flutter_localized_locales/flutter_localized_locales.dart";

import "package:inventree/api_form.dart";
import "package:inventree/l10.dart";
import "package:inventree/l10n/supported_locales.dart";
import "package:inventree/main.dart";
import "package:inventree/preferences.dart";


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

  Locale? locale;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future <void> loadSettings() async {
    barcodeSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_BARCODE, true) as bool;
    serverSounds = await InvenTreeSettingsManager().getValue(INV_SOUNDS_SERVER, true) as bool;
    reportErrors = await InvenTreeSettingsManager().getValue(INV_REPORT_ERRORS, true) as bool;
    strictHttps = await InvenTreeSettingsManager().getValue(INV_STRICT_HTTPS, false) as bool;

    locale = await InvenTreeSettingsManager().getSelectedLocale();

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
      icon: FontAwesomeIcons.checkCircle,
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
      }
    );

  }

  @override
  Widget build(BuildContext context) {

    String languageName = L10().languageDefault;

    if (locale != null) {
      languageName = LocaleNames.of(context)!.nameOf(locale.toString()) ?? L10().languageDefault;
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
                L10().sounds,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.volumeUp),
            ),
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
            ListTile(
              title: Text(
                L10().appSettings,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: FaIcon(FontAwesomeIcons.mobile),
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
          ]
        )
      )
    );
  }
}