import '../../Data/Codec.dart';
import '../../Data/IEnum.dart';
import '../../Data/RepresentationType.dart';

import '../../Net/IIP/DistributedResource.dart';

import '../../Data/BinaryList.dart';
import '../../Security/Integrity/SHA256.dart';

import '../../Data/IRecord.dart';
import '../IResource.dart';
import '../Warehouse.dart';
import './TemplateDescriber.dart';

import './MemberTemplate.dart';
import '../../Data/Guid.dart';
import '../../Data/DC.dart';
import './EventTemplate.dart';
import './PropertyTemplate.dart';
import './FunctionTemplate.dart';
import 'ArgumentTemplate.dart';
import 'ConstantTemplate.dart';
import 'TemplateType.dart';

class TypeTemplate {
  late Guid _classId;
  Guid? _parentId = null;

  String? _annotation;

  late String _className;
  List<MemberTemplate> _members = [];
  List<FunctionTemplate> _functions = [];
  List<EventTemplate> _events = [];
  List<PropertyTemplate> _properties = [];
  List<ConstantTemplate> _constants = [];

  late int _version;
  //bool isReady;

  late TemplateType _templateType;

  late DC _content;

  String? get annotation => _annotation;

  DC get content => _content;

  TemplateType get type => _templateType;

  Guid? get parentId => _parentId;

  Type? _definedType;

  Type? get definedType => _definedType;

  Type? get parentDefinedType => _parentDefinedType;
  Type? _parentDefinedType;

//@TODO: implement
  static List<TypeTemplate> getDependencies(TypeTemplate template) => [];

  EventTemplate? getEventTemplateByName(String eventName) {
    for (var i in _events) if (i.name == eventName) return i;
    return null;
  }

  EventTemplate? getEventTemplateByIndex(int index) {
    for (var i in _events) if (i.index == index) return i;
    return null;
  }

  FunctionTemplate? getFunctionTemplateByName(String functionName) {
    for (var i in _functions) if (i.name == functionName) return i;
    return null;
  }

  FunctionTemplate? getFunctionTemplateByIndex(int index) {
    for (var i in _functions) if (i.index == index) return i;
    return null;
  }

  PropertyTemplate? getPropertyTemplateByIndex(int index) {
    for (var i in _properties) if (i.index == index) return i;
    return null;
  }

  PropertyTemplate? getPropertyTemplateByName(String propertyName) {
    for (var i in _properties) if (i.name == propertyName) return i;
    return null;
  }

  ConstantTemplate? getConstantByIndex(int index) {
    for (var i in _constants) if (i.index == index) return i;
    return null;
  }

  ConstantTemplate? getConstantByName(String constantName) {
    for (var i in _constants) if (i.name == constantName) return i;
    return null;
  }

  static Guid getTypeGuid(String typeName) {
    var tn = DC.stringToBytes(typeName);
    var hash = SHA256.compute(tn).clip(0, 16);
    return new Guid(hash);
  }

  Guid get classId => _classId;

  String get className => _className;

  List<MemberTemplate> get methods => _members;

  List<FunctionTemplate> get functions => _functions;

  List<EventTemplate> get events => _events;

  List<PropertyTemplate> get properties => _properties;

  List<ConstantTemplate> get constants => _constants;

