import 'package:args/args.dart';

void main(List<String> arguments) {
  if (arguments.length == 0) {
    // print help
    print("Esiur package command line");
    print("");
    print("Usage: <command> [arguments]");
    print("");
    print("Available commands:");
    print("\tget-template\tGet a template from an IIP link.");
    print("\tversion: print esiur version.");
    print("");
    print("Global options:");
    print("\t-u, --username\tAuthentication username");
    print("\t-p, --password\tAuthentication password");
  }

  var cmd = arguments[0];

  if (cmd == "get-template") {
    if (arguments.length < 2) {
      print("Please provide an IIP link");
      return;
    }

    var link = arguments[1];

    final parser = ArgParser()
      ..addFlag('username', abbr: 'u')
      ..addFlag('password', abbr: 'p');

    var results = parser.parse(arguments.skip(2));

    var username = results['username'];
    var password = results['password'];

    // make template

  }
}
