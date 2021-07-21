import 'dart:ffi';

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
import '../StorageMode.dart';
import 'ArgumentTemplate.dart';
import 'TemplateDataType.dart';
import 'TemplateType.dart';

class TypeTemplate {
  Guid _classId;
  String _className;
  List<MemberTemplate> _members = [];
  List<FunctionTemplate> _functions = [];
  List<EventTemplate> _events = [];
  List<PropertyTemplate> _properties = [];
  int _version;
  //bool isReady;

  TemplateType _templateType;

  DC _content;

  DC get content => _content;

  TemplateType get type => _templateType;

  Type _definedType;

  Type get definedType => _definedType;
/*
    MemberTemplate getMemberTemplate(MemberInfo member)
    {
        if (member is MethodInfo)
            return getFunctionTemplate(member.Name);
        else if (member is EventInfo)
            return getEventTemplate(member.Name);
        else if (member is PropertyInfo)
            return getPropertyTemplate(member.Name);
        else
            return null;
    }
    */

//@TODO: implement
  static List<TypeTemplate> getDependencies(TypeTemplate template) => [];

  EventTemplate getEventTemplateByName(String eventName) {
    for (var i in _events) if (i.name == eventName) return i;
    return null;
  }

  EventTemplate getEventTemplateByIndex(int index) {
    for (var i in _events) if (i.index == index) return i;
    return null;
  }

  FunctionTemplate getFunctionTemplateByName(String functionName) {
    for (var i in _functions) if (i.name == functionName) return i;
    return null;
  }

  FunctionTemplate getFunctionTemplateByIndex(int index) {
    for (var i in _functions) if (i.index == index) return i;
    return null;
  }

  PropertyTemplate getPropertyTemplateByIndex(int index) {
    for (var i in _properties) if (i.index == index) return i;
    return null;
  }

