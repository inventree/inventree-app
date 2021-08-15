

import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventree/inventree/sentry.dart';
import 'package:inventree/widget/snacks.dart';

import '../l10.dart';

class SubmitFeedbackWidget extends StatefulWidget {

  @override
  _SubmitFeedbackState createState() => _SubmitFeedbackState();

}


class _SubmitFeedbackState extends State<SubmitFeedbackWidget> {

  final _formkey = new GlobalKey<FormState>();

  String message = "";

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(L10().submitFeedback),
        actions: [
          IconButton(
            icon: FaIcon(FontAwesomeIcons.paperPlane),
            onPressed: () async {
              if (_formkey.currentState!.validate()) {
                _formkey.currentState!.save();

                // Upload
                bool result = await sentryReportMessage(message);

                if (result) {
                  showSnackIcon(
                    L10().feedbackSuccess,
                    success: true,
                  );
                } else {
                  showSnackIcon(
                    L10().feedbackError,
                    success: false
                  );
                }

                // Exit
                Navigator.of(context).pop();
              }
            },
          )
        ],
      ),
      body: Form(
        key: _formkey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: L10().feedback,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return L10().valueCannotBeEmpty;
                  }
                },
                onSaved: (value) {
                  if (value != null) {
                    message = value;
                  }
                },
              ),
            ],
          )
        )
      )
    );
  }

}