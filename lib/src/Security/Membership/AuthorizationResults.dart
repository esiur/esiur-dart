import '../../Net/Packets/IIPAuthPacketIAuthDestination.dart';
import '../../Net/Packets/IIPAuthPacketIAuthFormat.dart';
import 'AuthorizationResultsResponse.dart';

class AuthorizationResults {
  AuthorizationResultsResponse response = AuthorizationResultsResponse.Failed;

  int reference = 0;
  int destination = IIPAuthPacketIAuthDestination.Self;
  String? clue;

  IIPAuthPacketIAuthFormat? requiredFormat;
  IIPAuthPacketIAuthFormat? contentFormat;
  dynamic content;

  int? trials;

  DateTime? issue;
  DateTime? expire;

  int get timeout =>
      expire != null ? DateTime.now().difference(expire!).inSeconds : 0;
}
