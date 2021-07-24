import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'TypeTemplate.dart';
import 'MemberType.dart';
import 'TemplateDataType.dart';

class EventTemplate extends MemberTemplate {
  String? expansion;
  bool listenable;
  TemplateDataType argumentType;

  DC compose() {
    var name = super.compose();

    if (expansion != null) {
      var exp = DC.stringToBytes(expansion as String);
      return (BinaryList()
            ..addUint8(listenable ? 0x58 : 0x50)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(argumentType.compose())
            ..addInt32(exp.length)
            ..addDC(exp))
          .toDC();
    } else {
      return (BinaryList()
            ..addUint8(listenable ? 0x48 : 0x40)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(argumentType.compose()))
          .toDC();
    }
  }

  EventTemplate(TypeTemplate template, int index, String name,
      this.argumentType, this.expansion, this.listenable)
      : super(template, MemberType.Property, index, name) {}
}
