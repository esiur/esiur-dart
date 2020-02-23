import "package:test/test.dart";
import 'package:esyur/esyur.dart';
import 'dart:io';

main()
{
    test("Connect to server", () async {

    // connect to the server
    var x = await Warehouse.get("iip://localhost:5000/sys/su", {"username": "admin", "password": "1234"
    , "domain": "example.com"});


 
    x.instance.store.on("close", (x){
        print("Closed");
      });

  x.on("modified", (peoperty, value){

  });

   // var users = await x.Users.Slice(0, 10);

   // print(users);
 //   await sleep(Duration(seconds: 10));

    // get property
    print(x.Level);
    // listen to event
    x.on("LevelUp", (v,y,z)=>print("Level up ${v} ${y}${z}"));
    // use await
    print("Added successfully ${await x.Add(40)}");
    // use named arguments
    print(await x.Add(value: 20));
    // test chunks
    //x.Stream(10).chunk((c)=>print(c));
    // property setter
    //x.Level += 900;


    //var msg = await stdin.readLineSync();

        print("Done");

  });

  
}



// describe object
 desc(dynamic x) {
   if (x is List)
   {
     for(var i = 0; i < x.length; i++)
        desc(x[i]);
   }
   else if (x is DistributedResource)
   {
      var y = x.instance.template;
      print("Fucntions = ${y.functions.length}\n");
      for (var i = 0; i < y.functions.length; i++) {
        print("name = ${y.functions[i].name}");
        print("args = ${y.functions[i].expansion}");
      }
      print("------------------------------\n");
      print("Events = ${y.events.length}\n");
      for (var i = 0; i < y.events.length; i++) {
        print("name = ${y.events[i].name}");
        print("args = ${y.events[i].expansion}");
      }

      print("------------------------------\n");
      print("Properties = ${y.properties.length}\n");
      for (var i = 0; i < y.properties.length; i++) {
        print("name = ${y.properties[i].name}");
        // recursion
        print("value = ${desc(x.get(y.properties[i].index))}");
      }
   }
   else
   {
     print(x.toString());
   }
}