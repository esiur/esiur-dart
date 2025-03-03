import 'IntType.dart';

import 'IEnum.dart';
import '../Resource/Template/TemplateType.dart';
import 'IRecord.dart';
import '../Resource/IResource.dart';
import '../Resource/Warehouse.dart';

import 'BinaryList.dart';
import 'DC.dart';
import 'UUID.dart';
import 'package:collection/collection.dart';

class RepresentationTypeIdentifier {
  static const int Void = 0x0,
      Dynamic = 0x1,
      Bool = 0x2,
      UInt8 = 0x3,
      Int8 = 0x4,
      Char = 0x5,
      UInt16 = 0x6,
      Int16 = 0x7,
      UInt32 = 0x8,
      Int32 = 0x9,
      Float32 = 0xA,
      UInt64 = 0xB,
      Int64 = 0xC,
      Float64 = 0xD,
      DateTime = 0xE,
      UInt128 = 0xF,
      Int128 = 0x10,
      Decimal = 0x11,
      String = 0x12,
      RawData = 0x13,
      Resource = 0x14,
      Record = 0x15,
      List = 0x16,
      Map = 0x17,
      Enum = 0x44,
      TypedResource = 0x45, // Followed by UUID
      TypedRecord = 0x46, // Followed by UUID
      TypedList = 0x48, // Followed by element type
      Tuple2 = 0x50, // Followed by element type
      TypedMap = 0x51, // Followed by key type and value type
      Tuple3 = 0x58,
      Tuple4 = 0x60,
      Tuple5 = 0x68,
      Tuple6 = 0x70,
      Tuple7 = 0x78;
}

class DumClass<T> {
  Type type = T;
}

Type getNullableType<T>() => DumClass<T?>().type;
Type getTypeOf<T>() => DumClass<T>().type;

class RepresentationTypeParseResults {
  RepresentationType type;
  int size;

  RepresentationTypeParseResults(this.size, this.type);
}

class RepresentationType {
  static Type getTypeFromName(String name) {
    const Map<String, Type> types = {
      "int": int,
      "bool": bool,
      "double": double,
      "String": String,
      "IResource": IResource,
      "IRecord": IRecord,
      "IEnum": IEnum,
      "DC": DC,
    };

    if (types.containsKey(name)) {
      return types[name]!;
    } else
      return Object().runtimeType;
  }

  RepresentationType toNullable() {
    return RepresentationType(identifier, true, uuid, subTypes);
  }

  static RepresentationType Void =
      RepresentationType(RepresentationTypeIdentifier.Void, true, null, null);

  static RepresentationType Dynamic = RepresentationType(
      RepresentationTypeIdentifier.Dynamic, true, null, null);

  static RepresentationType? fromType(Type type) {
    return Warehouse.typesFactory[type]?.representationType;

    //Warehouse.typesFactory.values.firstWhereOrNull(x => x.representationType == )
    //return RepresentationType(
    //  RepresentationTypeIdentifier.Dynamic, true, null, null);
  }

// @TODO : complete this;
  //   static RepresentationType? fromType(Type type)
  //   {
  //     var typeName = type.toString();

  //     var nullable = typeName.endsWith('?');
  //     if (nullable)
  //       typeName = typeName.substring(0, typeName.length - 1);

  //     if (typeName.endsWith('>')) // generic type
  //     {

  //       // get args
  //       var argsRex = RegExp(r"(\b[^<>]+)\<(.*)\>$");
  //       var matches = argsRex.allMatches(typeName);

  //       var name = matches.elementAt(0).input; // name
  //       var argsStr = matches.elementAt(1).input;

  //       var eachArg = RegExp(r"([^,]+\(.+?\))|([^,]+)");
  //       var args = eachArg.allMatches(argsStr);

  //       // parse sub types

  //       if (name == "List") {
  //         // get sub type
  //         getTypeFromName(args.first.input);
  //         return RepresentationType(RepresentationTypeIdentifier.TypedList, nullable, uuid, subTypes)
  //       }
  //     }
  //  }

