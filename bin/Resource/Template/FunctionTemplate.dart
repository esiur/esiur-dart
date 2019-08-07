import 'MemberTemplate.dart';
import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import 'ResourceTemplate.dart';
import 'MemberType.dart';

class FunctionTemplate extends MemberTemplate
{

    String expansion;
    bool isVoid;
    

    DC compose()
    {
        var name = super.compose();

        if (expansion != null)
        {
            var exp = DC.stringToBytes(expansion);
            return new BinaryList().addUint8((0x10 | (isVoid ? 0x8 : 0x0)))
                .addUint8(name.length)
                .addDC(name)
                .addInt32(exp.length)
                .addDC(exp)
                .toDC();
        }
        else
            return new BinaryList().addUint8((isVoid ? 0x8 : 0x0))
                .addUint8(name.length)
                .addDC(name)
                .toDC();
    }


    FunctionTemplate(ResourceTemplate template, int index, String name, bool isVoid, String expansion)
        :super(template, MemberType.Property, index, name)
    {
        this.isVoid = isVoid;
        this.expansion = expansion;
    }
}
