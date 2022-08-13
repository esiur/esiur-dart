import 'dart:io';

import '../Data/RepresentationType.dart';

import '../Net/IIP/DistributedConnection.dart';
import '../Resource/Template/TemplateType.dart';
import '../Resource/Warehouse.dart';

import '../Resource/Template/TypeTemplate.dart';

class TemplateGenerator {
//  static RegExp urlRegex = RegExp("^(?:([\S]*)://([^/]*)/?)");
  static final _urlRegex = RegExp(r'^(?:([^\s|:]*):\/\/([^\/]*)\/?(.*))');

  static String toLiteral(String? input) {
    if (input == null) return "null";

    String literal = "";

    literal += "\"";

    input.runes.forEach((int code) {
      var c = String.fromCharCode(code);
      switch (c) {
        case '\"':
          literal += "\\\"";
          break;
        case '\\':
          literal += "\\\\";
          break;
        case '\0':
          literal += "\\0";
          break;
        case '\a':
          literal += "\\a";
          break;
        case '\b':
          literal += "\\b";
          break;
        case '\f':
          literal += "\\f";
          break;
        case '\n':
          literal += "\\n";
          break;
        case '\r':
          literal += "\\r";
          break;
        case '\t':
          literal += "\\t";
          break;
        case '\v':
          literal += "\\v";
          break;
        default:
          literal += c;
          break;
      }
    });

    literal += "\"";
    return literal;
  }

  static String generateRecord(
      TypeTemplate template, List<TypeTemplate> templates) {
    var className = template.className.split('.').last;
    var rt = StringBuffer();

    String? parentName;

    if (template.parentId != null) {
      parentName = _translateClassName(templates
          .singleWhere((x) =>
              (x.classId == template.parentId) &&
              (x.type == TemplateType.Record))
          .className);
      rt.writeln("class ${className} extends ${parentName} {");
    } else {
      rt.writeln("class ${className} extends IRecord {");
    }

    template.properties.forEach((p) {
      if (p.inherited) return;
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
    var descProps = template.properties //.where((p) => !p.inherited)
        .map((p) {
      var ptTypeName = getTypeName(template, p.valueType, templates);
      return "Prop('${p.name}', getTypeOf<${ptTypeName}>(), ${_escape(p.readAnnotation)}, ${_escape(p.writeAnnotation)})";
    }).join(', ');

    if (parentName != null)
      rt.writeln("""@override
               TemplateDescriber get template => TemplateDescriber('${template.className}', parent: ${parentName}, properties: [${descProps}], annotation: ${toLiteral(template.annotation)});""");
    else
      rt.writeln("""@override
               TemplateDescriber get template => TemplateDescriber('${template.className}', properties: [${descProps}], annotation: ${toLiteral(template.annotation)});""");

    rt.writeln("\r\n}");

    return rt.toString();
  }

  static String _translateClassName(String className) {
    var cls = className.split('.');
    var nameSpace = cls.take(cls.length - 1).join('_').toLowerCase();
    return "$nameSpace.${cls.last}";
  }

  static String getTypeName(TypeTemplate forTemplate,
      RepresentationType representationType, List<TypeTemplate> templates) {
    String name;

    if (representationType.identifier ==
        RepresentationTypeIdentifier.TypedResource) {
      if (representationType.guid == forTemplate.classId)
        name = forTemplate.className.split('.').last;
      else
        name = _translateClassName(templates
            .singleWhere((x) =>
                x.classId == representationType.guid &&
                (x.type == TemplateType.Resource ||
                    x.type == TemplateType.Wrapper))
            .className);
    } else if (representationType.identifier ==
        RepresentationTypeIdentifier.TypedRecord) {
      if (representationType.guid == forTemplate.classId)
        name = forTemplate.className.split('.').last;
      else
        name = _translateClassName(templates
            .singleWhere((x) =>
                x.classId == representationType.guid &&
                x.type == TemplateType.Record)
            .className);
    } else if (representationType.identifier ==
        RepresentationTypeIdentifier
            .Enum) if (representationType.guid == forTemplate.classId)
      name = forTemplate.className.split('.').last;
    else
      name = _translateClassName(templates
          .singleWhere((x) =>
              x.classId == representationType.guid &&
              x.type == TemplateType.Enum)
          .className);
    else if (representationType.identifier ==
        RepresentationTypeIdentifier.TypedList)
      name = "List<" +
          getTypeName(forTemplate, representationType.subTypes![0], templates) +
          ">";
    else if (representationType.identifier ==
        RepresentationTypeIdentifier.TypedMap)
      name = "Map<" +
          getTypeName(forTemplate, representationType.subTypes![0], templates) +
          "," +
          getTypeName(forTemplate, representationType.subTypes![1], templates) +
          ">";
    else if (representationType.identifier ==
            RepresentationTypeIdentifier.Tuple2 ||
        representationType.identifier == RepresentationTypeIdentifier.Tuple3 ||
        representationType.identifier == RepresentationTypeIdentifier.Tuple4 ||
        representationType.identifier == RepresentationTypeIdentifier.Tuple5 ||
        representationType.identifier == RepresentationTypeIdentifier.Tuple6 ||
        representationType.identifier == RepresentationTypeIdentifier.Tuple7)
      name = "Tuple";
    //name = "(" + String.Join(",", representationType.SubTypes.Select(x=> GetTypeName(x, templates)))
    //       + ")";
    else {
      switch (representationType.identifier) {
        case RepresentationTypeIdentifier.Dynamic:
          name = "dynamic";
          break;
        case RepresentationTypeIdentifier.Bool:
          name = "bool";
          break;
        case RepresentationTypeIdentifier.Char:
          name = "String";
          break;
        case RepresentationTypeIdentifier.DateTime:
          name = "DateTime";
          break;
        case RepresentationTypeIdentifier.Decimal:
          name = "double";
          break;
        case RepresentationTypeIdentifier.Float32:
          name = "double";
          break;
        case RepresentationTypeIdentifier.Float64:
          name = "double";
          break;
        case RepresentationTypeIdentifier.Int16:
          name = "int";
          break;
        case RepresentationTypeIdentifier.Int32:
          name = "int";
          break;
        case RepresentationTypeIdentifier.Int64:
          name = "int";
          break;
        case RepresentationTypeIdentifier.Int8:
          name = "int";
          break;
        case RepresentationTypeIdentifier.String:
          name = "String";
          break;
        case RepresentationTypeIdentifier.Map:
          name = "Map";
          break;
        case RepresentationTypeIdentifier.UInt16:
          name = "int";
          break;
        case RepresentationTypeIdentifier.UInt32:
          name = "int";
          break;
        case RepresentationTypeIdentifier.UInt64:
          name = "int";
          break;
        case RepresentationTypeIdentifier.UInt8:
          name = "int";
          break;
        case RepresentationTypeIdentifier.List:
          name = "List";
          break;
        case RepresentationTypeIdentifier.Resource:
          name = "IResource";
          break;
        case RepresentationTypeIdentifier.Record:
          name = "IRecord";
          break;
        default:
          name = "dynamic";
      }
    }

    return (representationType.nullable) ? name + "?" : name;
  }

  static bool isNullOrEmpty(v) {
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
          username != null
              ? {"username": username, "password": password ?? ""}
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
        } else if (tmp.type == TemplateType.Enum) {
          source = makeImports(tmp) + generateEnum(tmp, templates);
        }
        f.writeAsStringSync(source);
      });