  TypeTemplate.fromType(Type type, [bool addToWarehouse = false]) {
    // debugging print("FromType ${type.toString()}");

    var instance = Warehouse.createInstance(type);

    TemplateDescriber describer;

    if (instance is DistributedResource) {
      _templateType = TemplateType.Wrapper;
      describer = instance.template;
    } else if (instance is IResource) {
      _templateType = TemplateType.Resource;
      describer = instance.template;
    } else if (instance is IRecord) {
      _templateType = TemplateType.Record;
      describer = instance.template;
    } else if (instance is IEnum) {
      _templateType = TemplateType.Enum;
      describer = instance.template;
    } else
      throw new Exception(
          "Type must implement IResource, IRecord, IEnum or a subtype of DistributedResource.");

    // if (instance is IRecord)
    //   _templateType = TemplateType.Record;
    // else if (instance is IResource)
    //   _templateType = TemplateType.Resource;
    // else
    //   throw new Exception("Type is neither a resource nor a record.");

    _definedType = type;

    _className = describer.nameSpace;

    // set guid
    _classId = getTypeGuid(_className);

    _version = describer.version;

    _annotation = describer.annotation;

    if (addToWarehouse) Warehouse.putTemplate(this);
    // _templates.add(template.classId, template);

    if (describer.constants != null) {
      var consts = describer.constants as List<Const>;
      for (var i = 0; i < consts.length; i++) {
        var ci = consts[i];
        var ct = ConstantTemplate(
            this,
            i,
            ci.name,
            false,
            RepresentationType.fromType(ci.type) ?? RepresentationType.Void,
            ci.value,
            ci.annotation);

        constants.add(ct);
      }
    }

    if (describer.properties != null) {
      var props = describer.properties as List<Prop>;

      for (var i = 0; i < props.length; i++) {
        var pi = props[i];
        var pt = PropertyTemplate(
            this,
            i,
            pi.name,
            false,
            RepresentationType.fromType(pi.type) ?? RepresentationType.Dynamic,
            pi.readAnnotation,
            pi.writeAnnotation,
            false);
        properties.add(pt);
      }
    }

    if (describer.functions != null) {
      var funcs = describer.functions as List<Func>;

      for (var i = 0; i < funcs.length; i++) {
        var fi = funcs[i];

        List<ArgumentTemplate> args = fi.args
            .asMap()
            .entries
            .map((arg) => ArgumentTemplate(
                arg.value.name,
                RepresentationType.fromType(arg.value.type) ??
                    RepresentationType.Dynamic,
                arg.value.optional,
                arg.key))
            .toList();

        var ft = FunctionTemplate(
            this,
            i,
            fi.name,
            false,
            fi.isStatic,
            args,
            RepresentationType.fromType(fi.returnType) ??
                RepresentationType.Void,
            fi.annotation);

        functions.add(ft);
      }
    }

    if (describer.events != null) {
      var evts = describer.events as List<Evt>;
      for (var i = 0; i < evts.length; i++) {
        var ei = evts[i];

        var et = new EventTemplate(
            this,
            i,
            ei.name,
            false,
            RepresentationType.fromType(ei.type) ?? RepresentationType.Dynamic,
            ei.annotation,
            ei.listenable);

        events.add(et);
      }
    }

    // append signals
    events.forEach(_members.add);
    // append slots
    functions.forEach(_members.add);
    // append properties
    properties.forEach(_members.add);
    // append constants
    constants.forEach(_members.add);

    // bake it binarily
    var b = BinaryList()
      ..addUint8((_annotation != null ? 0x40 : 0x0) | _templateType.index)
      ..addGuid(classId)
      ..addUint8(className.length)
      ..addString(className);

    if (_annotation != null) {
      var classAnnotationBytes = DC.stringToBytes(_annotation!);
      b
        ..addUint16(classAnnotationBytes.length)
        ..addDC(classAnnotationBytes);
    }

    b
      ..addInt32(_version)
      ..addUint16(_members.length);

    functions.forEach((ft) => b.addDC(ft.compose()));
    properties.forEach((pt) => b.addDC(pt.compose()));
    events.forEach((et) => b.addDC(et.compose()));

    _content = b.toDC();
  }

