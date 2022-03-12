import '../Resource/Template/TemplateDescriber.dart';

class IEnum {
  int index = 0;
  dynamic value;
  String name = '';
  IEnum([this.index = 0, this.value, this.name = ""]);

  TemplateDescriber get template => TemplateDescriber("IEnum");

  @override
  String toString() {
    return '${name}<$value>';
  }
}
