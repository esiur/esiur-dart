 
// import '../../Data/IRecord.dart';
// import '../../Resource/IResource.dart';

// import '../../Data/Structure.dart';

// import '../../Data/ParseResult.dart';

// import '../../Data/DataType.dart';
// import '../../Data/UUID.dart';
// import '../../Data/DC.dart';
// import '../../Data/BinaryList.dart';
// import 'TypeTemplate.dart';
// import '../../Resource/Warehouse.dart';
// import 'TemplateType.dart';

// class TemplateDataType {
//   late int type;
//   TypeTemplate? get typeTemplate => typeUUID == null
//       ? null
//       : Warehouse.getTemplateByClassId(typeUUID as UUID);

//   UUID? typeUUID;

// //  @TODO: implement fromType
//   TemplateDataType.fromType(type, bool isArray) {
//     int dt;

//     if (type == null || type == dynamic) {
//       dt = DataType.Void;
//     }
//     // else if (type is int) {
//     //   dt = type;
//     else if (type == bool)
//       dt = DataType.Bool;
//     // else if (type == Uint8)
//     //   dt = DataType.UInt8;
//     // else if (type == Int8)
//     //   dt = DataType.Int8;
//     // else if (type == Uint16)
//     //   dt = DataType.UInt16;
//     // else if (type == Int16)
//     //   dt = DataType.Int16;
//     // else if (type == Uint32)
//     //   dt = DataType.UInt32;
//     // else if (type == Int32)
//     //   dt = DataType.Int32;
//     // else if (type == Uint64)
//     //   dt = DataType.UInt64;
//     else if (/* type == Int64 || */ type == int)
//       dt = DataType.Int64;
//     // else if (type == Float)
//     //   dt = DataType.Float32;
//     else if (/* type == Double || */ type == double)
//       dt = DataType.Float64;
//     else if (type == String)
//       dt = DataType.String;
//     else if (type == DateTime)
//       dt = DataType.DateTime;
//     else if (type == Structure)
//       dt = DataType.Structure;
//     else if (type == IResource) // Dynamic resource (unspecified type)
//       dt = DataType.Void;
//     else if (type == IRecord) // Dynamic record (unspecified type)
//       dt = DataType.Void;
//     else {
//       var template = Warehouse.getTemplateByType(type);

//       if (template != null) {
//         typeUUID = template.classId;
//         dt = template.type == TemplateType.Resource
//             ? DataType.Resource
//             : DataType.Record;
//       } else
//         dt = DataType.Void;

//       // if (template)
//       //   try {
//       //     var ins = Warehouse.createInstance(type);
//       //     if (ins is IResource) {
//       //       typeUUID = TypeTemplate.getTypeUUID(ins.template.nameSpace);
//       //     } else if (ins is IRecord) {
//       //       typeUUID = TypeTemplate.getTypeUUID(ins.template.nameSpace);
//       //     } else {
//       //       dt = DataType.Void;
//       //     }
//       //   } catch (ex) {
//       //     dt = DataType.Void;
//       //   }
//     }

//     if (isArray) dt = dt | 0x80;

//     this.type = dt;
//   }

//   DC compose() {
//     if (type == DataType.Resource ||
//         type == DataType.ResourceArray ||
//         type == DataType.Record ||
//         type == DataType.RecordArray) {
//       return (BinaryList()
//             ..addUint8(type)
//             ..addDC((typeUUID as UUID).value))
//           .toDC();
//     } else
//       return DC.fromList([type]);
//   }

//   TemplateDataType(this.type, this.typeUUID);

//   static ParseResult<TemplateDataType> parse(DC data, int offset) {
//     var type = data[offset++];
//     if (type == DataType.Resource ||
//         type == DataType.ResourceArray ||
//         type == DataType.Record ||
//         type == DataType.RecordArray) {
//       var uuid = data.getUUID(offset);
//       return ParseResult<TemplateDataType>(
//           17, new TemplateDataType(type, uuid));
//     } else
//       return ParseResult<TemplateDataType>(1, new TemplateDataType(type, null));
//   }
// }
