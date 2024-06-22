import '../Data/RepresentationType.dart';

// class DumClass<T> {
//   Type type = T;
// }

// Type getNullableType<T>() => DumClass<T?>().type;
// Type getTypeOf<T>() => DumClass<T>().type;

class FactoryEntry<T> {
  Type get type => T;

  late Type nullableType;
  final Function instanceCreator;
  final Function arrayCreator = () => <T>[];
  final RepresentationType representationType;
  final Function mapCreator = () => Map<T, dynamic>();

  bool isMapKeySubType(Map map) {
    return map is Map<T, dynamic>;
  }

  bool isMapValueSubType(Map map) {
    return map is Map<dynamic, T>;
  }

  bool isListSubType(List list) {
    return list is List<T>;
  }

  FactoryEntry(this.instanceCreator, this.representationType) {
    nullableType = getNullableType<T>();
  }
}
