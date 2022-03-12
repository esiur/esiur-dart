import 'IResource.dart';
import 'Template/PropertyTemplate.dart';

class PropertyModificationInfo {
  final IResource resource;
  final PropertyTemplate propertyTemplate;
  final int age;
  final value;

  String get name => propertyTemplate.name;

  PropertyModificationInfo(
      this.resource, this.propertyTemplate, this.value, this.age) {}
}
