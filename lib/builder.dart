import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:yaml/yaml.dart';

//Builder iipService(BuilderOptions options) {
  //return LibraryBuilder(TemplateBuilder(), generatedExtension: '.info.dart');
//}

class TemplateBuilder implements Builder {
  //BuilderOptions options;
  String _fileName;
  TemplateBuilder([BuilderOptions? options]) : _fileName = _get_dest(options);

  @override
  Future build(BuildStep buildStep) async {
    final id = AssetId(buildStep.inputId.package, _fileName);

    // generate
    var content = "Testing";

    await buildStep.writeAsString(id, content);
  }

  static String _get_dest(BuilderOptions? options) {
    const defaultDestination = 'lib/src/iip_template.dart';
    if (options == null) return defaultDestination;
    if (options.config == null) return defaultDestination;
    return options.config['destination_file'] as String ?? defaultDestination;
  }

  @override
  Map<String, List<String>> get buildExtensions {
    return {
      '.iip.yaml': [".iip.dart"]
    };
  }
}

// class TemplateBuilder extends Generator {
//   @override
//   String generate(LibraryReader library, BuildStep buildStep) {
//     return '''
// // Source library: ${library.element.source.uri}
// const Testinggggg = 3;
// ''';
//   }
// }
