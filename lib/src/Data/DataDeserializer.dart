import 'dart:core';

import 'IEnum.dart';

import '../Core/Tuple.dart';
import '../Resource/Template/TemplateType.dart';
import '../Resource/Warehouse.dart';

import '../../esiur.dart';
import '../Core/AsyncBag.dart';

import '../Core/AsyncReply.dart';
import 'DC.dart';
import '../Net/IIP/DistributedConnection.dart';
import 'NotModified.dart';
import 'RepresentationType.dart';

class PropertyValueParserResults {
  final int size;
  final AsyncReply<PropertyValue> reply;

  PropertyValueParserResults(this.size, this.reply);
}

class DataDeserializer {
  static AsyncReply nullParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply.ready(null);
  }

  static AsyncReply booleanTrueParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<bool>.ready(true);
  }

  static AsyncReply booleanFalseParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<bool>.ready(false);
  }

  static AsyncReply notModifiedParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<NotModified>.ready(NotModified());
  }

  static AsyncReply byteParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<int>.ready(data[offset]);
  }

  static AsyncReply sByteParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<int>.ready(
        data[offset] > 127 ? data[offset] - 256 : data[offset]);
  }

  static AsyncReply char16Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<String>.ready(data.getChar(offset));
  }

  static AsyncReply char8Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<String>.ready(String.fromCharCode(data[offset]));
  }

  static AsyncReply int16Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<int>.ready(data.getInt16(offset));
  }

  static AsyncReply uInt16Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<int>.ready(data.getUint16(offset));
  }

  static AsyncReply int32Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<int>.ready(data.getInt32(offset));
  }

  static AsyncReply uInt32Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<int>.ready(data.getUint32(offset));
  }

  static AsyncReply float32Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<double>.ready(data.getFloat32(offset));
  }

  static AsyncReply float64Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<double>.ready(data.getFloat64(offset));
  }

  static AsyncReply float128Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    // @TODO
    return AsyncReply<double>.ready(data.getFloat64(offset));
  }

  static AsyncReply int128Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    // @TODO
    return AsyncReply<int>.ready(data.getInt64(offset));
  }

  static AsyncReply uInt128Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<int>.ready(data.getUint64(offset));
  }

  static AsyncReply int64Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<int>.ready(data.getInt64(offset));
  }

  static AsyncReply uInt64Parser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<int>.ready(data.getUint64(offset));
  }

  static AsyncReply dateTimeParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return AsyncReply<DateTime>.ready(data.getDateTime(offset));
  }

  static AsyncReply resourceParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    if (connection != null) {
      var id = data.getUint32(offset);
      return connection.fetch(id, requestSequence);
    }
    throw Exception("Can't parse resource with no connection");
  }

  static AsyncReply localResourceParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var id = data.getUint32(offset);
    return Warehouse.getById(id);
  }

  static AsyncReply rawDataParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<DC>.ready(data.clip(offset, length));
  }

  static AsyncReply stringParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    return new AsyncReply<String>.ready(data.getString(offset, length));
  }

  static AsyncReply recordParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var reply = new AsyncReply<IRecord>();

    var classId = data.getGuid(offset);
    offset += 16;
    length -= 16;

    var template = Warehouse.getTemplateByClassId(classId, TemplateType.Record);

    var initRecord = (TypeTemplate template) =>
        listParser(data, offset, length, connection, requestSequence).then((r) {
          var ar = r as List;
          IRecord record;

          if (template.definedType != null) {
            record = Warehouse.createInstance(template.definedType!) as IRecord;
          } else {
            record = Record();
          }

          var kv = Map<String, dynamic>();

          for (var i = 0; i < template.properties.length; i++)
            kv[template.properties[i].name] = ar[i];

          record.deserialize(kv);

          reply.trigger(record);
        });

    if (template != null) {
      initRecord(template);
    } else {
      if (connection == null)
        throw Exception("Can't parse record with no connection");

      connection.getTemplate(classId).then((tmp) {
        if (tmp == null)
          reply.triggerError(AsyncException(
              ErrorType.Management,
              ExceptionCode.TemplateNotFound.index,
              "Template not found for record."));
        else
          initRecord(tmp);
      }).error((x) => reply.triggerError(x));
    }

    return reply;
  }

  static AsyncReply constantParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    throw Exception("NotImplementedException");
  }

  static AsyncReply enumParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var classId = data.getGuid(offset);
    offset += 16;
    var index = data[offset++];

    var template = Warehouse.getTemplateByClassId(classId, TemplateType.Enum);

    if (template != null) {
      if (template.definedType != null) {
        var enumVal = Warehouse.createInstance(template.definedType!) as IEnum;
        enumVal.index = index;
        enumVal.name = template.constants[index].name;
        enumVal.value = template.constants[index].value;
        return new AsyncReply.ready(enumVal);
      } else {
        return AsyncReply.ready(IEnum(index, template.constants[index].value,
            template.constants[index].name));
      }
    } else {
      var reply = new AsyncReply();

      if (connection == null)
        throw Exception("Can't parse enum with no connection");
      connection.getTemplate(classId).then((tmp) {
        if (tmp != null) {
          if (tmp.definedType != null) {
            var enumVal = Warehouse.createInstance(tmp.definedType!) as IEnum;
            enumVal.index = index;
            enumVal.name = tmp.constants[index].name;
            enumVal.value = tmp.constants[index].value;
            reply.trigger(enumVal);
          } else {
            reply.trigger(IEnum(
                index, tmp.constants[index].value, tmp.constants[index].name));
          }
        } else
          reply.triggerError(Exception("Template not found for enum"));
      }).error((x) => reply.triggerError(x));

      return reply;
    }
  }

  static AsyncReply recordListParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var rt = new AsyncBag();

    while (length > 0) {
      var parsed = Codec.parse(data, offset, connection, requestSequence);

      rt.add(parsed.reply);

      if (parsed.size > 0) {
        offset += parsed.size;
        length -= parsed.size;
      } else
        throw new Exception("Error while parsing structured data");
    }

    rt.seal();
    return rt;
  }

  static AsyncReply resourceListParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var rt = new AsyncBag();

    while (length > 0) {
      var parsed = Codec.parse(data, offset, connection, requestSequence);

      rt.add(parsed.reply);

      if (parsed.size > 0) {
        offset += parsed.size;
        length -= parsed.size;
      } else
        throw new Exception("Error while parsing structured data");
    }

    rt.seal();
    return rt;
  }

  static AsyncBag listParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var rt = new AsyncBag();

    while (length > 0) {
      var parsed = Codec.parse(data, offset, connection, requestSequence);

      rt.add(parsed.reply);

      if (parsed.size > 0) {
        offset += parsed.size;
        length -= parsed.size;
      } else
        throw new Exception("Error while parsing structured data");
    }

    rt.seal();
    return rt;
  }

  static AsyncReply typedMapParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    // get key type
    var keyRep = RepresentationType.parse(data, offset);
    offset += keyRep.size;
    length -= keyRep.size;

    var valueRep = RepresentationType.parse(data, offset);
    offset += valueRep.size;
    length -= valueRep.size;

    var map = Map();
    var rt = new AsyncReply();

    var results = new AsyncBag();

    while (length > 0) {
      var parsed = Codec.parse(data, offset, connection, requestSequence);

      results.add(parsed.reply);

      if (parsed.size > 0) {
        offset += parsed.size;
        length -= parsed.size;
      } else
        throw new Exception("Error while parsing structured data");
    }

    results.seal();

    results.then((ar) {
      for (var i = 0; i < ar.length; i += 2) map[ar[i]] = ar[i + 1];

      rt.trigger(map);
    });

    return rt;
  }

  static AsyncReply tupleParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var results = new AsyncBag();
    var rt = new AsyncReply();

    var tupleSize = data[offset++];
    length--;

    var types = <Type>[];

    for (var i = 0; i < tupleSize; i++) {
      var rep = RepresentationType.parse(data, offset);
      if (rep.type != null) types.add(rep.type.getRuntimeType() ?? Object);
      offset += rep.size;
      length -= rep.size;
    }

    while (length > 0) {
      var parsed = Codec.parse(data, offset, connection, requestSequence);

      results.add(parsed.reply);

      if (parsed.size > 0) {
        offset += parsed.size;
        length -= parsed.size;
      } else
        throw new Exception("Error while parsing structured data");
    }

    results.seal();

    results.then((ar) {
      rt.trigger(Tuple(ar));
    });

    return rt;
  }

  static AsyncReply typedListParser(DC data, int offset, int length,
      DistributedConnection? connection, List<int>? requestSequence) {
    var rt = new AsyncBag();

    // get the type
    var rep = RepresentationType.parse(data, offset);

    offset += rep.size;
    length -= rep.size;

    var runtimeType = rep.type.getRuntimeType();

    rt.arrayType = runtimeType;

    while (length > 0) {
      var parsed = Codec.parse(data, offset, connection, requestSequence);

      rt.add(parsed.reply);

      if (parsed.size > 0) {
        offset += parsed.size;
        length -= parsed.size;
      } else
        throw new Exception("Error while parsing structured data");
    }

    rt.seal();
    return rt;
  }

  static AsyncBag<PropertyValue> PropertyValueArrayParser(
      DC data,
      int offset,
      int length,
      DistributedConnection? connection,
      List<int>? requestSequence) //, bool ageIncluded = true)
  {
    var rt = new AsyncBag<PropertyValue>();

    listParser(data, offset, length, connection, requestSequence).then((x) {
      var pvs = <PropertyValue>[];

      for (var i = 0; i < x.length; i += 3)
        pvs.add(new PropertyValue(x[2], x[0] as int, x[1] as DateTime));

      rt.trigger(pvs);
    });

    return rt;
  }

  static PropertyValueParserResults propertyValueParser(
      DC data,
      int offset,
      DistributedConnection? connection,
      List<int>? requestSequence) //, bool ageIncluded = true)
  {
    var reply = new AsyncReply<PropertyValue>();

    var age = data.getUint64(offset);
    offset += 8;

    DateTime date = data.getDateTime(offset);
    offset += 8;

    var parsed = Codec.parse(data, offset, connection, requestSequence);

    parsed.reply.then((value) {
      reply.trigger(new PropertyValue(value, age, date));
    });

    return PropertyValueParserResults(16 + parsed.size, reply);
  }

  static AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>>
      historyParser(DC data, int offset, int length, IResource resource,
          DistributedConnection? connection, List<int>? requestSequence) {
    throw Exception("Not implemented");
    // @TODO
    // var list = new KeyList<PropertyTemplate, List<PropertyValue>>();

    // var reply = new AsyncReply<KeyList<PropertyTemplate, List<PropertyValue[]>>>();

    // var bagOfBags = new AsyncBag<PropertyValue[]>();

    // var ends = offset + length;
    // while (offset < ends)
    // {
    //     var index = data[offset++];
    //     var pt = resource.Instance.Template.GetPropertyTemplateByIndex(index);
    //     list.Add(pt, null);
    //     var cs = data.GetUInt32(offset);
    //     offset += 4;

    //     var (len, pv) = PropertyValueParser(data, offset, connection);

    //     bagOfBags.Add(pv);// ParsePropertyValueArray(data, offset, cs, connection));
    //     offset += len;
    // }

    // bagOfBags.Seal();

    // bagOfBags.Then(x =>
    // {
    //     for (var i = 0; i < list.Count; i++)
    //         list[list.Keys.ElementAt(i)] = x[i];

    //     reply.Trigger(list);
    // });

    // return reply;
  }
}
