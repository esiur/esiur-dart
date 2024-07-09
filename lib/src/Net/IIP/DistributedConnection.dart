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

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:esiur/src/Security/Membership/AuthorizationRequest.dart';
import 'package:web_socket_channel/status.dart';
import '../../Misc/Global.dart';
import '../../Security/Membership/AuthorizationResults.dart';
import '../../Security/Membership/AuthorizationResultsResponse.dart';
import '../Packets/IIPAuthPacketAcknowledge.dart';
import '../Packets/IIPAuthPacketEvent.dart';
import '../Packets/IIPAuthPacketHeader.dart';
import '../Packets/IIPAuthPacketIAuthHeader.dart';
import '../Packets/IIPAuthPacketInitialize.dart';
import '../Sockets/SocketState.dart';
import 'ConnectionStatus.dart';

import '../../Data/IntType.dart';

import '../../Data/DataDeserializer.dart';
import '../../Data/DataSerializer.dart';
import '../../Data/TransmissionType.dart';
import '../../Resource/EventOccurredInfo.dart';
import '../../Resource/PropertyModificationInfo.dart';

import '../Sockets/WSocket.dart';

import '../../Resource/Template/TemplateDescriber.dart';
import '../../Resource/Template/TemplateType.dart';
import '../../Security/Authority/AuthenticationMethod.dart';

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
import '../../Resource/Template/TypeTemplate.dart';
import '../../Security/Permissions/Ruling.dart';
import '../../Security/Permissions/ActionType.dart';
import '../../Data/Codec.dart';
import '../../Core/ProgressType.dart';
import '../../Security/Integrity/SHA256.dart';
import '../../Resource/ResourceTrigger.dart';
import './DistributedServer.dart';

import '../Packets/IIPAuthPacketHashAlgorithm.dart';

class DistributedConnection extends NetworkConnection with IStore {
  // fields
  bool _invalidCredentials = false;

  Timer? _keepAliveTimer;
  DateTime? _lastKeepAliveSent;
  DateTime? _lastKeepAliveReceived;

  IIPPacket _packet = new IIPPacket();
  IIPAuthPacket _authPacket = new IIPAuthPacket();

  Session _session = new Session();
  AsyncReply<bool>? _openReply;

  DC? _localPasswordOrToken;

  bool _ready = false, _readyToEstablish = false;
  String? _hostname;
  int _port = 10518;

  DistributedServer? _server;
  DateTime? _loginDate;

  // Properties
  DateTime? get loginDate => _loginDate;

  int jitter = 0;
  ConnectionStatus _status = ConnectionStatus.Closed;
  ConnectionStatus get status => _status;

  //Attributes
  int keepAliveTime = 10;
  int keepAliveInterval = 30;
  AsyncReply Function(AuthorizationRequest)? authenticator;
  bool autoReconnect = false;
  int reconnectInterval = 5;

  DistributedServer? get server => _server;

  KeyList<int, WeakReference<DistributedResource>> _attachedResources =
      new KeyList<int, WeakReference<DistributedResource>>();

  KeyList<int, DistributedResource> _neededResources =
      new KeyList<int, DistributedResource>();
  KeyList<int, WeakReference<DistributedResource>> _suspendedResources =
      new KeyList<int, WeakReference<DistributedResource>>();

  KeyList<int, AsyncReply<DistributedResource>> _resourceRequests =
      new KeyList<int, AsyncReply<DistributedResource>>();

  KeyList<Guid, AsyncReply<TypeTemplate?>> _templateRequests =
      new KeyList<Guid, AsyncReply<TypeTemplate?>>();

  KeyList<String, AsyncReply<TypeTemplate?>> _templateByNameRequests =
      new KeyList<String, AsyncReply<TypeTemplate?>>();

  Map<Guid, TypeTemplate> _templates = new Map<Guid, TypeTemplate>();
  KeyList<int, AsyncReply<dynamic>> _requests =
      new KeyList<int, AsyncReply<dynamic>>();
  int _callbackCounter = 0;
  AsyncQueue<DistributedResourceQueueItem> _queue =
      new AsyncQueue<DistributedResourceQueueItem>();

  Map<IResource, List<int>> _subscriptions = new Map<IResource, List<int>>();

  /// <summary>
  /// The session related to this connection.
  /// </summary>
  Session get session => _session;

  /// <summary>
  /// Distributed server responsible for this connection, usually for incoming connections.
  /// </summary>
  //public DistributedServer Server

  bool remove(IResource resource) {
    // nothing to do
    return true;
  }

  /// <summary>
  /// Send data to the other end as parameters
  /// </summary>
  /// <param name="values">Values will be converted to bytes then sent.</param>
  SendList _sendParams([AsyncReply<List<dynamic>?>? reply = null]) {
    return new SendList(this, reply);
  }

  /// <summary>
  /// Send raw data through the connection.
  /// </summary>
  /// <param name="data">Data to send.</param>
  void send(DC data) {
    //Console.WriteLine("Client: {0}", Data.length);

    //Global.Counters["IIP Sent Packets"]++;
    super.send(data);
  }

  AsyncReply<bool> trigger(ResourceTrigger trigger) {
    if (trigger == ResourceTrigger.Open) {
      if (_server != null) return new AsyncReply<bool>.ready(true);

      var host = (instance as Instance).name.split(":");

      // assign domain from hostname if not provided
      var address = host[0];
      var port = host.length > 1 ? int.parse(host[1]) : 10518;

      var domain = instance?.attributes["domain"].toString() ?? address;

      var ws = instance?.attributes.containsKey("ws") == true ||
          instance?.attributes.containsKey("wss") == true;
      var secure = instance?.attributes.containsKey("secure") == true ||
          instance?.attributes.containsKey("wss") == true;

      if (instance?.attributes.containsKey("autoReconnect") ?? false)
        autoReconnect = instance?.attributes["autoReconnect"] == true;

      if (instance?.attributes.containsKey("reconnectInterval") ?? false)
        reconnectInterval = instance?.attributes["reconnectInterval"];

      if (instance?.attributes.containsKey("keepAliveInterval") ?? false)
        keepAliveInterval = instance?.attributes["keepAliveInterval"];

      if (instance?.attributes.containsKey("keepAliveTime") ?? false)
        keepAliveTime = instance?.attributes["keepAliveTime"];

      if (instance?.attributes.containsKey("username") == true &&
          instance?.attributes.containsKey("password") == true) {
        var username = instance?.attributes["username"] as String;
        var password =
            DC.stringToBytes(instance?.attributes["password"] as String);

        return connect(
            method: AuthenticationMethod.Credentials,
            domain: domain,
            hostname: address,
            port: port,
            passwordOrToken: password,
            username: username,
            useWebsocket: ws,
            secureWebSocket: secure);
      } else if (instance?.attributes.containsKey("token") == true) {
        var token =
            DC.stringToBytes(instance?.attributes["token"].toString() ?? "");
        var tokenIndex = instance?.attributes["tokenIndex"] as int? ?? 0;
        return connect(
            method: AuthenticationMethod.Credentials,
            domain: domain,
            hostname: address,
            port: port,
            passwordOrToken: token,
            tokenIndex: tokenIndex,
            useWebsocket: ws,
            secureWebSocket: secure);
      } else {
        return connect(
            method: AuthenticationMethod.None,
            hostname: address,
            port: port,
            domain: domain,
            useWebsocket: ws,
            secureWebSocket: secure);
      }
    }

    return new AsyncReply<bool>.ready(true);
  }

  AsyncReply<bool> connect(
      {AuthenticationMethod method = AuthenticationMethod.None,
      ISocket? socket,
      String? hostname,
      int? port,
      String? username,
      int? tokenIndex,
      DC? passwordOrToken,
      String? domain,
      bool useWebsocket = false,
      bool secureWebSocket = false}) {
    if (_openReply != null)
      throw AsyncException(ErrorType.Exception, 0, "Connection in progress");

    _status = ConnectionStatus.Connecting;

    _openReply = new AsyncReply<bool>();

    if (hostname != null) {
      _session = new Session();

      _session.authenticationType = AuthenticationType.Client;
      _session.localMethod = method;
      _session.remoteMethod = AuthenticationMethod.None;

      _session.localHeaders[IIPAuthPacketHeader.Domain] = domain;
      _session.localHeaders[IIPAuthPacketHeader.Nonce] =
          Global.generateCode(32);

      if (method == AuthenticationMethod.Credentials) {
        _session.localHeaders[IIPAuthPacketHeader.Username] = username;
      } else if (method == AuthenticationMethod.Token) {
        _session.localHeaders[IIPAuthPacketHeader.TokenIndex] = tokenIndex;
      } else if (method == AuthenticationMethod.Certificate) {
        throw Exception("Unsupported authentication method.");
      }

      _localPasswordOrToken = passwordOrToken;
      _invalidCredentials = false;
    }

    //if (_session == null)
    //  throw AsyncException(ErrorType.Exception, 0, "Session not initialized");

    if (socket == null) {
      if (useWebsocket || kIsWeb) {
        socket = new WSocket()..secure = secureWebSocket;
      } else
        socket = new TCPSocket();
    }

    _port = port ?? _port;
    _hostname = hostname ?? _hostname;

    if (_hostname == null) throw Exception("Host not specified.");

    _connectSocket(socket);

    return _openReply as AsyncReply<bool>;
  }

  _connectSocket(ISocket socket) {
    socket.connect(_hostname as String, _port)
      ..then((x) {
        assign(socket);
      })
      ..error((x) {
        if (autoReconnect) {
          print("Reconnecting socket...");
          Future.delayed(Duration(seconds: reconnectInterval),
              () => _connectSocket(socket));
        } else {
          _openReply?.triggerError(x);
          _openReply = null;
        }
      });
  }

  @override
  void disconnected() {
    // clean up
    _ready = false;
    _readyToEstablish = false;
    _status = ConnectionStatus.Closed;

    //print("Disconnected ..");

    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    _requests.values.forEach((x) {
      try {
        x.triggerError(
            AsyncException(ErrorType.Management, 0, "Connection closed"));
      } catch (ex) {}
    });

    _resourceRequests.values.forEach((x) {
      try {
        x.triggerError(
            AsyncException(ErrorType.Management, 0, "Connection closed"));
      } catch (ex) {}
    });

    _templateRequests.values.forEach((x) {
      try {
        x.triggerError(
            AsyncException(ErrorType.Management, 0, "Connection closed"));
      } catch (ex) {}
    });

    _requests.clear();
    _resourceRequests.clear();
    _templateRequests.clear();

    for (var x in _attachedResources.values) {
      var r = x.target;
      if (r != null) {
        r.suspend();
        _suspendedResources[r.distributedResourceInstanceId ?? 0] = x;
      }
    }

    if (server != null) {
      _suspendedResources.clear();

      _unsubscribeAll();
      Warehouse.remove(this);

      // @TODO: implement this
      // if (ready)
      //   _server.membership?.Logout(session);

    } else if (autoReconnect && !_invalidCredentials) {
      Future.delayed(Duration(seconds: reconnectInterval), reconnect);
    } else {
      _suspendedResources.clear();
    }

    _attachedResources.clear();
    _ready = false;
  }

  Future<bool> reconnect() async {
    try {
      if (!await connect()) return false;

      try {
        var toBeRestored = <DistributedResource>[];

        _suspendedResources.forEach((key, value) {
          var r = value.target;
          if (r != null) toBeRestored.add(r);
        });

        for (var r in toBeRestored) {
          var link = DC.stringToBytes(r.distributedResourceLink ?? "");

          //print("Restoring " + (r.distributedResourceLink ?? ""));

          try {
            var ar = await (_sendRequest(IIPPacketAction.QueryLink)
                  ..addUint16(link.length)
                  ..addDC(link))
                .done();

            var dataType = ar?[0] as TransmissionType;
            var data = ar?[1] as DC;

            if (dataType.identifier ==
                TransmissionTypeIdentifier.ResourceList) {
              // remove from suspended.
              _suspendedResources.remove(r.distributedResourceInstanceId);

              // parse them as int
              var id = data.getUint32(8);

              // id changed ?
              if (id != r.distributedResourceInstanceId)
                r.distributedResourceInstanceId = id;

              _neededResources[id] = r;

              await fetch(id, null);
            }
          } catch (ex) {
            if (ex is AsyncException &&
                ex.code == ExceptionCode.ResourceNotFound) {
              // skip this resource
            } else {
              break;
            }
          }
        }
      } catch (ex) {
        print(ex);
      }
    } catch (ex) {
      return false;
    }

    emitArgs("resumed", []);

    return true;
  }

  /// <summary>
  /// KeyList to store user variables related to this connection.
  /// </summary>
  final KeyList<String, dynamic> variables = new KeyList<String, dynamic>();

  /// <summary>
  /// IResource interface.
  /// </summary>
  Instance? instance;

