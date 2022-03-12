import '../../Data/BinaryList.dart';
import '../../Data/Codec.dart';
import '../../Data/DC.dart';
import '../../Data/RepresentationType.dart';

import 'MemberTemplate.dart';
import 'TypeTemplate.dart';

class ConstantTemplate extends MemberTemplate {
  final dynamic value;
  final String? expansion;
  final RepresentationType valueType;

  ConstantTemplate(TypeTemplate template, int index, String name,
      bool inherited, this.valueType, this.value, this.expansion)
      : super(template, index, name, inherited) {}

  DC compose() {
    var name = super.compose();
    var hdr = inherited ? 0x80 : 0;

    if (expansion != null) {
      var exp = DC.stringToBytes(expansion!);
      hdr |= 0x70;
      return (BinaryList()
            ..addUint8(hdr)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(valueType.compose())
            ..addDC(Codec.compose(value, null))
            ..addInt32(exp.length)
            ..addDC(exp))
          .toDC();
    } else {
      hdr |= 0x60;

      return (BinaryList()
            ..addUint8(hdr)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(valueType.compose())
            ..addDC(Codec.compose(value, null)))
          .toDC();
    }
  }
}
