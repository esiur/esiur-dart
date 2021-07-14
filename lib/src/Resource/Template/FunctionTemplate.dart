import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'TypeTemplate.dart';
import 'MemberType.dart';
import 'ArgumentTemplate.dart';
import 'TemplateDataType.dart';

class FunctionTemplate extends MemberTemplate {
  String expansion;
  bool isVoid;

  TemplateDataType returnType;
  List<ArgumentTemplate> arguments;

  DC compose() {

      var name = super.compose();
            
      var bl = new BinaryList()
              .addUint8(name.length)
              .addDC(name)
              .addDC(returnType.compose())
              .addUint8(arguments.length);

      for (var i = 0; i < arguments.length; i++)
          bl.addDC(arguments[i].compose());


      if (expansion != null)
      {
          var exp = DC.stringToBytes(expansion);
          bl.addInt32(exp.length)
          .addDC(exp);
          bl.insertUint8(0, 0x10);
      }
      else
          bl.insertUint8(0, 0x0);

      return bl.toDC();
  }

  FunctionTemplate(TypeTemplate template, int index, String name,
      this.arguments, this.returnType, String expansion)
      : super(template, MemberType.Property, index, name) {
    this.isVoid = isVoid;
    this.expansion = expansion;
  }
}