  TypeTemplate.parse(DC data, [int offset = 0, int? contentLength]) {
    // cool Dart feature
    contentLength ??= data.length;

    //int ends = offset + contentLength;

    //int oOffset = offset;

    // start parsing...

    //var od = new TypeTemplate();
    _content = data.clip(offset, contentLength);

    var hasParent = (data.getUint8(offset) & 0x80) > 0;
    var hasClassAnnotation = (data.getUint8(offset) & 0x40) > 0;

    _templateType = TemplateType.values[data.getUint8(offset++) & 0xF];

    _classId = data.getGuid(offset);
    offset += 16;
    _className = data.getString(offset + 1, data[offset]);
    offset += data[offset] + 1;

    if (hasParent) {
      _parentId = data.getGuid(offset);
      offset += 16;
    }

    if (hasClassAnnotation) {
      var len = data.getUint16(offset);
      offset += 2;
      _annotation = data.getString(offset, len);
      offset += len;
    }

    _version = data.getInt32(offset);
    offset += 4;

    var methodsCount = data.getUint16(offset);
    offset += 2;

    var functionIndex = 0;
    var propertyIndex = 0;
    var eventIndex = 0;
    var constantIndex = 0;

    for (int i = 0; i < methodsCount; i++) {
      var inherited = (data[offset] & 0x80) > 0;
      var type = (data[offset] >> 5) & 0x3;

      if (type == 0) // function
      {
        String? annotation = null;
        var isStatic = ((data[offset] & 0x4) == 0x4);

        var hasAnnotation = ((data[offset++] & 0x10) == 0x10);

        var name = data.getString(offset + 1, data[offset]);
        offset += data[offset] + 1;

        var dt = RepresentationType.parse(data, offset);
        offset += dt.size;

        // arguments count
        var argsCount = data[offset++];
        List<ArgumentTemplate> arguments = [];

        for (var a = 0; a < argsCount; a++) {
          var art = ArgumentTemplate.parse(data, offset, a);
          arguments.add(art.value);
          offset += art.size;
        }

        if (hasAnnotation) // annotation ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          annotation = data.getString(offset, cs);
          offset += cs;
        }

        var ft = new FunctionTemplate(this, functionIndex++, name, inherited,
            isStatic, arguments, dt.type, annotation);

        _functions.add(ft);
      } else if (type == 1) // property
      {
        String? readAnnotation = null, writeAnnotation = null;

        var hasReadAnnotation = ((data[offset] & 0x8) == 0x8);
        var hasWriteAnnotation = ((data[offset] & 0x10) == 0x10);
        var recordable = ((data[offset] & 1) == 1);
        var permission = (data[offset++] >> 1) & 0x3;
        var name = data.getString(offset + 1, data[offset]);

        offset += data[offset] + 1;

        var dt = RepresentationType.parse(data, offset);

        offset += dt.size;

        if (hasReadAnnotation) // annotation ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          readAnnotation = data.getString(offset, cs);
          offset += cs;
        }

        if (hasWriteAnnotation) // annotation ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          writeAnnotation = data.getString(offset, cs);
          offset += cs;
        }

        var pt = new PropertyTemplate(this, propertyIndex++, name, inherited,
            dt.type, readAnnotation, writeAnnotation, recordable);

        _properties.add(pt);
      } else if (type == 2) // Event
      {
        String? annotation = null;
        var hasAnnotation = ((data[offset] & 0x10) == 0x10);
        var listenable = ((data[offset++] & 0x8) == 0x8);

        var name = data.getString(offset + 1, data[offset]);
        offset += data[offset] + 1;

        var dt = RepresentationType.parse(data, offset);

        offset += dt.size;

        if (hasAnnotation) // annotation ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          annotation = data.getString(offset, cs);
          offset += cs;
        }

        var et = new EventTemplate(this, eventIndex++, name, inherited, dt.type,
            annotation, listenable);

        _events.add(et);
      } else if (type == 3) {
        String? annotation = null;
        var hasAnnotation = ((data[offset++] & 0x10) == 0x10);

        var name = data.getString(offset + 1, data[offset]);
        offset += data[offset] + 1;

        var dt = RepresentationType.parse(data, offset);

        offset += dt.size;

        var parsed = Codec.parse(data, offset, null, null);

        offset += parsed.size;

        if (hasAnnotation) // annotation ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          annotation = data.getString(offset, cs);
          offset += cs;
        }

        var ct = new ConstantTemplate(this, constantIndex++, name, inherited,
            dt.type, parsed.reply.result, annotation);

        _constants.add(ct);
      }
    }

    // append signals
    for (int i = 0; i < _events.length; i++) _members.add(_events[i]);
    // append slots
    for (int i = 0; i < _functions.length; i++) _members.add(_functions[i]);
    // append properties
    for (int i = 0; i < _properties.length; i++) _members.add(_properties[i]);
    // append constant
    for (int i = 0; i < _constants.length; i++) _members.add(_constants[i]);
  }
}