  PropertyTemplate getPropertyTemplateByName(String propertyName) {
    for (var i in _properties) if (i.name == propertyName) return i;
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

  TypeTemplate.fromType(Type type, [bool addToWarehouse = false]) {
    // debugging print("FromType ${type.toString()}");

    var instance = Warehouse.createInstance(type);

    if (instance is DistributedResource)
      _templateType = TemplateType.Wrapper;
    else if (instance is IResource)
      _templateType = TemplateType.Resource;
    else if (instance is IRecord)
      _templateType = TemplateType.Record;
    else
      throw new Exception(
          "Type must implement IResource, IRecord or inherit from DistributedResource.");

    // if (instance is IRecord)
    //   _templateType = TemplateType.Record;
    // else if (instance is IResource)
    //   _templateType = TemplateType.Resource;
    // else
    //   throw new Exception("Type is neither a resource nor a record.");

    TemplateDescriber describer = instance.template;

    _definedType = type;

    _className = describer.nameSpace;

    // set guid
    _classId = getTypeGuid(_className);

    _version = describer.version;

    if (addToWarehouse) Warehouse.putTemplate(this);
    // _templates.add(template.classId, template);

    if (describer.properties != null)
      for (var i = 0; i < describer.properties.length; i++) {
        var pi = describer.properties[i];
        var pt = PropertyTemplate(
            this,
            i,
            pi.name,
            TemplateDataType.fromType(pi.type, pi.isArray),
            pi.readAnnotation,
            pi.writeAnnotation,
            0);
        properties.add(pt);
      }

    if (describer.functions != null)
      for (var i = 0; i < describer.functions.length; i++) {
        var fi = describer.functions[i];

        List<ArgumentTemplate> args = fi.argsType
            .map((arg) => ArgumentTemplate(
                arg.name, TemplateDataType.fromType(arg.type, arg.isArray)))
            .toList();

        var ft = FunctionTemplate(
            this,
            i,
            fi.name,
            args,
            TemplateDataType.fromType(fi.returnType, fi.isArray),
            fi.annotation);

        functions.add(ft);
      }

    if (describer.events != null)
      for (var i = 0; i < describer.events.length; i++) {
        var ei = describer.events[i];

        var et = new EventTemplate(
            this,
            i,
            ei.name,
            TemplateDataType.fromType(ei.type, ei.isArray),
            ei.annotation,
            ei.listenable);

        events.add(et);
      }

    // append signals
    events.forEach(_members.add);
    // append slots
    functions.forEach(_members.add);
// append properties
    properties.forEach(_members.add);

    // bake it binarily
    var b = new BinaryList();
    b
        .addUint8(_templateType.index)
        .addGuid(classId)
        .addUint8(className.length)
        .addString(className)
        .addInt32(_version)
        .addUint16(_members.length);

    functions.forEach((ft) => b.addDC(ft.compose()));
    properties.forEach((pt) => b.addDC(pt.compose()));
    events.forEach((et) => b.addDC(et.compose()));

    _content = b.toDC();
  }

  // static Guid getTypeGuid(Type type) => getTypeGuid(type.toString());

  //  static Guid getTypeGuid(String typeName)
  // {
  //     var tn = Encoding.UTF8.GetBytes(typeName);
  //     var hash = SHA256.Create().ComputeHash(tn).Clip(0, 16);

  //     return new Guid(hash);
  // }

  // static Type GetElementType(Type type) => type switch
  //     {
  //         { IsArray: true } => type.GetElementType(),
  //         { IsEnum: true } => type.GetEnumUnderlyingType(),
  //         (_) => type
  //     };

  // static TypeTemplate[] GetRuntimeTypes(TypeTemplate template)
  // {

  //     List<TypeTemplate> list = [];

  //     list.add(template);

  //     var getRuntimeTypes = null;

  //     getRuntimeTypes = (TypeTemplate tmp, List<TypeTemplate> bag)
  //     {
  //         if (template.resourceType == null)
  //             return;

  //         // functions
  //         tmp.functions.foreach((f){

  //             var frtt = Warehouse.GetTemplate(getElementType(f.MethodInfo.ReturnType));
  //             if (frtt != null)
  //             {
  //                 if (!bag.Contains(frtt))
  //                 {
  //                     list.Add(frtt);
  //                     getRuntimeTypes(frtt, bag);
  //                 }
  //             }

  //             var args = f.MethodInfo.GetParameters();

  //             for(var i = 0; i < args.Length - 1; i++)
  //             {
  //                 var fpt = Warehouse.GetTemplate(GetElementType(args[i].ParameterType));
  //                 if (fpt != null)
  //                 {
  //                     if (!bag.Contains(fpt))
  //                     {
  //                         bag.Add(fpt);
  //                         getRuntimeTypes(fpt, bag);
  //                     }
  //                 }
  //             }

  //             // skip DistributedConnection argument
  //             if (args.Length > 0)
  //             {
  //                 var last = args.Last();
  //                 if (last.ParameterType != typeof(DistributedConnection))
  //                 {
  //                     var fpt = Warehouse.GetTemplate(GetElementType(last.ParameterType));
  //                     if (fpt != null)
  //                     {
  //                         if (!bag.Contains(fpt))
  //                         {
  //                             bag.Add(fpt);
  //                             getRuntimeTypes(fpt, bag);
  //                         }
  //                     }
  //                 }
  //             }

  //         });

  //         // properties
  //         foreach (var p in tmp.properties)
  //         {
  //             var pt = Warehouse.GetTemplate(GetElementType(p.PropertyInfo.PropertyType));
  //             if (pt != null)
  //             {
  //                 if (!bag.Contains(pt))
  //                 {
  //                     bag.Add(pt);
  //                     getRuntimeTypes(pt, bag);
  //                 }
  //             }
  //         }

  //         // events
  //         foreach (var e in tmp.events)
  //         {
  //             var et = Warehouse.GetTemplate(GetElementType(e.EventInfo.EventHandlerType.GenericTypeArguments[0]));

  //             if (et != null)
  //             {
  //                 if (!bag.Contains(et))
  //                 {
  //                     bag.Add(et);
  //                     getRuntimeTypes(et, bag);
  //                 }
  //             }
  //         }
  //     };

  //     getRuntimeTypes(template, list);
  //     return list.ToArray();
  // }

  // @TODO Create template from type
  // TypeTemplate.fromType(Type type) {

  // }

/*
    TypeTemplate(Type type)
    {

        type = ResourceProxy.GetBaseType(type);

        // set guid

        var typeName = Encoding.UTF8.GetBytes(type.FullName);
        var hash = SHA256.Create().ComputeHash(typeName).Clip(0, 16);

        classId = new Guid(hash);
        className = type.FullName;


#if NETSTANDARD1_5
        PropertyInfo[] propsInfo = type.GetTypeInfo().GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        EventInfo[] eventsInfo = type.GetTypeInfo().GetEvents(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        MethodInfo[] methodsInfo = type.GetTypeInfo().GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);

#else
        PropertyInfo[] propsInfo = type.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        EventInfo[] eventsInfo = type.GetEvents(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        MethodInfo[] methodsInfo = type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
#endif

        //byte currentIndex = 0;

        byte i = 0;

        foreach (var pi in propsInfo)
        {
            var ps = (ResourceProperty[])pi.GetCustomAttributes(typeof(ResourceProperty), true);
            if (ps.Length > 0)
            {
                var pt = new PropertyTemplate(this, i++, pi.Name, ps[0].ReadExpansion, ps[0].WriteExpansion, ps[0].Storage);
                pt.Info = pi;
                properties.Add(pt);
            }
        }

        i = 0;

        foreach (var ei in eventsInfo)
        {
            var es = (ResourceEvent[])ei.GetCustomAttributes(typeof(ResourceEvent), true);
            if (es.Length > 0)
            {
                var et = new EventTemplate(this, i++, ei.Name, es[0].Expansion);
                events.Add(et);
            }
        }

        i = 0;
        foreach (MethodInfo mi in methodsInfo)
        {
            var fs = (ResourceFunction[])mi.GetCustomAttributes(typeof(ResourceFunction), true);
            if (fs.Length > 0)
            {
                var ft = new FunctionTemplate(this, i++, mi.Name, mi.ReturnType == typeof(void), fs[0].Expansion);
                functions.Add(ft);
            }
        }

        // append signals
        for (i = 0; i < events.Count; i++)
            members.Add(events[i]);
        // append slots
        for (i = 0; i < functions.Count; i++)
            members.Add(functions[i]);
        // append properties
        for (i = 0; i < properties.Count; i++)
            members.Add(properties[i]);

        // bake it binarily
        var b = new BinaryList();
        b.AddGuid(classId)
            .AddUInt8((byte)className.Length)
            .AddString(className)
            .AddInt32(version)
            .AddUInt16((ushort)members.Count);


        foreach (var ft in functions)
            b.AddUInt8Array(ft.Compose());
        foreach (var pt in properties)
            b.AddUInt8Array(pt.Compose());
        foreach (var et in events)
            b.AddUInt8Array(et.Compose());

        content = b.ToArray();
    }

*/

  TypeTemplate.parse(DC data, [int offset = 0, int contentLength]) {
    // cool Dart feature
    contentLength ??= data.length;

    int ends = offset + contentLength;

    int oOffset = offset;

    // start parsing...

    //var od = new TypeTemplate();
    _content = data.clip(offset, contentLength);

    _templateType = TemplateType.values[data.getUint8(offset++)];

    _classId = data.getGuid(offset);
    offset += 16;
    _className = data.getString(offset + 1, data[offset]);
    offset += data[offset] + 1;

    _version = data.getInt32(offset);
    offset += 4;

    var methodsCount = data.getUint16(offset);
    offset += 2;

    var functionIndex = 0;
    var propertyIndex = 0;
    var eventIndex = 0;

    for (int i = 0; i < methodsCount; i++) {
      var type = data[offset] >> 5;

      if (type == 0) // function
      {
        String expansion = null;
        var hasExpansion = ((data[offset++] & 0x10) == 0x10);

        var name = data.getString(offset + 1, data[offset]);
        offset += data[offset] + 1;

        var dt = TemplateDataType.parse(data, offset);
        offset += dt.size;

        // arguments count
        var argsCount = data[offset++];
        List<ArgumentTemplate> arguments = [];

        for (var a = 0; a < argsCount; a++) {
          var art = ArgumentTemplate.parse(data, offset);
          arguments.add(art.value);
          offset += art.size;
        }

        if (hasExpansion) // expansion ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          expansion = data.getString(offset, cs);
          offset += cs;
        }

        var ft = new FunctionTemplate(
            this, functionIndex++, name, arguments, dt.value, expansion);

        _functions.add(ft);
      } else if (type == 1) // property
      {
        String readExpansion = null, writeExpansion = null;

        var hasReadExpansion = ((data[offset] & 0x8) == 0x8);
        var hasWriteExpansion = ((data[offset] & 0x10) == 0x10);
        var recordable = ((data[offset] & 1) == 1);
        var permission = (data[offset++] >> 1) & 0x3;
        var name = data.getString(offset + 1, data[offset]);

        offset += data[offset] + 1;

        var dt = TemplateDataType.parse(data, offset);

        offset += dt.size;

        if (hasReadExpansion) // expansion ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          readExpansion = data.getString(offset, cs);
          offset += cs;
        }

        if (hasWriteExpansion) // expansion ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          writeExpansion = data.getString(offset, cs);
          offset += cs;
        }

        var pt = new PropertyTemplate(
            this,
            propertyIndex++,
            name,
            dt.value,
            readExpansion,
            writeExpansion,
            recordable ? StorageMode.Recordable : StorageMode.Volatile);

        _properties.add(pt);
      } else if (type == 2) // Event
      {
        String expansion = null;
        var hasExpansion = ((data[offset] & 0x10) == 0x10);
        var listenable = ((data[offset++] & 0x8) == 0x8);

        var name = data.getString(offset + 1, data[offset]);
        offset += data[offset] + 1;

        var dt = TemplateDataType.parse(data, offset);

        offset += dt.size;

        if (hasExpansion) // expansion ?
        {
          var cs = data.getUint32(offset);
          offset += 4;
          expansion = data.getString(offset, cs);
          offset += cs;
        }

        var et = new EventTemplate(
            this, eventIndex++, name, dt.value, expansion, listenable);

        _events.add(et);
      }
    }

    // append signals
    for (int i = 0; i < _events.length; i++) _members.add(_events[i]);
    // append slots
    for (int i = 0; i < _functions.length; i++) _members.add(_functions[i]);
    // append properties
    for (int i = 0; i < _properties.length; i++) _members.add(_properties[i]);
  }
}
