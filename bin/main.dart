import 'esiur.dart';

main() async
{
    // connect to the server
    var x = await Warehouse.get("iip://localhost:5000/db/my", {"username": "demo", "password": "1234"});

    // get property
    print(x.Level);
    // listen to event
    x.on("LevelUp", (v,y,z)=>print("Level up ${v} ${y}${z}"));
    // use await
    print("Added successfully ${await x.Add(40)}");
    // use named arguments
    await x.Add(value: 20);
    // test chunks
    x.Stream(10).chunk((c)=>print(c));
    x.Level += 900;

    print("Done");

}
