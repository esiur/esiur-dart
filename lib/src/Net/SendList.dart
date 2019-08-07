import '../Data/BinaryList.dart';
import '../Core/AsyncReply.dart';
import 'NetworkConnection.dart';

class SendList extends BinaryList
{
    NetworkConnection connection;
    AsyncReply<List<dynamic>> reply;

    SendList(NetworkConnection connection, AsyncReply<List<dynamic>> reply)
    {
        this.reply = reply;
        this.connection = connection;
    }

    @override 
    AsyncReply<List<dynamic>> done()
    {
        connection.send(super.toDC());
        return reply;
    }
}
