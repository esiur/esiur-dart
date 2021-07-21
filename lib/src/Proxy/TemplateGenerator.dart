import 'dart:io';

import '../Data/DataType.dart';
import '../Net/IIP/DistributedConnection.dart';
import '../Resource/Template/TemplateType.dart';
import '../Resource/Warehouse.dart';

import '../Resource/Template/TemplateDataType.dart';

import '../Resource/Template/TypeTemplate.dart';

class TemplateGenerator {
//  static RegExp urlRegex = RegExp("^(?:([\S]*)://([^/]*)/?)");
  static final _urlRegex = RegExp(r'^(?:([^\s|:]*):\/\/([^\/]*)\/?(.*))');

  static String generateRecord(
      TypeTemplate template, List<TypeTemplate> templates) {
    var className = template.className.split('.').last;
    var rt = StringBuffer();

    rt.writeln("class ${className} extends IRecord {");

    template.properties.forEach((p) {
      var ptTypeName = getTypeName(template, p.valueType, templates);
      rt.writeln("${ptTypeName}? ${p.name};");
      rt.writeln();
    });

    rt.writeln();

    rt.writeln("@override");
    rt.writeln("void deserialize(Map<String, dynamic> value) {");

    template.properties.forEach((p) {
      rt.writeln("${p.name} = value['${p.name}'];");
    });

    rt.writeln("}");
    rt.writeln();

    rt.writeln("@override");
    rt.writeln("Map<String, dynamic> serialize() {");
    rt.writeln("var rt = Map<String, dynamic>();");

    template.properties.forEach((p) {
      rt.writeln("rt['${p.name}'] = ${p.name};");
    });

    rt.writeln("return rt;");
    rt.writeln("}");

    // add template
    var descProps = template.properties.map((p) {
      var isArray = p.valueType.type & 0x80 == 0x80;
      var ptType = p.valueType.type & 0x7F;
      var ptTypeName = getTypeName(
          template, TemplateDataType(ptType, p.valueType.typeGuid), templates);
//      return "Prop(\"${p.name}\", ${ptTypeName}, ${isArray})";
      return "Prop('${p.name}', ${ptTypeName}, ${isArray}, ${_escape(p.readExpansion)}, ${_escape(p.writeExpansion)})";
    }).join(', ');

    rt.writeln("""@override
               TemplateDescriber get template => TemplateDescriber('${template.className}', properties: [${descProps}]);""");

    rt.writeln("\r\n}");

    return rt.toString();
  }

  static String _translateClassName(String className) {
    var cls = className.split('.');
    var nameSpace = cls.take(cls.length - 1).join('_').toLowerCase();
    return "$nameSpace.${cls.last}";
  }

  static String getTypeName(TypeTemplate forTemplate,
      TemplateDataType templateDataType, List<TypeTemplate> templates) {
    if (templateDataType.type == DataType.Resource) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return forTemplate.className.split('.').last;
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            (x.type == TemplateType.Resource ||
                x.type == TemplateType.Wrapper));

        if (tmp == null) return "dynamic"; // something went wrong

