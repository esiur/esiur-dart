import '../Resource/IResource.dart';
import '../Resource/Template/PropertyTemplate.dart';

class PropertyModificationInfo {
  final PropertyTemplate propertyTemplate;
  final value;
  final int age;
  final IResource resource;

  String get name => propertyTemplate.name;

  PropertyModificationInfo(
      this.resource, this.propertyTemplate, this.value, this.age);
}
