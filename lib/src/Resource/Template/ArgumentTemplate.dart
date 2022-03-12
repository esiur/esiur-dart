import '../../Data/RepresentationType.dart';

import '../../Data/DC.dart';
import '../../Data/BinaryList.dart';
import "../../Data/ParseResult.dart";

class ArgumentTemplate {
  final String name;
  final bool optional;
  final RepresentationType type;
  final int index;

  static ParseResult<ArgumentTemplate> parse(DC data, int offset, int index) {
    var optional = (data[offset++] & 0x1) == 0x1;

    var cs = data[offset++];
    var name = data.getString(offset, cs);
    offset += cs;
    var tdr = RepresentationType.parse(data, offset);

    return ParseResult<ArgumentTemplate>(
        cs + 2 + tdr.size, ArgumentTemplate(name, tdr.type, optional, index));
  }

  ArgumentTemplate(this.name, this.type, this.optional, this.index);

  DC compose() {
    var name = DC.stringToBytes(this.name);

    return (BinaryList()
          ..addUint8(optional ? 1 : 0)
          ..addUint8(name.length)
          ..addDC(name)
          ..addDC(type.compose()))
        .toDC();
  }
}
