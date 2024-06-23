import '../../Data/IntType.dart';

class IIPAuthPacketIAuthHeader {
  static UInt8 Reference = UInt8(0);
  static UInt8 Destination = UInt8(1);
  static UInt8 Clue = UInt8(2);
  static UInt8 RequiredFormat = UInt8(3);
  static UInt8 ContentFormat = UInt8(4);
  static UInt8 Content = UInt8(5);
  static UInt8 Trials = UInt8(6);
  static UInt8 Issue = UInt8(7);
  static UInt8 Expire = UInt8(8);
}
