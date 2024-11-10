import 'dart:math';

import '../Data/DC.dart';

class Global {
  static String generateCode(
      [int length = 16,
      String chars =
          "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"]) {
    var rand = Random();

    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rand.nextInt(chars.length))));
  }

  static DC generateDC(int length) {
    var rand = Random();
    var rt = DC(length);
    for (var i = 0; i < length; i++) rt.setInt8(i, rand.nextInt(255));
    return rt;
  }
}
