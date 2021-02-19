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

import 'dart:ffi';

import 'package:esiur/src/Security/Authority/AuthenticationMethod.dart';

import '../../Core/AsyncBag.dart';

import '../Sockets/TCPSocket.dart';
import 'DistributedPropertyContext.dart';
import '../../Data/PropertyValue.dart';
import '../../Resource/Template/PropertyTemplate.dart';
import '../../Core/AsyncException.dart';
import '../NetworkBuffer.dart';
import '../Sockets/ISocket.dart';
import '../../Core/AsyncQueue.dart';
import '../../Core/ExceptionCode.dart';
import '../../Core/ErrorType.dart';

import '../../Resource/Warehouse.dart';
import '../Sockets/SocketState.dart';
import 'dart:math';
import '../../Resource/IStore.dart';
import '../../Resource/IResource.dart';
import '../Packets/IIPPacket.dart';
import '../Packets/IIPAuthPacket.dart';
import '../../Security/Authority/Session.dart';
import '../../Data/DC.dart';
import '../../Data/KeyList.dart';
import '../../Core/AsyncReply.dart';
import '../SendList.dart';
import '../../Security/Authority/SourceAttributeType.dart';
import '../../Resource/Instance.dart';
import '../../Security/Authority/AuthenticationType.dart';
import '../../Security/Authority/ClientAuthentication.dart';
import '../../Security/Authority/HostAuthentication.dart';
import 'DistributedResource.dart';
import 'DistributedResourceQueueItem.dart';
import 'DistributedResourceQueueItemType.dart';
import '../Packets/IIPAuthPacketAction.dart';
import '../Packets/IIPAuthPacketCommand.dart';
import '../Packets/IIPPacketAction.dart';
import '../Packets/IIPPacketCommand.dart';
import '../Packets/IIPPacketEvent.dart';
import '../Packets/IIPPacketReport.dart';
import '../../Data/BinaryList.dart';
import '../NetworkConnection.dart';
import '../../Data/Guid.dart';
import '../../Resource/Template/ResourceTemplate.dart';
import '../../Security/Permissions/Ruling.dart';
import '../../Security/Permissions/ActionType.dart';
import '../../Data/Codec.dart';
import '../../Data/DataType.dart';
import '../../Data/Structure.dart';
import '../../Core/ProgressType.dart';
import '../../Security/Integrity/SHA256.dart';
import '../../Resource/ResourceTrigger.dart';

class DistributedConnection extends NetworkConnection with IStore
{
    //public delegate void ReadyEvent(DistributedConnection sender);
    //public delegate void ErrorEvent(DistributedConnection sender, byte errorCode, string errorMessage);

    /// <summary>
    /// Ready event is raised when the connection is fully established.
    /// </summary>
    //public event ReadyEvent OnReady;

    /// <summary>
    /// Error event
    /// </summary>
    //public event ErrorEvent OnError;

    AsyncReply<bool> _openReply;

    IIPPacket _packet = new IIPPacket();
    IIPAuthPacket _authPacket = new IIPAuthPacket();

    Session _session;

    DC _localPasswordOrToken;
    DC _localNonce, _remoteNonce;

    String _hostname;
    int _port;

    bool _ready = false, _readyToEstablish = false;


    KeyList<int, DistributedResource> _resources = new KeyList<int, DistributedResource>();

    KeyList<int, AsyncReply<DistributedResource>> _resourceRequests = new KeyList<int, AsyncReply<DistributedResource>>();
    KeyList<Guid, AsyncReply<ResourceTemplate>> _templateRequests = new KeyList<Guid, AsyncReply<ResourceTemplate>>();
    //KeyList<String, AsyncReply<IResource>> _pathRequests = new KeyList<String, AsyncReply<IResource>>();
    Map<Guid, ResourceTemplate> _templates = new Map<Guid, ResourceTemplate>();
    KeyList<int, AsyncReply<dynamic>> _requests = new KeyList<int, AsyncReply<dynamic>>();
    int _callbackCounter = 0;
    AsyncQueue<DistributedResourceQueueItem> _queue = new AsyncQueue<DistributedResourceQueueItem>();


    /// <summary>
    /// Local username to authenticate ourselves.  
    /// </summary>
    String get localUsername => _session.localAuthentication.username;

    /// <summary>
    /// Peer's username.
    /// </summary>
    String get remoteUsername => _session.remoteAuthentication.username;// { get; set; }

    /// <summary>
    /// Working domain.
    /// </summary>
    //public string Domain { get { return domain; } }


    /// <summary>
    /// The session related to this connection.
    /// </summary>
    Session get session => _session;

    /// <summary>
    /// Distributed server responsible for this connection, usually for incoming connections.
    /// </summary>
    //public DistributedServer Server
    
    
    bool remove(IResource resource)
    {
        // nothing to do
        return true;
    }

    /// <summary>
    /// Send data to the other end as parameters
    /// </summary>
    /// <param name="values">Values will be converted to bytes then sent.</param>
    SendList sendParams([AsyncReply<List<dynamic>> reply = null])
    {
        return new SendList(this, reply);
    }

    /// <summary>
    /// Send raw data through the connection.
    /// </summary>
    /// <param name="data">Data to send.</param>
    void send(DC data)
    {
        //Console.WriteLine("Client: {0}", Data.length);

        //Global.Counters["IIP Sent Packets"]++;
        super.send(data);
    }


    AsyncReply<bool> trigger(ResourceTrigger trigger)
    {

      if (trigger == ResourceTrigger.Open)
      {
        if (instance.attributes.containsKey("username")
          && instance.attributes.containsKey("password"))
        {

            var host = instance.name.split(":");
            // assign domain from hostname if not provided

            var address = host[0];
            var port = int.parse(host[1]);
            var username = instance.attributes["username"].toString();

            var domain = instance.attributes.containsKey("domain") ? instance.attributes["domain"] : address;

            var password = DC.stringToBytes(instance.attributes["password"].toString());

            return connect(method: AuthenticationMethod.Credentials, domain: domain, hostname: address, port: port, passwordOrToken: password, username: username);

        }
        else if (instance.attributes.containsKey("token"))
        {
            var host = instance.name.split(":");
            // assign domain from hostname if not provided

            var address = host[0];
            var port = int.parse(host[1]);

            var domain = instance.attributes.containsKey("domain") ? instance.attributes["domain"] : address;

            var token = DC.stringToBytes(instance.attributes["token"].toString());
            var tokenIndex = instance.attributes["tokenIndex"] ?? 0;
            return connect(method: AuthenticationMethod.Credentials, domain: domain, hostname: address, port: port, passwordOrToken: token, tokenIndex: tokenIndex);
        }
      }

      return new AsyncReply<bool>.ready(true);
    }

    AsyncReply<bool> connect({AuthenticationMethod method, ISocket socket, String hostname, int port, String username, int tokenIndex, DC passwordOrToken, String domain})
    {
      if (_openReply != null)
        throw AsyncException(ErrorType.Exception, 0, "Connection in progress");

      _openReply = new AsyncReply<bool>();

      if (hostname != null)
      {
        _session = new Session(new ClientAuthentication()
                                  , new HostAuthentication());

        _session.localAuthentication.method = method;
        _session.localAuthentication.tokenIndex = tokenIndex;
        _session.localAuthentication.domain = domain;
        _session.localAuthentication.username = username;
        _localPasswordOrToken = passwordOrToken;
      }
      
      if (_session == null)
        throw AsyncException(ErrorType.Exception, 0, "Session not initialized");

      if (socket == null)
        socket = new TCPSocket();

      _port = port ?? _port;
      _hostname = hostname ?? _hostname;

      socket.connect(_hostname,  _port).then<dynamic>((x){
        assign(socket);
      }).error((x){
          _openReply.triggerError(x);
          _openReply = null;
      });

      return _openReply; 
    }


    @override
    void connectionClosed()
    {
      // clean up
      _ready = false;
      _readyToEstablish = false;
      
      _requests.values.forEach((x)=>x.triggerError(AsyncException(ErrorType.Management, 0, "Connection closed")));
      _resourceRequests.values.forEach((x)=>x.triggerError(AsyncException(ErrorType.Management, 0, "Connection closed")));
      _templateRequests.values.forEach((x)=>x.triggerError(AsyncException(ErrorType.Management, 0, "Connection closed")));
      
      _requests.clear();
      _resourceRequests.clear();
      _templateRequests.clear();

      _resources.values.forEach((x)=>x.suspend());
    }

    Future<bool> reconnect() async
    {
        if (await connect())
        {
          var bag = AsyncBag();

          for(var i = 0; i < _resources.keys.length; i++)
          {
            var index = _resources.keys.elementAt(i);
            // print("Re $i ${_resources[index].instance.template.className}");
            bag.add(fetch(index));
          }

          bag.seal();
          await bag;

          return true;
        }
        
        return false;
    }

    /// <summary>
    /// KeyList to store user variables related to this connection.
    /// </summary>
    final KeyList<String, dynamic> variables = new KeyList<String, dynamic>();