  Map<int, List<Type>> runtimeTypes = {
    RepresentationTypeIdentifier.Void: [dynamic, dynamic],
    RepresentationTypeIdentifier.Dynamic: [dynamic, dynamic],
    RepresentationTypeIdentifier.Bool: [bool, getNullableType<bool>()],
    RepresentationTypeIdentifier.Char: [String, getNullableType<String>()],
    RepresentationTypeIdentifier.UInt8: [UInt8, getNullableType<UInt8>()],
    RepresentationTypeIdentifier.Int8: [Int8, getNullableType<Int8>()],
    RepresentationTypeIdentifier.Int16: [Int16, getNullableType<Int16>()],
    RepresentationTypeIdentifier.UInt16: [UInt16, getNullableType<UInt16>()],
    RepresentationTypeIdentifier.Int32: [Int32, getNullableType<Int32>()],
    RepresentationTypeIdentifier.UInt32: [UInt32, getNullableType<UInt32>()],
    RepresentationTypeIdentifier.Int64: [int, getNullableType<int>()],
    RepresentationTypeIdentifier.UInt64: [int, getNullableType<int>()],
    RepresentationTypeIdentifier.Float32: [Float32, getNullableType<Float32>()],
    RepresentationTypeIdentifier.Float64: [double, getNullableType<double>()],
    RepresentationTypeIdentifier.Decimal: [double, getNullableType<double>()],
    RepresentationTypeIdentifier.String: [String, getNullableType<String>()],
    RepresentationTypeIdentifier.DateTime: [
      DateTime,
      getNullableType<DateTime>()
    ],
    RepresentationTypeIdentifier.Resource: [
      IResource,
      getNullableType<IResource>()
    ],
    RepresentationTypeIdentifier.Record: [IRecord, getNullableType<IRecord>()],
  };

  Type? getRuntimeType() {
    if (runtimeTypes.containsKey(identifier))
      return nullable
          ? runtimeTypes[identifier]![1]
          : runtimeTypes[identifier]![0];
    if (identifier == RepresentationTypeIdentifier.TypedRecord)
      return Warehouse.getTemplateByClassId(uuid!, TemplateType.Record)
          ?.definedType;
    else if (identifier == RepresentationTypeIdentifier.TypedResource)
      return Warehouse.getTemplateByClassId(uuid!, TemplateType.Resource)
          ?.definedType;
    else if (identifier == RepresentationTypeIdentifier.Enum)
      return Warehouse.getTemplateByClassId(uuid!, TemplateType.Enum)
          ?.definedType;

    return null;
  }

  int identifier;
  bool nullable;
  UUID? uuid;

  List<RepresentationType>? subTypes;

  RepresentationType(this.identifier, this.nullable,
      [this.uuid, this.subTypes]) {}

  DC compose() {
    var rt = BinaryList();

    if (nullable)
      rt.addUint8(0x80 | identifier);
    else
      rt.addUint8(identifier);

    if (uuid != null) rt.addDC(DC.uuidToBytes(uuid!));

    if (subTypes != null)
      for (var i = 0; i < subTypes!.length; i++)
        rt.addDC(subTypes![i].compose());

    return rt.toDC();
  }

  //public override string ToString() => Identifier.ToString() + (Nullable ? "?" : "")
  //      + TypeTemplate != null ? "<" + TypeTemplate.ClassName + ">" : "";

  static RepresentationTypeParseResults parse(DC data, int offset) {
    var oOffset = offset;

    var header = data[offset++];
    bool nullable = (header & 0x80) > 0;
    var identifier = (header & 0x7F);

    if ((header & 0x40) > 0) {
      var hasUUID = (header & 0x4) > 0;
      var subsCount = (header >> 3) & 0x7;

      UUID? uuid = null;

      if (hasUUID) {
        uuid = data.getUUID(offset);
        offset += 16;
      }

      var subs = <RepresentationType>[];

      for (var i = 0; i < subsCount; i++) {
        var parsed = RepresentationType.parse(data, offset);
        subs.add(parsed.type);
        offset += parsed.size;
      }

      return RepresentationTypeParseResults(offset - oOffset,
          RepresentationType(identifier, nullable, uuid, subs));
    } else {
      return RepresentationTypeParseResults(
          1, RepresentationType(identifier, nullable, null, null));
    }
  }
}
