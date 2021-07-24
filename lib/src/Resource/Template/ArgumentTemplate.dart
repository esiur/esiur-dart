import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import "../../Data/ParseResult.dart";
import './TemplateDataType.dart';

class ArgumentTemplate {
  String name;

  TemplateDataType type;

  static ParseResult<ArgumentTemplate> parse(DC data, int offset) {
    var cs = data[offset++];
    var name = data.getString(offset, cs);
    offset += cs;
    var tdr = TemplateDataType.parse(data, offset);

    return ParseResult<ArgumentTemplate>(
        cs + 1 + tdr.size, ArgumentTemplate(name, tdr.value));
  }

  ArgumentTemplate(this.name, this.type);

  DC compose() {
    var name = DC.stringToBytes(this.name);

    return (BinaryList()
          ..addUint8(name.length)
          ..addDC(name)
          ..addDC(type.compose()))
        .toDC();
  }
}