    /// <summary>
    /// IResource interface.
    /// </summary>
    Instance instance;

    /// <summary>
    /// Assign a socket to the connection.
    /// </summary>
    /// <param name="socket">Any socket that implements ISocket.</param>
    assign(ISocket socket)
    {
        super.assign(socket);

        session.remoteAuthentication.source.attributes[SourceAttributeType.IPv4] = socket.remoteEndPoint.address;
        session.remoteAuthentication.source.attributes[SourceAttributeType.Port] = socket.remoteEndPoint.port;
        session.localAuthentication.source.attributes[SourceAttributeType.IPv4]  = socket.localEndPoint.address;
        session.localAuthentication.source.attributes[SourceAttributeType.Port] = socket.localEndPoint.port;

        if (session.localAuthentication.type == AuthenticationType.Client)
        {
            // declare (Credentials -> No Auth, No Enctypt)

            var un = DC.stringToBytes(session.localAuthentication.username);
            var dmn = DC.stringToBytes(session.localAuthentication.domain);// domain);

            if (socket.state == SocketState.Established)
            {
                sendParams()
                    .addUint8(0x60)
                    .addUint8(dmn.length)
                    .addDC(dmn)
                    .addDC(_localNonce)
                    .addUint8(un.length)
                    .addDC(un)
                    .done();
            }
            else
            {
                socket.on("connect", ()
                {   // declare (Credentials -> No Auth, No Enctypt)
                    sendParams()
                    .addUint8(0x60)
                    .addUint8(dmn.length)
                    .addDC(dmn)
                    .addDC(_localNonce)
                    .addUint8(un.length)
                    .addDC(un)
                    .done();
                });
            }
        }
    }


    /// <summary>
    /// Create a new distributed connection. 
    /// </summary>
    /// <param name="socket">Socket to transfer data through.</param>
    /// <param name="domain">Working domain.</param>
    /// <param name="username">Username.</param>
    /// <param name="password">Password.</param>
    DistributedConnection.connect(ISocket socket, String domain, String username, String password)
    {
        _session = new Session(new ClientAuthentication()
                                    , new HostAuthentication());
        
        _session.localAuthentication.method = AuthenticationMethod.Credentials;
        _session.localAuthentication.domain = domain;
        _session.localAuthentication.username = username;
        
        _localPasswordOrToken = DC.stringToBytes(password);

        init();

        assign(socket);
    }

    DistributedConnection.connectWithToken(ISocket socket, String domain, int tokenIndex, String token)
    {
        _session = new Session(new ClientAuthentication()
                                    , new HostAuthentication());
        
        _session.localAuthentication.method = AuthenticationMethod.Token;
        _session.localAuthentication.domain = domain;
        _session.localAuthentication.tokenIndex = tokenIndex;
        
        _localPasswordOrToken = DC.stringToBytes(token);

        init();

        assign(socket);
    }


    /// <summary>
    /// Create a new instance of a distributed connection
    /// </summary>
    DistributedConnection()
    {
        //myId = Global.GenerateCode(12);
        // localParams.Host = DistributedParameters.HostType.Host;
        _session = new Session(new HostAuthentication(), new ClientAuthentication());
        init();
    }



    String link(IResource resource)
    {
        if (resource is DistributedResource)
        {
            var r = resource as DistributedResource;
            if (r.instance.store == this)
                return this.instance.name + "/" + r.id.toString();
        }

        return null;
    }


    void init()
    {
        _queue.then((x)
        {
            if (x.type == DistributedResourceQueueItemType.Event)
                x.resource.emitEventByIndex(x.index, x.value);
            else
                x.resource.updatePropertyByIndex(x.index, x.value);
        });

        var r = new Random();
        _localNonce = new DC(32);
        for(var i = 0; i < 32; i++)
           _localNonce[i] = r.nextInt(255);
    }



