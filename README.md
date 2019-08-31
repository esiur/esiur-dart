# [EsiurDart](https://esiur.io/dart) &middot; [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://img.shields.io/github/license/esiur/esiur-dart) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/esiur/esiur-dart/pulls)

A Distributed Object Framework for Dart

## Getting Started
To use EsiurDart you will need an [Esiur.Net](https://github.com/esiur/esiur-dotnet) server instance running

## Examples
```dart
import 'package:esiur/esiur.dart';

// Get a resource instance
final resource =
    await Warehouse.get('your-end-point (e.g. iip://esiur.io/test', { // Additional data (i.e my credentials)
  'username': 'username', 
  'password': 'password',
});

// Get the name by id
final name = await resource.getNameById('1')

print(name);

```

## Contributing

The main purpose of this repository is to continue to evolve EsiurDart, making it faster and easier to use. Development of Esiur happens in the open on GitHub. We welcome all contributers.


### License

EsiurDart is [MIT licensed](./LICENSE).
