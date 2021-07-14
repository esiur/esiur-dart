import 'NetworkBuffer.dart';

abstract class INetworkReceiver<T>
{
    void networkClose(T sender);
    void networkReceive(T sender, NetworkBuffer buffer);
    //void NetworkError(T sender);
    void networkConnect(T sender);
}