    int processPacket(DC msg, int offset, int ends, NetworkBuffer data, int chunkId)
    {
        var packet = new IIPPacket();

        if (_ready)
        {
            var rt = packet.parse(msg, offset, ends);
     
            if (rt <= 0)
            {
              // print("hold");
                var size = ends - offset;
                data.holdFor(msg, offset, size, size - rt);
                return ends;
            }
            else
            {
                //print("CMD ${packet.command} ${offset} ${ends}");

                offset += rt;


                if (packet.command == IIPPacketCommand.Event)
                {
                    switch (packet.event)
                    {
                        case IIPPacketEvent.ResourceReassigned:
                            iipEventResourceReassigned(packet.resourceId, packet.newResourceId);
                            break;
                        case IIPPacketEvent.ResourceDestroyed:
                            iipEventResourceDestroyed(packet.resourceId);
                            break;
                        case IIPPacketEvent.PropertyUpdated:
                            iipEventPropertyUpdated(packet.resourceId, packet.methodIndex, packet.content);
                            break;
                        case IIPPacketEvent.EventOccurred:
                            iipEventEventOccurred(packet.resourceId, packet.methodIndex, packet.content);
                            break;

                        case IIPPacketEvent.ChildAdded:
                            iipEventChildAdded(packet.resourceId, packet.childId);
                            break;
                        case IIPPacketEvent.ChildRemoved:
                            iipEventChildRemoved(packet.resourceId, packet.childId);
                            break;
                        case IIPPacketEvent.Renamed:
                            iipEventRenamed(packet.resourceId, packet.content);
                            break;
                        case IIPPacketEvent.AttributesUpdated:
                            iipEventAttributesUpdated(packet.resourceId, packet.content);
                            break;
                    }
                }
                else if (packet.command == IIPPacketCommand.Request)
                {
                    switch (packet.action)
                    {
                        // Manage
                        case IIPPacketAction.AttachResource:
                            iipRequestAttachResource(packet.callbackId, packet.resourceId);
                            break;
                        case IIPPacketAction.ReattachResource:
                            iipRequestReattachResource(packet.callbackId, packet.resourceId, packet.resourceAge);
                            break;
                        case IIPPacketAction.DetachResource:
                            iipRequestDetachResource(packet.callbackId, packet.resourceId);
                            break;
                        case IIPPacketAction.CreateResource:
                            iipRequestCreateResource(packet.callbackId, packet.storeId, packet.resourceId, packet.content);
                            break;
                        case IIPPacketAction.DeleteResource:
                            iipRequestDeleteResource(packet.callbackId, packet.resourceId);
                            break;
                        case IIPPacketAction.AddChild:
                            iipRequestAddChild(packet.callbackId, packet.resourceId, packet.childId);
                            break;
                        case IIPPacketAction.RemoveChild:
                            iipRequestRemoveChild(packet.callbackId, packet.resourceId, packet.childId);
                            break;
                        case IIPPacketAction.RenameResource:
                            iipRequestRenameResource(packet.callbackId, packet.resourceId, packet.content);
                            break;

                        // Inquire
                        case IIPPacketAction.TemplateFromClassName:
                            iipRequestTemplateFromClassName(packet.callbackId, packet.className);
                            break;
                        case IIPPacketAction.TemplateFromClassId:
                            iipRequestTemplateFromClassId(packet.callbackId, packet.classId);
                            break;
                        case IIPPacketAction.TemplateFromResourceId:
                            iipRequestTemplateFromResourceId(packet.callbackId, packet.resourceId);
                            break;
                        case IIPPacketAction.QueryLink:
                            iipRequestQueryResources(packet.callbackId, packet.resourceLink);
                            break;

                        case IIPPacketAction.ResourceChildren:
                            iipRequestResourceChildren(packet.callbackId, packet.resourceId);
                            break;
                        case IIPPacketAction.ResourceParents:
                            iipRequestResourceParents(packet.callbackId, packet.resourceId);
                            break;
                        
                        case IIPPacketAction.ResourceHistory:
                            iipRequestInquireResourceHistory(packet.callbackId, packet.resourceId, 
                                                              packet.fromDate, packet.toDate);
                            break;

                        // Invoke
                        case IIPPacketAction.InvokeFunctionArrayArguments:
                            iipRequestInvokeFunctionArrayArguments(packet.callbackId, packet.resourceId, 
                                                                    packet.methodIndex, packet.content);
                            break;

                        case IIPPacketAction.InvokeFunctionNamedArguments:
                            iipRequestInvokeFunctionNamedArguments(packet.callbackId, packet.resourceId, 
                                                                      packet.methodIndex, packet.content);
                            break;

                        case IIPPacketAction.GetProperty:
                            iipRequestGetProperty(packet.callbackId, packet.resourceId, packet.methodIndex);
                            break;
                        case IIPPacketAction.GetPropertyIfModified:
                            iipRequestGetPropertyIfModifiedSince(packet.callbackId, packet.resourceId, 
                                                                  packet.methodIndex, packet.resourceAge);
                            break;
                        case IIPPacketAction.SetProperty:
                            iipRequestSetProperty(packet.callbackId, packet.resourceId, packet.methodIndex, packet.content);
                            break;

                        // Attribute
                        case IIPPacketAction.GetAllAttributes:
                            iipRequestGetAttributes(packet.callbackId, packet.resourceId, packet.content, true);
                            break;
                        case IIPPacketAction.UpdateAllAttributes:
                            iipRequestUpdateAttributes(packet.callbackId, packet.resourceId, packet.content, true);
                            break;
                        case IIPPacketAction.ClearAllAttributes:
                            iipRequestClearAttributes(packet.callbackId, packet.resourceId, packet.content, true);
                            break;
                        case IIPPacketAction.GetAttributes:
                            iipRequestGetAttributes(packet.callbackId, packet.resourceId, packet.content, false);
                            break;
                        case IIPPacketAction.UpdateAttributes:
                            iipRequestUpdateAttributes(packet.callbackId, packet.resourceId, packet.content, false);
                            break;
                        case IIPPacketAction.ClearAttributes:
                            iipRequestClearAttributes(packet.callbackId, packet.resourceId, packet.content, false);
                            break;
                    }
                }
                else if (packet.command == IIPPacketCommand.Reply)
                {
                    switch (packet.action)
                    {
                        // Manage
                        case IIPPacketAction.AttachResource:
                            iipReply(packet.callbackId, [packet.classId, packet.resourceAge, packet.resourceLink, packet.content]);
                            break;

                        case IIPPacketAction.ReattachResource:
                            iipReply(packet.callbackId, [packet.resourceAge, packet.content]);

                            break;
                        case IIPPacketAction.DetachResource:
                            iipReply (packet.callbackId);
                            break;

                        case IIPPacketAction.CreateResource:
                            iipReply(packet.callbackId, [packet.resourceId]);
                            break;

                        case IIPPacketAction.DeleteResource:
                        case IIPPacketAction.AddChild:
                        case IIPPacketAction.RemoveChild:
                        case IIPPacketAction.RenameResource:
                            iipReply(packet.callbackId);
                            break;

                        // Inquire

                        case IIPPacketAction.TemplateFromClassName:
                        case IIPPacketAction.TemplateFromClassId:
                        case IIPPacketAction.TemplateFromResourceId:
                            iipReply(packet.callbackId, [ResourceTemplate.parse(packet.content)]);
                            break;

                        case IIPPacketAction.QueryLink:
                        case IIPPacketAction.ResourceChildren:
                        case IIPPacketAction.ResourceParents:
                        case IIPPacketAction.ResourceHistory:
                            iipReply(packet.callbackId, [packet.content]);
                            break;

                        // Invoke
                        case IIPPacketAction.InvokeFunctionArrayArguments:
                        case IIPPacketAction.InvokeFunctionNamedArguments:
                            iipReplyInvoke(packet.callbackId, packet.content);
                            break;

                        case IIPPacketAction.GetProperty:
                            iipReply(packet.callbackId, [packet.content]);
                            break;

                        case IIPPacketAction.GetPropertyIfModified:
                            iipReply(packet.callbackId, [packet.content]);
                            break;
                        case IIPPacketAction.SetProperty:
                            iipReply(packet.callbackId);
                            break;

                        // Attribute
                        case IIPPacketAction.GetAllAttributes:
                        case IIPPacketAction.GetAttributes:
                            iipReply(packet.callbackId, [packet.content]);
                            break;

                        case IIPPacketAction.UpdateAllAttributes:
                        case IIPPacketAction.UpdateAttributes:
                        case IIPPacketAction.ClearAllAttributes:
                        case IIPPacketAction.ClearAttributes:
                            iipReply(packet.callbackId);
                            break;

                    }

                }
                else if (packet.command == IIPPacketCommand.Report)
                {
                    switch (packet.report)
                    {
                        case IIPPacketReport.ManagementError:
                            iipReportError(packet.callbackId, ErrorType.Management, packet.errorCode, null);
                            break;
                        case IIPPacketReport.ExecutionError:
                            iipReportError(packet.callbackId, ErrorType.Exception, packet.errorCode, packet.errorMessage);
                            break;
                        case IIPPacketReport.ProgressReport:
                            iipReportProgress(packet.callbackId, ProgressType.Execution, packet.progressValue, packet.progressMax);
                            break;
                        case IIPPacketReport.ChunkStream:
                            iipReportChunk(packet.callbackId, packet.content);
                            break;
                    }
                }
            }
        }

        else
        {
            var rt = _authPacket.parse(msg, offset, ends);

            if (rt <= 0)
            {
                data.holdForNeeded(msg, ends -rt);
                return ends;
            }
            else
            {
                offset += rt;

                if (session.localAuthentication.type == AuthenticationType.Host)
                {
                    if (_authPacket.command == IIPAuthPacketCommand.Declare)
                    {
                        if (_authPacket.remoteMethod == AuthenticationMethod.Credentials && _authPacket.localMethod == AuthenticationMethod.None)
                        {

                            /*
                            server.membership.userExists(_authPacket.remoteUsername, _authPacket.domain).then((x)
                            {
                                if (x)
                                {
                                    _session.remoteAuthentication.username = _authPacket.remoteUsername;
                                    _remoteNonce = _authPacket.remoteNonce;
                                    _session.remoteAuthentication.domain = _authPacket.domain;
                                    sendParams()
                                                .addUint8(0xa0)
                                                .addDC(_localNonce)
                                                .done();
                                }
                                else
                                {
                                    sendParams().addUint8(0xc0).addUint8(1).addUint16(14).addString("User not found").done();
                                }
                            });
                            */

                        }
                    }
                    else if (_authPacket.command == IIPAuthPacketCommand.Action)
                    {
                        if (_authPacket.action == IIPAuthPacketAction.AuthenticateHash)
                        {
                            var remoteHash = _authPacket.hash;

                            /*
                            server.membership.getPassword(_session.remoteAuthentication.username,
                                                          _session.remoteAuthentication.domain).then((pw)
                                                          {
                                                              if (pw != null)
                                                              {
                                                                  //var hash = hashFunc.ComputeHash(BinaryList.ToBytes(pw, remoteNonce, localNonce));
                                                                  var hash = SHA256.compute((new BinaryList())
                                                                                                    .addDC(pw)
                                                                                                    .addDC(_remoteNonce)
                                                                                                    .addDC(_localNonce)
                                                                                                    .toDC());
                                                                  if (hash.sequenceEqual(remoteHash))
                                                                  {
                                                                      // send our hash
                                                                      //var localHash = hashFunc.ComputeHash(BinaryList.ToBytes(localNonce, remoteNonce, pw));
                                                                      //SendParams((byte)0, localHash);

                                                                      var localHash = SHA256.compute
                                                                              ((new BinaryList()).addDC(_localNonce).addDC(_remoteNonce).addDC(pw).toDC());
                                                                      sendParams().addUint8(0).addDC(localHash).done();

                                                                      _readyToEstablish = true;
                                                                  }
                                                                  else
                                                                  {
                                                                      sendParams().addUint8(0xc0).addUint8(1).addUint16(5).addString("Error").done();
                                                                  }
                                                              }
                                                          });
                                                          */
                        }
                        else if (_authPacket.action == IIPAuthPacketAction.NewConnection)
                        {
                            if (_readyToEstablish)
                            {
                                var r = new Random();
                                session.id = new DC(32);
                                for(var i = 0; i < 32; i++)
                                  session.id[i] = r.nextInt(255);


                                sendParams()
                                    .addUint8(0x28)
                                    .addDC(session.id)
                                    .done();

                                _ready = true;

                                _openReply.trigger(true);
                                _openReply = null;
                                emitArgs("ready", []);
                                //OnReady?.Invoke(this);
                               // server.membership.login(session);

                            }
                        }
                    }
                }
                else if (_session.localAuthentication.type == AuthenticationType.Client)
                {
                    if (_authPacket.command == IIPAuthPacketCommand.Acknowledge)
                    {
                        _remoteNonce = _authPacket.remoteNonce;

                        // send our hash
                        var localHash = SHA256.compute(new BinaryList()
                                                            .addDC(_localPasswordOrToken)
                                                            .addDC(_localNonce)
                                                            .addDC(_remoteNonce)
                                                            .toDC());

                        sendParams()
                            .addUint8(0)
                            .addDC(localHash)
                            .done();

                        //SendParams((byte)0, localHash);
                    }
                    else if (_authPacket.command == IIPAuthPacketCommand.Action)
                    {
                        if (_authPacket.action == IIPAuthPacketAction.AuthenticateHash)
                        {
                            // check if the server knows my password
                            var remoteHash = SHA256.compute(new BinaryList()
                                                                    .addDC(_remoteNonce)
                                                                    .addDC(_localNonce)
                                                                    .addDC(_localPasswordOrToken)
                                                                    .toDC());

                            
                            if (remoteHash.sequenceEqual(_authPacket.hash))
                            {
                                // send establish request
                                sendParams()
                                            .addUint8(0x20)
                                            .addUint16(0)
                                            .done();
                            }
                            else
                            {
                                sendParams()
                                            .addUint8(0xc0)
                                            .addUint8(ExceptionCode.ChallengeFailed.index)
                                            .addUint16(16)
                                            .addString("Challenge Failed")
                                            .done();

                                //SendParams((byte)0xc0, 1, 5, DC.ToBytes("Error"));
                            }
                        }
                        else if (_authPacket.action == IIPAuthPacketAction.ConnectionEstablished)
                        {
                            session.id = _authPacket.sessionId;

                            _ready = true;

                            _openReply.trigger(true);
                            _openReply = null;
                            emitArgs("ready", []);

                            //OnReady?.Invoke(this);

                        }
                    }
                    else if (_authPacket.command == IIPAuthPacketCommand.Error)
                    {
                        var ex = AsyncException(ErrorType.Management, _authPacket.errorCode, _authPacket.errorMessage);
                        _openReply.triggerError(ex);
                        _openReply = null;
                        emitArgs("error", [ex]);
                        //OnError?.Invoke(this, authPacket.ErrorCode, authPacket.ErrorMessage);
                        close();
                    }
                }
            }
        }

        return offset;

        //if (offset < ends)
          //  processPacket(msg, offset, ends, data, chunkId);
    }

