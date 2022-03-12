import 'BinaryList.dart';
import 'Codec.dart';
import 'IRecord.dart';
import '../Net/IIP/DistributedResource.dart';
import '../Resource/IResource.dart';
import '../Resource/Warehouse.dart';

import '../Resource/Template/PropertyTemplate.dart';

import 'PropertyValue.dart';

import './TransmissionType.dart';
import '../Net/IIP/DistributedConnection.dart';

import 'DC.dart';
import 'RepresentationType.dart';
import 'IntType.dart';

class DataSerializerComposeResults {
  int identifier;
  DC data;

  DataSerializerComposeResults(this.identifier, this.data);
}

class DataSerializer {
  //public delegate byte[] Serializer(object value);

  static DC historyComposer(Map<PropertyTemplate, List<PropertyValue>> history,
      DistributedConnection connection,
      [bool prependLength = false]) {
    throw Exception("Not implemented");
  }

  static DataSerializerComposeResults int32Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(4);
    rt.setInt32(0, (value as Int32).toInt());
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Int32, rt);
  }

  static DataSerializerComposeResults uInt32Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(4);
    rt.setUint32(0, (value as UInt32).toInt());
    return DataSerializerComposeResults(TransmissionTypeIdentifier.UInt32, rt);
  }

  static DataSerializerComposeResults int16Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(2);
    rt.setInt16(0, (value as Int16).toInt());
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Int16, rt);
  }

  static DataSerializerComposeResults uInt16Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(2);
    rt.setUint16(0, (value as UInt16).toInt());
    return DataSerializerComposeResults(TransmissionTypeIdentifier.UInt16, rt);
  }

  static DataSerializerComposeResults float32Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(4);
    rt.setFloat32(0, value as double);
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Float32, rt);
  }

  static DataSerializerComposeResults float64Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(8);
    rt.setFloat64(0, value as double);
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Float64, rt);
  }

  static DataSerializerComposeResults int64Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(8);
    rt.setInt64(0, value as int);
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Int64, rt);
  }

  static DataSerializerComposeResults uInt64Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(8);
    rt.setUint64(0, value as int);
    return DataSerializerComposeResults(TransmissionTypeIdentifier.UInt64, rt);
  }

  static DataSerializerComposeResults dateTimeComposer(
      value, DistributedConnection? connection) {
    var rt = new DC(8);
    rt.setDateTime(0, value as DateTime);
    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.DateTime, rt);
  }

  static DataSerializerComposeResults float128Composer(
      value, DistributedConnection? connection) {
    //@TODO: implement decimal
    var rt = new DC(16);
    rt.setFloat64(0, value as double);
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Float64, rt);
  }

  static DataSerializerComposeResults stringComposer(
      value, DistributedConnection? connection) {
    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.String, DC.stringToBytes(value as String));
  }

  static DataSerializerComposeResults enumComposer(
      value, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    var template = Warehouse.getTemplateByType(value.runtimeType);

    if (template == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    var cts = template.constants.where((x) => x.value == value);

    if (cts.isEmpty)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    var rt = BinaryList();

    rt.addGuid(template.classId);
    rt.addUint8(cts.first.index);

    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.Enum, rt.toDC());
  }

  static DataSerializerComposeResults uInt8Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(1);
    rt[0] = (value as UInt8).toInt();
    return DataSerializerComposeResults(TransmissionTypeIdentifier.UInt8, rt);
  }

  static DataSerializerComposeResults int8Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(1);
    rt[0] = (value as Int8).toInt();
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Int8, rt);
  }

  static DataSerializerComposeResults char8Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(1);
    rt[0] = value as int;
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Char8, rt);
  }

  static DataSerializerComposeResults char16Composer(
      value, DistributedConnection? connection) {
    var rt = new DC(2);
    rt.setUint16(0, value as int);
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Char16, rt);
  }

  static DataSerializerComposeResults boolComposer(
      value, DistributedConnection? connection) {
    return DataSerializerComposeResults(
        value as bool
            ? TransmissionTypeIdentifier.True
            : TransmissionTypeIdentifier.False,
        DC(0));
  }

  static DataSerializerComposeResults notModifiedComposer(
      value, DistributedConnection? connection) {
    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.NotModified, DC(0));
  }

  static DataSerializerComposeResults rawDataComposer(
      value, DistributedConnection? connection) {
    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.RawData, value as DC);
  }

  static DataSerializerComposeResults listComposer(
      value, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));
    else
      return DataSerializerComposeResults(TransmissionTypeIdentifier.List,
          arrayComposer(value as List, connection));

    //var rt = new List<byte>();
    //var list = (IEnumerable)value;// ((List<object>)value);

    //foreach (var o in list)
    //    rt.AddRange(Codec.Compose(o, connection));

    //return (TransmissionTypeIdentifier.List, rt.ToArray());
  }

  static DataSerializerComposeResults typedListComposer(
      value, Type type, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    var composed = arrayComposer(value as List, connection);

    var header =
        (RepresentationType.fromType(type) ?? RepresentationType.Dynamic)
            .compose();

    var rt = new BinaryList()
      ..addDC(header)
      ..addDC(composed);

    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.TypedList, rt.toDC());
  }

  static DataSerializerComposeResults propertyValueArrayComposer(
      value, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    var rt = BinaryList();
    var ar = value as List<PropertyValue>;

    for (var pv in ar) {
      rt.addDC(Codec.compose(pv.age, connection));
      rt.addDC(Codec.compose(pv.date, connection));
      rt.addDC(Codec.compose(pv.value, connection));
    }

    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.List, rt.toDC());
  }

  static DataSerializerComposeResults typedMapComposer(
      value, Type keyType, Type valueType, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    var kt =
        (RepresentationType.fromType(keyType) ?? RepresentationType.Dynamic)
            .compose();
    var vt =
        (RepresentationType.fromType(valueType) ?? RepresentationType.Dynamic)
            .compose();

    var rt = BinaryList();

    rt.addDC(kt);
    rt.addDC(vt);

    var map = value as Map;

    for (var el in map.entries) {
      rt.addDC(Codec.compose(el.key, connection));
      rt.addDC(Codec.compose(el.value, connection));
    }

    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.TypedMap, rt.toDC());
  }

  static DC arrayComposer(List value, DistributedConnection? connection) {
    var rt = BinaryList();

    for (var i in value) rt.addDC(Codec.compose(i, connection));

    return rt.toDC();
  }

  static DataSerializerComposeResults resourceListComposer(
      value, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    return DataSerializerComposeResults(TransmissionTypeIdentifier.ResourceList,
        arrayComposer(value as List, connection));
  }

  static DataSerializerComposeResults recordListComposer(
      value, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    return DataSerializerComposeResults(TransmissionTypeIdentifier.RecordList,
        arrayComposer(value as List, connection));
  }

  static DataSerializerComposeResults resourceComposer(
      value, DistributedConnection? connection) {
    var resource = value as IResource;
    var rt = new DC(4);

    if (Codec.isLocalResource(resource, connection)) {
      rt.setUint32(0, (resource as DistributedResource).id ?? 0);
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.ResourceLocal, rt);
    } else {
      // @TODO: connection.cache.Add(value as IResource, DateTime.UtcNow);
      rt.setUint32(0, resource.instance?.id ?? 0);
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Resource, rt);
    }
  }

  static DataSerializerComposeResults mapComposer(
      value, DistributedConnection? connection) {
    if (value == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    var rt = BinaryList();
    var map = value as Map;

    for (var el in map.entries) {
      rt.addDC(Codec.compose(el.key, connection));
      rt.addDC(Codec.compose(el.value, connection));
    }

    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.Map, rt.toDC());
  }

  static DataSerializerComposeResults recordComposer(
      value, DistributedConnection? connection) {
    var rt = BinaryList();
    var record = value as IRecord;

    var template = Warehouse.getTemplateByType(record.runtimeType);

    if (template == null)
      return DataSerializerComposeResults(
          TransmissionTypeIdentifier.Null, DC(0));

    rt.addDC(DC.guidToBytes(template.classId));

    var recordData = record.serialize();

    for (var pt in template.properties) {
      var propValue = recordData[pt.name];
      rt.addDC(Codec.compose(propValue, connection));
    }

    return DataSerializerComposeResults(
        TransmissionTypeIdentifier.Record, rt.toDC());
  }

  // TODO:
  // static DataSerializerComposeResults historyComposer(KeyList<PropertyTemplate, PropertyValue[]> history,
  //                                     DistributedConnection connection, bool prependLength = false)
  // {
  //     //@TODO:Test
  //     var rt = new BinaryList();

  //     for (var i = 0; i < history.Count; i++)
  //         rt.AddUInt8(history.Keys.ElementAt(i).Index)
  //           .AddUInt8Array(Codec.Compose(history.Values.ElementAt(i), connection));

  //     if (prependLength)
  //         rt.InsertInt32(0, rt.Length);

  //     return rt.ToArray();
  // }

  static DataSerializerComposeResults TupleComposer(
      value, DistributedConnection? connection) {
    //if (value == null)
    return DataSerializerComposeResults(TransmissionTypeIdentifier.Null, DC(0));

    //@TODO
    // var rt = BinaryList();

    // var fields = value.GetType().GetFields();
    // var list =  fields.Select(x => x.GetValue(value)).ToArray();
    // var types = fields.Select(x => RepresentationType.FromType(x.FieldType).Compose()).ToArray();

    // rt.Add((byte)list.Length);

    // foreach (var t in types)
    //     rt.AddRange(t);

    // var composed = ArrayComposer(list, connection);

    // if (composed == null)
    //     return (TransmissionTypeIdentifier.Null, new byte[0]);
    // else
    // {
    //     rt.AddRange(composed);
    //     return (TransmissionTypeIdentifier.Tuple, rt.ToArray());
    // }
  }
}
