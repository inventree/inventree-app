/*
 * A set of helper functions to reduce boilerplate code
 */

/*
 * Simplify a numerical value into a string,
 * supressing trailing zeroes
 */
String simpleNumberString(double number) {
  // Ref: https://stackoverflow.com/questions/55152175/how-to-remove-trailing-zeros-using-dart

  return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1);
}