    @override
    void dataReceived(NetworkBuffer data)
    {
        // Console.WriteLine("DR " + hostType + " " + data.Available + " " + RemoteEndPoint.ToString());
        var msg = data.read();
        int offset = 0;
        int ends = msg.length;

        var packs = new List<String>();

        var chunkId = (new Random()).nextInt(1000000);

        

        while (offset < ends)
        {
            offset = processPacket(msg, offset, ends, data, chunkId);
        }

    }

    /// <summary>
    /// Resource interface
    /// </summary>
    /// <param name="trigger">Resource trigger.</param>
    /// <returns></returns>
    //AsyncReply<bool> trigger(ResourceTrigger trigger)
    //{
      //  return new AsyncReply<bool>();
    //}

    /// <summary>
    /// Store interface.
    /// </summary>
    /// <param name="resource">Resource.</param>
    /// <returns></returns>
    AsyncReply<bool> put(IResource resource)
    {
      if (Codec.isLocalResource(resource, this))
        _resources.add((resource as DistributedResource).id, resource);
      // else .. put it in the server....
      return AsyncReply.ready(true);
    }


    

    
    bool record(IResource resource, String propertyName, value, int age, DateTime dateTime)
    {
        // nothing to do
        return true;
    }

    bool modify(IResource resource, String propertyName, value, int age, DateTime dateTime)
    {
        // nothing to do
        return true;
    }
      



      /// <summary>
      /// Send IIP request.
      /// </summary>
      /// <param name="action">Packet action.</param>
      /// <param name="args">Arguments to send.</param>
      /// <returns></returns>
      SendList sendRequest(int action)
      {
          var reply = new AsyncReply<List<dynamic>>();
          var c = _callbackCounter++; // avoid thread racing
          _requests.add(c, reply);

          return sendParams(reply).addUint8(0x40 | action).addUint32(c);
      }

      //int _maxcallerid = 0;

      SendList sendReply(int action, int callbackId)
      {
          return sendParams().addUint8((0x80 | action)).addUint32(callbackId);
      }

      SendList sendEvent(int evt)
      {
          return sendParams().addUint8((evt));
      }

      AsyncReply<dynamic> sendInvokeByArrayArguments(int instanceId, int index, List<dynamic> parameters)
      {
          var pb = Codec.composeVarArray(parameters, this, true);

          var reply = new AsyncReply<dynamic>();
          var c = _callbackCounter++;
          _requests.add(c, reply);

          sendParams().addUint8(0x40 | IIPPacketAction.InvokeFunctionArrayArguments)
                      .addUint32(c)
                      .addUint32(instanceId)
                      .addUint8(index)
                      .addDC(pb)
                      .done();
          return reply;
      }

      AsyncReply<dynamic> sendDetachRequest(int instanceId)
      {
          try
          {
            return sendRequest(IIPPacketAction.DetachResource).addUint32(instanceId).done();
          }
          catch(ex)
          {
            return null;
          }
      }
      
      AsyncReply<dynamic> sendInvokeByNamedArguments(int instanceId, int index, Structure parameters)
      {
          var pb = Codec.composeStructure(parameters, this, true, true, true);

          var reply = new AsyncReply<dynamic>();
          var c = _callbackCounter++;
          _requests.add(c, reply);

          sendParams().addUint8(0x40 | IIPPacketAction.InvokeFunctionNamedArguments)
                      .addUint32(c)
                      .addUint32(instanceId)
                      .addUint8(index)
                      .addDC(pb)
                      .done();
          return reply;
      }


      void sendError(ErrorType type, int callbackId, int errorCode, [String errorMessage = ""])
      {
          var msg = DC.stringToBytes(errorMessage);
          if (type == ErrorType.Management)
              sendParams()
                          .addUint8(0xC0 | IIPPacketReport.ManagementError)
                          .addUint32(callbackId)
                          .addUint16(errorCode)
                          .done();
          else if (type == ErrorType.Exception)
              sendParams()
                          .addUint8(0xC0 | IIPPacketReport.ExecutionError)
                          .addUint32(callbackId)
                          .addUint16(errorCode)
                          .addUint16(msg.length)
                          .addDC(msg)
                          .done();
      }

      void sendProgress(int callbackId, int value, int max)
      {
          sendParams()
              .addUint8(0xC0 | IIPPacketReport.ProgressReport)
              .addUint32(callbackId)
              .addInt32(value)
              .addInt32(max)
              .done();
          //SendParams(, callbackId, value, max);
      }

      void sendChunk(int callbackId, dynamic chunk)
      {
          var c = Codec.compose(chunk, this, true);
          sendParams()
              .addUint8(0xC0 | IIPPacketReport.ChunkStream)
              .addUint32(callbackId)
              .addDC(c)
              .done();
      }

      void iipReply(int callbackId, [List<dynamic> results = null])
      {
          var req = _requests.take(callbackId);
          req?.trigger(results);
      }

      void iipReplyInvoke(int callbackId, DC result)
      {
          var req = _requests.take(callbackId);

          Codec.parse(result, 0, this).then((rt)
          {
              req?.trigger(rt);
          });
      }

      void iipReportError(int callbackId, ErrorType errorType, int errorCode, String errorMessage)
      {
          var req = _requests.take(callbackId);
          req?.triggerError(new AsyncException(errorType, errorCode, errorMessage));
      }

      void iipReportProgress(int callbackId, ProgressType type, int value, int max)
      {
          var req = _requests[callbackId];
          req?.triggerProgress(type, value, max);
      }

      void iipReportChunk(int callbackId, DC data)
      {
          if (_requests.containsKey(callbackId))
          {
              var req = _requests[callbackId];
              Codec.parse(data, 0, this).then((x)
              {
                  req.triggerChunk(x);
              });
          }
      }

      void iipEventResourceReassigned(int resourceId, int newResourceId)
      {

      }

      void iipEventResourceDestroyed(int resourceId)
      {
          if (_resources.contains(resourceId))
          {
              var r = _resources[resourceId];
              _resources.remove(resourceId);
              r.destroy();
          }
      }

      void iipEventPropertyUpdated(int resourceId, int index, DC content)
      {

          fetch(resourceId).then((r)
          {
              var item = new AsyncReply<DistributedResourceQueueItem>();
              _queue.add(item);

              Codec.parse(content, 0, this).then((arguments)
              {
                  var pt = r.instance.template.getPropertyTemplateByIndex(index);
                  if (pt != null)
                  {
                      item.trigger(new DistributedResourceQueueItem(r as DistributedResource,
                                                      DistributedResourceQueueItemType.Propery,
                                                      arguments, index));
                  }
                  else
                  {    // ft found, fi not found, this should never happen
                      _queue.remove(item);
                  }
              });

          });

          /*
          if (resources.Contains(resourceId))
          {
              // push to the queue to gaurantee serialization
              var reply = new AsyncReply<DistributedResourceQueueItem>();
              queue.Add(reply);

              var r = resources[resourceId];
              Codec.parse(content, 0, this).then((arguments) =>
              {
                  if (!r.IsAttached)
                  {
                      // property updated before the template is received
                      r.AddAfterAttachement(reply, 
                                              new DistributedResourceQueueItem((DistributedResource)r, 
                                                                DistributedResourceQueueItem.DistributedResourceQueueItemType.Propery, 
                                                                arguments, index));
                  }
                  else
                  {
                      var pt = r.instance.template.GetPropertyTemplate(index);
                      if (pt != null)
                      {
                          reply.trigger(new DistributedResourceQueueItem((DistributedResource)r, 
                                                          DistributedResourceQueueItem.DistributedResourceQueueItemType.Propery, 
                                                          arguments, index));
                      }
                      else
                      {    // ft found, fi not found, this should never happen
                          queue.Remove(reply);
                      }
                  }
              });
          }
          */
      }


