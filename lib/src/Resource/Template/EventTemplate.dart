import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'TypeTemplate.dart';
import 'MemberType.dart';
import '../../Data/RepresentationType.dart';

class EventTemplate extends MemberTemplate {
  final String? expansion;
  final bool listenable;
  final RepresentationType argumentType;

  DC compose() {
    var name = super.compose();

    var hdr = inherited ? 0x80 : 0;

    if (listenable) hdr |= 0x8;

    if (expansion != null) {
      var exp = DC.stringToBytes(expansion as String);
      hdr |= 0x50;
      return (BinaryList()
            ..addUint8(hdr)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(argumentType.compose())
            ..addInt32(exp.length)
            ..addDC(exp))
          .toDC();
    } else {
      hdr |= 0x40;
      return (BinaryList()
            ..addUint8(hdr)
            ..addUint8(name.length)
            ..addDC(name)
            ..addDC(argumentType.compose()))
          .toDC();
    }
  }

  EventTemplate(TypeTemplate template, int index, String name, bool inherited,
      this.argumentType,
      [this.expansion = null, this.listenable = false])
      : super(template, index, name, inherited) {}
}
