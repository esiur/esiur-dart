import 'dart:io';

import 'package:args/args.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import '../lib/src/Proxy/TemplateGenerator.dart';

void main(List<String> arguments) async {
  if (arguments.length == 0) {
    printUsage();
    return;
  }

  var cmd = arguments[0];

  if (cmd == "get-template") {
    if (arguments.length < 2) {
      print("Please provide an IIP link");
      return;
    }

    var link = arguments[1];

    final parser = ArgParser()
      ..addOption('username', abbr: 'u')
      ..addOption('password', abbr: 'p')
      ..addOption('dir', abbr: 'd')
      ..addFlag('sync', abbr: 's', defaultsTo: false)
      ..addFlag(
        "getx",
        abbr: 'x',
        defaultsTo: false,
        help: "Generate apropriate getx bindings for resources.",
      );

    var results = parser.parse(arguments.skip(2));

    var username = results['username'];
    var password = results['password'];
    var dir = results['dir'];

    //print("Username ${username} password ${password} dir ${dir}");

    // make template
    var destDir = await TemplateGenerator.getTemplate(link,
        dir: dir,
        username: username,
        password: password,
        getx: results['getx'],
        asyncSetters: !results['sync']);

    print("Generated directory `${destDir}`");

    return;
  } else if (cmd == "version") {
    printVersion();
  } else {
    printUsage();
  }
}

void printUsage() {
  // print help
  print("Esiur package command line");
  print("");
  print("Usage: <command> [arguments]");
  print("");
  print("Available commands:");
  print("\tget-template\tGet a template from an IIP link.");
  print("\tversion: Print Esiur version.");
  print("");
  print("Global options:");
  print("\t-u, --username\tAuthentication username");
  print("\t-p, --password\tAuthentication password");
  print("\t-d, --dir\tName of the directory to generate model inside.");
  print("\t-s, --async\tSynchronous property setters.");
}

void printVersion() async {
  var p = Platform.script.pathSegments;
  var path = p.take(p.length - 2).join('/') + "/pubspec.yaml";
  var yaml = await File(path).readAsString();
  var pub = Pubspec.parse(yaml);
  print("${pub.name} ${pub.version}");
  print("\t${pub.description}");
  print("\t${pub.homepage}");
}
