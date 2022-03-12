import 'MemberType.dart';
import '../../Data/DC.dart';
import 'TypeTemplate.dart';

class MemberTemplate {
  final TypeTemplate template;
  final String name;
  final int index;
  final bool inherited;

  MemberTemplate(this.template, this.index, this.name, this.inherited) {}

  String get fullname => template.className + "." + name;

  DC compose() {
    return DC.stringToBytes(name);
  }
}
