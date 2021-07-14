import 'dart:io';

import '../Data/DataType.dart';
import '../Net/IIP/DistributedConnection.dart';
import '../Resource/Template/TemplateType.dart';
import '../Resource/Warehouse.dart';

import '../Resource/Template/TemplateDataType.dart';

import '../Resource/Template/TypeTemplate.dart';

class TemplateGenerator {
//  static RegExp urlRegex = new RegExp("^(?:([\S]*)://([^/]*)/?)");
  static final _urlRegex = RegExp(r'^(?:([^\s|:]*):\/\/([^\/]*)\/?(.*))');

  static String generateRecord(
      TypeTemplate template, List<TypeTemplate> templates) {
    var className = template.className.split('.').last;
    var rt = new StringBuffer();

    rt.writeln("class ${className} extends IRecord {");

    template.properties.forEach((p) {
      var ptTypeName = getTypeName(template, p.valueType, templates);
      rt.writeln("${ptTypeName} ${p.name};");
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
    rt.writeln("\r\n}");

    return rt.toString();
  }

  static String getTypeName(TypeTemplate forTemplate,
      TemplateDataType templateDataType, List<TypeTemplate> templates) {
    if (templateDataType.type == DataType.Resource) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return forTemplate.className.split('.').last;
      else {
        var tmp =
            templates.firstWhere((x) => x.classId == templateDataType.typeGuid);

        if (tmp == null) return "dynamic"; // something went wrong

        var cls = tmp.className.split('.');
        var nameSpace = cls.take(cls.length - 1).join('_');

        return "$nameSpace.${cls.last}";
      }
    } else if (templateDataType.type == DataType.ResourceArray) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return "List<${forTemplate.className.split('.').last}>";
      else {
        var tmp =
            templates.firstWhere((x) => x.classId == templateDataType.typeGuid);

        if (tmp == null) return "dynamic"; // something went wrong

        var cls = tmp.className.split('.');
        var nameSpace = cls.take(cls.length - 1).join('_');

        return "List<$nameSpace.${cls.last}>";
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
          return "List<double>";
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
      if (!_urlRegex.hasMatch(url)) throw new Exception("Invalid IIP URL");

      var path = _urlRegex.allMatches(url).first;
      var con = await Warehouse.get<DistributedConnection>(
          path[1] + "://" + path[2],
          !isNullOrEmpty(username) && !isNullOrEmpty(password)
              ? {username: username, password: password}
              : null);

      if (con == null) throw new Exception("Can't connect to server");

      if (isNullOrEmpty(dir)) dir = path[2].replaceAll(":", "_");

      var templates = await con.getLinkTemplates(path[3]);

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
            var nameSpace = cls.take(cls.length - 1).join('_');
            imports.writeln(
                "import '${tmp.className}.Generated.dart' as $nameSpace;");
          }
        });

        imports.writeln();
        return imports.toString();
      };

      // make sources
      templates.forEach((tmp) {
        if (tmp.type == TemplateType.Resource) {
          var source = makeImports(tmp) + generateClass(tmp, templates);
          var f = File("${dstDir.path}/${tmp.className}.Generated.dart");
          f.writeAsStringSync(source);
        } else if (tmp.type == TemplateType.Record) {
          var source = makeImports(tmp) + generateRecord(tmp, templates);
          var f = File("${dstDir.path}/${tmp.className}.Generated.dart");
          f.writeAsStringSync(source);
        }
      });

      // generate info class
      var typesFile =
          "using System; \r\n namespace Esiur { public static class Generated { public static Type[] Resources {get;} = new Type[] { " +
              templates
                  .where((x) => x.type == TemplateType.Resource)
                  .map((x) => "typeof(${x.className})")
                  .join(',') +
              " }; \r\n public static Type[] Records { get; } = new Type[] { " +
              templates
                  .where((x) => x.type == TemplateType.Record)
                  .map((x) => "typeof(${x.className})")
                  .join(',') +
              " }; " +
              "\r\n } \r\n}";

      var f = File("${dstDir.path}/Esiur.Generated.cs");
      f.writeAsStringSync(typesFile);

      return dstDir.path;
    } catch (ex) {
      //File.WriteAllText("C:\\gen\\gettemplate.err", ex.ToString());
      throw ex;
    }
  }

  static String generateClass(
      TypeTemplate template, List<TypeTemplate> templates) {
    var className = template.className.split('.').last;

    var rt = new StringBuffer();
    rt.writeln("class $className extends DistributedResource {");

    rt.writeln(
        "$className(DistributedConnection connection, int instanceId, int age, String link) : super(connection, instanceId, age, link) {");

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
      rt.writeln("var rt = new AsyncReply<$rtTypeName>();");
      rt.writeln(
          "invokeByArrayArguments(${f.index}, [${f.arguments.map((x) => x.name).join(',')}])");
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

    rt.writeln("\r\n}");

    return rt.toString();
  }
}
