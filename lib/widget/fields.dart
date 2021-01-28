
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

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
    
    File image;
    
    await ImagePicker.pickImage(source: ImageSource.gallery).then((File img) {
      image = img;
    });

    field.didChange(image);
  }

  static Future<void> _getImageFromCamera(FormFieldState<File> field) async {
    File image;

    await ImagePicker.pickImage(source: ImageSource.camera).then((File img) {
      image = img;
    });

    field.didChange(image);
  }

  ImagePickerField({String label = "Attach Image", Function onSaved, bool required = false}) :
      super(
        onSaved: onSaved,
        validator: (File img) {
          if (required && (img == null)) {
            return "Required";
          }

          return null;
        },
        builder: (FormFieldState<File> state) {
          return InputDecorator(
            decoration: InputDecoration(
              errorText: state.errorText,
              labelText: required ? label + "*" : label,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                FlatButton(
                  child: Text("Select Image"),
                  onPressed: () {
                    _selectFromGallery(state);
                  },
                ),
                FlatButton(
                  child: Text("Take Picture"),
                  onPressed: () {
                    _selectFromCamera(state);
                  },
                )
              ],
            ),
          );
          return ListTile(
            title: Text("Select Image"),
          );
        }
      );
}


class CheckBoxField extends FormField<bool> {
  CheckBoxField({String label, String hint, bool initial = false, Function onSaved}) :
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

  StringField({String label, String hint, String initial, Function onSaved, Function validator, bool allowEmpty = false, bool isEnabled = true}) :
      super(
        decoration: InputDecoration(
          labelText: allowEmpty ? label : label + "*",
          hintText: hint
        ),
        initialValue: initial,
        onSaved: onSaved,
        enabled: isEnabled,
        validator: (value) {
          if (!allowEmpty && value.isEmpty) {
            return "Value cannot be empty";
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

  QuantityField({String label = "", String hint = "", String initial = "", double max = null, TextEditingController controller}) :
      super(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
        validator: (value) {
          if (value.isEmpty) return "Quantity is empty";

          double quantity = double.tryParse(value);

          if (quantity == null) return "Invalid quantity";
          if (quantity <= 0) return "Quantity must be positive";
          if ((max != null) && (quantity > max)) return "Quantity must not exceed ${max}";

          return null;
        },
      );
}