      void iipEventEventOccurred(int resourceId, int index, DC content)
      {
          fetch(resourceId).then((r)
          {
              // push to the queue to gaurantee serialization
              var item = new AsyncReply<DistributedResourceQueueItem>();
              _queue.add(item);

              Codec.parseVarArray(content,  0, content.length, this).then((arguments)
              {
                  var et = r.instance.template.getEventTemplateByIndex(index);
                  if (et != null)
                  {
                      item.trigger(new DistributedResourceQueueItem(r,
                                    DistributedResourceQueueItemType.Event, arguments, index));
                  }
                  else
                  {    // ft found, fi not found, this should never happen
                      _queue.remove(item);
                  }

              });
          });

          /*
          if (resources.Contains(resourceId))
          {
              // push to the queue to gaurantee serialization
              var reply = new AsyncReply<DistributedResourceQueueItem>();
              var r = resources[resourceId];

              queue.Add(reply);

              Codec.parseVarArray(content, this).then((arguments) =>
              {
                  if (!r.IsAttached)
                  {
                      // event occurred before the template is received
                      r.AddAfterAttachement(reply,
                                              new DistributedResourceQueueItem((DistributedResource)r,
                                        DistributedResourceQueueItem.DistributedResourceQueueItemType.Event, arguments, index));
                  }
                  else
                  {
                      var et = r.instance.template.GetEventTemplate(index);
                      if (et != null)
                      {
                          reply.trigger(new DistributedResourceQueueItem((DistributedResource)r, 
                                        DistributedResourceQueueItem.DistributedResourceQueueItemType.Event, arguments, index));
                      }
                      else
                      {    // ft found, fi not found, this should never happen
                          queue.Remove(reply);
                      }
                  }
              });
          }
          */
      }

      void iipEventChildAdded(int resourceId, int childId)
      {
          fetch(resourceId).then((parent)
          {
              fetch(childId).then((child)
              {
                  parent.instance.children.add(child);
              });
          });
      }

      void iipEventChildRemoved(int resourceId, int childId)
      {
          fetch(resourceId).then((parent)
          {
              fetch(childId).then((child)
              {
                  parent.instance.children.remove(child);
              });
          });
      }

      void iipEventRenamed(int resourceId, DC name)
      {
          fetch(resourceId).then((resource)
          {
              resource.instance.attributes["name"] = name.getString(0, name.length);
          });
      }


      void iipEventAttributesUpdated(int resourceId, DC attributes)
      {
          fetch(resourceId).then((resource)
          {
              var attrs = attributes.getStringArray(0, attributes.length);

              getAttributes(resource, attrs).then((s)
              {
                  resource.instance.setAttributes(s);
              });
          });
      }

      void iipRequestAttachResource(int callback, int resourceId)
      {
          Warehouse.getById(resourceId).then((res)
          {
              if (res != null)
              {
                  if (res.instance.applicable(session, ActionType.Attach, null) == Ruling.Denied)
                  {
                      sendError(ErrorType.Management, callback, 6);
                      return;
                  }

                  var r = res as IResource;

                  var link = DC.stringToBytes(r.instance.link);

                  if (r is DistributedResource)
                  {
                      // reply ok
                      sendReply(IIPPacketAction.AttachResource, callback)
                              .addGuid(r.instance.template.classId)
                              .addUint64(r.instance.age)
                              .addUint16(link.length)
                              .addDC(link)
                              .addDC(Codec.composePropertyValueArray((r as DistributedResource).serialize(), this, true))
                              .done();
                  }
                  else
                  {
                      // reply ok
                      sendReply(IIPPacketAction.AttachResource, callback)
                              .addGuid(r.instance.template.classId)
                              .addUint64(r.instance.age)
                              .addUint16(link.length)
                              .addDC(link)
                              .addDC(Codec.composePropertyValueArray(r.instance.serialize(), this, true))
                              .done();
                  }

                  r.instance.on("resourceEventOccurred", _instance_EventOccurred);
                  r.instance.on("resourceModified", _instance_PropertyModified);
                  r.instance.on("resourceDestroyed", _instance_ResourceDestroyed);
                  r.instance.children.on("add", _children_OnAdd);
                  r.instance.children.on("removed", _children_OnRemoved);
                  r.instance.attributes.on("modified", _attributes_OnModified);

              }
              else
              {
                  // reply failed
                  //SendParams(0x80, r.instance.id, r.instance.Age, r.instance.serialize(false, this));
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
              }
          });
      }

      void _attributes_OnModified(String key, oldValue, newValue, KeyList<String, dynamic> sender)
      {
          if (key == "name")
          {
              var instance = (sender.owner as Instance);
              var name = DC.stringToBytes(newValue.toString());
              sendEvent(IIPPacketEvent.ChildRemoved)
                      .addUint32(instance.id)
                      .addUint16(name.length)
                      .addDC(name)
                      .done();
          }
      }

      void _children_OnRemoved(Instance sender, IResource value)
      {
          sendEvent(IIPPacketEvent.ChildRemoved)
              .addUint32(sender.id)
              .addUint32(value.instance.id)
              .done();
      }

      void _children_OnAdd(Instance sender, IResource value)
      {
          //if (sender.applicable(sender.Resource, this.session, ActionType.))
          sendEvent(IIPPacketEvent.ChildAdded)
              .addUint32(sender.id)
              .addUint32(value.instance.id)
              .done();
      }

      void iipRequestReattachResource(int callback, int resourceId, int resourceAge)
      {
          Warehouse.getById(resourceId).then((res)
          {
              if (res != null)
              {
                  var r = res as IResource;
                  r.instance.on("resourceEventOccurred", _instance_EventOccurred);
                  r.instance.on("resourceModified", _instance_PropertyModified);
                  r.instance.on("resourceDestroyed", _instance_ResourceDestroyed);

                  // reply ok
                  sendReply(IIPPacketAction.ReattachResource, callback)
                              .addUint64(r.instance.age)
                              .addDC(Codec.composePropertyValueArray(r.instance.serialize(), this, true))
                              .done();
              }
              else
              {
                  // reply failed
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
              }
          });
      }

      void iipRequestDetachResource(int callback, int resourceId)
      {
          Warehouse.getById(resourceId).then((res)
          {
              if (res != null)
              {
                  var r = res as IResource;
                  r.instance.off("resourceEventOccurred", _instance_EventOccurred);
                  r.instance.off("resourceModified", _instance_PropertyModified);
                  r.instance.off("resourceDestroyed", _instance_ResourceDestroyed);
                  // reply ok
                  sendReply(IIPPacketAction.DetachResource, callback).done();
              }
              else
              {
                  // reply failed
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
              }
          });
      }

      void iipRequestCreateResource(int callback, int storeId, int parentId, DC content)
      {

          Warehouse.getById(storeId).then((store)
          {
              if (store == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.StoreNotFound.index);
                  return;
              }

              if (!(store is IStore))
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceIsNotStore.index);
                  return;
              }

