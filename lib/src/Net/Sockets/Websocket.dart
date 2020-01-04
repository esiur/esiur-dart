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

/*

import 'dart:io';
import 'ISocket.dart';
import '../../Data/DC.dart';
import '../NetworkBuffer.dart';
import 'SocketState.dart';
import 'IPEndPoint.dart';
import '../../Core/AsyncReply.dart';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WSSocket extends ISocket
{
    WebSocketChannel sock;

    NetworkBuffer receiveNetworkBuffer = new NetworkBuffer();

    bool began = false;

    SocketState _state = SocketState.Initial;


    IPEndPoint _localEP, _remoteEP;

    bool begin()
    {
        if (began)
            return false;

        began = true;

        _localEP = IPEndPoint(sock. address.rawAddress, sock.port);
        _remoteEP = IPEndPoint(sock.remoteAddress.rawAddress, sock.remotePort);
        return true;
    }

    void dataHandler(List<int> data){
      //print(new String.fromCharCodes(data).trim());


        try
        {
            if (_state == SocketState.Closed || _state == SocketState.Terminated)
                return;


            var dc = new DC.fromList(data);
            receiveNetworkBuffer.write(dc, 0, dc.length);
            emitArgs("receive", [receiveNetworkBuffer]);

        }
        catch (ex)
        {
            if (_state != SocketState.Closed)// && !sock.connected)
            {
                _state = SocketState.Terminated;
                close();
            }

        }

    }

    void errorHandler(error, StackTrace trace){
      print(error);
    }

    void doneHandler(){
      sock.destroy();
    }


    AsyncReply<bool> connect(String hostname, int port)
    {
      var rt = new AsyncReply<bool>();

        try
        {
            _state = SocketState.Connecting;

            WebSocket()
            prefix0.WebSocket(url) 
            IOWebSocketChannel.
            Socket.connect(hostname, port).then((s){
                sock = s;
                s.listen(dataHandler, 
                    onError: errorHandler, 
                    onDone: doneHandler, 
                    cancelOnError: false);
                _state = SocketState.Established;
                emitArgs("connect", []);
                begin();
                rt.trigger(true);

            }).catchError((ex){
              close();
              rt.triggerError(ex);
            });

            
        }
        catch(ex)
        {
            rt.triggerError(ex);
        }

        return rt;
    }




    IPEndPoint get localEndPoint => _localEP;
    IPEndPoint get remoteEndPoint => _remoteEP;

   
    SocketState get state => _state;
    

    TCPSocket.fromSocket(Socket socket)
    {
        sock = socket;
        //if (socket.)
          //  _state = SocketState.Established;
    }

    TCPSocket()
    {
      // default constructor
    }

    void close()
    {
        if (state != SocketState.Closed && state != SocketState.Terminated)
            _state = SocketState.Closed;

        sock?.close();

        emitArgs("close", []);
    }

    
    void send(DC message, [int offset, int size])
    {
        if (state == SocketState.Established)
          sock.add(message.toList());
    }



    void destroy()
    {
        close();
        emitArgs("destroy", [this]);
    }

    AsyncReply<ISocket> accept()
    {


        var reply = new AsyncReply<ISocket>();
        return reply;
    }
}
*/