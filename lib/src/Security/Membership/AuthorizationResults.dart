import '../../Net/Packets/IIPAuthPacketIAuthDestination.dart';
import '../../Net/Packets/IIPAuthPacketIAuthFormat.dart';
import 'AuthorizationResultsResponse.dart';

class AuthorizationResults
    {
        AuthorizationResultsResponse response = AuthorizationResultsResponse.Failed;
        int destination = IIPAuthPacketIAuthDestination.Self;
        int requiredFormat = IIPAuthPacketIAuthFormat.None ;
        String clue = "";

        int timeout = 0; // 0 means no timeout
        int reference = 0;

        DateTime issue = DateTime.now();

        //bool expired => timeout == 0 ? false : (DateTime.UtcNow - Issue).TotalSeconds > Timeout;
    }