  _declare() {
    // if (session.KeyExchanger != null)
    // {
    //     // create key
    //     var key = session.keyExchanger.GetPublicKey();
    //     session.localHeaders[IIPAuthPacketHeader.CipherKey] = key;
    // }

    if (session.localMethod == AuthenticationMethod.Credentials &&
        session.remoteMethod == AuthenticationMethod.None) {
      // change to Map<byte, object> for compatibility
      var headers = Codec.compose(session.localHeaders, this);

      // declare (Credentials -> No Auth, No Enctypt)
      _sendParams()
        ..addUint8(IIPAuthPacketInitialize.CredentialsNoAuth)
        ..addDC(headers)
        ..done();
    } else if (session.localMethod == AuthenticationMethod.Token &&
        session.remoteMethod == AuthenticationMethod.None) {
      // change to Map<byte, object> for compatibility
      var headers = Codec.compose(session.localHeaders, this);

      _sendParams()
        ..addUint8(IIPAuthPacketInitialize.TokenNoAuth)
        ..addDC(headers)
        ..done();
    } else if (session.localMethod == AuthenticationMethod.None &&
        session.remoteMethod == AuthenticationMethod.None) {
      // change to Map<byte, object> for compatibility
      var headers = Codec.compose(session.localHeaders, this);

      // @REVIEW: MITM Attack can still occure
      _sendParams()
        ..addUint8(IIPAuthPacketInitialize.NoAuthNoAuth)
        ..addDC(headers)
        ..done();
    } else {
      throw new Exception("Authentication method is not implemented.");
    }
  }

  /// <summary>
  /// Assign a socket to the connection.
  /// </summary>
  /// <param name="socket">Any socket that implements ISocket.</param>
  assign(ISocket socket) {
    super.assign(socket);

    session.localHeaders[IIPAuthPacketHeader.IPv4] =
        socket.remoteEndPoint?.address;
    if (socket.state == SocketState.Established &&
        session.authenticationType == AuthenticationType.Client) {
      _declare();
    }
  }

  /// <summary>
  /// Create a new distributed connection.
  /// </summary>
  /// <param name="socket">Socket to transfer data through.</param>
  /// <param name="domain">Working domain.</param>
  /// <param name="username">Username.</param>
  /// <param name="password">Password.</param>
/*
  DistributedConnection.connect(
      ISocket socket, String domain, String username, String password) {
    _session =
        new Session(new ClientAuthentication(), new HostAuthentication());

    _session.localAuthentication.method = AuthenticationMethod.Credentials;
    _session.localAuthentication.domain = domain;
    _session.localAuthentication.username = username;

    _localPasswordOrToken = DC.stringToBytes(password);

    init();

    assign(socket);
  }

  DistributedConnection.connectWithToken(
      ISocket socket, String domain, int tokenIndex, String token) {
    _session =
        new Session(new ClientAuthentication(), new HostAuthentication());

    _session.localAuthentication.method = AuthenticationMethod.Token;
    _session.localAuthentication.domain = domain;
    _session.localAuthentication.tokenIndex = tokenIndex;

    _localPasswordOrToken = DC.stringToBytes(token);

    init();

    assign(socket);
  }
*/

  /// <summary>
  /// Create a new instance of a distributed connection
  /// </summary>
  DistributedConnection() {
    session.authenticationType = AuthenticationType.Host;
    session.localMethod = AuthenticationMethod.None;
    init();
  }

  String? link(IResource resource) {
    if (resource is DistributedResource) {
      if (resource.instance?.store == this)
        return (this.instance?.name ?? "") +
            "/" +
            resource.distributedResourceInstanceId.toString();
    }

    return null;
  }

  void init() {
    _queue.then((x) {
      if (x?.type == DistributedResourceQueueItemType.Event)
        x?.resource.internal_emitEventByIndex(x.index, x.value);
      else
        x?.resource.internal_updatePropertyByIndex(x.index, x.value);
    });

    var r = new Random();
    var n = new DC(32);
    for (var i = 0; i < 32; i++) n[i] = r.nextInt(255);

    session.localHeaders[IIPAuthPacketHeader.Nonce] = n;

    // removed because dart timers start at initialization
    //  _keepAliveTimer =
    //      Timer(Duration(seconds: keepAliveInterval), _keepAliveTimerElapsed);
  }

  void _keepAliveTimerElapsed() {
    if (!isConnected) return;

    _keepAliveTimer?.cancel();

    var now = DateTime.now().toUtc();

    int interval = _lastKeepAliveSent == null
        ? 0
        : (now.difference(_lastKeepAliveSent!).inMilliseconds);

    _lastKeepAliveSent = now;

    //print("keep alive sent");

    (_sendRequest(IIPPacketAction.KeepAlive)
          ..addDateTime(now)
          ..addUint32(interval))
        .done()
      ..then((x) {
        jitter = x?[1];

        _keepAliveTimer =
            Timer(Duration(seconds: keepAliveInterval), _keepAliveTimerElapsed);

        //print("Keep Alive Received ${jitter}");

        // Run GC
        var toBeRemoved = [];
        _attachedResources.forEach((key, value) {
          var r = value.target;
          if (r == null) toBeRemoved.add(key);
        });

        if (toBeRemoved.length > 0)
          print("GC " + toBeRemoved.length.toString());

        toBeRemoved.forEach((id) {
          sendDetachRequest(id);
          _attachedResources.remove(id);
        });
      })
      ..error((ex) {
        _keepAliveTimer?.cancel();
        close();
      })
      ..timeout(Duration(seconds: keepAliveTime));
  }

  int processPacket(
      DC msg, int offset, int ends, NetworkBuffer data, int chunkId) {
    if (_ready) {
      var rt = _packet.parse(msg, offset, ends);

      if (rt <= 0) {
        var size = ends - offset;
        data.holdFor(msg, offset, size, size - rt);
        return ends;
      } else {
        offset += rt;

        if (_packet.command == IIPPacketCommand.Event) {
          switch (_packet.event) {
            case IIPPacketEvent.ResourceReassigned:
              iipEventResourceReassigned(
                  _packet.resourceId, _packet.newResourceId);
              break;
            case IIPPacketEvent.ResourceDestroyed:
              iipEventResourceDestroyed(_packet.resourceId);
              break;
            case IIPPacketEvent.PropertyUpdated:
              iipEventPropertyUpdated(_packet.resourceId, _packet.methodIndex,
                  _packet.dataType ?? TransmissionType.Null, msg);
              break;
            case IIPPacketEvent.EventOccurred:
              iipEventEventOccurred(_packet.resourceId, _packet.methodIndex,
                  _packet.dataType ?? TransmissionType.Null, msg);
              break;

            case IIPPacketEvent.ChildAdded:
              iipEventChildAdded(_packet.resourceId, _packet.childId);
              break;
            case IIPPacketEvent.ChildRemoved:
              iipEventChildRemoved(_packet.resourceId, _packet.childId);
              break;
            case IIPPacketEvent.Renamed:
              iipEventRenamed(_packet.resourceId, _packet.resourceName);
              break;
            case IIPPacketEvent.AttributesUpdated:
              // @TODO: fix this
              //iipEventAttributesUpdated(packet.resourceId, packet.dataType. ?? TransmissionType.Null);
              break;
          }
        } else if (_packet.command == IIPPacketCommand.Request) {
          switch (_packet.action) {
            // Manage
            case IIPPacketAction.AttachResource:
              iipRequestAttachResource(_packet.callbackId, _packet.resourceId);
              break;
            case IIPPacketAction.ReattachResource:
              iipRequestReattachResource(
                  _packet.callbackId, _packet.resourceId, _packet.resourceAge);
              break;
            case IIPPacketAction.DetachResource:
              iipRequestDetachResource(_packet.callbackId, _packet.resourceId);
              break;
            case IIPPacketAction.CreateResource:

              // @TODO: Fix this
              //iipRequestCreateResource(packet.callbackId, packet.storeId,
              //  packet.resourceId, packet.content);
              break;
            case IIPPacketAction.DeleteResource:
              iipRequestDeleteResource(_packet.callbackId, _packet.resourceId);
              break;
            case IIPPacketAction.AddChild:
              iipRequestAddChild(
                  _packet.callbackId, _packet.resourceId, _packet.childId);
              break;
            case IIPPacketAction.RemoveChild:
              iipRequestRemoveChild(
                  _packet.callbackId, _packet.resourceId, _packet.childId);
              break;
            case IIPPacketAction.RenameResource:
              iipRequestRenameResource(
                  _packet.callbackId, _packet.resourceId, _packet.resourceName);
              break;

            // Inquire
            case IIPPacketAction.TemplateFromClassName:
              iipRequestTemplateFromClassName(
                  _packet.callbackId, _packet.className);
              break;
            case IIPPacketAction.TemplateFromClassId:
              iipRequestTemplateFromClassId(
                  _packet.callbackId, _packet.classId);
              break;
            case IIPPacketAction.TemplateFromResourceId:
              iipRequestTemplateFromResourceId(
                  _packet.callbackId, _packet.resourceId);
              break;
            case IIPPacketAction.QueryLink:
              iipRequestQueryResources(
                  _packet.callbackId, _packet.resourceLink);
              break;

            case IIPPacketAction.ResourceChildren:
              iipRequestResourceChildren(
                  _packet.callbackId, _packet.resourceId);
              break;
            case IIPPacketAction.ResourceParents:
              iipRequestResourceParents(_packet.callbackId, _packet.resourceId);
              break;

            case IIPPacketAction.ResourceHistory:
              iipRequestInquireResourceHistory(_packet.callbackId,
                  _packet.resourceId, _packet.fromDate, _packet.toDate);
              break;

            case IIPPacketAction.LinkTemplates:
              iipRequestLinkTemplates(_packet.callbackId, _packet.resourceLink);
              break;

            // Invoke
            case IIPPacketAction.InvokeFunction:
              iipRequestInvokeFunction(
                  _packet.callbackId,
                  _packet.resourceId,
                  _packet.methodIndex,
                  _packet.dataType ?? TransmissionType.Null,
                  msg);
              break;

            case IIPPacketAction.Listen:
              iipRequestListen(
                  _packet.callbackId, _packet.resourceId, _packet.methodIndex);
              break;
            case IIPPacketAction.Unlisten:
              iipRequestUnlisten(
                  _packet.callbackId, _packet.resourceId, _packet.methodIndex);
              break;
/*
                        case IIPPacketAction.GetProperty:
                            iipRequestGetProperty(packet.callbackId, packet.resourceId, packet.methodIndex);
                            break;
                        case IIPPacketAction.GetPropertyIfModified:
                            iipRequestGetPropertyIfModifiedSince(packet.callbackId, packet.resourceId, 
                                                                  packet.methodIndex, packet.resourceAge);
                            break;
*/
            case IIPPacketAction.SetProperty:
              iipRequestSetProperty(
                  _packet.callbackId,
                  _packet.resourceId,
                  _packet.methodIndex,
                  _packet.dataType ?? TransmissionType.Null,
                  msg);
              break;

            // Attribute
            case IIPPacketAction.GetAllAttributes:
              // @TODO: fix this
              //iipRequestGetAttributes(
              //  packet.callbackId, packet.resourceId, packet.content, true);
              break;
            case IIPPacketAction.UpdateAllAttributes:
              //iipRequestUpdateAttributes(
              //  packet.callbackId, packet.resourceId, packet.content, true);
              break;
            case IIPPacketAction.ClearAllAttributes:
              //iipRequestClearAttributes(
              //  packet.callbackId, packet.resourceId, packet.content, true);
              break;
            case IIPPacketAction.GetAttributes:
              //iipRequestGetAttributes(
              //  packet.callbackId, packet.resourceId, packet.content, false);
              break;
            case IIPPacketAction.UpdateAttributes:
              //iipRequestUpdateAttributes(
              //    packet.callbackId, packet.resourceId, packet.content, false);
              break;
            case IIPPacketAction.ClearAttributes:
              //iipRequestClearAttributes(
              //    packet.callbackId, packet.resourceId, packet.content, false);
              break;

            case IIPPacketAction.KeepAlive:
              iipRequestKeepAlive(
                  _packet.callbackId, _packet.currentTime, _packet.interval);
              break;

            case IIPPacketAction.ProcedureCall:
              iipRequestProcedureCall(_packet.callbackId, _packet.procedure,
                  _packet.dataType as TransmissionType, msg);
              break;

            case IIPPacketAction.StaticCall:
              iipRequestStaticCall(
                  _packet.callbackId,
                  _packet.classId,
                  _packet.methodIndex,
                  _packet.dataType as TransmissionType,
                  msg);
              break;
          }
        } else if (_packet.command == IIPPacketCommand.Reply) {
          switch (_packet.action) {
            // Manage
            case IIPPacketAction.AttachResource:
              iipReply(_packet.callbackId, [
                _packet.classId,
                _packet.resourceAge,
                _packet.resourceLink,
                _packet.dataType ?? TransmissionType.Null,
                msg
              ]);
              break;

            case IIPPacketAction.ReattachResource:
              iipReply(_packet.callbackId, [
                _packet.resourceAge,
                _packet.dataType ?? TransmissionType.Null,
                msg
              ]);

              break;
            case IIPPacketAction.DetachResource:
              iipReply(_packet.callbackId);
              break;

            case IIPPacketAction.CreateResource:
              iipReply(_packet.callbackId, [_packet.resourceId]);
              break;

            case IIPPacketAction.DeleteResource:
            case IIPPacketAction.AddChild:
            case IIPPacketAction.RemoveChild:
            case IIPPacketAction.RenameResource:
              iipReply(_packet.callbackId);
              break;

            // Inquire

            case IIPPacketAction.TemplateFromClassName:
            case IIPPacketAction.TemplateFromClassId:
            case IIPPacketAction.TemplateFromResourceId:
              if (_packet.dataType != null) {
                var content = msg.clip(_packet.dataType?.offset ?? 0,
                    _packet.dataType?.contentLength ?? 0);
                iipReply(_packet.callbackId, [TypeTemplate.parse(content)]);
              } else {
                iipReportError(_packet.callbackId, ErrorType.Management,
                    ExceptionCode.TemplateNotFound.index, "Template not found");
              }

              break;

            case IIPPacketAction.QueryLink:
            case IIPPacketAction.ResourceChildren:
            case IIPPacketAction.ResourceParents:
            case IIPPacketAction.ResourceHistory:
            case IIPPacketAction.LinkTemplates:
              iipReply(_packet.callbackId,
                  [_packet.dataType ?? TransmissionType.Null, msg]);
              break;

            // Invoke
            case IIPPacketAction.InvokeFunction:
            case IIPPacketAction.StaticCall:
            case IIPPacketAction.ProcedureCall:
              iipReplyInvoke(_packet.callbackId,
                  _packet.dataType ?? TransmissionType.Null, msg);
              break;

            // case IIPPacketAction.GetProperty:
            //   iipReply(packet.callbackId, [packet.content]);
            //   break;

            // case IIPPacketAction.GetPropertyIfModified:
            //   iipReply(packet.callbackId, [packet.content]);
            //   break;

            case IIPPacketAction.Listen:
            case IIPPacketAction.Unlisten:
            case IIPPacketAction.SetProperty:
              iipReply(_packet.callbackId);
              break;

            // Attribute
            case IIPPacketAction.GetAllAttributes:
            case IIPPacketAction.GetAttributes:
              iipReply(_packet.callbackId,
                  [_packet.dataType ?? TransmissionType.Null, msg]);
              break;

            case IIPPacketAction.UpdateAllAttributes:
            case IIPPacketAction.UpdateAttributes:
            case IIPPacketAction.ClearAllAttributes:
            case IIPPacketAction.ClearAttributes:
              iipReply(_packet.callbackId);
              break;

            case IIPPacketAction.KeepAlive:
              iipReply(
                  _packet.callbackId, [_packet.currentTime, _packet.jitter]);
              break;
          }
        } else if (_packet.command == IIPPacketCommand.Report) {
          switch (_packet.report) {
            case IIPPacketReport.ManagementError:
              iipReportError(_packet.callbackId, ErrorType.Management,
                  _packet.errorCode, null);
              break;
            case IIPPacketReport.ExecutionError:
              iipReportError(_packet.callbackId, ErrorType.Exception,
                  _packet.errorCode, _packet.errorMessage);
              break;
            case IIPPacketReport.ProgressReport:
              iipReportProgress(_packet.callbackId, ProgressType.Execution,
                  _packet.progressValue, _packet.progressMax);
              break;
            case IIPPacketReport.ChunkStream:
              iipReportChunk(_packet.callbackId,
                  _packet.dataType ?? TransmissionType.Null, msg);
              break;
          }
        }
      }
    } else {
      var rt = _authPacket.parse(msg, offset, ends);

      if (rt <= 0) {
        data.holdForNeeded(msg, ends - rt);
        return ends;
      } else {
        offset += rt;

        if (session.authenticationType == AuthenticationType.Host) {
          _processHostAuth(msg);
        } else if (session.authenticationType == AuthenticationType.Client) {
          _processClientAuth(msg);
        }
      }
    }

    return offset;

    //if (offset < ends)
    //  processPacket(msg, offset, ends, data, chunkId);
  }

