import '../../Core/AsyncReply.dart';
import '../../Data/DC.dart';
import '../../Net/Packets/IIPAuthPacketHashAlgorithm.dart';
import '../Authority/Session.dart';
import 'AuthorizationResults.dart';

abstract class IMembership
{
    //public event ResourceEventHandler<AuthorizationIndication> Authorization;

    AsyncReply<String?> userExists(String username, String domain);
    AsyncReply<String?> tokenExists(int tokenIndex, String domain);

    AsyncReply<DC?> getPassword(String username, String domain);
    AsyncReply<DC?> getToken(String tokenIndex, String domain);
    AsyncReply<AuthorizationResults> authorize(Session session);
    AsyncReply<AuthorizationResults> authorizePlain(Session session, int reference, value);
    AsyncReply<AuthorizationResults> authorizeHashed(Session session, int reference, int algorithm, DC value);
    AsyncReply<AuthorizationResults> authorizeEncrypted(Session session, int reference, int algorithm, DC value);

    AsyncReply<bool> login(Session session);
    AsyncReply<bool> logout(Session session);
    bool get guestsAllowed;


}
