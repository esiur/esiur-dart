import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'TypeTemplate.dart';
import 'MemberType.dart';
import 'ArgumentTemplate.dart';
import '../../Data/RepresentationType.dart';

class FunctionTemplate extends MemberTemplate {
  String? annotation;
  // bool isVoid;

  List<ArgumentTemplate> arguments;
  RepresentationType returnType;

  DC compose() {
    var name = super.compose();

    var bl = new BinaryList()
      ..addUint8(name.length)
      ..addDC(name)
      ..addDC(returnType.compose())
      ..addUint8(arguments.length);

    for (var i = 0; i < arguments.length; i++) bl.addDC(arguments[i].compose());

    if (annotation != null) {
      var exp = DC.stringToBytes(annotation as String);
      bl
        ..addInt32(exp.length)
        ..addDC(exp);
      bl.insertUint8(0, inherited ? 0x90 : 0x10);
    } else
      bl.insertUint8(0, inherited ? 0x80 : 0x0);

    return bl.toDC();
  }

  FunctionTemplate(TypeTemplate template, int index, String name,
      bool inherited, this.arguments, this.returnType,
      [this.annotation = null])
      : super(template, index, name, inherited) {}
}
