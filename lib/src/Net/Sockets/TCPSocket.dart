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

import 'dart:io';

import '../../Core/ErrorType.dart';
import '../../Core/ExceptionCode.dart';

import '../../Core/AsyncException.dart';

import 'ISocket.dart';
import '../../Data/DC.dart';
import '../NetworkBuffer.dart';
import 'SocketState.dart';
import 'IPEndPoint.dart';
import '../../Core/AsyncReply.dart';

class TCPSocket extends ISocket {
  Socket? sock;
  NetworkBuffer receiveNetworkBuffer = new NetworkBuffer();

  //bool asyncSending;
  bool began = false;

  SocketState _state = SocketState.Initial;

  //public event ISocketReceiveEvent OnReceive;
  //public event ISocketConnectEvent OnConnect;
  //public event ISocketCloseEvent OnClose;
  //public event DestroyedEvent OnDestroy;

  //SocketAsyncEventArgs socketArgs = new SocketAsyncEventArgs();

  /*
    void connected(Task t)
    {
        state = SocketState.Established;
        OnConnect?.Invoke();
        Begin();
    }
    */

  IPEndPoint? _localEP, _remoteEP;

  bool begin() {
    if (began) return false;

    began = true;

    if (sock != null) {
      var s = sock as Socket;
      _localEP = IPEndPoint(s.address.rawAddress, s.port);
      _remoteEP = IPEndPoint(s.remoteAddress.rawAddress, s.remotePort);
    }
    return true;
  }

  void dataHandler(List<int> data) {
    //print(new String.fromCharCodes(data).trim());

    try {
      if (_state == SocketState.Closed || _state == SocketState.Terminated)
        return;

      var dc = new DC.fromList(data);
      receiveNetworkBuffer.write(dc, 0, dc.length);
      receiver?.networkReceive(this, receiveNetworkBuffer);

      //emitArgs("receive", [receiveNetworkBuffer]);

    } catch (ex) {
      if (_state != SocketState.Closed) // && !sock.connected)
      {
        _state = SocketState.Terminated;
        close();
      }
    }
  }

  void errorHandler(error, StackTrace trace) {
    print(error);
  }

  void doneHandler() {
    close();
    sock?.destroy();
  }

  AsyncReply<bool> connect(String hostname, int port) {
    var rt = new AsyncReply<bool>();

    try {
      _state = SocketState.Connecting;

      Socket.connect(hostname, port).then((s) {
        sock = s;
        s.listen(dataHandler,
            onError: errorHandler, onDone: doneHandler, cancelOnError: false);
        _state = SocketState.Established;

        //emitArgs("connect", []);
        receiver?.networkConnect(this);

        begin();
        rt.trigger(true);
      }).catchError((ex) {
        close();
        rt.triggerError(AsyncException(ErrorType.Management,
            ExceptionCode.HostNotReachable.index, ex.toString()));
      });
    } catch (ex) {
      rt.triggerError(AsyncException(ErrorType.Management,
          ExceptionCode.HostNotReachable.index, ex.toString()));
    }

    return rt;
  }

  IPEndPoint? get localEndPoint => _localEP;
  IPEndPoint? get remoteEndPoint => _remoteEP;

  SocketState get state => _state;

  TCPSocket.fromSocket(this.sock) {
    //sock = socket;
    //if (socket.)
    //  _state = SocketState.Established;
  }

  TCPSocket() {
    // default constructor
  }

  void close() {
    if (state == SocketState.Closed) return;

    if (state != SocketState.Closed && state != SocketState.Terminated)
      _state = SocketState.Closed;

    sock?.close();

    receiver?.networkClose(this);

    //emitArgs("close", []);
  }

  void send(DC message, [int? offset, int? size]) {
    if (state == SocketState.Established) {
      if (offset != null && size == null) {
        sock?.add(message.clip(offset, message.length - offset).toList());
      } else if (offset != null && size != null) {
        sock?.add(message.clip(offset, size).toList());
      } else {
        sock?.add(message.toList());
      }
    }
  }

  void destroy() {
    close();
    emitArgs("destroy", [this]);
  }

  AsyncReply<ISocket> accept() {
    var reply = new AsyncReply<ISocket>();
    return reply;

/*
  ServerSocket.bind(InternetAddress.ANY_IP_V4, 4567).then(
    (ServerSocket server) {
      server.listen(handleClient);
    }
  );

  void handleClient(Socket client){
  print('Connection from '
    '${client.remoteAddress.address}:${client.remotePort}');

  client.write("Hello from simple server!\n");
  client.close();
}

*/
  }
}
