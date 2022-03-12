import 'dart:math';

class Global {
  static String generateCode(
      [int length = 16,
      String chars =
          "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"]) {
    var rand = Random();

    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rand.nextInt(chars.length))));
  }
}