              // check security
              if (store.instance.applicable(session, ActionType.CreateResource, null) != Ruling.Allowed)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.CreateDenied.index);
                  return;
              }

              Warehouse.getById(parentId).then((parent)
              {

                  // check security

                  if (parent != null)
                      if (parent.instance.applicable(session, ActionType.AddChild, null) != Ruling.Allowed)
                      {
                          sendError(ErrorType.Management, callback, ExceptionCode.AddChildDenied.index);
                          return;
                      }

                  int offset = 0;

                  var className = content.getString(offset + 1, content[0]);
                  offset += 1 + content[0];

                  var nameLength = content.getUint16(offset);
                  offset += 2;
                  var name = content.getString(offset, nameLength);

                  var cl = content.getUint32(offset);
                  offset += 4;

                  var type = null;//Type.getType(className);

                  if (type == null)
                  {
                      sendError(ErrorType.Management, callback, ExceptionCode.ClassNotFound.index);
                      return;
                  }

                  Codec.parseVarArray(content, offset, cl, this).then((parameters)
                  {
                      offset += cl;
                      cl = content.getUint32(offset);
                      Codec.parseStructure(content, offset, cl, this).then((attributes)
                      {
                          offset += cl;
                          cl = content.length - offset;

                          Codec.parseStructure(content, offset, cl, this).then((values)
                          {

                            
                              var constructors = [];//Type.GetType(className).GetTypeInfo().GetConstructors();

                              var matching = constructors.where((x)
                              {
                                  var ps = x.GetParameters();
                                 // if (ps.length > 0 && ps.length == parameters.length + 1)
                                   //   if (ps.Last().ParameterType == typeof(DistributedConnection))
                                     //     return true;

                                  return ps.length == parameters.length;
                              }
                              ).toList();

                              var pi = matching[0].getParameters();

                              // cast arguments
                              List<dynamic> args = null;

                              if (pi.length > 0)
                              {
                                  int argsCount = pi.length;
                                  args = new List<dynamic>(pi.length);

                                  if (pi[pi.length - 1].parameterType.runtimeType == DistributedConnection)
                                  {
                                      args[--argsCount] = this;
                                  }

                                  if (parameters != null)
                                  {
                                      for (int i = 0; i < argsCount && i < parameters.length; i++)
                                      {
                                          //args[i] = DC.CastConvert(parameters[i], pi[i].ParameterType);
                                      }
                                  }
                              }

                              // create the resource
                              var resource = null; //Activator.CreateInstance(type, args) as IResource;

                              Warehouse.put(resource, name, store as IStore, parent);

                              sendReply(IIPPacketAction.CreateResource, callback)
                                          .addUint32(resource.instance.id)
                                          .done();

                          });
                      });
                  });
              });
          });
      }

      void iipRequestDeleteResource(int callback, int resourceId)
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              if (r.instance.store.instance.applicable(session, ActionType.Delete, null) != Ruling.Allowed)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.DeleteDenied.index);
                  return;
              }

              if (Warehouse.remove(r))
                  sendReply(IIPPacketAction.DeleteResource, callback).done();
              //SendParams((byte)0x84, callback);
              else
                  sendError(ErrorType.Management, callback, ExceptionCode.DeleteFailed.index);
          });
      }

      void iipRequestGetAttributes(int callback, int resourceId, DC attributes, [bool all = false])
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              //                if (!r.instance.store.instance.applicable(r, session, ActionType.InquireAttributes, null))
              if (r.instance.applicable(session, ActionType.InquireAttributes, null) != Ruling.Allowed)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ViewAttributeDenied.index);
                  return;
              }

              List<String> attrs = null;

              if (!all)
                  attrs = attributes.getStringArray(0, attributes.length);

              var st = r.instance.getAttributes(attrs);

              if (st != null)
                  sendReply(all ? IIPPacketAction.GetAllAttributes : IIPPacketAction.GetAttributes, callback)
                            .addDC(Codec.composeStructure(st, this, true, true, true))
                            .done();
              else
                  sendError(ErrorType.Management, callback, ExceptionCode.GetAttributesFailed.index);

          });
      }

      void iipRequestAddChild(int callback, int parentId, int childId)
      {
          Warehouse.getById(parentId).then((parent)
          {
              if (parent == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              Warehouse.getById(childId).then((child)
              {
                  if (child == null)
                  {
                      sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                      return;
                  }

                  if (parent.instance.applicable(this.session, ActionType.AddChild, null) != Ruling.Allowed)
                  {
                      sendError(ErrorType.Management, callback, ExceptionCode.AddChildDenied.index);
                      return;
                  }

                  if (child.instance.applicable(this.session, ActionType.AddParent, null) != Ruling.Allowed)
                  {
                      sendError(ErrorType.Management, callback, ExceptionCode.AddParentDenied.index);
                      return;
                  }

                  parent.instance.children.add(child);

                  sendReply(IIPPacketAction.AddChild, callback).done();
                  //child.instance.Parents
              });

          });
      }

      void iipRequestRemoveChild(int callback, int parentId, int childId)
      {
          Warehouse.getById(parentId).then((parent)
          {
              if (parent == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              Warehouse.getById(childId).then((child)
              {
                  if (child == null)
                  {
                      sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                      return;
                  }

                  if (parent.instance.applicable(this.session, ActionType.RemoveChild, null) != Ruling.Allowed)
                  {
                      sendError(ErrorType.Management, callback, ExceptionCode.AddChildDenied.index);
                      return;
                  }

                  if (child.instance.applicable(this.session, ActionType.RemoveParent, null) != Ruling.Allowed)
                  {
                      sendError(ErrorType.Management, callback, ExceptionCode.AddParentDenied.index);
                      return;
                  }

                  parent.instance.children.remove(child);

                  sendReply(IIPPacketAction.RemoveChild, callback).done();
                  //child.instance.Parents
              });

          });
      }

      void iipRequestRenameResource(int callback, int resourceId, DC name)
      {
          Warehouse.getById(resourceId).then((resource)
          {
              if (resource == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              if (resource.instance.applicable(this.session, ActionType.Rename, null) != Ruling.Allowed)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.RenameDenied.index);
                  return;
              }


              resource.instance.name = name.getString(0, name.length);
              sendReply(IIPPacketAction.RenameResource, callback).done();
          });
      }

      void iipRequestResourceChildren(int callback, int resourceId)
      {
          Warehouse.getById(resourceId).then((resource)
          {
              if (resource == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              sendReply(IIPPacketAction.ResourceChildren, callback)
                  .addDC(Codec.composeResourceArray(resource.instance.children.toList(), this, true))
                  .done();

          });
      }

      void iipRequestResourceParents(int callback, int resourceId)
      {
          Warehouse.getById(resourceId).then((resource)
          {
              if (resource == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              sendReply(IIPPacketAction.ResourceParents, callback)
                      .addDC(Codec.composeResourceArray(resource.instance.parents.toList(), this, true))
                      .done();
          });
      }

      void iipRequestClearAttributes(int callback, int resourceId, DC attributes, [bool all = false])
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              if (r.instance.store.instance.applicable(session, ActionType.UpdateAttributes, null) != Ruling.Allowed)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.UpdateAttributeDenied.index);
                  return;
              }

              List<String> attrs = null;

              if (!all)
                  attrs = attributes.getStringArray(0, attributes.length);

              if (r.instance.removeAttributes(attrs))
                  sendReply(all ? IIPPacketAction.ClearAllAttributes : IIPPacketAction.ClearAttributes, callback).done();
              else
                  sendError(ErrorType.Management, callback, ExceptionCode.UpdateAttributeFailed.index);

          });
      }

      void iipRequestUpdateAttributes(int callback, int resourceId, DC attributes, [bool clearAttributes = false])
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r == null)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
                  return;
              }

              if (r.instance.store.instance.applicable(session, ActionType.UpdateAttributes, null) != Ruling.Allowed)
              {
                  sendError(ErrorType.Management, callback, ExceptionCode.UpdateAttributeDenied.index);
                  return;
              }

              Codec.parseStructure(attributes, 0, attributes.length, this).then((attrs)
              {
                  if (r.instance.setAttributes(attrs, clearAttributes))
                      sendReply(clearAttributes ? IIPPacketAction.ClearAllAttributes : IIPPacketAction.ClearAttributes,
                                callback).done();
                  else
                      sendError(ErrorType.Management, callback, ExceptionCode.UpdateAttributeFailed.index);
              });

          });

      }

      void iipRequestTemplateFromClassName(int callback, String className)
      {
          Warehouse.getTemplateByClassName(className).then((t)
          {
              if (t != null)
                  sendReply(IIPPacketAction.TemplateFromClassName, callback)
                          .addInt32(t.content.length)
                          .addDC(t.content)
                          .done();
              else
              {
                  // reply failed
                  sendError(ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
              }
          });
      }

      void iipRequestTemplateFromClassId(int callback, Guid classId)
      {
          Warehouse.getTemplateByClassId(classId).then((t)
          {
              if (t != null)
                  sendReply(IIPPacketAction.TemplateFromClassId, callback)
                          .addInt32(t.content.length)
                          .addDC(t.content)
                          .done();
              else
              {
                  // reply failed
                  sendError(ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
              }
          });
      }



      void iipRequestTemplateFromResourceId(int callback, int resourceId)
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r != null)
                  sendReply(IIPPacketAction.TemplateFromResourceId, callback)
                          .addInt32(r.instance.template.content.length)
                          .addDC(r.instance.template.content)
                          .done();
              else
              {
                  // reply failed
                  sendError(ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
              }
          });
      }




      void iipRequestQueryResources(int callback, String resourceLink)
      {
          Warehouse.query(resourceLink).then((r) 
          {
              //if (r != null)
              //{
              var list = r.where((x) => x.instance.applicable(session, ActionType.Attach, null) != Ruling.Denied).toList();

              if (list.length == 0)
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
              else
                  sendReply(IIPPacketAction.QueryLink, callback)
                              .addDC(Codec.composeResourceArray(list, this, true))
                              .done();
          });
      }

      void IIPRequestResourceAttribute(int callback, int resourceId)
      {

      }

      void iipRequestInvokeFunctionArrayArguments(int callback, int resourceId, int index, DC content)
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r != null)
              {
                  Codec.parseVarArray(content, 0, content.length, this).then((arguments)
                  {
                      var ft = r.instance.template.getFunctionTemplateByIndex(index);
                      if (ft != null)
                      {
                          if (r is DistributedResource)
                          {
                              var rt = (r as DistributedResource).invokeByArrayArguments(index, arguments);
                              if (rt != null)
                              {
                                  rt.then((res)
                                  {
                                      sendReply(IIPPacketAction.InvokeFunctionArrayArguments, callback)
                                                  .addDC(Codec.compose(res, this))
                                                  .done();
                                  });
                              }
                              else
                              {

                                  // function not found on a distributed object
                              }
                          }
                          else
                          {

                            
                              var fi = null ;//r.GetType().GetTypeInfo().GetMethod(ft.name);


                              if (fi != null)
                              {

                              }
                              else
                              {
                                  // ft found, fi not found, this should never happen
                              }
                          }
                      }
                      else
                      {
                          // no function at this index
                      }
                  });
              }
              else
              {
                  // no resource with this id
              }
          });
      }


      void iipRequestInvokeFunctionNamedArguments(int callback, int resourceId, int index, DC content)
      {

          Warehouse.getById(resourceId).then((r)
          {
              if (r != null)
              {
                  Codec.parseStructure(content, 0, content.length, this).then((namedArgs)
                    {
                        var ft = r.instance.template.getFunctionTemplateByIndex(index);
                        if (ft != null)
                        {
                            if (r is DistributedResource)
                            {
                                var rt = (r as DistributedResource).invokeByNamedArguments(index, namedArgs);
                                if (rt != null)
                                {
                                    rt.then((res)
                                    {
                                        sendReply(IIPPacketAction.InvokeFunctionNamedArguments, callback)
                                                .addDC(Codec.compose(res, this))
                                                .done();
                                    });
                                }
                                else
                                {

                                  // function not found on a distributed object
                              }
                            }
                            else
                            {

                              var fi = null;


                              if (fi != null)
                                {
                                }
                                else
                                {
                                  // ft found, fi not found, this should never happen
                              }
                            }
                        }
                        else
                        {
                          // no function at this index
                      }
                    });
              }
              else
              {
                  // no resource with this id
              }
          });
      }

      void iipRequestGetProperty(int callback, int resourceId, int index)
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r != null)
              {
                  var pt = r.instance.template.getFunctionTemplateByIndex(index);
                  if (pt != null)
                  {
                      if (r is DistributedResource)
                      {
                          sendReply(IIPPacketAction.GetProperty, callback)
                                      .addDC(Codec.compose((r as DistributedResource).get(pt.index), this))
                                      .done();
                      }
                      else
                      {
                          var pi = null; //r.GetType().GetTypeInfo().GetProperty(pt.Name);

                          if (pi != null)
                          {
                              sendReply(IIPPacketAction.GetProperty, callback)
                                          .addDC(Codec.compose(pi.GetValue(r), this))
                                          .done();
                          }
                          else
                          {
                              // pt found, pi not found, this should never happen
                          }
                      }
                  }
                  else
                  {
                      // pt not found
                  }
              }
              else
              {
                  // resource not found
              }
          });
      }

      void iipRequestInquireResourceHistory(int callback, int resourceId, DateTime fromDate, DateTime toDate)
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r != null)
              {
                  r.instance.store.getRecord(r, fromDate, toDate).then((results)
                  {
                      var history = Codec.composeHistory(results, this, true);

                      /*
                      ulong fromAge = 0;
                      ulong toAge = 0;

                      if (results.Count > 0)
                      {
                          var firstProp = results.Values.First();
                          //var lastProp = results.Values.Last();

                          if (firstProp.length > 0)
                          {
                              fromAge = firstProp[0].Age;
                              toAge = firstProp.Last().Age;
                          }

                      }*/

                      sendReply(IIPPacketAction.ResourceHistory, callback)
                              .addDC(history)
                              .done();

                  });
              }
          });
      }

      void iipRequestGetPropertyIfModifiedSince(int callback, int resourceId,int index, int age)
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r != null)
              {
                  var pt = r.instance.template.getFunctionTemplateByIndex(index);
                  if (pt != null)
                  {
                      if (r.instance.getAge(index) > age)
                      {
                          var pi = null; //r.GetType().GetProperty(pt.Name);
                          if (pi != null)
                          {
                              sendReply(IIPPacketAction.GetPropertyIfModified, callback)
                                          .addDC(Codec.compose(pi.GetValue(r), this))
                                          .done();
                          }
                          else
                          {
                              // pt found, pi not found, this should never happen
                          }
                      }
                      else
                      {
                          sendReply(IIPPacketAction.GetPropertyIfModified, callback)
                                  .addUint8(DataType.NotModified)
                                  .done();
                      }
                  }
                  else
                  {
                      // pt not found
                  }
              }
              else
              {
                  // resource not found
              }
          });
      }

      void iipRequestSetProperty(int callback, int resourceId, int index, DC content)
      {
          Warehouse.getById(resourceId).then((r)
          {
              if (r != null)
              {


                  var pt = r.instance.template.getPropertyTemplateByIndex(index);
                  if (pt != null)
                  {
                      Codec.parse(content, 0, this).then((value)
                      {
                          if (r is DistributedResource)
                          {
                              // propagation
                              (r as DistributedResource).set(index, value).then<dynamic>((x)
                              {
                                  sendReply(IIPPacketAction.SetProperty, callback).done();
                              }).error((x)
                              {
                                  sendError(x.type, callback, x.code, x.message);
                              });
                          }
                          else
                          {

                              /*
#if NETSTANDARD1_5
                              var pi = r.GetType().GetTypeInfo().GetProperty(pt.Name);
#else
                              var pi = r.GetType().GetProperty(pt.Name);
#endif*/


                              var pi = null;// pt.Info;

                              if (pi != null)
                              {

                                  if (r.instance.applicable(session, ActionType.SetProperty, pt, this) == Ruling.Denied)
                                  {
                                      sendError(ErrorType.Exception, callback, ExceptionCode.SetPropertyDenied.index);
                                      return;
                                  }

                                  if (!pi.CanWrite)
                                  {
                                      sendError(ErrorType.Management, callback, ExceptionCode.ReadOnlyProperty.index);
                                      return;
                                  }


                                  if (pi.propertyType.runtimeType == DistributedPropertyContext)
                                  {
                                      value = new DistributedPropertyContext.setter(this, value);
                                  }
                                  else
                                  {
                                      // cast new value type to property type
                                     // value = DC.castConvert(value, pi.PropertyType);
                                  }


                                  try
                                  {
                                      pi.setValue(r, value);
                                      sendReply(IIPPacketAction.SetProperty, callback).done();
                                  }
                                  catch (ex)
                                  {
                                      sendError(ErrorType.Exception, callback, 0, ex.message);
                                  }

                              }
                              else
                              {
                                  // pt found, pi not found, this should never happen
                                  sendError(ErrorType.Management, callback, ExceptionCode.PropertyNotFound.index);
                              }
                          }

                      });
                  }
                  else
                  {
                      // property not found
                      sendError(ErrorType.Management, callback, ExceptionCode.PropertyNotFound.index);
                  }
              }
              else
              {
                  // resource not found
                  sendError(ErrorType.Management, callback, ExceptionCode.ResourceNotFound.index);
              }
          });
      }

      /// <summary>
      /// Get the ResourceTemplate for a given class Id. 
      /// </summary>
      /// <param name="classId">Class GUID.</param>
      /// <returns>ResourceTemplate.</returns>
      AsyncReply<ResourceTemplate> getTemplate(Guid classId)
      {
          if (_templates.containsKey(classId))
              return new AsyncReply<ResourceTemplate>.ready(_templates[classId]);
          else if (_templateRequests.containsKey(classId))
              return _templateRequests[classId];

          var reply = new AsyncReply<ResourceTemplate>();
          _templateRequests.add(classId, reply);

          sendRequest(IIPPacketAction.TemplateFromClassId)
                      .addGuid(classId)
                      .done()
                      .then<dynamic>((rt)
                      {
                          _templateRequests.remove(classId);
                          _templates[(rt[0] as ResourceTemplate).classId] = rt[0] as ResourceTemplate;
                          Warehouse.putTemplate(rt[0] as ResourceTemplate);
                          reply.trigger(rt[0]);
                      }).error((ex)
                      {
                          reply.triggerError(ex);
                      });

          return reply;
      }

      // IStore interface 
      /// <summary>
      /// Get a resource by its path.
      /// </summary>
      /// <param name="path">Path to the resource.</param>
      /// <returns>Resource</returns>
      AsyncReply<IResource> get(String path)
      {

          var rt = new AsyncReply<IResource>();

          query(path).then<dynamic>((ar)
          {
              if (ar?.length > 0)
                  rt.trigger(ar[0]);
              else
                  rt.trigger(null);
          }).error((ex) => rt.triggerError(ex));

          return rt;

        
      }

      /// <summary>
      /// Retrive a resource by its instance Id.
      /// </summary>
      /// <param name="iid">Instance Id</param>
      /// <returns>Resource</returns>
      AsyncReply<IResource> retrieve(int iid)
      {
          for (var r in _resources.values)
              if (r.instance.id == iid)
                  return new AsyncReply<IResource>.ready(r);
          return new AsyncReply<IResource>.ready(null);
      }

      /// <summary>
      /// Fetch a resource from the other end
      /// </summary>
      /// <param name="classId">Class GUID</param>
      /// <param name="id">Resource Id</param>Guid classId
      /// <returns>DistributedResource</returns>
      AsyncReply<DistributedResource> fetch(int id)
      {
          var resource = _resources[id];
          var request = _resourceRequests[id];

          if (request != null)
          {
              // dig for dead locks
              if (resource != null) // dead lock
                return new AsyncReply<DistributedResource>.ready(_resources[id]);
              else
                return request;
          }
          else if (resource != null && !resource.suspended)
              return new AsyncReply<DistributedResource>.ready(resource);

          var reply = new AsyncReply<DistributedResource>();
          _resourceRequests.add(id, reply);
          
          sendRequest(IIPPacketAction.AttachResource)
                      .addUint32(id)
                      .done()
                      .then<dynamic>((rt)
                      {
                          var dr = resource ?? new DistributedResource(this, id, rt[1], rt[2]);

                          getTemplate(rt[0] as Guid).then<dynamic>((tmp)
                          {
                              //print("New template ");

                              // ClassId, ResourceAge, ResourceLink, Content
                              if (resource == null)
                                Warehouse.put(dr, id.toString(), this, null, tmp);

                              var d = rt[3] as DC;

                              Codec.parsePropertyValueArray(d, 0, d.length, this).then((ar)
                              {
                                //print("attached");
                                  dr.attach(ar);
                                  _resourceRequests.remove(id);
                                  reply.trigger(dr);
                              });
                          }).error((ex)
                          {
                              reply.triggerError(ex);
                          });
                      }).error((ex)
                      {
                          reply.triggerError(ex);
                      });

          return reply;
      }


      AsyncReply<List<IResource>> getChildren(IResource resource)
      {
          var rt = new AsyncReply<List<IResource>>();

          sendRequest(IIPPacketAction.ResourceChildren)
                      .addUint32(resource.instance.id)
                      .done()
                      .then<dynamic>((ar)
                      {
                          var d = ar[0] as DC;
                          Codec.parseResourceArray(d, 0, d.length, this).then((resources)
                          {
                              rt.trigger(resources);
                          }).error((ex) => rt.triggerError(ex));
                      });

          return rt;
      }

      AsyncReply<List<IResource>> getParents(IResource resource)
      {
          var rt = new AsyncReply<List<IResource>>();

          sendRequest(IIPPacketAction.ResourceParents)
              .addUint32(resource.instance.id)
              .done()
              .then<dynamic>((ar)
              {
                  var d = ar[0] as DC;
                  Codec.parseResourceArray(d, 0, d.length, this).then<dynamic>((resources)
                  {
                      rt.trigger(resources);
                  }).error((ex) => rt.triggerError(ex));
              });

          return rt;
      }

      AsyncReply<bool> removeAttributes(IResource resource, [List<String> attributes = null])
      {
          var rt = new AsyncReply<bool>();

          if (attributes == null)
              sendRequest(IIPPacketAction.ClearAllAttributes)
                  .addUint32(resource.instance.id)
                  .done()
                  .then<dynamic>((ar) => rt.trigger(true))
                  .error((ex) => rt.triggerError(ex));
          else
          {
              var attrs = DC.stringArrayToBytes(attributes);
              sendRequest(IIPPacketAction.ClearAttributes)
                  .addUint32(resource.instance.id)
                  .addInt32(attrs.length)
                  .addDC(attrs)
                  .done()
                  .then<dynamic>((ar) => rt.trigger(true))
                  .error((ex) => rt.triggerError(ex));
          }

          return rt;
      }

      AsyncReply<bool> setAttributes(IResource resource, Structure attributes, [ bool clearAttributes = false ])
      {
          var rt = new AsyncReply<bool>();

          sendRequest(clearAttributes ? IIPPacketAction.UpdateAllAttributes : IIPPacketAction.UpdateAttributes)
              .addUint32(resource.instance.id)
              .addDC(Codec.composeStructure(attributes, this, true, true, true))
              .done()
              .then<dynamic>((ar) => rt.trigger(true))
              .error((ex) => rt.triggerError(ex));

          return rt;
      }

      AsyncReply<Structure> getAttributes(IResource resource, [List<String> attributes = null])
      {
          var rt = new AsyncReply<Structure>();

          if (attributes == null)
          {
              sendRequest(IIPPacketAction.GetAllAttributes)
                  .addUint32(resource.instance.id)
                  .done()
                  .then((ar)
                  {
                      var d = ar[0] as DC;
                      Codec.parseStructure(d, 0, d.length, this).then<dynamic>((st)
                      {
                          resource.instance.setAttributes(st);
                          rt.trigger(st);
                      }).error((ex) => rt.triggerError(ex));
                  });
          }
          else
          {
              var attrs = DC.stringArrayToBytes(attributes);
              sendRequest(IIPPacketAction.GetAttributes)
                  .addUint32(resource.instance.id)
                  .addInt32(attrs.length)
                  .addDC(attrs)
                  .done()
                  .then((ar)
                  {
                      var d = ar[0] as DC;
                      Codec.parseStructure(d, 0, d.length, this).then<dynamic>((st)
                      {

                          resource.instance.setAttributes(st);

                          rt.trigger(st);
                      }).error((ex) => rt.triggerError(ex));
                  });
          }

          return rt;
      }

      /// <summary>
      /// Get resource history.
      /// </summary>
      /// <param name="resource">IResource.</param>
      /// <param name="fromDate">From date.</param>
      /// <param name="toDate">To date.</param>
      /// <returns></returns>
      AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>> getRecord(IResource resource, DateTime fromDate, DateTime toDate)
      {
          if (resource is DistributedResource)
          {
              var dr = resource as DistributedResource;

              if (dr.connection != this)
                  return new AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>>.ready(null);

              var reply = new AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>>();

              sendRequest(IIPPacketAction.ResourceHistory)
                  .addUint32(dr.id)
                  .addDateTime(fromDate)
                  .addDateTime(toDate)
                  .done()
                  .then<dynamic>((rt)
                  {
                      var content = rt[0] as DC;

                      Codec.parseHistory(content, 0, content.length, resource, this)
                                        .then((history) => reply.trigger(history));

                  }).error((ex) => reply.triggerError(ex));

              return reply;
          }
          else
              return new AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>>.ready(null);
      }

      /// <summary>
      /// Query resources at specific link.
      /// </summary>
      /// <param name="path">Link path.</param>
      /// <returns></returns>
       AsyncReply<List<IResource>> query(String path)
      {
          var str = DC.stringToBytes(path);
          var reply = new AsyncReply<List<IResource>>();

          sendRequest(IIPPacketAction.QueryLink)
                      .addUint16(str.length)
                      .addDC(str)
                      .done()
                      .then<dynamic>((args)
                      {
                          var content = args[0] as DC;

                          Codec.parseResourceArray(content, 0, content.length, this)
                                                  .then((resources) => reply.trigger(resources));

                      }).error((ex)=>reply.triggerError(ex));

          return reply;
      }


      /// <summary>
      /// Create a new resource.
      /// </summary>
      /// <param name="store">The store in which the resource is saved.</param>
      /// <param name="className">Class full name.</param>
      /// <param name="parameters">Constructor parameters.</param>
      /// <param name="attributes">Resource attributeds.</param>
      /// <param name="values">Values for the resource properties.</param>
      /// <returns>New resource instance</returns>
      AsyncReply<DistributedResource> create(IStore store, IResource parent, String className, List parameters, Structure attributes, Structure values)
      {
          var reply = new AsyncReply<DistributedResource>();
          var pkt = new BinaryList()
                                  .addUint32(store.instance.id)
                                  .addUint32(parent.instance.id)
                                  .addUint8(className.length)
                                  .addString(className)
                                  .addDC(Codec.composeVarArray(parameters, this, true))
                                  .addDC(Codec.composeStructure(attributes, this, true, true, true))
                                  .addDC(Codec.composeStructure(values, this));

          pkt.insertInt32(8, pkt.length);

          sendRequest(IIPPacketAction.CreateResource)
              .addDC(pkt.toDC())
              .done()
              .then((args)
              {
                  var rid = args[0];

                  fetch(rid).then((r)
                  {
                      reply.trigger(r);
                  });

              });

          return reply;
      }

      _instance_ResourceDestroyed(IResource resource)
      {
          // compose the packet
          sendEvent(IIPPacketEvent.ResourceDestroyed)
                      .addUint32(resource.instance.id)
                      .done();
      }

      void _instance_PropertyModified(IResource resource, String name, newValue)
      {
          var pt = resource.instance.template.getPropertyTemplateByName(name);

          if (pt == null)
              return;

          sendEvent(IIPPacketEvent.PropertyUpdated)
                      .addUint32(resource.instance.id)
                      .addUint8(pt.index)
                      .addDC(Codec.compose(newValue, this))
                      .done();

      }

      //        private void Instance_EventOccurred(IResource resource, string name, string[] users, DistributedConnection[] connections, object[] args)

      void _instance_EventOccurred(IResource resource, issuer, List<Session> receivers, String name, List args)
      {
          var et = resource.instance.template.getEventTemplateByName(name);

          if (et == null)
              return;


          if (receivers != null)
              if (!receivers.contains(this.session))
                  return;

          if (resource.instance.applicable(this.session, ActionType.ReceiveEvent, et, issuer) == Ruling.Denied)
              return;

          // compose the packet
          sendEvent(IIPPacketEvent.EventOccurred)
                      .addUint32(resource.instance.id)
                      .addUint8(et.index)
                      .addDC(Codec.composeVarArray(args, this, true))
                      .done();
      }
}
