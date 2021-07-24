/*

Copyright (c) 2019 Ahmed Kh. Zamil

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

import 'INetworkReceiver.dart';

import '../Core/IDestructible.dart';
import 'Sockets/ISocket.dart';
import 'Sockets/SocketState.dart';
import 'NetworkBuffer.dart';
import '../Data/DC.dart';
import 'Sockets/IPEndPoint.dart';

class NetworkConnection extends IDestructible with INetworkReceiver<ISocket> {
  ISocket? _sock;

  DateTime _lastAction = DateTime.now();

  //public delegate void DataReceivedEvent(NetworkConnection sender, NetworkBuffer data);
  //public delegate void ConnectionClosedEvent(NetworkConnection sender);
  //public delegate void ConnectionEstablishedEvent(NetworkConnection sender);

  //public event ConnectionEstablishedEvent OnConnect;
  //public event DataReceivedEvent OnDataReceived;
  //public event ConnectionClosedEvent OnClose;
  //public event DestroyedEvent OnDestroy;
  //object receivingLock = new object();

  bool _processing = false;

  void destroy() {
    // if (connected)
    close();
    //emitArgs("close", [this]);
    //OnDestroy?.Invoke(this);
  }

  NetworkConnection() {}

  ISocket? get socket => _sock;

  void assign(ISocket socket) {
    _lastAction = DateTime.now();
    _sock = socket;

    socket.receiver = this;

    //socket.on("receive", socket_OnReceive);
    //socket.on("close", socket_OnClose);
    //socket.on("connect", socket_OnConnect);
  }

  ISocket? unassign() {
    if (_sock != null) {
      // connected = false;
      // _sock.off("close", socket_OnClose);
      // _sock.off("connect", socket_OnConnect);
      // _sock.off("receive", socket_OnReceive);

      _sock?.receiver = null;
      var rt = _sock;
      _sock = null;

      return rt;
    } else
      return null;
  }

  // to be overridden
  void dataReceived(NetworkBuffer data) {
    emitArgs("dataReceived", [data]);
  }

  void connected() {}

  void disconnected() {}

  void close() {
    try {
      if (_sock != null) _sock?.close();
    } catch (ex) {
      //Global.Log("NetworkConenction:Close", LogType.Error, ex.ToString());

    }
  }

  DateTime get lastAction => _lastAction;

  IPEndPoint? get remoteEndPoint => _sock?.remoteEndPoint;

  IPEndPoint? get localEndPoint => _sock?.localEndPoint;

  bool get isConnected => _sock?.state == SocketState.Established;

  void send(DC msg) {
    try {
      if (_sock != null) {
        _lastAction = DateTime.now();
        _sock?.send(msg);
      }
    } catch (ex) {
      //Console.WriteLine(ex.ToString());
    }
  }

  void sendString(String data) {
    send(DC.stringToBytes(data));
  }

  @override
  void networkClose(sender) {
    disconnected();
    emitArgs("close", [this]);
  }

  @override
  void networkConnect(sender) {
    connected();
    emitArgs("connect", [this]);
  }

  @override
  void networkReceive(sender, NetworkBuffer buffer) {
    try {
      // Unassigned ?
      if (_sock == null) return;

      // Closed ?
      if (_sock?.state == SocketState.Closed ||
          _sock?.state == SocketState.Terminated) // || !connected)
        return;

      _lastAction = DateTime.now();

      if (!_processing) {
        _processing = true;

        try {
          while (buffer.available > 0 && !buffer.protected)
            dataReceived(buffer);
        } catch (ex) {}

        _processing = false;
      }
    } catch (ex) {
      print(ex);
      //Global.Log("NetworkConnection", LogType.Warning, ex.ToString());
    }
  }
}
