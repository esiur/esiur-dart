import 'TemplateDataType.dart';

import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'TypeTemplate.dart';
import 'MemberType.dart';
import '../StorageMode.dart';

class PropertyTemplate extends MemberTemplate {
  TemplateDataType valueType;

  int permission = 0;

  int storage;

  String readExpansion;

  String writeExpansion;

  DC compose() {
    var name = super.compose();
    var pv = ((permission) << 1) | (storage == StorageMode.Recordable ? 1 : 0);

    if (writeExpansion != null && readExpansion != null) {
      var rexp = DC.stringToBytes(readExpansion);
      var wexp = DC.stringToBytes(writeExpansion);
      return new BinaryList()
          .addUint8(0x38 | pv)
          .addUint8(name.length)
          .addDC(name)
          .addDC(valueType.compose())
          .addInt32(wexp.length)
          .addDC(wexp)
          .addInt32(rexp.length)
          .addDC(rexp)
          .toDC();
    } else if (writeExpansion != null) {
      var wexp = DC.stringToBytes(writeExpansion);
      return new BinaryList()
          .addUint8(0x30 | pv)
          .addUint8(name.length)
          .addDC(name)
          .addDC(valueType.compose())
          .addInt32(wexp.length)
          .addDC(wexp)
          .toDC();
    } else if (readExpansion != null) {
      var rexp = DC.stringToBytes(readExpansion);
      return new BinaryList()
          .addUint8(0x28 | pv)
          .addUint8(name.length)
          .addDC(name)
          .addDC(valueType.compose())
          .addInt32(rexp.length)
          .addDC(rexp)
          .toDC();
    } else
      return new BinaryList()
          .addUint8(0x20 | pv)
          .addUint8(name.length)
          .addDC(name)
          .addDC(valueType.compose())
          .toDC();
  }

  PropertyTemplate(TypeTemplate template, int index, String name,
      TemplateDataType valueType, String read, String write, int storage)
      : super(template, MemberType.Property, index, name) {
    //this.Recordable = recordable;
    this.storage = storage;
    this.readExpansion = read;
    this.writeExpansion = write;
    this.valueType = valueType;
  }
}
