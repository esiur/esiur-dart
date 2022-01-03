import '../Data/BinaryList.dart';
import '../Core/AsyncReply.dart';
import 'NetworkConnection.dart';

class SendList extends BinaryList {
  NetworkConnection connection;
  AsyncReply<List<dynamic>?>? reply;

  SendList(this.connection, this.reply) {}

  @override
  AsyncReply<List<dynamic>?> done() {
    connection.send(super.toDC());

    return reply ?? AsyncReply.ready([]);
  }
}
