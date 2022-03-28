/*
 
Copyright (c) 2019 Ahmed Kh. Zamil

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/
import 'package:collection/collection.dart';
import '../Data/RepresentationType.dart';

import 'IEnum.dart';
import 'IntType.dart';

import '../Core/AsyncException.dart';
import '../Core/ErrorType.dart';
import '../Core/ExceptionCode.dart';

import '../Resource/Template/TemplateType.dart';

import 'DataDeserializer.dart';
import 'DataSerializer.dart';
import 'Guid.dart';
import 'IRecord.dart';
import 'Record.dart';
import 'ResourceArrayType.dart';
import 'dart:typed_data';
import '../Core/AsyncBag.dart';
import '../Core/AsyncReply.dart';
import 'DC.dart';
import 'BinaryList.dart';
import 'SizeObject.dart';
import 'NotModified.dart';
import 'PropertyValue.dart';
import 'KeyList.dart';
import '../Net/IIP/DistributedConnection.dart';
import '../Net/IIP/DistributedResource.dart';
import '../Resource/Warehouse.dart';
import '../Resource/IResource.dart';
import '../Resource/Template/PropertyTemplate.dart';
import '../Net/IIP/DistributedPropertyContext.dart';
import 'TransmissionType.dart';

// extension ListTyping<T> on List<T> {
//   Type get genericType => T;
// }

// extension MapTyping<KT, VT> on Map<KT, VT> {
//   Type get keyType => KT;
//   Type get valueType => VT;
// }

typedef Parser = AsyncReply Function(
    DC data, int offset, int length, DistributedConnection? connection);
typedef Composer = DataSerializerComposeResults Function(
    dynamic value, DistributedConnection? connection);

class CodecComposeResults {
  final int transmissionTypeIdentifier;
  final DC data;

  CodecComposeResults(this.transmissionTypeIdentifier, this.data);
}

class CodecParseResults {
  final AsyncReply reply;
  final int size;

  CodecParseResults(this.size, this.reply);
}

class Codec {
  //AsyncReply Parser(byte[] data, uint offset, uint length, DistributedConnection connection);

  static List<List<Parser>> fixedParsers = [
    [
      DataDeserializer.nullParser,
      DataDeserializer.booleanFalseParser,
      DataDeserializer.booleanTrueParser,
      DataDeserializer.notModifiedParser,
    ],
    [
      DataDeserializer.byteParser,
      DataDeserializer.sByteParser,
      DataDeserializer.char8Parser,
    ],
    [
      DataDeserializer.int16Parser,
      DataDeserializer.uInt16Parser,
      DataDeserializer.char16Parser,
    ],
    [
      DataDeserializer.int32Parser,
      DataDeserializer.uInt32Parser,
      DataDeserializer.float32Parser,
      DataDeserializer.resourceParser,
      DataDeserializer.localResourceParser,
    ],
    [
      DataDeserializer.int64Parser,
      DataDeserializer.uInt64Parser,
      DataDeserializer.float64Parser,
      DataDeserializer.dateTimeParser,
    ],
    [
      DataDeserializer.int128Parser, // int 128
      DataDeserializer.uInt128Parser, // uint 128
      DataDeserializer.float128Parser,
    ]
  ];

  static List<Parser> dynamicParsers = [
    DataDeserializer.rawDataParser,
    DataDeserializer.stringParser,
    DataDeserializer.listParser,
    DataDeserializer.resourceListParser,
    DataDeserializer.recordListParser,
  ];

  static List<Parser> typedParsers = [
    DataDeserializer.recordParser,
    DataDeserializer.typedListParser,
    DataDeserializer.typedMapParser,
    DataDeserializer.tupleParser,
    DataDeserializer.enumParser,
    DataDeserializer.constantParser,
  ];

  /// <summary>
  /// Parse a value
  /// </summary>
  /// <param name="data">Bytes array</param>
  /// <param name="offset">Zero-indexed offset.</param>
  /// <param name="size">Output the number of bytes parsed</param>
  /// <param name="connection">DistributedConnection is required in case a structure in the array holds items at the other end.</param>
  /// <param name="dataType">DataType, in case the data is not prepended with DataType</param>
  /// <returns>Value</returns>
  static CodecParseResults parse(
      DC data, int offset, DistributedConnection? connection,
      [TransmissionType? dataType = null]) {
    int len = 0;

    if (dataType == null) {
      var parsedDataTyped = TransmissionType.parse(data, offset, data.length);
      len = parsedDataTyped.size;
      dataType = parsedDataTyped.type;
      offset = dataType?.offset ?? 0;
    } else
      len = dataType.contentLength;

    if (dataType != null) {
      if (dataType.classType == TransmissionTypeClass.Fixed) {
        return CodecParseResults(
            len,
            fixedParsers[dataType.exponent][dataType.index](
                data, dataType.offset, dataType.contentLength, connection));
      } else if (dataType.classType == TransmissionTypeClass.Dynamic) {
        return CodecParseResults(
            len,
            dynamicParsers[dataType.index](
                data, dataType.offset, dataType.contentLength, connection));
      } else //if (tt.Class == TransmissionTypeClass.Typed)
      {
        return CodecParseResults(
            len,
            typedParsers[dataType.index](
                data, dataType.offset, dataType.contentLength, connection));
      }
    }

    throw Exception("Can't parse transmission type.");
  }

  static Map<Type, Composer> composers = {
    // Fixed
    bool: DataSerializer.boolComposer,
    NotModified: DataSerializer.notModifiedComposer,
    //byte = DataSerializer.ByteComposer,
    //[typeof(byte?)] = DataSerializer.ByteComposer,
    //[typeof(sbyte)] = DataSerializer.SByteComposer,
    //[typeof(sbyte?)] = DataSerializer.SByteComposer,
    //[typeof(char)] = DataSerializer.Char16Composer,
    //[typeof(char?)] = DataSerializer.Char16Composer,
    //[typeof(short)] = DataSerializer.Int16Composer,
    //[typeof(short?)] = DataSerializer.Int16Composer,
    //[typeof(ushort)] = DataSerializer.UInt16Composer,
    //[typeof(ushort?)] = DataSerializer.UInt16Composer,
    Int32: DataSerializer.int32Composer,
    UInt32: DataSerializer.uInt32Composer,
    Int8: DataSerializer.int8Composer,
    UInt8: DataSerializer.uInt8Composer,
    Int16: DataSerializer.int16Composer,
    UInt16: DataSerializer.uInt16Composer,
    int: DataSerializer.int64Composer,
    //[typeof(long?)] = DataSerializer.Int64Composer,
    //[typeof(ulong)] = DataSerializer.UIn64Composer,
    //[typeof(ulong?)] = DataSerializer.UIn64Composer,
    double: DataSerializer.float64Composer,
    //[typeof(double?)] = DataSerializer.Float64Composer,
    DateTime: DataSerializer.dateTimeComposer,
    //[typeof(DateTime?)] = DataSerializer.DateTimeComposer,
    //[typeof(decimal)] = DataSerializer.Float128Composer,
    //[typeof(decimal?)] = DataSerializer.Float128Composer,
    DC: DataSerializer.rawDataComposer,
    //[typeof(byte?[])] = DataSerializer.RawDataComposerFromArray,
    //[typeof(List<byte>)] = DataSerializer.RawDataComposerFromList,
    //[typeof(List<byte?>)] = DataSerializer.RawDataComposerFromList,
    String: DataSerializer.stringComposer,
    // Special
    List: DataSerializer.listComposer, // DataSerializer.ListComposerFromArray,
    //[typeof(List<object>)] = DataSerializer.ListComposer,// DataSerializer.ListComposerFromList,
    List<IResource>: DataSerializer
        .resourceListComposer, // (value, con) => (TransmissionTypeIdentifier.ResourceList, DC.ToBytes((decimal)value)),
    List<IResource?>: DataSerializer
        .resourceListComposer, // (value, con) => (TransmissionTypeIdentifier.ResourceList, DC.ToBytes((decimal)value)),
    //[typeof(List<IResource>)] = DataSerializer.ResourceListComposer, //(value, con) => (TransmissionTypeIdentifier.ResourceList, DC.ToBytes((decimal)value)),
    //[typeof(List<IResource?>)] = DataSerializer.ResourceListComposer, //(value, con) => (TransmissionTypeIdentifier.ResourceList, DC.ToBytes((decimal)value)),
    //[typeof(IRecord[])] = DataSerializer.RecordListComposer,// (value, con) => (TransmissionTypeIdentifier.RecordList, DC.ToBytes((decimal)value)),
    //[typeof(IRecord?[])] = DataSerializer.RecordListComposer,// (value, con) => (TransmissionTypeIdentifier.RecordList, DC.ToBytes((decimal)value)),
    List<IRecord>: DataSerializer
        .recordListComposer, //(value, con) => (TransmissionTypeIdentifier.RecordList, DC.ToBytes((decimal)value)),
    List<IRecord?>: DataSerializer
        .recordListComposer, //(value, con) => (TransmissionTypeIdentifier.RecordList, DC.ToBytes((decimal)value)),
    Map: DataSerializer.mapComposer,
    List<PropertyValue>: DataSerializer.propertyValueArrayComposer
    // Typed
    // [typeof(bool[])] = (value, con) => DataSerializer.TypedListComposer((IEnumerable)value, typeof(bool), con),
    // [typeof(bool?[])] = (value, con) => (TransmissionTypeIdentifier.TypedList, new byte[] { (byte)value }),
    // [typeof(List<bool>)] = (value, con) => (TransmissionTypeIdentifier.TypedList, new byte[] { (byte)value }),
    // [typeof(List<bool?>)] = (value, con) => (TransmissionTypeIdentifier.TypedList, new byte[] { (byte)value }),

    // [typeof(byte?[])] = (value, con) => (TransmissionTypeIdentifier.TypedList, new byte[] { (byte)value }),
    // [typeof(List<bool?>)] = (value, con) => (TransmissionTypeIdentifier.TypedList, new byte[] { (byte)value }),
  };

  //static Type getListType<T>(List<T> list) => DumClass<T>().type;
  //static Type getListType2<T>(List<T> list) => T;
  //static List<Type> getMapTypes<KT, VT>(Map<KT, VT> map) => [KT, VT];

  static Type getListType(List list) {
    return Warehouse.typesFactory.values
            .firstWhereOrNull((x) => x.isListSubType(list))
            ?.type ??
        dynamic;
  }

  static List<Type> getMapTypes(Map map) {
    var kt = Warehouse.typesFactory.values
        .firstWhereOrNull((x) => x.isMapKeySubType(map))
        ?.type;
    var vt = Warehouse.typesFactory.values
        .firstWhereOrNull((x) => x.isMapValueSubType(map))
        ?.type;

    return <Type>[kt ?? dynamic, vt ?? dynamic];
  }

  /// <summary>
  /// Compose a variable
  /// </summary>
  /// <param name="value">Value to compose.</param>
  /// <param name="connection">DistributedConnection is required to check locality.</param>
  /// <param name="prependType">If True, prepend the DataType at the beginning of the output.</param>
  /// <returns>Array of bytes in the network byte order.</returns>
  static DC compose(dynamic valueOrSource, DistributedConnection? connection) {
    if (valueOrSource == null)
      return TransmissionType.compose(TransmissionTypeIdentifier.Null, DC(0));

    var type = valueOrSource.runtimeType;

    // if (type.)
    // {

    //     var genericType = type.GetGenericTypeDefinition();
    //     if (genericType == typeof(DistributedPropertyContext<>))
    //     {
    //         valueOrSource = ((IDistributedPropertyContext)valueOrSource).GetValue(connection);
    //     }
    //     else if (genericType == typeof(Func<>))
    //     {
    //         var args = genericType.GetGenericArguments();
    //         if (args.Length == 2 && args[0] == typeof(DistributedConnection))
    //         {
    //             //Func<DistributedConnection, DistributedConnection> a;
    //             //a.Invoke()
    //         }
    //     }
    // }

    // if (valueOrSource is IUserType)
    //     valueOrSource = (valueOrSource as IUserType).Get();

    //if (valueOrSource is Func<DistributedConnection, object>)
    //    valueOrSource = (valueOrSource as Func<DistributedConnection, object>)(connection);

    // if (valueOrSource == null)
    //     return TransmissionType.Compose(TransmissionTypeIdentifier.Null, null);

    // type = valueOrSource.GetType();

    if (composers.containsKey(type)) {
      var results = composers[type]!(valueOrSource, connection);
      return TransmissionType.compose(results.identifier, results.data);
    } else {
      if (valueOrSource is List) {
        var genericType = getListType(valueOrSource);
        var results = DataSerializer.typedListComposer(
            valueOrSource, genericType, connection);
        return TransmissionType.compose(results.identifier, results.data);
      } else if (valueOrSource is Map) {
        var genericTypes = getMapTypes(valueOrSource);
        var results = DataSerializer.typedMapComposer(
            valueOrSource, genericTypes[0], genericTypes[1], connection);
        return TransmissionType.compose(results.identifier, results.data);
      } else if (valueOrSource is IResource) {
        var results =
            DataSerializer.resourceComposer(valueOrSource, connection);
        return TransmissionType.compose(results.identifier, results.data);
      } else if (valueOrSource is IRecord) {
        var results = DataSerializer.recordComposer(valueOrSource, connection);
        return TransmissionType.compose(results.identifier, results.data);
      } else if (valueOrSource is IEnum) {
        var results = DataSerializer.enumComposer(valueOrSource, connection);
        return TransmissionType.compose(results.identifier, results.data);
      }
    }

    return TransmissionType.compose(TransmissionTypeIdentifier.Null, DC(0));
  }

  /// <summary>
  /// Check if a resource is local to a given connection.
  /// </summary>
  /// <param name="resource">Resource to check.</param>
  /// <param name="connection">DistributedConnection to check if the resource is local to it.</param>
  /// <returns>True, if the resource owner is the given connection, otherwise False.</returns>
  static bool isLocalResource(
      IResource resource, DistributedConnection? connection) {
    if (connection == null) return false;
    if (resource is DistributedResource) {
      if (resource.distributedResourceConnection == connection) return true;
    }
    return false;
  }

  /// <summary>
  /// Check if a type implements an interface
  /// </summary>
  /// <param name="type">Sub-class type.</param>
  /// <param name="iface">Super-interface type.</param>
  /// <returns>True, if <paramref name="type"/> implements <paramref name="iface"/>.</returns>
  static bool implementsInterface<type, ifac>() =>
      _DummyClass<type>() is _DummyClass<ifac>;
}

// related to implementsInterface
class _DummyClass<T> {}
