
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:inventree/l10.dart';

import 'dart:async';
import 'dart:io';

// TODO - Perhaps refactor all this using flutter_form_builder - https://pub.dev/packages/flutter_form_builder


/*
 * Form field for selecting an image file,
 * either from the gallery, or from the camera.
 */
class ImagePickerField extends FormField<File> {

  static void _selectFromGallery(FormFieldState<File> field) {
    _getImageFromGallery(field);
  }

  static void _selectFromCamera(FormFieldState<File> field) {
    _getImageFromCamera(field);
  }

  static Future<void> _getImageFromGallery(FormFieldState<File> field) async {

    final picker = ImagePicker();

    final pickedImage = await picker.getImage(source: ImageSource.gallery);

    if (pickedImage != null)
    {
      field.didChange(File(pickedImage.path));
    }
  }

  static Future<void> _getImageFromCamera(FormFieldState<File> field) async {

    final picker = ImagePicker();

    final pickedImage = await picker.getImage(source: ImageSource.camera);

    if (pickedImage != null)
    {
        field.didChange(File(pickedImage.path));
    }

  }

  ImagePickerField(BuildContext context, {String? label, Function(File?)? onSaved, bool required = false}) :
      super(
        onSaved: onSaved,
        validator: (File? img) {
          if (required && (img == null)) {
            return L10().required;
          }

          return null;
        },
        builder: (FormFieldState<File> state) {

          String _label = label ?? L10().attachImage;

          return InputDecorator(
            decoration: InputDecoration(
              errorText: state.errorText,
              labelText: required ? _label + "*" : _label,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                TextButton(
                  child: Text(L10().selectImage),
                  onPressed: () {
                    _selectFromGallery(state);
                  },
                ),
                TextButton(
                  child: Text(L10().takePicture),
                  onPressed: () {
                    _selectFromCamera(state);
                  },
                )
              ],
            ),
          );
        }
      );
}


class CheckBoxField extends FormField<bool> {
  CheckBoxField({String? label, String? hint, bool initial = false, Function(bool?)? onSaved}) :
      super(
        onSaved: onSaved,
        initialValue: initial,
        builder: (FormFieldState<bool> state) {
          return CheckboxListTile(
            //dense: state.hasError,
            title: label == null ? null : Text(label),
            value: state.value,
            onChanged: state.didChange,
            subtitle: hint == null ? null : Text(hint),
          );
        }
      );
}


class StringField extends TextFormField {

  StringField({String label = "", String? hint, String? initial, Function(String?)? onSaved, Function? validator, bool allowEmpty = false, bool isEnabled = true}) :
      super(
        decoration: InputDecoration(
          labelText: allowEmpty ? label : label + "*",
          hintText: hint
        ),
        initialValue: initial,
        onSaved: onSaved,
        enabled: isEnabled,
        validator: (value) {
          if (!allowEmpty && value != null && value.isEmpty) {
            return L10().valueCannotBeEmpty;
          }

          if (validator != null) {
            return validator(value);
          }

          return null;
        }
      );
}


/*
 * Helper class for quantity values
 */
class QuantityField extends TextFormField {

  QuantityField({String label = "", String hint = "", String initial = "", double? max, TextEditingController? controller}) :
      super(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
        validator: (value) {

          if (value != null && value.isEmpty) return L10().quantityEmpty;

          double quantity = double.tryParse(value.toString()) ?? 0;

          if (quantity <= 0) return L10().quantityPositive;
          if ((max != null) && (quantity > max)) return "Quantity must not exceed ${max}";

          return null;
        },
      );
}