  void _processClientAuth(DC data) {
    if (_authPacket.command == IIPAuthPacketCommand.Acknowledge) {
      // if there is a mismatch in authentication
      if (session.localMethod != _authPacket.remoteMethod ||
          session.remoteMethod != _authPacket.localMethod) {
        _openReply?.triggerError(
            new Exception("Peer refused authentication method."));
        _openReply = null;
      }

      // Parse remote headers

      var dataType = _authPacket.dataType!;

      var pr = Codec.parse(data, dataType.offset, this, null, dataType);

      var rt = pr.reply.result as Map<UInt8, dynamic>;

      session.remoteHeaders = rt;

      if (session.localMethod == AuthenticationMethod.None) {
        // send establish
        _sendParams()
          ..addUint8(IIPAuthPacketAction.EstablishNewSession)
          ..done();
      } else if (session.localMethod == AuthenticationMethod.Credentials ||
          session.localMethod == AuthenticationMethod.Token) {
        var remoteNonce = session.remoteHeaders[IIPAuthPacketHeader.Nonce];
        var localNonce = session.localHeaders[IIPAuthPacketHeader.Nonce];

        // send our hash
        // local nonce + password or token + remote nonce
        var challenge = SHA256.compute((new BinaryList()
              ..addDC(localNonce)
              ..addDC(_localPasswordOrToken!)
              ..addDC(remoteNonce))
            .toDC());

        _sendParams()
          ..addUint8(IIPAuthPacketAction.AuthenticateHash)
          ..addUint8(IIPAuthPacketHashAlgorithm.SHA256)
          ..addUint16(challenge.length)
          ..addDC(challenge)
          ..done();
      }
    } else if (_authPacket.command == IIPAuthPacketCommand.Action) {
      if (_authPacket.action == IIPAuthPacketAction.AuthenticateHash) {
        var remoteNonce = session.remoteHeaders[IIPAuthPacketHeader.Nonce];
        var localNonce = session.localHeaders[IIPAuthPacketHeader.Nonce];

        // check if the server knows my password

        var challenge = SHA256.compute((new BinaryList()
              ..addDC(remoteNonce)
              ..addDC(_localPasswordOrToken!)
              ..addDC(localNonce))
            .toDC());

        if (challenge.sequenceEqual(_authPacket.challenge)) {
          // send establish request
          _sendParams()
            ..addUint8(IIPAuthPacketAction.EstablishNewSession)
            ..done();
        } else {
          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.ChallengeFailed.index)
            ..addUint16(16)
            ..addString("Challenge Failed")
            ..done();
        }
      }
    } else if (_authPacket.command == IIPAuthPacketCommand.Event) {
      if (_authPacket.event == IIPAuthPacketEvent.ErrorTerminate ||
          _authPacket.event == IIPAuthPacketEvent.ErrorMustEncrypt ||
          _authPacket.event == IIPAuthPacketEvent.ErrorRetry) {
        _invalidCredentials = true;
        _openReply?.triggerError(new AsyncException(
            ErrorType.Management, _authPacket.errorCode, _authPacket.message));
        _openReply = null;

        var ex = AsyncException(
            ErrorType.Management, _authPacket.errorCode, _authPacket.message);

        emitArgs("error", [ex]);

        close();
      } else if (_authPacket.event ==
          IIPAuthPacketEvent.IndicationEstablished) {
        session.id = _authPacket.sessionId;
        session.authorizedAccount =
            _authPacket.accountId!.getString(0, _authPacket.accountId!.length);

        _ready = true;
        _status = ConnectionStatus.Connected;

        // put it in the warehouse

        if (this.instance == null) {
          Warehouse.put(session.authorizedAccount!.replaceAll("/", "_"), this,
                  null, server)
              .then((x) {
            _openReply?.trigger(true);

            emitArgs("ready", []);
            _openReply = null;
          }).error((x) {
            _openReply?.triggerError(x);
            _openReply = null;
          });
        } else {
          _openReply?.trigger(true);
          _openReply = null;
          emitArgs("ready", []);
        }

        // start perodic keep alive timer
        _keepAliveTimer =
            Timer(Duration(seconds: keepAliveInterval), _keepAliveTimerElapsed);
      } else if (_authPacket.event == IIPAuthPacketEvent.IAuthPlain) {
        var dataType = _authPacket.dataType!;
        var pr = Codec.parse(data, dataType.offset, this, null, dataType);
        var rt = pr.reply.result;

        Map<UInt8, dynamic> headers = rt;
        var iAuthRequest = new AuthorizationRequest(headers);

        if (authenticator == null) {
          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.NotSupported.index)
            ..addUint16(13)
            ..addString("Not supported")
            ..done();
        } else {
          authenticator!(iAuthRequest).then((response) {
            _sendParams()
              ..addUint8(IIPAuthPacketAction.IAuthPlain)
              ..addUint32(headers[IIPAuthPacketIAuthHeader.Reference])
              ..addDC(Codec.compose(response, this))
              ..done();
          }).timeout(Duration(seconds: iAuthRequest.timeout), onTimeout: () {
            _sendParams()
              ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
              ..addUint8(ExceptionCode.Timeout.index)
              ..addUint16(7)
              ..addString("Timeout")
              ..done();
          });
        }
      } else if (_authPacket.event == IIPAuthPacketEvent.IAuthHashed) {
        var dataType = _authPacket.dataType!;
        var parsed = Codec.parse(data, dataType.offset, this, null, dataType);
        Map<UInt8, dynamic> headers = parsed.reply.result;
        var iAuthRequest = new AuthorizationRequest(headers);

        if (authenticator == null) {
          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.NotSupported.index)
            ..addUint16(13)
            ..addString("Not supported")
            ..done();
        } else {
          authenticator!(iAuthRequest).then((response) {
            var hash = SHA256.compute((new BinaryList()
                  ..addDC(session.localHeaders[IIPAuthPacketHeader.Nonce])
                  ..addDC(Codec.compose(response, this))
                  ..addDC(session.remoteHeaders[IIPAuthPacketHeader.Nonce]))
                .toDC());

            _sendParams()
              ..addUint8(IIPAuthPacketAction.IAuthHashed)
              ..addUint32(headers[IIPAuthPacketIAuthHeader.Reference])
              ..addUint8(IIPAuthPacketHashAlgorithm.SHA256)
              ..addUint16(hash.length)
              ..addDC(hash)
              ..done();
          }).timeout(Duration(seconds: iAuthRequest.timeout), onTimeout: () {
            _sendParams()
              ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
              ..addUint8(ExceptionCode.Timeout.index)
              ..addUint16(7)
              ..addString("Timeout")
              ..done();
          });
        }
      } else if (_authPacket.event == IIPAuthPacketEvent.IAuthEncrypted) {
        throw new Exception("IAuthEncrypted not implemented.");
      }
    }
  }

  void _processHostAuth(DC data) {
    if (_authPacket.command == IIPAuthPacketCommand.Initialize) {
      // Parse headers

      var dataType = _authPacket.dataType!;

      var parsed = Codec.parse(data, dataType.offset, this, null, dataType);

      Map<UInt8, dynamic> rt = parsed.reply.result;

      session.remoteHeaders = rt;
      session.remoteMethod = _authPacket.localMethod;

      if (_authPacket.initialization ==
          IIPAuthPacketInitialize.CredentialsNoAuth) {
        try {
          var username = session.remoteHeaders[IIPAuthPacketHeader.Username];
          var domain = session.remoteHeaders[IIPAuthPacketHeader.Domain];

          if (_server?.membership == null) {
            var errMsg = DC.stringToBytes("Membership not set.");

            _sendParams()
              ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
              ..addUint8(ExceptionCode.GeneralFailure.index)
              ..addUint16(errMsg.length)
              ..addDC(errMsg)
              ..done();
          } else {
            _server!.membership!.userExists(username, domain).then((x) {
              if (x != null) {
                session.authorizedAccount = x;

                var localHeaders = session.localHeaders;

                _sendParams()
                  ..addUint8(IIPAuthPacketAcknowledge.NoAuthCredentials)
                  ..addDC(Codec.compose(localHeaders, this))
                  ..done();
              } else {
                // Send user not found error
                _sendParams()
                  ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
                  ..addUint8(ExceptionCode.UserOrTokenNotFound.index)
                  ..addUint16(14)
                  ..addString("User not found")
                  ..done();
              }
            });
          }
        } catch (ex) {
          // Send the server side error
          var errMsg = DC.stringToBytes(ex.toString());

          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.GeneralFailure.index)
            ..addUint16(errMsg.length)
            ..addDC(errMsg)
            ..done();
        }
      } else if (_authPacket.initialization ==
          IIPAuthPacketInitialize.TokenNoAuth) {
        try {
          if (_server?.membership == null) {
            _sendParams()
              ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
              ..addUint8(ExceptionCode.UserOrTokenNotFound.index)
              ..addUint16(15)
              ..addString("Token not found")
              ..done();
          }
          // Check if user and token exists
          else {
            int tokenIndex =
                session.remoteHeaders[IIPAuthPacketHeader.TokenIndex];
            String domain = session.remoteHeaders[IIPAuthPacketHeader.Domain];

            _server!.membership!.tokenExists(tokenIndex, domain).then((x) {
              if (x != null) {
                session.authorizedAccount = x;

                var localHeaders = session.localHeaders;

                _sendParams()
                  ..addUint8(IIPAuthPacketAcknowledge.NoAuthToken)
                  ..addDC(Codec.compose(localHeaders, this))
                  ..done();
              } else {
                // Send token not found error.
                _sendParams()
                  ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
                  ..addUint8(ExceptionCode.UserOrTokenNotFound.index)
                  ..addUint16(15)
                  ..addString("Token not found")
                  ..done();
              }
            });
          }
        } catch (ex) {
          // Sender server side error.

          var errMsg = DC.stringToBytes(ex.toString());

          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.GeneralFailure.index)
            ..addUint16(errMsg.length)
            ..addDC(errMsg)
            ..done();
        }
      } else if (_authPacket.initialization ==
          IIPAuthPacketInitialize.NoAuthNoAuth) {
        try {
          // Check if guests are allowed
          if (_server?.membership?.guestsAllowed ?? true) {
            var localHeaders = session.localHeaders;

            session.authorizedAccount = "g-" + Global.generateCode();

            _readyToEstablish = true;

            _sendParams()
              ..addUint8(IIPAuthPacketAcknowledge.NoAuthNoAuth)
              ..addDC(Codec.compose(localHeaders, this))
              ..done();
          } else {
            // Send access denied error because the server does not allow guests.
            _sendParams()
              ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
              ..addUint8(ExceptionCode.AccessDenied.index)
              ..addUint16(18)
              ..addString("Guests not allowed")
              ..done();
          }
        } catch (ex) {
          // Send the server side error.
          var errMsg = DC.stringToBytes(ex.toString());

          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.GeneralFailure.index)
            ..addUint16(errMsg.length)
            ..addDC(errMsg)
            ..done();
        }
      }
    } else if (_authPacket.command == IIPAuthPacketCommand.Action) {
      if (_authPacket.action == IIPAuthPacketAction.AuthenticateHash) {
        var remoteHash = _authPacket.challenge;
        AsyncReply<DC?> reply;

        try {
          if (session.remoteMethod == AuthenticationMethod.Credentials) {
            reply = server!.membership!.getPassword(
                session.remoteHeaders[IIPAuthPacketHeader.Username],
                session.remoteHeaders[IIPAuthPacketHeader.Domain]);
          } else if (session.remoteMethod == AuthenticationMethod.Token) {
            reply = _server!.membership!.getToken(
                session.remoteHeaders[IIPAuthPacketHeader.TokenIndex],
                session.remoteHeaders[IIPAuthPacketHeader.Domain]);
          } else {
            // Error
            throw Exception("Unsupported authentication method");
          }

          reply.then((pw) {
            if (pw != null) {
              var localNonce = session.localHeaders[IIPAuthPacketHeader.Nonce];
              var remoteNonce =
                  session.remoteHeaders[IIPAuthPacketHeader.Nonce];

              var hash = SHA256.compute((new BinaryList()
                    ..addDC(remoteNonce)
                    ..addDC(pw)
                    ..addDC(localNonce))
                  .toDC());

              if (hash.sequenceEqual(remoteHash)) {
                // send our hash
                var localHash = SHA256.compute((new BinaryList()
                      ..addDC(localNonce)
                      ..addDC(pw)
                      ..addDC(remoteNonce))
                    .toDC());

                _sendParams()
                  ..addUint8(IIPAuthPacketAction.AuthenticateHash)
                  ..addUint8(IIPAuthPacketHashAlgorithm.SHA256)
                  ..addUint16(localHash.length)
                  ..addDC(localHash)
                  ..done();

                _readyToEstablish = true;
              } else {
                _sendParams()
                  ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
                  ..addUint8(ExceptionCode.AccessDenied.index)
                  ..addUint16(13)
                  ..addString("Access Denied")
                  ..done();
              }
            }
          });
        } catch (ex) {
          var errMsg = DC.stringToBytes(ex.toString());

          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.GeneralFailure.index)
            ..addUint16(errMsg.length)
            ..addDC(errMsg)
            ..done();
        }
      } else if (_authPacket.action == IIPAuthPacketAction.IAuthPlain) {
        var reference = _authPacket.reference;
        var dataType = _authPacket.dataType!;

        var parsed = Codec.parse(data, dataType.offset, this, null, dataType);

        var value = parsed.reply.result;

        _server?.membership
            ?.authorizePlain(session, reference, value)
            .then((x) => _processAuthorization(x));
      } else if (_authPacket.action == IIPAuthPacketAction.IAuthHashed) {
        var reference = _authPacket.reference;
        var value = _authPacket.challenge!;
        var algorithm = _authPacket.hashAlgorithm;

        _server?.membership
            ?.authorizeHashed(session, reference, algorithm, value)
            .then((x) => _processAuthorization(x));
      } else if (_authPacket.action == IIPAuthPacketAction.IAuthEncrypted) {
        var reference = _authPacket.reference;
        var value = _authPacket.challenge!;
        var algorithm = _authPacket.publicKeyAlgorithm;

        _server?.membership
            ?.authorizeEncrypted(session, reference, algorithm, value)
            .then((x) => _processAuthorization(x));
      } else if (_authPacket.action ==
          IIPAuthPacketAction.EstablishNewSession) {
        if (_readyToEstablish) {
          if (_server?.membership == null) {
            _processAuthorization(null);
          } else {
            server?.membership?.authorize(session).then((x) {
              _processAuthorization(x);
            });
          }
        } else {
          _sendParams()
            ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
            ..addUint8(ExceptionCode.GeneralFailure.index)
            ..addUint16(9)
            ..addString("Not ready")
            ..done();
        }
      }
    }
  }

  _processAuthorization(AuthorizationResults? results) {
    if (results == null ||
        results.response == AuthorizationResultsResponse.Success) {
      var r = new Random();
      var n = new DC(32);
      for (var i = 0; i < 32; i++) n[i] = r.nextInt(255);

      session.id = n;

      var accountId = DC.stringToBytes(session.authorizedAccount!);

      _sendParams()
        ..addUint8(IIPAuthPacketEvent.IndicationEstablished)
        ..addUint8(n.length)
        ..addDC(n)
        ..addUint8(accountId.length)
        ..addDC(accountId)
        ..done();

      if (this.instance == null) {
        Warehouse.put(this.hashCode.toString().replaceAll("/", "_"), this, null,
                _server)
            .then((x) {
          _ready = true;
          _status = ConnectionStatus.Connected;
          _openReply?.trigger(true);
          _openReply = null;
          emitArgs("ready", []);

          _server?.membership?.login(session);
          _loginDate = DateTime.now();
        }).error((x) {
          _openReply?.triggerError(x);
          _openReply = null;
        });
      } else {
        _ready = true;
        _status = ConnectionStatus.Connected;

        _openReply?.trigger(true);
        _openReply = null;

        emitArgs("ready", []);

        server?.membership?.login(session);
      }
    } else if (results.response == AuthorizationResultsResponse.Failed) {
      _sendParams()
        ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
        ..addUint8(ExceptionCode.ChallengeFailed.index)
        ..addUint16(21)
        ..addString("Authentication failed")
        ..done();
    } else if (results.response == AuthorizationResultsResponse.Expired) {
      _sendParams()
        ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
        ..addUint8(ExceptionCode.Timeout.index)
        ..addUint16(22)
        ..addString("Authentication expired")
        ..done();
    } else if (results.response ==
        AuthorizationResultsResponse.ServiceUnavailable) {
      _sendParams()
        ..addUint8(IIPAuthPacketEvent.ErrorTerminate)
        ..addUint8(ExceptionCode.GeneralFailure.index)
        ..addUint16(19)
        ..addString("Service unavailable")
        ..done();
    } else if (results.response == AuthorizationResultsResponse.IAuthPlain) {
      var args = <UInt8, dynamic>{
        IIPAuthPacketIAuthHeader.Reference: results.reference,
        IIPAuthPacketIAuthHeader.Destination: results.destination,
        IIPAuthPacketIAuthHeader.Expire: results.timeout,
        IIPAuthPacketIAuthHeader.Clue: results.clue,
        IIPAuthPacketIAuthHeader.RequiredFormat: results.requiredFormat,
      };

      _sendParams()
        ..addUint8(IIPAuthPacketEvent.IAuthPlain)
        ..addDC(Codec.compose(args, this))
        ..done();
    } else if (results.response == AuthorizationResultsResponse.IAuthHashed) {
      var args = <UInt8, dynamic>{
        IIPAuthPacketIAuthHeader.Reference: results.reference,
        IIPAuthPacketIAuthHeader.Destination: results.destination,
        IIPAuthPacketIAuthHeader.Expire: results.timeout,
        IIPAuthPacketIAuthHeader.Clue: results.clue,
        IIPAuthPacketIAuthHeader.RequiredFormat: results.requiredFormat,
      };

      _sendParams()
        ..addUint8(IIPAuthPacketEvent.IAuthHashed)
        ..addDC(Codec.compose(args, this))
        ..done();
    } else if (results.response ==
        AuthorizationResultsResponse.IAuthEncrypted) {
      var args = <UInt8, dynamic>{
        IIPAuthPacketIAuthHeader.Destination: results.destination,
        IIPAuthPacketIAuthHeader.Expire: results.timeout,
        IIPAuthPacketIAuthHeader.Clue: results.clue,
        IIPAuthPacketIAuthHeader.RequiredFormat: results.requiredFormat,
      };

      _sendParams()
        ..addUint8(IIPAuthPacketEvent.IAuthEncrypted)
        ..addDC(Codec.compose(args, this))
        ..done();
    }
  }

  @override
  void dataReceived(NetworkBuffer data) {
    // print("dataReceived");
    var msg = data.read();
    int offset = 0;

    if (msg != null) {
      int ends = msg.length;

      //List<String> packs = [];

      var chunkId = (new Random()).nextInt(1000000);

      while (offset < ends) {
        offset = processPacket(msg, offset, ends, data, chunkId);
      }
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
  AsyncReply<bool> put(IResource resource) {
    if (Codec.isLocalResource(resource, this))
      _neededResources.add(
          (resource as DistributedResource).distributedResourceInstanceId
              as int,
          resource);
    // else .. put it in the server....
    return AsyncReply.ready(true);
  }

  bool record(IResource resource, String propertyName, value, int? age,
      DateTime? dateTime) {
    // nothing to do
    return true;
  }

  bool modify(IResource resource, String propertyName, value, int? age,
      DateTime? dateTime) {
    // nothing to do
    return true;
  }

  /// <summary>
  /// Send IIP request.
  /// </summary>
  /// <param name="action">Packet action.</param>
  /// <param name="args">Arguments to send.</param>
  /// <returns></returns>
  SendList _sendRequest(int action) {
    var reply = new AsyncReply<List<dynamic>?>();
    var c = _callbackCounter++; // avoid thread racing
    _requests.add(c, reply);

    return (_sendParams(reply)
      ..addUint8(0x40 | action)
      ..addUint32(c));
  }

  //int _maxcallerid = 0;

  SendList _sendReply(int action, int callbackId) {
    return (_sendParams()
      ..addUint8((0x80 | action))
      ..addUint32(callbackId));
  }

  SendList sendEvent(int evt) {
    return (_sendParams()..addUint8((evt)));
  }

  AsyncReply<dynamic> sendListenRequest(int instanceId, int index) {
    var reply = new AsyncReply<dynamic>();
    var c = _callbackCounter++;
    _requests.add(c, reply);

    _sendParams()
      ..addUint8(0x40 | IIPPacketAction.Listen)
      ..addUint32(c)
      ..addUint32(instanceId)
      ..addUint8(index)
      ..done();
    return reply;
  }

  AsyncReply<dynamic> sendUnlistenRequest(int instanceId, int index) {
    var reply = new AsyncReply<dynamic>();
    var c = _callbackCounter++;
    _requests.add(c, reply);

    _sendParams()
      ..addUint8(0x40 | IIPPacketAction.Unlisten)
      ..addUint32(c)
      ..addUint32(instanceId)
      ..addUint8(index)
      ..done();
    return reply;
  }

  AsyncReply<dynamic> sendInvoke(
      int instanceId, int index, Map<UInt8, dynamic> parameters) {
    var pb = Codec.compose(parameters, this);

    var reply = new AsyncReply<dynamic>();
    var c = _callbackCounter++;
    _requests.add(c, reply);

    _sendParams()
      ..addUint8(0x40 | IIPPacketAction.InvokeFunction)
      ..addUint32(c)
      ..addUint32(instanceId)
      ..addUint8(index)
      ..addDC(pb)
      ..done();
    return reply;
  }

  AsyncReply<List<dynamic>?> sendSetProperty(int instanceId, int index, value) {
    var cv = Codec.compose(value, this);

    return (_sendRequest(IIPPacketAction.SetProperty)
          ..addUint32(instanceId)
          ..addUint8(index)
          ..addDC(cv))
        .done();
  }

  AsyncReply<dynamic>? sendDetachRequest(int instanceId) {
    try {
      var sendDetach = false;

      if (_attachedResources.containsKey(instanceId)){
        _attachedResources.remove(instanceId);
        sendDetach = true;
      }

      if (_suspendedResources.containsKey(instanceId)){
        _suspendedResources.remove(instanceId);
        sendDetach = true;
      }

      if (sendDetach)
        return (_sendRequest(IIPPacketAction.DetachResource)
              ..addUint32(instanceId))
            .done();

      return null;

    } catch (ex) {
      return null;
    }
  }

  void _sendError(ErrorType type, int callbackId, int errorCode,
      [String? errorMessage]) {
    var msg = DC.stringToBytes(errorMessage ?? "");
    if (type == ErrorType.Management)
      _sendParams()
        ..addUint8(0xC0 | IIPPacketReport.ManagementError)
        ..addUint32(callbackId)
        ..addUint16(errorCode)
        ..done();
    else if (type == ErrorType.Exception)
      _sendParams()
        ..addUint8(0xC0 | IIPPacketReport.ExecutionError)
        ..addUint32(callbackId)
        ..addUint16(errorCode)
        ..addUint16(msg.length)
        ..addDC(msg)
        ..done();
  }

  void sendProgress(int callbackId, int value, int max) {
    _sendParams()
      ..addUint8(0xC0 | IIPPacketReport.ProgressReport)
      ..addUint32(callbackId)
      ..addInt32(value)
      ..addInt32(max)
      ..done();
    //SendParams(, callbackId, value, max);
  }

  void sendChunk(int callbackId, dynamic chunk) {
    var c = Codec.compose(chunk, this);
    _sendParams()
      ..addUint8(0xC0 | IIPPacketReport.ChunkStream)
      ..addUint32(callbackId)
      ..addDC(c)
      ..done();
  }

  void iipReply(int callbackId, [List<dynamic>? results = null]) {
    var req = _requests.take(callbackId);
    req?.trigger(results);
  }

  // @TODO: check for deadlocks
  void iipReplyInvoke(int callbackId, TransmissionType dataType, DC data) {
    var req = _requests.take(callbackId);

    Codec.parse(data, 0, this, null, dataType).reply.then((rt) {
      req?.trigger(rt);
    });
  }

  void iipReportError(int callbackId, ErrorType errorType, int errorCode,
      String? errorMessage) {
    var req = _requests.take(callbackId);
    req?.triggerError(new AsyncException(errorType, errorCode, errorMessage));
  }

  void iipReportProgress(
      int callbackId, ProgressType type, int value, int max) {
    var req = _requests[callbackId];
    req?.triggerProgress(type, value, max);
  }

  // @TODO: Check for deadlocks
  void iipReportChunk(int callbackId, TransmissionType dataType, DC data) {
    if (_requests.containsKey(callbackId)) {
      var req = _requests[callbackId];
      Codec.parse(data, 0, this, null, dataType).reply.then((x) {
        req?.triggerChunk(x);
      });
    }
  }

  void iipEventResourceReassigned(int resourceId, int newResourceId) {

  }

  void iipEventResourceDestroyed(int resourceId) {
    var r = _attachedResources[resourceId]?.target;

    // remove from attached to avoid sending unnecessary deattach request when Destroy() is called
    _attachedResources.remove(resourceId);

    if (r != null) {
      r.destroy();
      return;
    } else if (_neededResources.contains(resourceId)) {
      // @TODO: handle this mess
      _neededResources.remove(resourceId);
    }

  }

  // @TODO: Check for deadlocks
  void iipEventPropertyUpdated(
      int resourceId, int index, TransmissionType dataType, DC data) {
    fetch(resourceId, null).then((r) {
      var item = new AsyncReply<DistributedResourceQueueItem>();
      _queue.add(item);

      Codec.parse(data, 0, this, null, dataType).reply.then((arguments) {
        var pt = r.instance?.template.getPropertyTemplateByIndex(index);
        if (pt != null) {
          item.trigger(DistributedResourceQueueItem(
              r, DistributedResourceQueueItemType.Propery, arguments, index));
        } else {
          // ft found, fi not found, this should never happen
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

  // @TODO: Check for deadlocks
  void iipEventEventOccurred(
      int resourceId, int index, TransmissionType dataType, DC data) {
    fetch(resourceId, null).then((r) {
      // push to the queue to gaurantee serialization
      var item = new AsyncReply<DistributedResourceQueueItem>();
      _queue.add(item);

      Codec.parse(data, 0, this, null, dataType).reply.then((arguments) {
        var et = r.instance?.template.getEventTemplateByIndex(index);
        if (et != null) {
          item.trigger(new DistributedResourceQueueItem(
              r, DistributedResourceQueueItemType.Event, arguments, index));
        } else {
          // ft found, fi not found, this should never happen
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

  // @TODO: check for deadlocks
  void iipEventChildAdded(int resourceId, int childId) {
    fetch(resourceId, null).then((parent) {
      if (parent != null)
        fetch(childId, null).then((child) {
          if (child != null) parent.instance?.children.add(child);
        });
    });
  }

// @TODO: check for deadlocks
  void iipEventChildRemoved(int resourceId, int childId) {
    fetch(resourceId, null).then((parent) {
      if (parent != null)
        fetch(childId, null).then((child) {
          if (child != null) parent.instance?.children.remove(child);
        });
    });
  }

// @TODO: check for deadlocks
  void iipEventRenamed(int resourceId, String name) {
    fetch(resourceId, null)
      ..then((resource) {
        if (resource != null) {
          resource.instance?.attributes["name"] = name;
        }
      });
  }

// @TODO: check for deadlocks
  void iipEventAttributesUpdated(int resourceId, DC attributes) {
    fetch(resourceId, null)
      ..then((resource) {
        if (resource != null) {
          var attrs = attributes.getStringArray(0, attributes.length);

          getAttributes(resource, attrs).then((s) {
            resource.instance?.setAttributes(s);
          });
        }
      });
  }

  void iipRequestAttachResource(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null) {
        if (r.instance
                ?.applicable(_session as Session, ActionType.Attach, null) ==
            Ruling.Denied) {
          _sendError(ErrorType.Management, callback, 6);
          return;
        }

        _unsubscribe(r);

        var link = DC.stringToBytes(r.instance?.link ?? "");

        if (r is DistributedResource) {
          // reply ok
          _sendReply(IIPPacketAction.AttachResource, callback)
            ..addGuid(r.instance?.template.classId as Guid)
            ..addUint64(r.instance?.age as int)
            ..addUint16(link.length)
            ..addDC(link)
            //..addDC(Codec.composePropertyValueArray(
            //    r.internal_serialize(), this, true))
            ..addDC(Codec.compose(
                (r as DistributedResource).internal_serialize(), this))
            ..done();
        } else {
          // reply ok
          _sendReply(IIPPacketAction.AttachResource, callback)
            ..addGuid((r.instance as Instance).template.classId)
            ..addUint64((r.instance as Instance).age)
            ..addUint16(link.length)
            ..addDC(link)
            ..addDC(Codec.compose((r.instance as Instance).serialize(), this))
            ..done();
        }

        _subscribe(r);
        //r.instance.children.on("add", _children_OnAdd);
        //r.instance.children.on("removed", _children_OnRemoved);
        //r.instance.attributes.on("modified", _attributes_OnModified);
      } else {
        // reply failed
        //SendParams(0x80, r.instance.id, r.instance.Age, r.instance.serialize(false, this));
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

  void _attributes_OnModified(
      String key, oldValue, newValue, KeyList<String, dynamic> sender) {
    if (key == "name") {
      var instance = (sender.owner as Instance);
      var name = DC.stringToBytes(newValue.toString());
      sendEvent(IIPPacketEvent.ChildRemoved)
        ..addUint32(instance.id)
        ..addUint16(name.length)
        ..addDC(name)
        ..done();
    }
  }

  void _children_OnRemoved(Instance sender, IResource value) {
    sendEvent(IIPPacketEvent.ChildRemoved)
      ..addUint32(sender.id)
      ..addUint32(value.instance?.id as int)
      ..done();
  }

  void _children_OnAdd(Instance sender, IResource value) {
    //if (sender.applicable(sender.Resource, this.session, ActionType.))
    sendEvent(IIPPacketEvent.ChildAdded)
      ..addUint32(sender.id)
      ..addUint32((value.instance as Instance).id)
      ..done();
  }

  void _subscribe(IResource resource) {
    resource.instance?.on("resourceEventOccurred", _instance_EventOccurred);
    resource.instance?.on("resourceModified", _instance_PropertyModified);
    resource.instance?.on("resourceDestroyed", _instance_ResourceDestroyed);
    _subscriptions[resource] = <int>[];
  }

  void _unsubscribe(IResource resource) {
    resource.instance?.off("resourceEventOccurred", _instance_EventOccurred);
    resource.instance?.off("resourceModified", _instance_PropertyModified);
    resource.instance?.off("resourceDestroyed", _instance_ResourceDestroyed);
    _subscriptions.remove(resource);
  }

  void _unsubscribeAll() {
    _subscriptions.forEach((resource, value) {
      resource.instance?.off("resourceEventOccurred", _instance_EventOccurred);
      resource.instance?.off("resourceModified", _instance_PropertyModified);
      resource.instance?.off("resourceDestroyed", _instance_ResourceDestroyed);
    });

    _subscriptions.clear();
  }

  void iipRequestReattachResource(
      int callback, int resourceId, int resourceAge) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null) {
        _unsubscribe(r);
        _subscribe(r);

        // reply ok
        _sendReply(IIPPacketAction.ReattachResource, callback)
          ..addUint64((r.instance as Instance).age)
          ..addDC(Codec.compose((r.instance as Instance).serialize(), this))
          ..done();
      } else {
        // reply failed
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

  void iipRequestDetachResource(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((res) {
      if (res != null) {
        _unsubscribe(res);
        // reply ok
        _sendReply(IIPPacketAction.DetachResource, callback).done();
      } else {
        // reply failed
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

//@TODO: implement this
  void iipRequestCreateResource(
      int callback, int storeId, int parentId, DC content) {
    Warehouse.getById(storeId).then((store) {
      if (store == null) {
        _sendError(
            ErrorType.Management, callback, ExceptionCode.StoreNotFound.index);
        return;
      }

      if (!(store is IStore)) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceIsNotStore.index);
        return;
      }

      // check security
      if (store.instance?.applicable(
              _session as Session, ActionType.CreateResource, null) !=
          Ruling.Allowed) {
        _sendError(
            ErrorType.Management, callback, ExceptionCode.CreateDenied.index);
        return;
      }

      Warehouse.getById(parentId).then((parent) {
        // check security

        if (parent != null) if (parent.instance
                ?.applicable(_session as Session, ActionType.AddChild, null) !=
            Ruling.Allowed) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.AddChildDenied.index);
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

        var type = null; //Type.getType(className);

        if (type == null) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.ClassNotFound.index);
          return;
        }

// @TODO: check for deadlocks
        DataDeserializer.listParser(content, offset, cl, this, null)
            .then((parameters) {
          offset += cl;
          cl = content.getUint32(offset);
          DataDeserializer.typedMapParser(content, offset, cl, this, null)
              .then((attributes) {
            offset += cl;
            cl = content.length - offset;

            DataDeserializer.typedMapParser(content, offset, cl, this, null)
                .then((values) {
              var constructors =
                  []; //Type.GetType(className).GetTypeInfo().GetConstructors();

              var matching = constructors.where((x) {
                var ps = x.GetParameters();
                return ps.length == parameters.length;
              }).toList();

              var pi = matching[0].getParameters() as List;

              if (pi.length > 0) {
                int argsCount = pi.length;
                //args = new List<dynamic>(pi.length);

                if (pi[pi.length - 1].parameterType.runtimeType ==
                    DistributedConnection) {
                  //args[--argsCount] = this;
                }

                if (parameters != null) {
                  for (int i = 0; i < argsCount && i < parameters.length; i++) {
                    //args[i] = DC.CastConvert(parameters[i], pi[i].ParameterType);
                  }
                }
              }

              // create the resource
              IResource? resource =
                  null; //Activator.CreateInstance(type, args) as IResource;

              Warehouse.put<IResource>(
                  name, resource as IResource, store, parent)
                ..then((ok) {
                  _sendReply(IIPPacketAction.CreateResource, callback)
                    ..addUint32((resource.instance as Instance).id)
                    ..done();
                })
                ..error((ex) {
                  // send some error
                  _sendError(ErrorType.Management, callback,
                      ExceptionCode.AddToStoreFailed.index);
                });
            });
          });
        });
      });
    });
  }

  void iipRequestDeleteResource(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((r) {
      if (r == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (r.instance?.store?.instance
              ?.applicable(_session as Session, ActionType.Delete, null) !=
          Ruling.Allowed) {
        _sendError(
            ErrorType.Management, callback, ExceptionCode.DeleteDenied.index);
        return;
      }

      if (Warehouse.remove(r))
        _sendReply(IIPPacketAction.DeleteResource, callback).done();
      //SendParams((byte)0x84, callback);
      else
        _sendError(
            ErrorType.Management, callback, ExceptionCode.DeleteFailed.index);
    });
  }

  void iipRequestGetAttributes(int callback, int resourceId, DC attributes,
      [bool all = false]) {
    Warehouse.getById(resourceId).then((r) {
      if (r == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      //                if (!r.instance.store.instance.applicable(r, session, ActionType.InquireAttributes, null))
      if (r.instance?.applicable(
              _session as Session, ActionType.InquireAttributes, null) !=
          Ruling.Allowed) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ViewAttributeDenied.index);
        return;
      }

      List<String>? attrs = null;

      if (!all) attrs = attributes.getStringArray(0, attributes.length);

      var st = r.instance?.getAttributes(attrs);

      if (st != null)
        _sendReply(
            all
                ? IIPPacketAction.GetAllAttributes
                : IIPPacketAction.GetAttributes,
            callback)
          ..addDC(Codec.compose(st, this))
          ..done();
      else
        _sendError(ErrorType.Management, callback,
            ExceptionCode.GetAttributesFailed.index);
    });
  }

  void iipRequestAddChild(int callback, int parentId, int childId) {
    Warehouse.getById(parentId).then((parent) {
      if (parent == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      Warehouse.getById(childId).then((child) {
        if (child == null) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.ResourceNotFound.index);
          return;
        }

        if (parent.instance
                ?.applicable(_session as Session, ActionType.AddChild, null) !=
            Ruling.Allowed) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.AddChildDenied.index);
          return;
        }

        if (child.instance
                ?.applicable(_session as Session, ActionType.AddParent, null) !=
            Ruling.Allowed) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.AddParentDenied.index);
          return;
        }

        parent.instance?.children.add(child);

        _sendReply(IIPPacketAction.AddChild, callback).done();
        //child.instance.Parents
      });
    });
  }

  void iipRequestRemoveChild(int callback, int parentId, int childId) {
    Warehouse.getById(parentId).then((parent) {
      if (parent == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      Warehouse.getById(childId).then((child) {
        if (child == null) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.ResourceNotFound.index);
          return;
        }

        if (parent.instance?.applicable(
                _session as Session, ActionType.RemoveChild, null) !=
            Ruling.Allowed) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.AddChildDenied.index);
          return;
        }

        if (child.instance?.applicable(
                _session as Session, ActionType.RemoveParent, null) !=
            Ruling.Allowed) {
          _sendError(ErrorType.Management, callback,
              ExceptionCode.AddParentDenied.index);
          return;
        }

        parent.instance?.children.remove(child);

        _sendReply(IIPPacketAction.RemoveChild, callback).done();
        //child.instance.Parents
      });
    });
  }

  void iipRequestRenameResource(int callback, int resourceId, String name) {
    Warehouse.getById(resourceId).then((resource) {
      if (resource == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (resource.instance
              ?.applicable(_session as Session, ActionType.Rename, null) !=
          Ruling.Allowed) {
        _sendError(
            ErrorType.Management, callback, ExceptionCode.RenameDenied.index);
        return;
      }

      resource.instance?.name = name;
      _sendReply(IIPPacketAction.RenameResource, callback).done();
    });
  }

  void iipRequestResourceChildren(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((resource) {
      if (resource == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      _sendReply(IIPPacketAction.ResourceChildren, callback)
        ..addDC(Codec.compose(
            resource.instance?.children.toList() as List<IResource>, this))
        ..done();
    });
  }

  void iipRequestResourceParents(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((resource) {
      if (resource == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      _sendReply(IIPPacketAction.ResourceParents, callback)
        ..addDC(Codec.compose(
            resource.instance?.parents.toList() as List<IResource>, this))
        ..done();
    });
  }

  void iipRequestClearAttributes(int callback, int resourceId, DC attributes,
      [bool all = false]) {
    Warehouse.getById(resourceId).then((r) {
      if (r == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (r.instance?.store?.instance?.applicable(
              _session as Session, ActionType.UpdateAttributes, null) !=
          Ruling.Allowed) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.UpdateAttributeDenied.index);
        return;
      }

      List<String>? attrs = null;

      if (!all) attrs = attributes.getStringArray(0, attributes.length);

      if (r.instance?.removeAttributes(attrs) == true)
        _sendReply(
                all
                    ? IIPPacketAction.ClearAllAttributes
                    : IIPPacketAction.ClearAttributes,
                callback)
            .done();
      else
        _sendError(ErrorType.Management, callback,
            ExceptionCode.UpdateAttributeFailed.index);
    });
  }

  void iipRequestUpdateAttributes(int callback, int resourceId, DC attributes,
      [bool clearAttributes = false]) {
    Warehouse.getById(resourceId).then((r) {
      if (r == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (r.instance?.store?.instance?.applicable(
              _session as Session, ActionType.UpdateAttributes, null) !=
          Ruling.Allowed) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.UpdateAttributeDenied.index);
        return;
      }

      DataDeserializer.typedListParser(
              attributes, 0, attributes.length, this, null)
          .then((attrs) {
        if (r.instance?.setAttributes(
                attrs as Map<String, dynamic>, clearAttributes) ==
            true)
          _sendReply(
                  clearAttributes
                      ? IIPPacketAction.ClearAllAttributes
                      : IIPPacketAction.ClearAttributes,
                  callback)
              .done();
        else
          _sendError(ErrorType.Management, callback,
              ExceptionCode.UpdateAttributeFailed.index);
      });
    });
  }

  void iipRequestLinkTemplates(int callback, String resourceLink) {
    var queryCallback = (List<IResource>? r) {
      if (r == null)
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      else {
        var list = r.where((x) =>
            x.instance?.applicable(
                _session as Session, ActionType.ViewTemplate, null) !=
            Ruling.Denied);

        if (list.length == 0)
          _sendError(ErrorType.Management, callback,
              ExceptionCode.ResourceNotFound.index);
        else {
          // get all templates related to this resource
          var msg = new BinaryList();

          List<TypeTemplate> templates = [];

          list.forEach((resource) {
            templates.addAll(TypeTemplate.getDependencies(
                    resource.instance?.template as TypeTemplate)
                .where((x) => !templates.contains(x)));
          });

          templates.forEach((t) {
            msg
              ..addInt32(t.content.length)
              ..addDC(t.content);
          });

          // digggg
          _sendReply(IIPPacketAction.LinkTemplates, callback)
            ..addDC(TransmissionType.compose(
                TransmissionTypeIdentifier.RawData, msg.toDC()))
            ..done();
        }
      }
    };

    if (_server?.entryPoint != null)
      _server?.entryPoint?.query(resourceLink, this).then(queryCallback);
    else
      Warehouse.query(resourceLink).then(queryCallback);
  }

  void iipRequestTemplateFromClassName(int callback, String className) {
    var t = Warehouse.getTemplateByClassName(className);
    if (t != null) {
      _sendReply(IIPPacketAction.TemplateFromClassName, callback)
        ..addDC(TransmissionType.compose(
            TransmissionTypeIdentifier.RawData, t.content))
        ..done();
    } else {
      // reply failed
      _sendError(
          ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
    }
  }

  void iipRequestTemplateFromClassId(int callback, Guid classId) {
    var t = Warehouse.getTemplateByClassId(classId);
    if (t != null)
      _sendReply(IIPPacketAction.TemplateFromClassId, callback)
        ..addDC(TransmissionType.compose(
            TransmissionTypeIdentifier.RawData, t.content))
        ..done();
    else {
      // reply failed
      _sendError(
          ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
    }
  }

  void iipRequestTemplateFromResourceId(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null)
        _sendReply(IIPPacketAction.TemplateFromResourceId, callback)
          ..addDC(TransmissionType.compose(TransmissionTypeIdentifier.RawData,
              r.instance?.template.content ?? new DC(0)))
          ..done();
      else {
        // reply failed
        _sendError(ErrorType.Management, callback,
            ExceptionCode.TemplateNotFound.index);
      }
    });
  }

  void iipRequestQueryResources(int callback, String resourceLink) {
    Warehouse.query(resourceLink).then((r) {
      if (r == null) {
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      } else {
        var list = r
            .where((x) =>
                x.instance?.applicable(
                    _session as Session, ActionType.Attach, null) !=
                Ruling.Denied)
            .toList();

        if (list.length == 0)
          _sendError(ErrorType.Management, callback,
              ExceptionCode.ResourceNotFound.index);
        else
          _sendReply(IIPPacketAction.QueryLink, callback)
            ..addDC(Codec.compose(list, this))
            ..done();
      }
    });
  }

  void iipRequestProcedureCall(int callback, String procedureCall,
      TransmissionType transmissionType, DC content) {
    // server not implemented
    _sendError(
        ErrorType.Management, callback, ExceptionCode.GeneralFailure.index);

    // if (server == null)
    // {
    //     sendError(ErrorType.Management, callback, ExceptionCode.GeneralFailure.index);
    //     return;
    // }

    // var call = Server.Calls[procedureCall];

    // if (call == null)
    // {
    //     sendError(ErrorType.Management, callback, ExceptionCode.MethodNotFound.index);
    //     return;
    // }

    // var (_, parsed) = Codec.Parse(content, 0, this, null, transmissionType);

    // parsed.Then(results =>
    // {
    //     var arguments = (Map<byte, object>)results;// (object[])results;

    //     // un hold the socket to send data immediately
    //     this.Socket.Unhold();

    //     // @TODO: Make managers for procedure calls
    //     //if (r.Instance.Applicable(session, ActionType.Execute, ft) == Ruling.Denied)
    //     //{
    //     //    SendError(ErrorType.Management, callback,
    //     //        (ushort)ExceptionCode.InvokeDenied);
    //     //    return;
    //     //}

    //     InvokeFunction(call.Method, callback, arguments, IIPPacket.IIPPacketAction.ProcedureCall, call.Target);

    // }).Error(x =>
    // {
    //     SendError(ErrorType.Management, callback, (ushort)ExceptionCode.ParseError);
    // });
  }

  void iipRequestStaticCall(int callback, Guid classId, int index,
      TransmissionType transmissionType, DC content) {
    var template = Warehouse.getTemplateByClassId(classId);

    if (template == null) {
      _sendError(
          ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
      return;
    }

    var ft = template.getFunctionTemplateByIndex(index);

    if (ft == null) {
      // no function at this index
      _sendError(
          ErrorType.Management, callback, ExceptionCode.MethodNotFound.index);
      return;
    }

    // var parsed = Codec.parse(content, 0, this, null, transmissionType);

    // parsed.then((results)
    // {
    //     var arguments = (Map<byte, object>)results;

    //     // un hold the socket to send data immediately
    //     socket?.unhold();

    //     var fi = ft.methodInfo;

    //     if (fi == null)
    //     {
    //         // ft found, fi not found, this should never happen
    //         sendError(ErrorType.Management, callback, (ushort)ExceptionCode.MethodNotFound);
    //         return;
    //     }

    //     // @TODO: Make managers for static calls
    //     //if (r.Instance.Applicable(session, ActionType.Execute, ft) == Ruling.Denied)
    //     //{
    //     //    SendError(ErrorType.Management, callback,
    //     //        (ushort)ExceptionCode.InvokeDenied);
    //     //    return;
    //     //}

    //     InvokeFunction(fi, callback, arguments, IIPPacket.IIPPacketAction.StaticCall, null);

    // }).Error(x =>
    // {
    //     SendError(ErrorType.Management, callback, (ushort)ExceptionCode.ParseError);
    // });
  }

  void iipRequestResourceAttribute(int callback, int resourceId) {}

// @TODO: Check for deadlocks
  void iipRequestInvokeFunction(int callback, int resourceId, int index,
      TransmissionType dataType, DC data) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null) {
        Codec.parse(data, 0, this, null, dataType).reply.then((arguments) {
          var ft = r.instance?.template.getFunctionTemplateByIndex(index);
          if (ft != null) {
            if (r is DistributedResource) {
              var rt =
                  r.internal_invoke(index, arguments as Map<UInt8, dynamic>);
              if (rt != null) {
                rt.then((res) {
                  _sendReply(IIPPacketAction.InvokeFunction, callback)
                    ..addDC(Codec.compose(res, this))
                    ..done();
                });
              } else {
                // function not found on a distributed object
              }
            } else {
              var fi = null; //r.GetType().GetTypeInfo().GetMethod(ft.name);

              if (fi != null) {
              } else {
                // ft found, fi not found, this should never happen
              }
            }
          } else {
            // no function at this index
          }
        });
      } else {
        // no resource with this id
      }
    });
  }

  void iipRequestListen(int callback, int resourceId, int index) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null) {
        var et = r.instance?.template.getEventTemplateByIndex(index);

        if (et != null) {
          if (r is DistributedResource) {
            r.listen(et.name).then((x) {
              _sendReply(IIPPacketAction.Listen, callback).done();
            }).error((x) => _sendError(ErrorType.Exception, callback,
                ExceptionCode.GeneralFailure.index));
          } else {
            // if (!subscriptions.ContainsKey(r))
            // {
            //     sendError(ErrorType.Management, callback, ExceptionCode.NotAttached.index);
            //     return;
            // }

            // if (subscriptions[r].Contains(index))
            // {
            //     sendError(ErrorType.Management, callback, ExceptionCode.AlreadyListened.index);
            //     return;
            // }

            // subscriptions[r].add(index);

            // sendReply(IIPPacketAction.Listen, callback).done();
          }
        } else {
          // pt not found
          _sendError(ErrorType.Management, callback,
              ExceptionCode.MethodNotFound.index);
        }
      } else {
        // resource not found
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

  void iipRequestUnlisten(int callback, int resourceId, int index) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null) {
        var et = r.instance?.template.getEventTemplateByIndex(index);

        if (et != null) {
          if (r is DistributedResource) {
            r.unlisten(et.name).then((x) {
              _sendReply(IIPPacketAction.Unlisten, callback).done();
            }).error((x) => _sendError(ErrorType.Exception, callback,
                ExceptionCode.GeneralFailure.index));
          } else {
            // if (!subscriptions.ContainsKey(r))
            // {
            //     SendError(ErrorType.Management, callback, (ushort)ExceptionCode.NotAttached);
            //     return;
            // }

            // if (!subscriptions[r].Contains(index))
            // {
            //     SendError(ErrorType.Management, callback, (ushort)ExceptionCode.AlreadyUnlistened);
            //     return;
            // }

            // subscriptions[r].Remove(index);

            // SendReply(IIPPacket.IIPPacketAction.Unlisten, callback).Done();
          }
        } else {
          // pt not found
          _sendError(ErrorType.Management, callback,
              ExceptionCode.MethodNotFound.index);
        }
      } else {
        // resource not found
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

  // void iipRequestGetProperty(int callback, int resourceId, int index) {
  //   Warehouse.getById(resourceId).then((r) {
  //     if (r != null) {
  //       var pt = r.instance.template.getFunctionTemplateByIndex(index);
  //       if (pt != null) {
  //         if (r is DistributedResource) {
  //           sendReply(IIPPacketAction.GetProperty, callback)
  //               .addDC(Codec.compose(
  //                   (r as DistributedResource).get(pt.index), this))
  //               .done();
  //         } else {
  //           var pi = null; //r.GetType().GetTypeInfo().GetProperty(pt.Name);

  //           if (pi != null) {
  //             sendReply(IIPPacketAction.GetProperty, callback)
  //                 .addDC(Codec.compose(pi.GetValue(r), this))
  //                 .done();
  //           } else {
  //             // pt found, pi not found, this should never happen
  //           }
  //         }
  //       } else {
  //         // pt not found
  //       }
  //     } else {
  //       // resource not found
  //     }
  //   });
  // }

  // @TODO: implement this
  void iipRequestInquireResourceHistory(
      int callback, int resourceId, DateTime fromDate, DateTime toDate) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null) {
        r.instance?.store?.getRecord(r, fromDate, toDate).then((results) {
          if (results != null) {
            var history = DataSerializer.historyComposer(results, this, true);

            _sendReply(IIPPacketAction.ResourceHistory, callback)
              ..addDC(history)
              ..done();
          }

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
        });
      }
    });
  }

  // void iipRequestGetPropertyIfModifiedSince(
  //     int callback, int resourceId, int index, int age) {
  //   Warehouse.getById(resourceId).then((r) {
  //     if (r != null) {
  //       var pt = r.instance.template.getFunctionTemplateByIndex(index);
  //       if (pt != null) {
  //         if (r.instance.getAge(index) > age) {
  //           var pi = null; //r.GetType().GetProperty(pt.Name);
  //           if (pi != null) {
  //             sendReply(IIPPacketAction.GetPropertyIfModified, callback)
  //                 .addDC(Codec.compose(pi.GetValue(r), this))
  //                 .done();
  //           } else {
  //             // pt found, pi not found, this should never happen
  //           }
  //         } else {
  //           sendReply(IIPPacketAction.GetPropertyIfModified, callback)
  //               .addUint8(DataType.NotModified)
  //               .done();
  //         }
  //       } else {
  //         // pt not found
  //       }
  //     } else {
  //       // resource not found
  //     }
  //   });
  // }

