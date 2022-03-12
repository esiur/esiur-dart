import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'TypeTemplate.dart';
import 'MemberType.dart';
import '../StorageMode.dart';
import '../../Data/RepresentationType.dart';

class PropertyTemplate extends MemberTemplate {
  RepresentationType valueType;

  int permission = 0;

  bool recordable;

  String? readExpansion;

  String? writeExpansion;

  DC compose() {
    var name = super.compose();
    var pv = (permission << 1) | (recordable ? 1 : 0);

    if (inherited) pv |= 0x80;

    if (writeExpansion != null && readExpansion != null) {
      var rexp = DC.stringToBytes(readExpansion as String);
      var wexp = DC.stringToBytes(writeExpansion as String);
      return (BinaryList()
            ..addUint8(0x38 | pv)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(valueType.compose())
            ..addInt32(wexp.length)
            ..addDC(wexp)
            ..addInt32(rexp.length)
            ..addDC(rexp))
          .toDC();
    } else if (writeExpansion != null) {
      var wexp = DC.stringToBytes(writeExpansion as String);
      return (BinaryList()
            ..addUint8(0x30 | pv)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(valueType.compose())
            ..addInt32(wexp.length)
            ..addDC(wexp))
          .toDC();
    } else if (readExpansion != null) {
      var rexp = DC.stringToBytes(readExpansion as String);
      return (BinaryList()
            ..addUint8(0x28 | pv)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(valueType.compose())
            ..addInt32(rexp.length)
            ..addDC(rexp))
          .toDC();
    } else
      return (BinaryList()
            ..addUint8(0x20 | pv)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(valueType.compose()))
          .toDC();
  }

  PropertyTemplate(TypeTemplate template, int index, String name,
      bool inherited, this.valueType,
      [this.readExpansion = null,
      this.writeExpansion = null,
      this.recordable = false])
      : super(template, index, name, inherited) {}
}
