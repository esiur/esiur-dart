import "package:test/test.dart";
import 'package:esyur/esyur.dart';
import 'dart:io';

main() async
{
    //test("Connect to server", () async {
    var now = DateTime.now();

  // //   // connect to the server
  //  var x = await Warehouse.get("iip://localhost:5000/sys/su", {"username": "admin", "password": "1234"
  //  , "domain": "example.com"});


         var x = await Warehouse.get("iip://gps.dijlh.com:2628/app", {"username": "delta", "password": "interactivereflection2020"
     , "domain": "gps.dijlh.com"});


  // desc(x);
  var date = DateTime.now();

         var from =DateTime(date.year, date.month, date.day);
        var to =DateTime(date.year, date.month, date.day + 1);

    List<dynamic> trackers = await x.getMyTrackers();



      var rt = await x.getObjectTracks(trackers[0], from, to, 0, 0, 0);

    print("Time ${DateTime.now().difference(now).inSeconds}");

    print(x.suspended);

    DistributedConnection con = x.connection;
    //con.close();
        print(x.suspended);

   now = DateTime.now();

    //await con.reconnect();

    print("Time ${DateTime.now().difference(now).inSeconds}");
    print(x.suspended);
    var u = await x.getMyTrackers();
    print(trackers[0].suspended);

    u[0].on("moved", (x){
      print("Movvvvvvvvvvvvvvvvved");
    });
    
  Future.delayed(Duration(seconds: 100));
  // for(var i = 0; i < trackers.length; i++)
  //   print(trackers[i].name);

  // var arc = await x.getObjectTracks(trackers[1], DateTime.now().subtract(Duration(days: 6)), DateTime.now());

  // x.instance.store.on("close", (x){
  //     print("Closed");
  //   });

  // x.on("modified", (peoperty, value){

  // });

   // var users = await x.Users.Slice(0, 10);

   // print(users);
 //   await sleep(Duration(seconds: 10));

    // get property
    //print(x.Level);
    // listen to event
    //x.on("LevelUp", (v,y,z)=>print("Level up ${v} ${y}${z}"));
    // use await
    //print("Added successfully ${await x.Add(40)}");
    // use named arguments
    //print(await x.Add(value: 20));
    // test chunks
    //x.Stream(10).chunk((c)=>print(c));
    // property setter
    //x.Level += 900;


    //var msg = await stdin.readLineSync();

        //print("Done");

  //});

  
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
        print("Function ${y.functions[i].name} ${y.functions[i].expansion}");
      }
      print("------------------------------\n");
      print("Events = ${y.events.length}\n");
      for (var i = 0; i < y.events.length; i++) {
        print("Events ${y.events[i].name} ${y.events[i].expansion}");
      }

      print("------------------------------\n");
      print("Properties = ${y.properties.length}\n");
      for (var i = 0; i < y.properties.length; i++) {
        print("Property ${y.properties[i].name} ${y.properties[i].readExpansion}");
        // recursion
        //print("value = ${desc(x.get(y.properties[i].index))}");
      }
   }
   else
   {
     print(x.toString());
   }
}