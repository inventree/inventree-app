import "dart:async";
import "dart:io";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:image_picker/image_picker.dart";
import "package:one_context/one_context.dart";

import "package:inventree/l10.dart";


class FilePickerDialog {

  static Future<File?> pickImageFromCamera() async {

    final picker = ImagePicker();

    final pickedImage = await picker.pickImage(source: ImageSource.camera);

    if (pickedImage != null) {
      return File(pickedImage.path);
    }

    return null;
  }

  static Future<File?> pickImageFromGallery() async {

    final picker = ImagePicker();

    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      return File(pickedImage.path);
    }

    return null;
  }

  static Future<File?> pickFileFromDevice() async {

    final FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String? path = result.files.single.path;

      if (path != null) {
        return File(path);
      }
    }

    return null;
  }

  // Present a dialog to pick a file, either from local file system or from camera
  static Future<void> pickFile({String message = "", bool allowImages = true, bool allowFiles = true, Function(File)? onPicked}) async {

    String title = "";

    if (allowImages && !allowFiles) {
      title = L10().selectImage;
    } else {
      title = L10().selectFile;
    }

    // Construct actions
    List<Widget> actions = [

    ];

    if (message.isNotEmpty) {
      actions.add(
        ListTile(
          title: Text(message)
        )
      );
    }

    actions.add(
      SimpleDialogOption(
        child: ListTile(
          leading: FaIcon(FontAwesomeIcons.fileArrowUp),
          title: Text(allowFiles ? L10().selectFile : L10().selectImage),
        ),
        onPressed: () async {

          // Close the dialog
          OneContext().popDialog();

          File? file;
          if (allowFiles) {
            file = await pickFileFromDevice();
          } else {
            file = await pickImageFromGallery();
          }

          if (file != null) {
            if (onPicked != null) {
              onPicked(file);
            }
          }
        },
      )
    );

    if (allowImages) {
      actions.add(
        SimpleDialogOption(
          child: ListTile(
            leading: FaIcon(FontAwesomeIcons.camera),
            title: Text(L10().takePicture),
          ),
          onPressed: () async {
            // Close the dialog
            OneContext().popDialog();

            File? file = await pickImageFromCamera();

            if (file != null) {
              if (onPicked != null) {
                onPicked(file);
              }
            }
          }
        )
      );
    }

    OneContext().showDialog(
        builder: (context) {
        return SimpleDialog(
          title: Text(title),
          children: actions,
        );
      }
    );
  }

}


class CheckBoxField extends FormField<bool> {
  CheckBoxField({
      String? label,
      bool? initial = false,
      bool tristate = false,
      Function(bool?)? onSaved,
      TextStyle? labelStyle,
      String? helperText,
      TextStyle? helperStyle,
  }) :
      super(
        onSaved: onSaved,
        initialValue: initial,
        builder: (FormFieldState<bool> state) {
          return CheckboxListTile(
            //dense: state.hasError,
            title: label != null ? Text(label, style: labelStyle) : null,
            value: state.value,
            tristate: tristate,
            onChanged: state.didChange,
            subtitle: helperText != null ? Text(helperText, style: helperStyle) : null,
            contentPadding: EdgeInsets.zero,
          );
        }
      );
}

class StringField extends TextFormField {

  StringField({String label = "", String? hint, String? initial, Function(String?)? onSaved, Function(String?)? validator, bool allowEmpty = false, bool isEnabled = true}) :
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
            return validator(value) as String?;
          }

          return null;
        }
      );
}


/*
 * Helper class for quantity values
 */
class QuantityField extends TextFormField {

  QuantityField({String label = "", String hint = "", double? max, TextEditingController? controller}) :
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