// @TODO: Check for deadlocks
  void iipRequestSetProperty(int callback, int resourceId, int index,
      TransmissionType dataType, DC data) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null) {
        var pt = r.instance?.template.getPropertyTemplateByIndex(index);
        if (pt != null) {
          Codec.parse(data, 0, this, null, dataType).reply.then((value) {
            if (r is DistributedResource) {
              // propagation
              (r as DistributedResource).set(index, value)
                ..then((x) {
                  _sendReply(IIPPacketAction.SetProperty, callback).done();
                })
                ..error((x) {
                  _sendError(x.type, callback, x.code, x.message);
                });
            } else {
              var pi = null;

              if (pi != null) {
                if (r.instance?.applicable(_session as Session,
                        ActionType.SetProperty, pt, this) ==
                    Ruling.Denied) {
                  _sendError(ErrorType.Exception, callback,
                      ExceptionCode.SetPropertyDenied.index);
                  return;
                }

                if (pi == null) {
                  _sendError(ErrorType.Management, callback,
                      ExceptionCode.ReadOnlyProperty.index);
                  return;
                }

                if (pi.propertyType.runtimeType == DistributedPropertyContext) {
                  value = new DistributedPropertyContext.setter(value, this);
                } else {
                  // cast new value type to property type
                  // value = DC.castConvert(value, pi.PropertyType);
                }

                try {
                  pi.setValue(r, value);
                  _sendReply(IIPPacketAction.SetProperty, callback).done();
                } catch (ex) {
                  _sendError(ErrorType.Exception, callback, 0, ex.toString());
                }
              } else {
                // pt found, pi not found, this should never happen
                _sendError(ErrorType.Management, callback,
                    ExceptionCode.PropertyNotFound.index);
              }
            }
          });
        } else {
          // property not found
          _sendError(ErrorType.Management, callback,
              ExceptionCode.PropertyNotFound.index);
        }
      } else {
        // resource not found
        _sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

  AsyncReply<TypeTemplate?> getTemplateByClassName(String className) {
    var template =
        _templates.values.firstWhereOrNull((x) => x.className == className);
    if (template != null) return AsyncReply<TypeTemplate>.ready(template);

    if (_templateByNameRequests.containsKey(className))
      return _templateByNameRequests[className] as AsyncReply<TypeTemplate?>;

    var reply = new AsyncReply<TypeTemplate?>();
    _templateByNameRequests.add(className, reply);

    var classNameBytes = DC.stringToBytes(className);

    (_sendRequest(IIPPacketAction.TemplateFromClassName)
          ..addUint8(classNameBytes.length)
          ..addDC(classNameBytes))
        .done()
      ..then((rt) {
        _templateByNameRequests.remove(className);
        if (rt != null) {
          _templates[(rt[0] as TypeTemplate).classId] = rt[0] as TypeTemplate;
          Warehouse.putTemplate(rt[0] as TypeTemplate);
          reply.trigger(rt[0]);
        } else
          reply.triggerError(Exception("Null response"));
      })
      ..error((ex) {
        reply.triggerError(ex);
      });

    return reply;
  }

  /// <summary>
  /// Get the TypeTemplate for a given class Id.
  /// </summary>
  /// <param name="classId">Class GUID.</param>
  /// <returns>TypeTemplate.</returns>
  AsyncReply<TypeTemplate?> getTemplate(Guid classId) {
    //Warehouse.getTemplateByClassId(classId)

    if (_templates.containsKey(classId))
      return AsyncReply<TypeTemplate?>.ready(_templates[classId]);
    else if (_templateRequests.containsKey(classId))
      return _templateRequests[classId] as AsyncReply<TypeTemplate?>;

    var reply = new AsyncReply<TypeTemplate>();
    _templateRequests.add(classId, reply);

    (_sendRequest(IIPPacketAction.TemplateFromClassId)..addGuid(classId)).done()
      ..then((rt) {
        if (rt != null) {
          _templateRequests.remove(classId);
          _templates[(rt[0] as TypeTemplate).classId] = rt[0] as TypeTemplate;
          Warehouse.putTemplate(rt[0] as TypeTemplate);
          reply.trigger(rt[0] as TypeTemplate);
        } else {
          reply.triggerError(Exception("Null response"));
        }
      })
      ..error((ex) {
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
  AsyncReply<IResource?> get(String path) {
    var rt = new AsyncReply<IResource?>();

    query(path)
      ..then((ar) {
        if (ar.length > 0)
          rt.trigger(ar[0]);
        else
          rt.trigger(null);
      })
      ..error((ex) => rt.triggerError(ex));

    return rt;
  }

  // /// <summary>
  // /// Retrive a resource by its instance Id.
  // /// </summary>
  // /// <param name="iid">Instance Id</param>
  // /// <returns>Resource</returns>
  // AsyncReply<IResource?> retrieve(int iid) {
  //   for (var r in _resources.values)
  //     if (r.instance?.id == iid) return new AsyncReply<IResource>.ready(r);
  //   return new AsyncReply<IResource?>.ready(null);
  // }

  AsyncReply<List<TypeTemplate>> getLinkTemplates(String link) {
    var reply = new AsyncReply<List<TypeTemplate>>();

    var l = DC.stringToBytes(link);

    (_sendRequest(IIPPacketAction.LinkTemplates)
          ..addUint16(l.length)
          ..addDC(l))
        .done()
      ..then((rt) {
        List<TypeTemplate> templates = [];
        // parse templates

        if (rt != null) {
          TransmissionType tt = rt[0] as TransmissionType;
          DC data = rt[1] as DC;
          //var offset = 0;
          for (int offset = tt.offset; offset < tt.contentLength;) {
            var cs = data.getUint32(offset);
            offset += 4;
            templates.add(TypeTemplate.parse(data, offset, cs));
            offset += cs;
          }
        } else {
          reply.triggerError(Exception("Null response"));
        }

        reply.trigger(templates);
      })
      ..error((ex) {
        reply.triggerError(ex);
      });

    return reply;
  }

  /// <summary>
  /// Fetch a resource from the other end
  /// </summary>
  /// <param name="classId">Class GUID</param>
  /// <param name="id">Resource Id</param>Guid classId
  /// <returns>DistributedResource</returns>
  AsyncReply<DistributedResource> fetch(int id, List<int>? requestSequence) {
    var resource = _attachedResources[id]?.target;

    if (resource != null)
      return AsyncReply<DistributedResource>.ready(resource);

    resource = _neededResources[id];

    var request = _resourceRequests[id];

    //print("fetch $id");

    if (request != null) {
      if (resource != null && (requestSequence?.contains(id) ?? false))
        return AsyncReply<DistributedResource>.ready(resource);
      return request;
    } else if (resource != null && !resource.distributedResourceSuspended) {
      // @REVIEW: this should never happen
      print("DCON: Resource not moved to attached.");
      return new AsyncReply<DistributedResource>.ready(resource);
    }

    var reply = new AsyncReply<DistributedResource>();
    _resourceRequests.add(id, reply);

    //print("AttachResource sent ${id}");

    var newSequence =
        requestSequence != null ? List<int>.from(requestSequence) : <int>[];

    newSequence.add(id);

    (_sendRequest(IIPPacketAction.AttachResource)..addUint32(id)).done()
      ..then((rt) {
        //print("AttachResource rec ${id}");

        // Resource not found (null)
        if (rt == null) {
          //print("Null response");
          reply.triggerError(AsyncException(ErrorType.Management,
              ExceptionCode.ResourceNotFound.index, "Null response"));
          return;
        }

        DistributedResource dr;
        TypeTemplate? template;

        Guid classId = rt[0] as Guid;

        if (resource == null) {
          template =
              Warehouse.getTemplateByClassId(classId, TemplateType.Resource);
          if (template?.definedType != null && (template?.isWrapper ?? false)) {
            dr = Warehouse.createInstance(template?.definedType as Type);
            dr.internal_init(this, id, rt[1] as int, rt[2] as String);
          } else {
            dr = new DistributedResource();
            dr.internal_init(this, id, rt[1] as int, rt[2] as String);
          }
        } else {
          dr = resource;
          template = resource.instance?.template;
        }

        TransmissionType transmissionType = rt[3] as TransmissionType;
        DC content = rt[4] as DC;

        var initResource = (ok) {
          //print("parse req ${id}");

          Codec.parse(content, 0, this, newSequence, transmissionType)
              .reply
              .then((results) {
            //print("parsed ${id}");

            var pvs = <PropertyValue>[];
            var ar = results as List;

            for (var i = 0; i < ar.length; i += 3)
              pvs.add(new PropertyValue(
                  ar[i + 2], ar[i] as int, ar[i + 1] as DateTime));

            dr.internal_attach(pvs);
            _resourceRequests.remove(id);

            // move from needed to attached.
            _neededResources.remove(id);
            _attachedResources[id] = WeakReference<DistributedResource>(dr);

            reply.trigger(dr);
          })
            ..error((ex) => reply.triggerError(ex));
        };

        if (template == null) {
          //print("tmp == null");
          getTemplate(rt[0] as Guid)
            ..then((tmp) {
              // ClassId, ResourceAge, ResourceLink, Content
              if (resource == null) {
                Warehouse.put(id.toString(), dr, this, null, tmp)
                  ..then(initResource)
                  ..error((ex) => reply.triggerError(ex));
              } else {
                initResource(resource);
              }
            })
            ..error((ex) {
              reply.triggerError(ex);
            });
        } else {
          //print("tmp != null");
          if (resource == null) {
            Warehouse.put(id.toString(), dr, this, null, template)
              ..then(initResource)
              ..error((ex) => reply.triggerError(ex));
          } else {
            initResource(resource);
          }
        }
      })
      ..error((ex) {
        reply.triggerError(ex);
      });

    return reply;
  }

// @TODO: Check for deadlocks
  AsyncReply<List<IResource?>> getChildren(IResource resource) {
    var rt = new AsyncReply<List<IResource?>>();

    (_sendRequest(IIPPacketAction.ResourceChildren)
          ..addUint32(resource.instance?.id as int))
        .done()
      ..then((ar) {
        if (ar != null) {
          TransmissionType dataType = ar[0] as TransmissionType;
          DC data = ar[1] as DC;

          Codec.parse(data, 0, this, null, dataType).reply.then((resources) {
            rt.trigger(resources as List<IResource?>);
          })
            ..error((ex) => rt.triggerError(ex));
        } else {
          rt.triggerError(Exception("Null response"));
        }
      }).error((ex) => rt.triggerError(ex));

    return rt;
  }

// @TODO: Check for deadlocks
  AsyncReply<List<IResource?>> getParents(IResource resource) {
    var rt = new AsyncReply<List<IResource?>>();

    (_sendRequest(IIPPacketAction.ResourceParents)
          ..addUint32((resource.instance as Instance).id))
        .done()
      ..then((ar) {
        if (ar != null) {
          TransmissionType dataType = ar[0] as TransmissionType;
          DC data = ar[1] as DC;
          Codec.parse(data, 0, this, null, dataType).reply.then((resources) {
            rt.trigger(resources as List<IResource>);
          })
            ..error((ex) => rt.triggerError(ex));
        } else {
          rt.triggerError(Exception("Null response"));
        }
      })
      ..error((ex) => rt.triggerError(ex));

    return rt;
  }

  AsyncReply<bool> removeAttributes(IResource resource,
      [List<String>? attributes = null]) {
    var rt = new AsyncReply<bool>();

    if (attributes == null)
      (_sendRequest(IIPPacketAction.ClearAllAttributes)
            ..addUint32(resource.instance?.id as int))
          .done()
        ..then((ar) => rt.trigger(true))
        ..error((ex) => rt.triggerError(ex));
    else {
      var attrs = DC.stringArrayToBytes(attributes);
      (_sendRequest(IIPPacketAction.ClearAttributes)
            ..addUint32(resource.instance?.id as int)
            ..addInt32(attrs.length)
            ..addDC(attrs))
          .done()
        ..then((ar) => rt.trigger(true))
        ..error((ex) => rt.triggerError(ex));
    }

    return rt;
  }

  AsyncReply<bool> setAttributes(
      IResource resource, Map<String, dynamic> attributes,
      [bool clearAttributes = false]) {
    var rt = new AsyncReply<bool>();

    (_sendRequest(clearAttributes
            ? IIPPacketAction.UpdateAllAttributes
            : IIPPacketAction.UpdateAttributes)
          ..addUint32(resource.instance?.id as int)
          ..addDC(Codec.compose(attributes, this)))
        .done()
      ..then((ar) => rt.trigger(true))
      ..error((ex) => rt.triggerError(ex));

    return rt;
  }

// @TODO: Check for deadlocks
  AsyncReply<Map<String, dynamic>> getAttributes(IResource resource,
      [List<String>? attributes = null]) {
    var rt = new AsyncReply<Map<String, dynamic>>();

    if (attributes == null) {
      (_sendRequest(IIPPacketAction.GetAllAttributes)
            ..addUint32(resource.instance?.id as int))
          .done()
        ..then((ar) {
          if (ar != null) {
            TransmissionType dataType = ar[0] as TransmissionType;
            DC data = ar[1] as DC;

            Codec.parse(data, 0, this, null, dataType).reply.then((st) {
              resource.instance?.setAttributes(st as Map<String, dynamic>);
              rt.trigger(st as Map<String, dynamic>);
            })
              ..error((ex) => rt.triggerError(ex));
          } else {
            rt.triggerError(Exception("Null response"));
          }
        })
        ..error((ex) => rt.triggerError(ex));
      ;
    } else {
      var attrs = DC.stringArrayToBytes(attributes);
      (_sendRequest(IIPPacketAction.GetAttributes)
            ..addUint32(resource.instance?.id as int)
            ..addInt32(attrs.length)
            ..addDC(attrs))
          .done()
        ..then((ar) {
          if (ar != null) {
            TransmissionType dataType = ar[0] as TransmissionType;
            DC data = ar[1] as DC;

            Codec.parse(data, 0, this, null, dataType).reply
              ..then((st) {
                resource.instance?.setAttributes(st as Map<String, dynamic>);

                rt.trigger(st as Map<String, dynamic>);
              })
              ..error((ex) => rt.triggerError(ex));
          } else {
            rt.triggerError(Exception("Null response"));
          }
        })
        ..error((ex) => rt.triggerError(ex));
      ;
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
  AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>?> getRecord(
      IResource resource, DateTime fromDate, DateTime toDate) {
    if (resource is DistributedResource) {
      var dr = resource as DistributedResource;

      if (dr.distributedResourceConnection != this)
        return new AsyncReply<
            KeyList<PropertyTemplate, List<PropertyValue>>?>.ready(null);

      var reply =
          new AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>>();

      (_sendRequest(IIPPacketAction.ResourceHistory)
            ..addUint32(dr.distributedResourceInstanceId as int)
            ..addDateTime(fromDate)
            ..addDateTime(toDate))
          .done()
        ..then((rt) {
          if (rt != null) {
            var content = rt[0] as DC;

            DataDeserializer.historyParser(
                    content, 0, content.length, resource, this, null)
                .then((history) => reply.trigger(history));
          } else {
            reply.triggerError(Exception("Null response"));
          }
        })
        ..error((ex) => reply.triggerError(ex));

      return reply;
    } else
      return AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>?>.ready(
          null);
  }

  /// <summary>
  /// Query resources at specific link.
  /// </summary>
  /// <param name="path">Link path.</param>
  /// <returns></returns>
// @TODO: Check for deadlocks
  AsyncReply<List<IResource?>> query(String path) {
    var str = DC.stringToBytes(path);
    var reply = new AsyncReply<List<IResource?>>();

    (_sendRequest(IIPPacketAction.QueryLink)
          ..addUint16(str.length)
          ..addDC(str))
        .done()
      ..then((ar) {
        if (ar != null) {
          TransmissionType dataType = ar[0] as TransmissionType;
          DC data = ar[1] as DC;

          Codec.parse(data, 0, this, null, dataType).reply.then((resources) =>
              reply.trigger((resources as List).cast<IResource?>()))
            ..error((ex) => reply.triggerError(ex));
        } else {
          reply.triggerError(Exception("Null response"));
        }
      })
      ..error((ex) => reply.triggerError(ex));

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
  AsyncReply<DistributedResource?> create(
      IStore store,
      IResource parent,
      String className,
      List parameters,
      Map<String, dynamic> attributes,
      Map<String, dynamic> values) {
    var reply = new AsyncReply<DistributedResource?>();
    var pkt = BinaryList()
      ..addUint32((store.instance as Instance).id)
      ..addUint32((parent.instance as Instance).id)
      ..addUint8(className.length)
      ..addString(className)
      ..addDC(Codec.compose(parameters, this))
      ..addDC(Codec.compose(attributes, this))
      ..addDC(Codec.compose(values, this));

    pkt.insertInt32(8, pkt.length);

    (_sendRequest(IIPPacketAction.CreateResource)..addDC(pkt.toDC())).done()
      ..then((args) {
        if (args != null) {
          var rid = args[0];

          fetch(rid as int, null).then((r) {
            reply.trigger(r);
          });
        } else {
          reply.triggerError(Exception("Null response"));
        }
      });

    return reply;
  }

  _instance_ResourceDestroyed(IResource resource) {
    // compose the packet
    _unsubscribe(resource);
    sendEvent(IIPPacketEvent.ResourceDestroyed)
      ..addUint32((resource.instance as Instance).id)
      ..done();
  }

  void _instance_PropertyModified(PropertyModificationInfo info) {
    //var pt = resource.instance?.template.getPropertyTemplateByName(name);

    //if (pt == null) return;

    sendEvent(IIPPacketEvent.PropertyUpdated)
      ..addUint32(info.resource.instance?.id as int)
      ..addUint8(info.propertyTemplate.index)
      ..addDC(Codec.compose(info.value, this))
      ..done();
  }

  //        private void Instance_EventOccurred(IResource resource, string name, string[] users, DistributedConnection[] connections, object[] args)

  void _instance_EventOccurred(EventOccurredInfo info) {
    //IResource resource, issuer,
    //List<Session>? receivers, String name, dynamic args) {
    //var et = resource.instance?.template.getEventTemplateByName(name);

    //if (et == null) return;

    if (info.eventTemplate.listenable) {
      // check the client requested listen
      if (_subscriptions[info.resource] == null) return;

      if (!_subscriptions[info.resource]!.contains(info.eventTemplate.index))
        return;
    }

    if (info.receivers != null) if (!info.receivers!(this._session)) return;

    if (info.resource.instance?.applicable(_session as Session,
            ActionType.ReceiveEvent, info.eventTemplate, info.issuer) ==
        Ruling.Denied) return;

    // compose the packet
    sendEvent(IIPPacketEvent.EventOccurred)
      ..addUint32((info.resource.instance as Instance).id)
      ..addUint8(info.eventTemplate.index)
      ..addDC(Codec.compose(info.value, this))
      ..done();
  }

  @override
  getProperty(String name) => null;

  @override
  invoke(String name, List arguments) => null;

  @override
  setProperty(String name, value) => true;

  @override
  TemplateDescriber get template =>
      TemplateDescriber("Esiur.Net.IIP.DistributedConnection");

  AsyncReply<dynamic> staticCall(
      Guid classId, int index, Map<UInt8, dynamic> parameters) {
    var pb = Codec.compose(parameters, this);

    var reply = AsyncReply<dynamic>();
    var c = _callbackCounter++;
    _requests.add(c, reply);

    _sendParams()
      ..addUint8((0x40 | IIPPacketAction.StaticCall))
      ..addUint32(c)
      ..addGuid(classId)
      ..addUint8(index)
      ..addDC(pb)
      ..done();

    return reply;
  }

  AsyncReply<dynamic> call(String procedureCall, [List? parameters = null]) {
    if (parameters == null) {
      return callArgs(procedureCall, Map<UInt8, dynamic>());
    } else {
      var map = Map<UInt8, dynamic>();
      parameters.forEachIndexed((index, element) {
        map[UInt8(index)] = element;
      });
      return callArgs(procedureCall, map);
    }
  }

  AsyncReply<dynamic> callArgs(
      String procedureCall, Map<UInt8, dynamic> parameters) {
    var pb = Codec.compose(parameters, this);

    var reply = new AsyncReply<dynamic>();
    var c = _callbackCounter++;
    _requests.add(c, reply);

    var callName = DC.stringToBytes(procedureCall);

    _sendParams()
      ..addUint8(0x40 | IIPPacketAction.ProcedureCall)
      ..addUint32(c)
      ..addUint16(callName.length)
      ..addDC(callName)
      ..addDC(pb)
      ..done();

    return reply;
  }

  void iipRequestKeepAlive(int callbackId, DateTime peerTime, int interval) {
    int jitter = 0;

    var now = DateTime.now().toUtc();

    if (_lastKeepAliveReceived != null) {
      var diff = now.difference(_lastKeepAliveReceived!).inMicroseconds;
      //Console.WriteLine("Diff " + diff + " " + interval);

      jitter = (diff - interval).abs();
    }

    _sendParams()
      ..addUint8(0x80 | IIPPacketAction.KeepAlive)
      ..addUint32(callbackId)
      ..addDateTime(now)
      ..addUint32(jitter)
      ..done();

    _lastKeepAliveReceived = now;
  }
}
