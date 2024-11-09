
import '../../Data/IntType.dart';
import '../../Net/Packets/IIPAuthPacketIAuthDestination.dart';
import '../../Net/Packets/IIPAuthPacketIAuthFormat.dart';
import '../../Net/Packets/IIPAuthPacketIAuthHeader.dart';

class AuthorizationRequest {
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

  AuthorizationRequest(Map<UInt8, dynamic> headers) {
    reference = headers[IIPAuthPacketIAuthHeader.Reference];
    destination = headers[IIPAuthPacketIAuthHeader.Destination];
    clue = headers[IIPAuthPacketIAuthHeader.Clue];

    if (headers.containsKey(IIPAuthPacketIAuthHeader.RequiredFormat))
      requiredFormat = headers[IIPAuthPacketIAuthHeader.RequiredFormat];

    if (headers.containsKey(IIPAuthPacketIAuthHeader.ContentFormat))
      contentFormat = headers[IIPAuthPacketIAuthHeader.ContentFormat];

    if (headers.containsKey(IIPAuthPacketIAuthHeader.Content))
      content = headers[IIPAuthPacketIAuthHeader.Content];

    if (headers.containsKey(IIPAuthPacketIAuthHeader.Trials))
      trials = headers[IIPAuthPacketIAuthHeader.Trials];

    if (headers.containsKey(IIPAuthPacketIAuthHeader.Expire))
      expire = headers[IIPAuthPacketIAuthHeader.Expire];
  }
}
