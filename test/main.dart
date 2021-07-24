import 'package:esiur/esiur.dart';
import 'TestResource.dart';

main() async {
  try {
    
  } catch (ex) {
    print("Error occured");
    print(ex);
  }
}

// // describe object
// desc(dynamic x) {
//   if (x is List) {
//     for (var i = 0; i < x.length; i++) desc(x[i]);
//   } else if (x is DistributedResource) {
//     var y = x.instance?.template;
//     print("Fucntions = ${y.functions.length}\n");
//     for (var i = 0; i < y.functions.length; i++) {
//       print("Function ${y.functions[i].name} ${y.functions[i].expansion}");
//     }
//     print("------------------------------\n");
//     print("Events = ${y.events.length}\n");
//     for (var i = 0; i < y.events.length; i++) {
//       print("Events ${y.events[i].name} ${y.events[i].expansion}");
//     }

//     print("------------------------------\n");
//     print("Properties = ${y.properties.length}\n");
//     for (var i = 0; i < y.properties.length; i++) {
//       print(
//           "Property ${y.properties[i].name} ${y.properties[i].readExpansion}");
//       // recursion
//       //print("value = ${desc(x.get(y.properties[i].index))}");
//     }
//   } else {
//     print(x.toString());
//   }
// }
