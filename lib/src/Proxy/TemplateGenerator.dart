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
      var ptTypeName = getTypeName(template, p.valueType, templates, false);
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
      var ptTypeName = getTypeName(template,
          TemplateDataType(ptType, p.valueType.typeGuid), templates, false);
//      return "Prop(\"${p.name}\", ${ptTypeName}, ${isArray})";
      return "Prop('${p.name}', ${ptTypeName}, ${isArray}, ${_escape(p.readExpansion)}, ${_escape(p.writeExpansion)})";
    }).join(', ');

    rt.writeln("""@override
               TemplateDescriber get template => TemplateDescriber('${template.className}', properties: [${descProps}]);""");

    rt.writeln("\r\n}");

    return rt.toString();
  }

  static String _translateClassName(String className, bool nullable) {
    var cls = className.split('.');
    var nameSpace = cls.take(cls.length - 1).join('_').toLowerCase();
    return "$nameSpace.${cls.last}${nullable ? '?' : ''}";
  }

  static String getTypeName(
      TypeTemplate forTemplate,
      TemplateDataType templateDataType,
      List<TypeTemplate> templates,
      bool nullable) {
    if (templateDataType.type == DataType.Resource) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return forTemplate.className.split('.').last + (nullable ? "?" : "");
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            (x.type == TemplateType.Resource ||
                x.type == TemplateType.Wrapper));

        if (tmp == null) return "dynamic"; // something went wrong

        return _translateClassName(tmp.className, nullable);
      }
    } else if (templateDataType.type == DataType.ResourceArray) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return "List<${forTemplate.className.split('.').last + (nullable ? '?' : '')}>";
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            (x.type == TemplateType.Resource ||
                x.type == TemplateType.Wrapper));

        if (tmp == null) return "dynamic"; // something went wrong

        return "List<${_translateClassName(tmp.className, nullable)}>";
      }
    } else if (templateDataType.type == DataType.Record) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return forTemplate.className.split('.').last + (nullable ? '?' : '');
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            x.type == TemplateType.Record);
        if (tmp == null) return "dynamic"; // something went wrong
        return _translateClassName(tmp.className, nullable);
      }
    } else if (templateDataType.type == DataType.RecordArray) {
      if (templateDataType.typeGuid == forTemplate.classId)
        return "List<${forTemplate.className.split('.').last + (nullable ? '?' : '')}?>";
      else {
        var tmp = templates.firstWhere((x) =>
            x.classId == templateDataType.typeGuid &&
            x.type == TemplateType.Record);
        if (tmp == null) return "dynamic"; // something went wrong
        return "List<${_translateClassName(tmp.className, nullable)}>";
      }
    }

    var name = ((x) {
      switch (x) {
        case DataType.Bool:
          return "bool";
        case DataType.BoolArray:
          return "List<bool>";
        case DataType.Char:
          return "String" + (nullable ? "?" : "");
        case DataType.CharArray:
          return "List<String${nullable ? '?' : ''}>";
        case DataType.DateTime:
          return "DateTime";
        case DataType.DateTimeArray:
          return "List<DateTime${nullable ? '?' : ''}>";
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
          return "List<String${nullable ? '?' : ''}>";
        case DataType.Structure:
          return "Structure" + (nullable ? "?" : "");
        case DataType.StructureArray:
          return "List<Structure${(nullable ? '?' : '')}>";
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

  static Future<String> getTemplate(
    String url, {
    String? dir,
    String? username,
    String? password,
    bool getx = false,
    bool namedArgs = false,
  }) async {
    try {
      if (!_urlRegex.hasMatch(url)) throw Exception("Invalid IIP URL");

      var path = _urlRegex.allMatches(url).first;
      var con = await Warehouse.get<DistributedConnection>(
          (path[1] as String) + "://" + (path[2] as String),
          !isNullOrEmpty(username) && !isNullOrEmpty(password)
              ? {"username": username, "password": password}
              : null);

      if (con == null) throw Exception("Can't connect to server");

      if (isNullOrEmpty(dir)) dir = (path[2] as String).replaceAll(":", "_");

      var templates = await con.getLinkTemplates(path[3] as String);

      // no longer needed
      Warehouse.remove(con);

      var dstDir = Directory("lib/$dir");

      if (!dstDir.existsSync()) dstDir.createSync(recursive: true);

      //Map<String, String> namesMap = Map<String, String>();

      var makeImports = (TypeTemplate? skipTemplate) {
        var imports = StringBuffer();
        imports.writeln("import 'dart:async';");
        imports.writeln("import 'package:esiur/esiur.dart';");
        if (getx) {
          imports.writeln("import 'package:get/get.dart';");
        }
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
        final filePath = "${dstDir.path}/${tmp.className}.g.dart";
        final f = File(filePath);

        var source = "";
        if (tmp.type == TemplateType.Resource) {
          source = makeImports(tmp) +
              generateClass(tmp, templates, getx: getx, namedArgs: namedArgs);
        } else if (tmp.type == TemplateType.Record) {
          source = makeImports(tmp) + generateRecord(tmp, templates);
        }
        f.writeAsStringSync(source);
      });

      // generate info class

      var defineCreators = templates.map((tmp) {
        // creator
        var className = _translateClassName(tmp.className, false);
        return "Warehouse.defineCreator(${className}, () => ${className}(), () => <${className}?>[]);";
      }).join("\r\n");

      var putTemplates = templates.map((tmp) {
        var className = _translateClassName(tmp.className, false);
        return "Warehouse.putTemplate(TypeTemplate.fromType(${className}));";
      }).join("\r\n");

      var typesFile = makeImports(null) +
          "\r\n void init_${dir}(){ ${defineCreators} \r\n ${putTemplates}}";

      var f = File("${dstDir.path}/init.g.dart");
      f.writeAsStringSync(typesFile);

      Process.run("dart", ["format", dstDir.path]);

      return dstDir.path;
    } catch (ex) {
      throw ex;
    }
  }

  static String _escape(String? str) {
    if (str == null)
      return "null";
    else
      return "r'$str'";
  }

  static String generateClass(
    TypeTemplate template,
    List<TypeTemplate> templates, {
    bool getx = false,
    bool namedArgs = false,
  }) {
    var className = template.className.split('.').last;

    var rt = StringBuffer();
    rt.writeln("class $className extends DistributedResource {");

    rt.writeln(
//      "$className(DistributedConnection connection, int instanceId, int age, String link) : super(connection, instanceId, age, link) {");
        "$className() {");

    template.events.forEach((e) {
      rt.writeln("on('${e.name}', (x) => _${e.name}Controller.add(x));");
    });

    if (getx) {
      rt.writeln("ob = obs;");
      rt.writeln("_sub = properyModified.listen((_) => ob.trigger(this));");
    }

    rt.writeln("}");

    if (getx) {
      rt.writeln("\nlate final Rx<$className> ob;");
      rt.writeln("late final StreamSubscription? _sub;\n");

      rt.writeln("""@override
  void destroy() {
    _sub?.cancel();

    super.destroy();
  }""");
    }

    template.functions.forEach((f) {
      var rtTypeName = getTypeName(template, f.returnType, templates, true);
      rt.write("AsyncReply<$rtTypeName> ${f.name}(");
      if (f.arguments.isNotEmpty && namedArgs) {
        rt.write("{");
      }
      rt.write(f.arguments.map((x) {
        final typeName = getTypeName(template, x.type, templates, true);
        return typeName +
            (namedArgs && !typeName.endsWith("?") ? "?" : "") +
            " " +
            x.name;
      }).join(","));
      if (f.arguments.isNotEmpty && namedArgs) {
        rt.write("}");
      }

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
      final ptTypeName = getTypeName(template, p.valueType, templates, true);
      final suffix = p.valueType.type == DataType.String ? "?" : "";
      rt.writeln(
          "$ptTypeName$suffix get ${p.name} { return get(${p.index}); }");
      rt.writeln(
          "set ${p.name}($ptTypeName$suffix value) { set(${p.index}, value); }");
    });

    template.events.forEach((e) {
      var etTypeName = getTypeName(template, e.argumentType, templates, true);

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
      var ptTypeName = getTypeName(template,
          TemplateDataType(ptType, p.valueType.typeGuid), templates, false);
      return "Prop('${p.name}', ${ptTypeName}, ${isArray}, ${_escape(p.readExpansion)}, ${_escape(p.writeExpansion)})";
    }).join(', ');

    var descFuncs = template.functions.map((f) {
      var isArray = f.returnType.type & 0x80 == 0x80;
      var ftType = f.returnType.type & 0x7F;
      var ftTypeName = getTypeName(template,
          TemplateDataType(ftType, f.returnType.typeGuid), templates, false);

      var args = f.arguments.map((a) {
        var isArray = a.type.type & 0x80 == 0x80;
        var atType = a.type.type & 0x7F;
        var atTypeName = getTypeName(template,
            TemplateDataType(atType, a.type.typeGuid), templates, false);
        return "Arg('${a.name}', ${atTypeName}, ${isArray})";
      }).join(', ');

      return "Func('${f.name}', ${ftTypeName}, ${isArray}, [${args}], ${_escape(f.expansion)})";
    }).join(', ');

    var descEvents = template.events.map((e) {
      var isArray = e.argumentType.type & 0x80 == 0x80;
      var etType = e.argumentType.type & 0x7F;
      var etTypeName = getTypeName(template,
          TemplateDataType(etType, e.argumentType.typeGuid), templates, false);
      return "Evt('${e.name}', ${etTypeName}, ${isArray}, ${e.listenable}, ${_escape(e.expansion)})";
    }).join(', ');

    rt.writeln(
        "TemplateDescriber get template => TemplateDescriber('${template.className}', properties: [${descProps}], functions: [${descFuncs}], events: [$descEvents]);");

    rt.writeln("\r\n}");

    return rt.toString();
  }
}
