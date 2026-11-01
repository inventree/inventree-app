import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/auth/auth_manager.dart";
import "package:inventree/auth/auth_result.dart";
import "package:inventree/l10.dart";
import "package:inventree/settings/login.dart";
import "package:inventree/user_profile.dart";
import "package:inventree/widget/progress.dart";

/*
 * Second login step - enter a TOTP (or recovery) code
 */
class InvenTreeMfaWidget extends StatefulWidget {
  const InvenTreeMfaWidget(this.profile, this.flow) : super();

  final UserProfile profile;

  // The pending MFA flow (provides the available authenticator types)
  final AuthFlow flow;

  @override
  _InvenTreeMfaState createState() => _InvenTreeMfaState();
}

class _InvenTreeMfaState extends State<InvenTreeMfaWidget> {
  final formKey = GlobalKey<FormState>();

  String code = "";

  // Enter a recovery code, rather than a TOTP code
  bool _useRecoveryCode = false;

  // Ask the server to skip MFA on this device in future
  bool _trustDevice = false;

  String error = "";

  bool get _supportsTotp => widget.flow.types.contains(MFA_TYPE_TOTP);

  @override
  void initState() {
    super.initState();

    // Only recovery codes available
    _useRecoveryCode = !_supportsTotp;
  }

  Future<void> _submit(BuildContext context) async {
    formKey.currentState?.save();

    bool valid = formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    FocusScopeNode currentFocus = FocusScope.of(context);

    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    showLoadingOverlay();

    setState(() {
      error = "";
    });

    final AuthResult result = await InvenTreeAuth().submitMfaCode(
      code,
      trustDevice: _trustDevice,
    );

    if (!context.mounted) {
      hideLoadingOverlay();
      return;
    }

    await handleAuthResult(context, widget.profile, result, (String err) {
      if (mounted) {
        setState(() {
          error = err;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> after = [];

    if (error.isNotEmpty) {
      after.add(Divider());
      after.add(
        ListTile(
          leading: Icon(TablerIcons.exclamation_circle, color: COLOR_DANGER),
          title: Text(L10().error, style: TextStyle(color: COLOR_DANGER)),
          subtitle: Text(error, style: TextStyle(color: COLOR_DANGER)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(L10().mfaTitle),
        actions: [
          IconButton(
            icon: Icon(TablerIcons.transition_right, color: COLOR_SUCCESS),
            onPressed: () async {
              _submit(context);
            },
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(L10().mfaTitle),
                subtitle: Text(
                  _useRecoveryCode
                      ? L10().mfaEnterRecoveryCode
                      : L10().mfaEnterCode,
                ),
                leading: Icon(TablerIcons.shield_lock),
              ),
              ListTile(
                title: Text(L10().server),
                subtitle: Text(widget.profile.server),
                leading: Icon(TablerIcons.server),
              ),
              Divider(),
              TextFormField(
                // Rebuild the field when switching code type
                key: ValueKey(_useRecoveryCode),
                decoration: InputDecoration(
                  labelText: _useRecoveryCode
                      ? L10().mfaRecoveryCode
                      : L10().mfaCode,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                initialValue: "",
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: _useRecoveryCode
                    ? null
                    : [AutofillHints.oneTimeCode],
                keyboardType: _useRecoveryCode
                    ? TextInputType.visiblePassword
                    : TextInputType.number,
                inputFormatters: _useRecoveryCode
                    ? null
                    : [FilteringTextInputFormatter.digitsOnly],
                onSaved: (value) {
                  code = value?.trim() ?? "";
                },
                onFieldSubmitted: (value) {
                  _submit(context);
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return L10().mfaCodeEmpty;
                  }

                  return null;
                },
              ),
              if (_supportsTotp && widget.flow.supportsRecoveryCodes)
                SwitchListTile(
                  title: Text(L10().mfaUseRecoveryCode),
                  value: _useRecoveryCode,
                  onChanged: (value) {
                    setState(() {
                      _useRecoveryCode = value;
                    });
                  },
                ),
              CheckboxListTile(
                title: Text(L10().mfaTrustDevice),
                subtitle: Text(L10().mfaTrustDeviceDetail),
                value: _trustDevice,
                onChanged: (value) {
                  setState(() {
                    _trustDevice = value ?? false;
                  });
                },
              ),
              ...after,
            ],
          ),
          padding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}
