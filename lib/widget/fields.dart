
import 'package:flutter/material.dart';

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