      // generate info class
      // Warehouse.defineType<test.MyService>(
      //     () => test.MyService(),
      //     RepresentationType(RepresentationTypeIdentifier.TypedResource, false,
      //         Guid(DC.fromList([1, 2, 3]))));

      var defineCreators = templates.map((tmp) {
        // creator
        var className = _translateClassName(tmp.className);
        if (tmp.type == TemplateType.Resource ||
            tmp.type == TemplateType.Wrapper) {
          return "Warehouse.defineType<${className}>(() => ${className}(), RepresentationType(RepresentationTypeIdentifier.TypedResource, false, Guid.parse('${tmp.classId.toString()}')));\r\n";
        } else if (tmp.type == TemplateType.Record) {
          return "Warehouse.defineType<${className}>(() => ${className}(), RepresentationType(RepresentationTypeIdentifier.TypedRecord, false, Guid.parse('${tmp.classId.toString()}')));\r\n";
        } else if (tmp.type == TemplateType.Enum) {
          return "Warehouse.defineType<${className}>(() => ${className}(), RepresentationType(RepresentationTypeIdentifier.Enum, false, Guid.parse('${tmp.classId.toString()}')));\r\n";
        }
      }).join("\r\n");

      var putTemplates = templates.map((tmp) {
        var className = _translateClassName(tmp.className);
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

  static String generateEnum(
      TypeTemplate template, List<TypeTemplate> templates) {
    var className = template.className.split('.').last;
    var rt = StringBuffer();

    rt.writeln("class ${className} extends IEnum {");

    template.constants.forEach((c) {
      rt.writeln(
          "static ${className} ${c.name} = ${className}(${c.index}, ${c.value}, '${c.name}');");
      rt.writeln();
    });

    rt.writeln();

    rt.writeln(
        "${className}([int index = 0, value, String name = '']) : super(index, value, name);");

    // add template
    var descConsts = template.constants.map((p) {
      var ctTypeName = getTypeName(template, p.valueType, templates);
      return "Const('${p.name}', getTypeOf<${ctTypeName}>(), ${p.value}, ${_escape(p.annotation)})";
    }).join(', ');

    rt.writeln("""@override
               TemplateDescriber get template => TemplateDescriber('${template.className}', constants: [${descConsts}], annotation: ${toLiteral(template.annotation)});""");

    rt.writeln("\r\n}");

    return rt.toString();
  }

  static String generateClass(
    TypeTemplate template,
    List<TypeTemplate> templates, {
    bool getx = false,
    bool namedArgs = false,
  }) {
    var className = template.className.split('.').last;

    String? parentName;

    var rt = StringBuffer();

    if (template.parentId != null) {
      parentName = _translateClassName(templates
          .singleWhere((x) =>
              (x.classId == template.parentId) &&
              (x.type == TemplateType.Resource ||
                  x.type == TemplateType.Wrapper))
          .className);
      rt.writeln("class ${className} extends ${parentName} {");
    } else {
      rt.writeln("class ${className} extends DistributedResource {");
    }

    rt.writeln("$className() {");

    template.events.where((e) => !e.inherited).forEach((e) {
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

    template.functions.where((f) => !f.inherited).forEach((f) {
      var rtTypeName = getTypeName(template, f.returnType, templates);
      var positionalArgs = f.arguments.where((x) => !x.optional);
      var optionalArgs = f.arguments.where((x) => x.optional);

      if (f.isStatic) {
        rt.write(
            "static AsyncReply<$rtTypeName> ${f.name}(DistributedConnection connection");

        if (positionalArgs.length > 0)
          rt.write(
              ", ${positionalArgs.map((a) => getTypeName(template, a.type, templates) + " " + a.name).join(',')}");

        if (optionalArgs.length > 0) {
          rt.write(
              ", [${optionalArgs.map((a) => getTypeName(template, a.type.toNullable(), templates) + " " + a.name).join(',')}]");
        }
      } else {
        rt.write("AsyncReply<$rtTypeName> ${f.name}(");

        if (positionalArgs.length > 0)
          rt.write(
              "${positionalArgs.map((a) => getTypeName(template, a.type, templates) + " " + a.name).join(',')}");

        if (optionalArgs.length > 0) {
          if (positionalArgs.length > 0) rt.write(",");
          rt.write(
              "[${optionalArgs.map((a) => getTypeName(template, a.type.toNullable(), templates) + " " + a.name).join(',')}]");
        }
      }

      rt.writeln(") {");

      rt.writeln(
          "var args = <UInt8, dynamic>{${positionalArgs.map((e) => "UInt8(" + e.index.toString() + ') :' + e.name).join(',')}};");

      optionalArgs.forEach((a) {
        rt.writeln(
            "if (${a.name} != null) args[UInt8(${a.index})] = ${a.name};");
      });

      rt.writeln("var rt = AsyncReply<$rtTypeName>();");
      if (f.isStatic) {
        rt.writeln(
            "connection.staticCall(Guid.parse('${template.classId.toString()}'), ${f.index}, args)");
      } else {
        rt.writeln("internal_invoke(${f.index}, args)");
      }
      rt.writeln("..then((x) => rt.trigger(x))");
      rt.writeln("..error((x) => rt.triggerError(x))");
      rt.writeln("..chunk((x) => rt.triggerChunk(x));");
      rt.writeln("return rt; }");
    });

    template.properties.where((p) => !p.inherited).forEach((p) {
      var ptTypeName = getTypeName(template, p.valueType, templates);
      rt.writeln("${ptTypeName} get ${p.name} { return get(${p.index}); }");
      rt.writeln(
          "set ${p.name}(${ptTypeName} value) { set(${p.index}, value); }");
    });

    template.events.where((e) => !e.inherited).forEach((e) {
      var etTypeName = getTypeName(template, e.argumentType, templates);

      rt.writeln(
          "final _${e.name}Controller = StreamController<$etTypeName>();");
      rt.writeln("Stream<$etTypeName> get ${e.name} { ");
      rt.writeln("return _${e.name}Controller.stream;");
      rt.writeln("}");
    });

    // add template
    var descProps = template.properties //.where((p) => !p.inherited)
        .map((p) {
      var ptTypeName = getTypeName(template, p.valueType, templates);
      return "Prop('${p.name}', getTypeOf<${ptTypeName}>(), ${_escape(p.readAnnotation)}, ${_escape(p.writeAnnotation)})";
    }).join(', ');

    var descFuncs = template.functions //.where((f) => !f.inherited)
        .map((f) {
      var ftTypeName = getTypeName(template, f.returnType, templates);

      var args = f.arguments.map((a) {
        var atTypeName = getTypeName(template, a.type, templates);
        return "Arg('${a.name}', getTypeOf<${atTypeName}>(), ${a.optional})";
      }).join(', ');

      return "Func('${f.name}', getTypeOf<${ftTypeName}>(), [${args}], ${_escape(f.annotation)})";
    }).join(', ');

    var descEvents = template.events
        //.where((e) => !e.inherited)
        .map((e) {
      var etTypeName = getTypeName(template, e.argumentType, templates);
      return "Evt('${e.name}', getTypeOf<${etTypeName}>(), ${e.listenable}, ${_escape(e.annotation)})";
    }).join(', ');

    if (parentName != null)
      rt.writeln(
          "TemplateDescriber get template => TemplateDescriber('${template.className}', parent: ${parentName}, properties: [${descProps}], functions: [${descFuncs}], events: [$descEvents], annotation: ${toLiteral(template.annotation)});");
    else
      rt.writeln(
          "TemplateDescriber get template => TemplateDescriber('${template.className}', properties: [${descProps}], functions: [${descFuncs}], events: [$descEvents], annotation: ${toLiteral(template.annotation)});");

    rt.writeln("\r\n}");

    return rt.toString();
  }
}