        return _translateClassName(tmp.className);
      }
    } else if (templateDataType.type == DataType.ResourceArray) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return "List<${forTemplate.className.split('.').last}>";
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            (x.type == TemplateType.Resource ||
                x.type == TemplateType.Wrapper));

        if (tmp == null) return "dynamic"; // something went wrong

        return "List<${_translateClassName(tmp.className)}>";
      }
    } else if (templateDataType.type == DataType.Record) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return forTemplate.className.split('.').last;
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            x.type == TemplateType.Record);
        if (tmp == null) return "dynamic"; // something went wrong
        return _translateClassName(tmp.className);
      }
    } else if (templateDataType.type == DataType.RecordArray) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return "List<${forTemplate.className.split('.').last}>";
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            x.type == TemplateType.Record);
        if (tmp == null) return "dynamic"; // something went wrong
        return "List<${_translateClassName(tmp.className)}>";
      }
    }

    var name = ((x) {
      switch (x) {
        case DataType.Bool:
          return "bool";
        case DataType.BoolArray:
          return "List<bool>";
        case DataType.Char:
          return "String";
        case DataType.CharArray:
          return "List<String>";
        case DataType.DateTime:
          return "DateTime";
        case DataType.DateTimeArray:
          return "List<DateTime>";
        case DataType.Decimal:
          return "double";
        case DataType.DecimalArray:
          return "List<double>";
        case DataType.Float32:
          return "double";
        case DataType.Float32Array:
          return "List<double>";
        case DataType.Float64:
          return "double";
        case DataType.Float64Array:
          return "List<double>";
        case DataType.Int16:
          return "int";
        case DataType.Int16Array:
          return "List<int>";
        case DataType.Int32:
          return "int";
        case DataType.Int32Array:
          return "List<int>";
        case DataType.Int64:
          return "int";
        case DataType.Int64Array:
          return "List<int>";
        case DataType.Int8:
          return "int";
        case DataType.Int8Array:
          return "List<int>";
        case DataType.String:
          return "String";
        case DataType.StringArray:
          return "List<String>";
        case DataType.Structure:
          return "Structure";
        case DataType.StructureArray:
          return "List<Structure>";
        case DataType.UInt16:
          return "int";
        case DataType.UInt16Array:
          return "List<int>";
        case DataType.UInt32:
          return "int";
        case DataType.UInt32Array:
          return "List<int>";
        case DataType.UInt64:
          return "int";
        case DataType.UInt64Array:
          return "List<int>";
        case DataType.UInt8:
          return "int";
        case DataType.UInt8Array:
          return "List<int>";
        case DataType.VarArray:
          return "List<dynamic>";
        case DataType.Void:
          return "dynamic";
        default:
          return "dynamic";
      }
    })(templateDataType.type);

    return name;
  }

  static isNullOrEmpty(v) {
    return v == null || v == "";
  }

  static Future<String> getTemplate(String url,
      [String dir = null,
      String username = null,
      String password = null]) async {
    try {
      if (!_urlRegex.hasMatch(url)) throw Exception("Invalid IIP URL");

      var path = _urlRegex.allMatches(url).first;
      var con = await Warehouse.get<DistributedConnection>(
          path[1] + "://" + path[2],
          !isNullOrEmpty(username) && !isNullOrEmpty(password)
              ? {username: username, password: password}
              : null);

      if (con == null) throw Exception("Can't connect to server");

      if (isNullOrEmpty(dir)) dir = path[2].replaceAll(":", "_");

      var templates = await con.getLinkTemplates(path[3]);

      // no longer needed
      Warehouse.remove(con);

      var dstDir = Directory("lib/$dir");

      if (!dstDir.existsSync()) dstDir.createSync();

      //Map<String, String> namesMap = Map<String, String>();

      var makeImports = (TypeTemplate skipTemplate) {
        var imports = StringBuffer();
        imports.writeln("import 'dart:async';");
        imports.writeln("import 'package:esiur/esiur.dart';");
        // make import names
        templates.forEach((tmp) {
          if (tmp != skipTemplate) {
            var cls = tmp.className.split('.');
            var nameSpace = cls.take(cls.length - 1).join('_').toLowerCase();
            imports.writeln("import '${tmp.className}.g.dart' as $nameSpace;");
          }
        });

        imports.writeln();
        return imports.toString();
      };

      // make sources
      templates.forEach((tmp) {
        print("Generating `${tmp.className}`.");

        if (tmp.type == TemplateType.Resource) {
          var source = makeImports(tmp) + generateClass(tmp, templates);
          var f = File("${dstDir.path}/${tmp.className}.g.dart");
          f.writeAsStringSync(source);
        } else if (tmp.type == TemplateType.Record) {
          var source = makeImports(tmp) + generateRecord(tmp, templates);
          var f = File("${dstDir.path}/${tmp.className}.g.dart");
          f.writeAsStringSync(source);
        }
      });

      // generate info class

      var defineCreators = templates.map((tmp) {
        // creator
        var className = _translateClassName(tmp.className);
        return "Warehouse.defineCreator(${className}, () => ${className}(), () => <${className}>[]);";
      }).join("\r\n");

      var putTemplates = templates.map((tmp) {
        var className = _translateClassName(tmp.className);
        return "Warehouse.putTemplate(TypeTemplate.fromType(${className}));";
      }).join("\r\n");

      var typesFile = makeImports(null) +
          "\r\n void init_${dir}(){ ${defineCreators} \r\n ${putTemplates}}";

      var f = File("${dstDir.path}/init.g.dart");
      f.writeAsStringSync(typesFile);

      return dstDir.path;
    } catch (ex) {
      throw ex;
    }
  }

  static String _escape(String str) {
    if (str == null)
      return "null";
    else
      return "r'$str'";
  }

  static String generateClass(
      TypeTemplate template, List<TypeTemplate> templates) {
    var className = template.className.split('.').last;

    var rt = StringBuffer();
    rt.writeln("class $className extends DistributedResource {");

    rt.writeln(
//      "$className(DistributedConnection connection, int instanceId, int age, String link) : super(connection, instanceId, age, link) {");
        "$className() {");

    template.events.forEach((e) {
      rt.writeln("on('${e.name}', (x) => _${e.name}Controller.add(x));");
    });

    rt.writeln("}");

    template.functions.forEach((f) {
      var rtTypeName = getTypeName(template, f.returnType, templates);
      rt.write("AsyncReply<$rtTypeName> ${f.name}(");
      rt.write(f.arguments
          .map((x) => getTypeName(template, x.type, templates) + " " + x.name)
          .join(","));

      rt.writeln(") {");
      rt.writeln("var rt = AsyncReply<$rtTypeName>();");
      rt.writeln(
          "internal_invokeByArrayArguments(${f.index}, [${f.arguments.map((x) => x.name).join(',')}])");
      rt.writeln(".then<dynamic>((x) => rt.trigger(x))");
      rt.writeln(".error((x) => rt.triggerError(x))");
      rt.writeln(".chunk((x) => rt.triggerChunk(x));");
      rt.writeln("return rt; }");
    });

    template.properties.forEach((p) {
      var ptTypeName = getTypeName(template, p.valueType, templates);
      rt.writeln("${ptTypeName} get ${p.name} { return get(${p.index}); }");
      rt.writeln(
          "set ${p.name}(${ptTypeName} value) { set(${p.index}, value); }");
    });

    template.events.forEach((e) {
      var etTypeName = getTypeName(template, e.argumentType, templates);

      rt.writeln(
          "final _${e.name}Controller = StreamController<$etTypeName>();");
      rt.writeln("Stream<$etTypeName> get ${e.name} { ");
      rt.writeln("return _${e.name}Controller.stream;");
      rt.writeln("}");
    });

    // add template
    var descProps = template.properties.map((p) {
      var isArray = p.valueType.type & 0x80 == 0x80;
      var ptType = p.valueType.type & 0x7F;
      var ptTypeName = getTypeName(
          template, TemplateDataType(ptType, p.valueType.typeGuid), templates);
      return "Prop('${p.name}', ${ptTypeName}, ${isArray}, ${_escape(p.readExpansion)}, ${_escape(p.writeExpansion)})";
    }).join(', ');

    var descFuncs = template.functions.map((f) {
      var isArray = f.returnType.type & 0x80 == 0x80;
      var ftType = f.returnType.type & 0x7F;
      var ftTypeName = getTypeName(
          template, TemplateDataType(ftType, f.returnType.typeGuid), templates);

      var args = f.arguments.map((a) {
        var isArray = a.type.type & 0x80 == 0x80;
        var atType = a.type.type & 0x7F;
        var atTypeName = getTypeName(
            template, TemplateDataType(atType, a.type.typeGuid), templates);
        return "Arg('${a.name}', ${atTypeName}, ${isArray})";
      }).join(', ');

      return "Func('${f.name}', ${ftTypeName}, ${isArray}, [${args}], ${_escape(f.expansion)})";
    }).join(', ');

    var descEvents = template.events.map((e) {
      var isArray = e.argumentType.type & 0x80 == 0x80;
      var etType = e.argumentType.type & 0x7F;
      var etTypeName = getTypeName(template,
          TemplateDataType(etType, e.argumentType.typeGuid), templates);
      return "Evt('${e.name}', ${etTypeName}, ${isArray}, ${e.listenable}, ${_escape(e.expansion)})";
    }).join(', ');

    rt.writeln(
        "TemplateDescriber get template => TemplateDescriber('${template.className}', properties: [${descProps}], functions: [${descFuncs}], events: [$descEvents]);");

    rt.writeln("\r\n}");

    return rt.toString();
  }
}
