
import 'package:flutter/material.dart';


class StringField extends TextFormField {

  StringField({String label, String hint, String initial, Function onSaved, Function validator, bool allowEmpty = false}) :
      super(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint
        ),
        initialValue: initial,
        onSaved: onSaved,
        validator: (value) {
          print("Value: ${value}");
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
        initialValue: initial,
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