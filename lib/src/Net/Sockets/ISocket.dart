/*
 
Copyright (c) 2017 Ahmed Kh. Zamil

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
import '../../Core/IDestructible.dart';
import '../../Data/DC.dart';
import '../INetworkReceiver.dart';
import 'IPEndPoint.dart';
import '../../Core/AsyncReply.dart';
import 'SocketState.dart';

abstract class ISocket extends IDestructible {
  SocketState get state; //{ get; }

  //event ISocketReceiveEvent OnReceive;
  //event ISocketConnectEvent OnConnect;
  //event ISocketCloseEvent OnClose;

  //void send(DC message);

  INetworkReceiver<ISocket>? receiver;

  void send(DC message, [int offset, int size]);
  void close();
  AsyncReply<bool> connect(String hostname, int port);
  bool begin();

  AsyncReply<ISocket> accept();
  IPEndPoint? remoteEndPoint;
  IPEndPoint? localEndPoint;
}
