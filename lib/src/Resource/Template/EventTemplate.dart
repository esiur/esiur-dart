
import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'ResourceTemplate.dart';
import 'MemberType.dart';

class EventTemplate extends MemberTemplate
{

  String expansion;


  DC compose()
  {
      var name = super.compose();

      if (expansion != null)
      {
          var exp = DC.stringToBytes(expansion);
          return new BinaryList()
                  .addUint8(0x50)
                  .addInt32(exp.length)
                  .addDC(exp)
                  .addUint8(name.length)
                  .addDC(name)
                  .toDC();
      }
      else
      {
          return new BinaryList()
                  .addUint8(0x40)
                  .addUint8(name.length)
                  .addDC(name)
                  .toDC();
      }
  }


  EventTemplate(ResourceTemplate template, int index, String name, String expansion)
      : super(template, MemberType.Property, index, name)
  {
      this.expansion = expansion;
  }
}
