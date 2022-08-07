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

class DistributedConnection extends NetworkConnection with IStore {
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

  AsyncReply<bool>? _openReply;

  DistributedServer? _server;

  IIPPacket _packet = new IIPPacket();
  IIPAuthPacket _authPacket = new IIPAuthPacket();

  Session? _session;

  DC? _localPasswordOrToken;
  DC? _localNonce, _remoteNonce;

  String? _hostname;
  int _port = 10518;

  bool _ready = false, _readyToEstablish = false;

  KeyList<int, DistributedResource> _resources =
      new KeyList<int, DistributedResource>();

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

  DateTime? _lastKeepAliveSent;
  DateTime? _lastKeepAliveReceived;
  int jitter;
  int keepAliveTime = 10;

  /// <summary>
  /// Local username to authenticate ourselves.
  /// </summary>
  String get localUsername => _session?.localAuthentication.username ?? "";

  /// <summary>
  /// Peer's username.
  /// </summary>
  String get remoteUsername =>
      _session?.remoteAuthentication.username ?? ""; // { get; set; }

  /// <summary>
  /// Working domain.
  /// </summary>
  //public string Domain { get { return domain; } }

  /// <summary>
  /// The session related to this connection.
  /// </summary>
  Session? get session => _session;

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
  SendList sendParams([AsyncReply<List<dynamic>?>? reply = null]) {
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

    _openReply = new AsyncReply<bool>();
    //print("_openReply hash ${_openReply.hashCode}");

    if (hostname != null) {
      _session =
          new Session(new ClientAuthentication(), new HostAuthentication());

      _session?.localAuthentication.method = method;
      _session?.localAuthentication.tokenIndex = tokenIndex;
      _session?.localAuthentication.domain = domain;
      _session?.localAuthentication.username = username;
      _localPasswordOrToken = passwordOrToken;
    }

    if (_session == null)
      throw AsyncException(ErrorType.Exception, 0, "Session not initialized");

    if (socket == null) {
      if (useWebsocket || kIsWeb) {
        socket = new WSocket()..secure = secureWebSocket;
      } else
        socket = new TCPSocket();
    }

    _port = port ?? _port;
    _hostname = hostname ?? _hostname;

    if (_hostname == null) throw Exception("Host not specified.");

    if (socket != null) {
      socket.connect(_hostname as String, _port)
        ..then((x) {
          assign(socket as ISocket);
        })
        ..error((x) {
          _openReply?.triggerError(x);
          _openReply = null;
        });
    }

    return _openReply as AsyncReply<bool>;
  }

  @override
  void disconnected() {
    // clean up
    _ready = false;
    _readyToEstablish = false;

    _requests.values.forEach((x) { try { 
              x.triggerError(AsyncException(ErrorType.Management, 0, "Connection closed"));
            } catch (ex){ }
          });

    _resourceRequests.values.forEach((x) { try { 
              x.triggerError(AsyncException(ErrorType.Management, 0, "Connection closed"));
            } catch (ex){ }
          });

    _templateRequests.values.forEach((x) { try { 
              x.triggerError(AsyncException(ErrorType.Management, 0, "Connection closed"));
            } catch (ex){ }
          });

    _requests.clear();
    _resourceRequests.clear();
    _templateRequests.clear();

    

    // @TODO: check if we need this with reconnect
    // _resources.values.forEach((x) => x.suspend());
    //_unsubscribeAll();

  }

  Future<bool> reconnect() async {
    if (await connect()) {
      var bag = AsyncBag();

      for (var i = 0; i < _resources.keys.length; i++) {
        var index = _resources.keys.elementAt(i);
        // print("Re $i ${_resources[index].instance.template.className}");
        bag.add(fetch(index, null));
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
  Instance? instance;

  _declare() {
    var dmn = DC.stringToBytes(_session?.localAuthentication.domain ?? "");

    if (_session?.localAuthentication.method ==
        AuthenticationMethod.Credentials) {
      // declare (Credentials -> No Auth, No Enctypt)

      var un = DC.stringToBytes(_session?.localAuthentication.username ?? "");

      sendParams()
        ..addUint8(0x60)
        ..addUint8(dmn.length)
        ..addDC(dmn)
        ..addDC(_localNonce as DC)
        ..addUint8(un.length)
        ..addDC(un)
        ..done(); //, dmn, localNonce, (byte)un.Length, un);
    } else if (_session?.localAuthentication.method ==
        AuthenticationMethod.Token) {
      sendParams()
        ..addUint8(0x70)
        ..addUint8(dmn.length)
        ..addDC(dmn)
        ..addDC(_localNonce as DC)
        ..addUint64(_session?.localAuthentication.tokenIndex ?? 0)
        ..done(); //, dmn, localNonce, token

    } else if (_session?.localAuthentication.method ==
        AuthenticationMethod.None) {
      sendParams()
        ..addUint8(0x40)
        ..addUint8(dmn.length)
        ..addDC(dmn)
        ..done(); //, dmn, localNonce, token
    }
  }

  /// <summary>
  /// Assign a socket to the connection.
  /// </summary>
  /// <param name="socket">Any socket that implements ISocket.</param>
  assign(ISocket socket) {
    super.assign(socket);

    _session?.remoteAuthentication.source
        ?.attributes[SourceAttributeType.IPv4] = socket.remoteEndPoint?.address;
    _session?.remoteAuthentication.source
        ?.attributes[SourceAttributeType.Port] = socket.remoteEndPoint?.port;
    _session?.localAuthentication.source?.attributes[SourceAttributeType.IPv4] =
        socket.localEndPoint?.address;
    _session?.localAuthentication.source?.attributes[SourceAttributeType.Port] =
        socket.localEndPoint?.port;

    if (_session?.localAuthentication.type == AuthenticationType.Client) {
      // declare (Credentials -> No Auth, No Enctypt)
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
    //myId = Global.GenerateCode(12);
    // localParams.Host = DistributedParameters.HostType.Host;
    _session =
        new Session(new HostAuthentication(), new ClientAuthentication());
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

  Timer? _keepAliveTimer;

  int KeepAliveInterval = 30;

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
    _localNonce = n;

    // _keepAliveTimer =
    //     Timer(Duration(seconds: KeepAliveInterval), _keepAliveTimer_Elapsed);
  }



  void _keepAliveTimer_Elapsed() {
    if (!isConnected) return;

    _keepAliveTimer?.cancel();

    var now = DateTime.now().toUtc();

    int interval = _lastKeepAliveSent == null
        ? 0
        : (now.difference(_lastKeepAliveSent!).inMilliseconds);

    _lastKeepAliveSent = now;

    sendRequest(IIPPacketAction.KeepAlive)
      ..addDateTime(now)
      ..addUint32(interval)
      ..done().then((x) {
        jitter = x?[1];

        _keepAliveTimer = Timer(
            Duration(seconds: KeepAliveInterval), _keepAliveTimer_Elapsed);

        print("Keep Alive Received ${jitter}");
      }).error((ex) {
        _keepAliveTimer?.cancel();
        close();
      }).timeout(Duration(microseconds: keepAliveTime), onTimeout: () {
        _keepAliveTimer?.cancel();
        close();
      });
  }

  int processPacket(
      DC msg, int offset, int ends, NetworkBuffer data, int chunkId) {
    var packet = new IIPPacket();

    if (_ready) {
      //print("Inc " + msg.length.toString());

      var rt = packet.parse(msg, offset, ends);

      //print("Packet " + packet.toString());

      if (rt <= 0) {
        // print("hold");
        var size = ends - offset;
        data.holdFor(msg, offset, size, size - rt);
        return ends;
      } else {
        //print("CMD ${packet.command} ${offset} ${ends}");

        offset += rt;

        if (packet.command == IIPPacketCommand.Event) {
          switch (packet.event) {
            case IIPPacketEvent.ResourceReassigned:
              iipEventResourceReassigned(
                  packet.resourceId, packet.newResourceId);
              break;
            case IIPPacketEvent.ResourceDestroyed:
              iipEventResourceDestroyed(packet.resourceId);
              break;
            case IIPPacketEvent.PropertyUpdated:
              iipEventPropertyUpdated(packet.resourceId, packet.methodIndex,
                  packet.dataType ?? TransmissionType.Null, msg);
              break;
            case IIPPacketEvent.EventOccurred:
              iipEventEventOccurred(packet.resourceId, packet.methodIndex,
                  packet.dataType ?? TransmissionType.Null, msg);
              break;

            case IIPPacketEvent.ChildAdded:
              iipEventChildAdded(packet.resourceId, packet.childId);
              break;
            case IIPPacketEvent.ChildRemoved:
              iipEventChildRemoved(packet.resourceId, packet.childId);
              break;
            case IIPPacketEvent.Renamed:
              iipEventRenamed(packet.resourceId, packet.resourceName);
              break;
            case IIPPacketEvent.AttributesUpdated:
              // @TODO: fix this
              //iipEventAttributesUpdated(packet.resourceId, packet.dataType. ?? TransmissionType.Null);
              break;
          }
        } else if (packet.command == IIPPacketCommand.Request) {
          switch (packet.action) {
            // Manage
            case IIPPacketAction.AttachResource:
              iipRequestAttachResource(packet.callbackId, packet.resourceId);
              break;
            case IIPPacketAction.ReattachResource:
              iipRequestReattachResource(
                  packet.callbackId, packet.resourceId, packet.resourceAge);
              break;
            case IIPPacketAction.DetachResource:
              iipRequestDetachResource(packet.callbackId, packet.resourceId);
              break;
            case IIPPacketAction.CreateResource:

              // @TODO: Fix this
              //iipRequestCreateResource(packet.callbackId, packet.storeId,
              //  packet.resourceId, packet.content);
              break;
            case IIPPacketAction.DeleteResource:
              iipRequestDeleteResource(packet.callbackId, packet.resourceId);
              break;
            case IIPPacketAction.AddChild:
              iipRequestAddChild(
                  packet.callbackId, packet.resourceId, packet.childId);
              break;
            case IIPPacketAction.RemoveChild:
              iipRequestRemoveChild(
                  packet.callbackId, packet.resourceId, packet.childId);
              break;
            case IIPPacketAction.RenameResource:
              iipRequestRenameResource(
                  packet.callbackId, packet.resourceId, packet.resourceName);
              break;

            // Inquire
            case IIPPacketAction.TemplateFromClassName:
              iipRequestTemplateFromClassName(
                  packet.callbackId, packet.className);
              break;
            case IIPPacketAction.TemplateFromClassId:
              iipRequestTemplateFromClassId(packet.callbackId, packet.classId);
              break;
            case IIPPacketAction.TemplateFromResourceId:
              iipRequestTemplateFromResourceId(
                  packet.callbackId, packet.resourceId);
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
              iipRequestInquireResourceHistory(packet.callbackId,
                  packet.resourceId, packet.fromDate, packet.toDate);
              break;

            case IIPPacketAction.LinkTemplates:
              iipRequestLinkTemplates(packet.callbackId, packet.resourceLink);
              break;

            // Invoke
            case IIPPacketAction.InvokeFunction:
              iipRequestInvokeFunction(
                  packet.callbackId,
                  packet.resourceId,
                  packet.methodIndex,
                  packet.dataType ?? TransmissionType.Null,
                  msg);
              break;

            case IIPPacketAction.Listen:
              iipRequestListen(
                  packet.callbackId, packet.resourceId, packet.methodIndex);
              break;
            case IIPPacketAction.Unlisten:
              iipRequestUnlisten(
                  packet.callbackId, packet.resourceId, packet.methodIndex);
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
                  packet.callbackId,
                  packet.resourceId,
                  packet.methodIndex,
                  packet.dataType ?? TransmissionType.Null,
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
                iipRequestKeepAlive(packet.callbackId, packet.currentTime, packet.interval);
                break;

            case IIPPacketAction.ProcedureCall:
                iipRequestProcedureCall(packet.callbackId, packet.procedure, (TransmissionType)packet.dataType, msg);
                break;

            case IIPPacketAction.StaticCall:
                iipRequestStaticCall(packet.callbackId, packet.classId, packet.methodIndex, (TransmissionType)packet.dataType, msg);
                break;


          }
        } else if (packet.command == IIPPacketCommand.Reply) {
          switch (packet.action) {
            // Manage
            case IIPPacketAction.AttachResource:
              iipReply(packet.callbackId, [
                packet.classId,
                packet.resourceAge,
                packet.resourceLink,
                packet.dataType ?? TransmissionType.Null,
                msg
              ]);
              break;

            case IIPPacketAction.ReattachResource:
              iipReply(packet.callbackId, [
                packet.resourceAge,
                packet.dataType ?? TransmissionType.Null,
                msg
              ]);

              break;
            case IIPPacketAction.DetachResource:
              iipReply(packet.callbackId);
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
              if (packet.dataType != null) {
                var content = msg.clip(packet.dataType?.offset ?? 0,
                    packet.dataType?.contentLength ?? 0);
                iipReply(packet.callbackId, [TypeTemplate.parse(content)]);
              } else {
                iipReportError(packet.callbackId, ErrorType.Management,
                    ExceptionCode.TemplateNotFound.index, "Template not found");
              }

              break;

            case IIPPacketAction.QueryLink:
            case IIPPacketAction.ResourceChildren:
            case IIPPacketAction.ResourceParents:
            case IIPPacketAction.ResourceHistory:
            case IIPPacketAction.LinkTemplates:
              iipReply(packet.callbackId,
                  [packet.dataType ?? TransmissionType.Null, msg]);
              break;

            // Invoke
            case IIPPacketAction.InvokeFunction:
            case IIPPacketAction.StaticCall:
            case IIPPacketAction.ProcedureCall:

              iipReplyInvoke(packet.callbackId,
                  packet.dataType ?? TransmissionType.Null, msg);
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
              iipReply(packet.callbackId);
              break;

            // Attribute
            case IIPPacketAction.GetAllAttributes:
            case IIPPacketAction.GetAttributes:
              iipReply(packet.callbackId,
                  [packet.dataType ?? TransmissionType.Null, msg]);
              break;

            case IIPPacketAction.UpdateAllAttributes:
            case IIPPacketAction.UpdateAttributes:
            case IIPPacketAction.ClearAllAttributes:
            case IIPPacketAction.ClearAttributes:
              iipReply(packet.callbackId);
              break;

            case IIPPacketAction.KeepAlive:
              iipReply(packet.callbackId, packet.currentTime, packet.jitter);
              break;
          }
        } else if (packet.command == IIPPacketCommand.Report) {
          switch (packet.report) {
            case IIPPacketReport.ManagementError:
              iipReportError(packet.callbackId, ErrorType.Management,
                  packet.errorCode, null);
              break;
            case IIPPacketReport.ExecutionError:
              iipReportError(packet.callbackId, ErrorType.Exception,
                  packet.errorCode, packet.errorMessage);
              break;
            case IIPPacketReport.ProgressReport:
              iipReportProgress(packet.callbackId, ProgressType.Execution,
                  packet.progressValue, packet.progressMax);
              break;
            case IIPPacketReport.ChunkStream:
              iipReportChunk(packet.callbackId,
                  packet.dataType ?? TransmissionType.Null, msg);
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

        if (_session?.localAuthentication.type == AuthenticationType.Host) {
          if (_authPacket.command == IIPAuthPacketCommand.Declare) {
            if (_authPacket.remoteMethod == AuthenticationMethod.Credentials &&
                _authPacket.localMethod == AuthenticationMethod.None) {
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
          } else if (_authPacket.command == IIPAuthPacketCommand.Action) {
            if (_authPacket.action == IIPAuthPacketAction.AuthenticateHash) {
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
            } else if (_authPacket.action ==
                IIPAuthPacketAction.NewConnection) {
              if (_readyToEstablish) {
                var r = new Random();

                var sid = DC(32);

                for (var i = 0; i < 32; i++) sid[i] = r.nextInt(255);
                _session?.id = sid;

                sendParams()
                  ..addUint8(0x28)
                  ..addDC(sid)
                  ..done();

                _ready = true;

                _openReply?.trigger(true);
                _openReply = null;
                emitArgs("ready", []);
                //OnReady?.Invoke(this);
                // server.membership.login(session);

              }
            }
          }
        } else if (_session?.localAuthentication.type ==
            AuthenticationType.Client) {
          if (_authPacket.command == IIPAuthPacketCommand.Acknowledge) {
            if (_authPacket.remoteMethod == AuthenticationMethod.None) {
              sendParams()
                ..addUint8(0x20)
                ..addUint16(0)
                ..done();
            } else if (_authPacket.remoteMethod ==
                    AuthenticationMethod.Credentials ||
                _authPacket.remoteMethod == AuthenticationMethod.Token) {
              _remoteNonce = _authPacket.remoteNonce;

              // send our hash
              var localHash = SHA256.compute((BinaryList()
                    ..addDC(_localPasswordOrToken as DC)
                    ..addDC(_localNonce as DC)
                    ..addDC(_remoteNonce as DC))
                  .toDC());

              sendParams()
                ..addUint8(0)
                ..addDC(localHash)
                ..done();
            }
            //SendParams((byte)0, localHash);
          } else if (_authPacket.command == IIPAuthPacketCommand.Action) {
            if (_authPacket.action == IIPAuthPacketAction.AuthenticateHash) {
              // check if the server knows my password
              var remoteHash = SHA256.compute((BinaryList()
                    ..addDC(_remoteNonce as DC)
                    ..addDC(_localNonce as DC)
                    ..addDC(_localPasswordOrToken as DC))
                  .toDC());

              if (remoteHash.sequenceEqual(_authPacket.hash)) {
                // send establish request
                sendParams()
                  ..addUint8(0x20)
                  ..addUint16(0)
                  ..done();
              } else {
                sendParams()
                  ..addUint8(0xc0)
                  ..addUint8(ExceptionCode.ChallengeFailed.index)
                  ..addUint16(16)
                  ..addString("Challenge Failed")
                  ..done();

                //SendParams((byte)0xc0, 1, 5, DC.ToBytes("Error"));
              }
            } else if (_authPacket.action ==
                IIPAuthPacketAction.ConnectionEstablished) {
              _session?.id = _authPacket.sessionId;

              _ready = true;

              _openReply?.trigger(true);
              _openReply = null;
              emitArgs("ready", []);

              // start perodic keep alive timer
              _keepAliveTimer = Timer(Duration(seconds: KeepAliveInterval), _keepAliveTimer_Elapsed);
              
            }
          } else if (_authPacket.command == IIPAuthPacketCommand.Error) {
            var ex = AsyncException(ErrorType.Management, _authPacket.errorCode,
                _authPacket.errorMessage);
            _openReply?.triggerError(ex);
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
      _resources.add(
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
  SendList sendRequest(int action) {
    var reply = new AsyncReply<List<dynamic>?>();
    var c = _callbackCounter++; // avoid thread racing
    _requests.add(c, reply);

    return (sendParams(reply)
      ..addUint8(0x40 | action)
      ..addUint32(c));
  }

  //int _maxcallerid = 0;

  SendList sendReply(int action, int callbackId) {
    return (sendParams()
      ..addUint8((0x80 | action))
      ..addUint32(callbackId));
  }

  SendList sendEvent(int evt) {
    return (sendParams()..addUint8((evt)));
  }

  AsyncReply<dynamic> sendListenRequest(int instanceId, int index) {
    var reply = new AsyncReply<dynamic>();
    var c = _callbackCounter++;
    _requests.add(c, reply);

    sendParams()
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

    sendParams()
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

    sendParams()
      ..addUint8(0x40 | IIPPacketAction.InvokeFunction)
      ..addUint32(c)
      ..addUint32(instanceId)
      ..addUint8(index)
      ..addDC(pb)
      ..done();
    return reply;
  }

  AsyncReply<dynamic>? sendDetachRequest(int instanceId) {
    try {
      return (sendRequest(IIPPacketAction.DetachResource)
            ..addUint32(instanceId))
          .done();
    } catch (ex) {
      return null;
    }
  }

  void sendError(ErrorType type, int callbackId, int errorCode,
      [String? errorMessage]) {
    var msg = DC.stringToBytes(errorMessage ?? "");
    if (type == ErrorType.Management)
      sendParams()
        ..addUint8(0xC0 | IIPPacketReport.ManagementError)
        ..addUint32(callbackId)
        ..addUint16(errorCode)
        ..done();
    else if (type == ErrorType.Exception)
      sendParams()
        ..addUint8(0xC0 | IIPPacketReport.ExecutionError)
        ..addUint32(callbackId)
        ..addUint16(errorCode)
        ..addUint16(msg.length)
        ..addDC(msg)
        ..done();
  }

  void sendProgress(int callbackId, int value, int max) {
    sendParams()
      ..addUint8(0xC0 | IIPPacketReport.ProgressReport)
      ..addUint32(callbackId)
      ..addInt32(value)
      ..addInt32(max)
      ..done();
    //SendParams(, callbackId, value, max);
  }

  void sendChunk(int callbackId, dynamic chunk) {
    var c = Codec.compose(chunk, this);
    sendParams()
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

  void iipEventResourceReassigned(int resourceId, int newResourceId) {}

  void iipEventResourceDestroyed(int resourceId) {
    if (_resources.contains(resourceId)) {
      var r = _resources[resourceId];
      _resources.remove(resourceId);
      r?.destroy();
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
          sendError(ErrorType.Management, callback, 6);
          return;
        }

        _unsubscrive(r);

        var link = DC.stringToBytes(r.instance?.link ?? "");

        if (r is DistributedResource) {
          // reply ok
          sendReply(IIPPacketAction.AttachResource, callback)
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
          sendReply(IIPPacketAction.AttachResource, callback)
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
        sendError(ErrorType.Management, callback,
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

void _unsubscribeAll(){
  _subscriptions.forEach((resource, value) => {
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
        sendReply(IIPPacketAction.ReattachResource, callback)
          ..addUint64((r.instance as Instance).age)
          ..addDC(Codec.compose((r.instance as Instance).serialize(), this))
          ..done();
      } else {
        // reply failed
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

  void iipRequestDetachResource(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((res) {
      if (res != null) {
        _unsubscribe(res);
        // reply ok
        sendReply(IIPPacketAction.DetachResource, callback).done();
      } else {
        // reply failed
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      }
    });
  }

//@TODO: implement this
  void iipRequestCreateResource(
      int callback, int storeId, int parentId, DC content) {
    Warehouse.getById(storeId).then((store) {
      if (store == null) {
        sendError(
            ErrorType.Management, callback, ExceptionCode.StoreNotFound.index);
        return;
      }

      if (!(store is IStore)) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceIsNotStore.index);
        return;
      }

      // check security
      if (store.instance?.applicable(
              _session as Session, ActionType.CreateResource, null) !=
          Ruling.Allowed) {
        sendError(
            ErrorType.Management, callback, ExceptionCode.CreateDenied.index);
        return;
      }

      Warehouse.getById(parentId).then((parent) {
        // check security

        if (parent != null) if (parent.instance
                ?.applicable(_session as Session, ActionType.AddChild, null) !=
            Ruling.Allowed) {
          sendError(ErrorType.Management, callback,
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
          sendError(ErrorType.Management, callback,
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
                  sendReply(IIPPacketAction.CreateResource, callback)
                    ..addUint32((resource.instance as Instance).id)
                    ..done();
                })
                ..error((ex) {
                  // send some error
                  sendError(ErrorType.Management, callback,
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
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (r.instance?.store?.instance
              ?.applicable(_session as Session, ActionType.Delete, null) !=
          Ruling.Allowed) {
        sendError(
            ErrorType.Management, callback, ExceptionCode.DeleteDenied.index);
        return;
      }

      if (Warehouse.remove(r))
        sendReply(IIPPacketAction.DeleteResource, callback).done();
      //SendParams((byte)0x84, callback);
      else
        sendError(
            ErrorType.Management, callback, ExceptionCode.DeleteFailed.index);
    });
  }

  void iipRequestGetAttributes(int callback, int resourceId, DC attributes,
      [bool all = false]) {
    Warehouse.getById(resourceId).then((r) {
      if (r == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      //                if (!r.instance.store.instance.applicable(r, session, ActionType.InquireAttributes, null))
      if (r.instance?.applicable(
              _session as Session, ActionType.InquireAttributes, null) !=
          Ruling.Allowed) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ViewAttributeDenied.index);
        return;
      }

      List<String>? attrs = null;

      if (!all) attrs = attributes.getStringArray(0, attributes.length);

      var st = r.instance?.getAttributes(attrs);

      if (st != null)
        sendReply(
            all
                ? IIPPacketAction.GetAllAttributes
                : IIPPacketAction.GetAttributes,
            callback)
          ..addDC(Codec.compose(st, this))
          ..done();
      else
        sendError(ErrorType.Management, callback,
            ExceptionCode.GetAttributesFailed.index);
    });
  }

  void iipRequestAddChild(int callback, int parentId, int childId) {
    Warehouse.getById(parentId).then((parent) {
      if (parent == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      Warehouse.getById(childId).then((child) {
        if (child == null) {
          sendError(ErrorType.Management, callback,
              ExceptionCode.ResourceNotFound.index);
          return;
        }

        if (parent.instance
                ?.applicable(_session as Session, ActionType.AddChild, null) !=
            Ruling.Allowed) {
          sendError(ErrorType.Management, callback,
              ExceptionCode.AddChildDenied.index);
          return;
        }

        if (child.instance
                ?.applicable(_session as Session, ActionType.AddParent, null) !=
            Ruling.Allowed) {
          sendError(ErrorType.Management, callback,
              ExceptionCode.AddParentDenied.index);
          return;
        }

        parent.instance?.children.add(child);

        sendReply(IIPPacketAction.AddChild, callback).done();
        //child.instance.Parents
      });
    });
  }

  void iipRequestRemoveChild(int callback, int parentId, int childId) {
    Warehouse.getById(parentId).then((parent) {
      if (parent == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      Warehouse.getById(childId).then((child) {
        if (child == null) {
          sendError(ErrorType.Management, callback,
              ExceptionCode.ResourceNotFound.index);
          return;
        }

        if (parent.instance?.applicable(
                _session as Session, ActionType.RemoveChild, null) !=
            Ruling.Allowed) {
          sendError(ErrorType.Management, callback,
              ExceptionCode.AddChildDenied.index);
          return;
        }

        if (child.instance?.applicable(
                _session as Session, ActionType.RemoveParent, null) !=
            Ruling.Allowed) {
          sendError(ErrorType.Management, callback,
              ExceptionCode.AddParentDenied.index);
          return;
        }

        parent.instance?.children.remove(child);

        sendReply(IIPPacketAction.RemoveChild, callback).done();
        //child.instance.Parents
      });
    });
  }

  void iipRequestRenameResource(int callback, int resourceId, String name) {
    Warehouse.getById(resourceId).then((resource) {
      if (resource == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (resource.instance
              ?.applicable(_session as Session, ActionType.Rename, null) !=
          Ruling.Allowed) {
        sendError(
            ErrorType.Management, callback, ExceptionCode.RenameDenied.index);
        return;
      }

      resource.instance?.name = name;
      sendReply(IIPPacketAction.RenameResource, callback).done();
    });
  }

  void iipRequestResourceChildren(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((resource) {
      if (resource == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      sendReply(IIPPacketAction.ResourceChildren, callback)
        ..addDC(Codec.compose(
            resource.instance?.children.toList() as List<IResource>, this))
        ..done();
    });
  }

  void iipRequestResourceParents(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((resource) {
      if (resource == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      sendReply(IIPPacketAction.ResourceParents, callback)
        ..addDC(Codec.compose(
            resource.instance?.parents.toList() as List<IResource>, this))
        ..done();
    });
  }

  void iipRequestClearAttributes(int callback, int resourceId, DC attributes,
      [bool all = false]) {
    Warehouse.getById(resourceId).then((r) {
      if (r == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (r.instance?.store?.instance?.applicable(
              _session as Session, ActionType.UpdateAttributes, null) !=
          Ruling.Allowed) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.UpdateAttributeDenied.index);
        return;
      }

      List<String>? attrs = null;

      if (!all) attrs = attributes.getStringArray(0, attributes.length);

      if (r.instance?.removeAttributes(attrs) == true)
        sendReply(
                all
                    ? IIPPacketAction.ClearAllAttributes
                    : IIPPacketAction.ClearAttributes,
                callback)
            .done();
      else
        sendError(ErrorType.Management, callback,
            ExceptionCode.UpdateAttributeFailed.index);
    });
  }

  void iipRequestUpdateAttributes(int callback, int resourceId, DC attributes,
      [bool clearAttributes = false]) {
    Warehouse.getById(resourceId).then((r) {
      if (r == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
        return;
      }

      if (r.instance?.store?.instance?.applicable(
              _session as Session, ActionType.UpdateAttributes, null) !=
          Ruling.Allowed) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.UpdateAttributeDenied.index);
        return;
      }

      DataDeserializer.typedListParser(
              attributes, 0, attributes.length, this, null)
          .then((attrs) {
        if (r.instance?.setAttributes(
                attrs as Map<String, dynamic>, clearAttributes) ==
            true)
          sendReply(
                  clearAttributes
                      ? IIPPacketAction.ClearAllAttributes
                      : IIPPacketAction.ClearAttributes,
                  callback)
              .done();
        else
          sendError(ErrorType.Management, callback,
              ExceptionCode.UpdateAttributeFailed.index);
      });
    });
  }

  void iipRequestLinkTemplates(int callback, String resourceLink) {
    var queryCallback = (List<IResource>? r) {
      if (r == null)
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      else {
        var list = r.where((x) =>
            x.instance?.applicable(
                _session as Session, ActionType.ViewTemplate, null) !=
            Ruling.Denied);

        if (list.length == 0)
          sendError(ErrorType.Management, callback,
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
          sendReply(IIPPacketAction.LinkTemplates, callback)
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
      sendReply(IIPPacketAction.TemplateFromClassName, callback)
        ..addDC(TransmissionType.compose(
            TransmissionTypeIdentifier.RawData, t.content))
        ..done();
    } else {
      // reply failed
      sendError(
          ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
    }
  }

  void iipRequestTemplateFromClassId(int callback, Guid classId) {
    var t = Warehouse.getTemplateByClassId(classId);
    if (t != null)
      sendReply(IIPPacketAction.TemplateFromClassId, callback)
        ..addDC(TransmissionType.compose(
            TransmissionTypeIdentifier.RawData, t.content))
        ..done();
    else {
      // reply failed
      sendError(
          ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
    }
  }

  void iipRequestTemplateFromResourceId(int callback, int resourceId) {
    Warehouse.getById(resourceId).then((r) {
      if (r != null)
        sendReply(IIPPacketAction.TemplateFromResourceId, callback)
          ..addDC(TransmissionType.compose(TransmissionTypeIdentifier.RawData,
              r.instance?.template.content ?? new DC(0)))
          ..done();
      else {
        // reply failed
        sendError(ErrorType.Management, callback,
            ExceptionCode.TemplateNotFound.index);
      }
    });
  }

  void iipRequestQueryResources(int callback, String resourceLink) {
    Warehouse.query(resourceLink).then((r) {
      if (r == null) {
        sendError(ErrorType.Management, callback,
            ExceptionCode.ResourceNotFound.index);
      } else {
        var list = r
            .where((x) =>
                x.instance?.applicable(
                    _session as Session, ActionType.Attach, null) !=
                Ruling.Denied)
            .toList();

        if (list.length == 0)
          sendError(ErrorType.Management, callback,
              ExceptionCode.ResourceNotFound.index);
        else
          sendReply(IIPPacketAction.QueryLink, callback)
            ..addDC(Codec.compose(list, this))
            ..done();
      }
    });
  }


    void iipRequestProcedureCall(int callback, String procedureCall, TransmissionType transmissionType, DC content)
    {
        // server not implemented
        sendError(ErrorType.Management, callback, ExceptionCode.GeneralFailure.index);

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

    void IIPRequestStaticCall(int callback, Guid classId, int index, TransmissionType transmissionType, DC content)
    {
        var template = Warehouse.getTemplateByClassId(classId);

        if (template == null)
        {
            sendError(ErrorType.Management, callback, ExceptionCode.TemplateNotFound.index);
            return;
        }

        var ft = template.getFunctionTemplateByIndex(index);

        if (ft == null)
        {
            // no function at this index
            sendError(ErrorType.Management, callback, ExceptionCode.MethodNotFound.index);
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
                  sendReply(IIPPacketAction.InvokeFunction, callback)
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
              sendReply(IIPPacketAction.Listen, callback).done();
            }).error((x) => sendError(ErrorType.Exception, callback,
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
          sendError(ErrorType.Management, callback,
              ExceptionCode.MethodNotFound.index);
        }
      } else {
        // resource not found
        sendError(ErrorType.Management, callback,
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
              sendReply(IIPPacketAction.Unlisten, callback).done();
            }).error((x) => sendError(ErrorType.Exception, callback,
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
          sendError(ErrorType.Management, callback,
              ExceptionCode.MethodNotFound.index);
        }
      } else {
        // resource not found
        sendError(ErrorType.Management, callback,
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

            sendReply(IIPPacketAction.ResourceHistory, callback)
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
                  sendReply(IIPPacketAction.SetProperty, callback).done();
                })
                ..error((x) {
                  sendError(x.type, callback, x.code, x.message);
                });
            } else {
              /*
#if NETSTANDARD1_5
                              var pi = r.GetType().GetTypeInfo().GetProperty(pt.Name);
#else
                              var pi = r.GetType().GetProperty(pt.Name);
#endif*/

              var pi = null; // pt.Info;

              if (pi != null) {
                if (r.instance?.applicable(_session as Session,
                        ActionType.SetProperty, pt, this) ==
                    Ruling.Denied) {
                  sendError(ErrorType.Exception, callback,
                      ExceptionCode.SetPropertyDenied.index);
                  return;
                }

                if (pi == null) {
                  sendError(ErrorType.Management, callback,
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
                  sendReply(IIPPacketAction.SetProperty, callback).done();
                } catch (ex) {
                  sendError(ErrorType.Exception, callback, 0, ex.toString());
                }
              } else {
                // pt found, pi not found, this should never happen
                sendError(ErrorType.Management, callback,
                    ExceptionCode.PropertyNotFound.index);
              }
            }
          });
        } else {
          // property not found
          sendError(ErrorType.Management, callback,
              ExceptionCode.PropertyNotFound.index);
        }
      } else {
        // resource not found
        sendError(ErrorType.Management, callback,
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

    (sendRequest(IIPPacketAction.TemplateFromClassName)
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

    (sendRequest(IIPPacketAction.TemplateFromClassId)..addGuid(classId)).done()
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

  /// <summary>
  /// Retrive a resource by its instance Id.
  /// </summary>
  /// <param name="iid">Instance Id</param>
  /// <returns>Resource</returns>
  AsyncReply<IResource?> retrieve(int iid) {
    for (var r in _resources.values)
      if (r.instance?.id == iid) return new AsyncReply<IResource>.ready(r);
    return new AsyncReply<IResource?>.ready(null);
  }

  AsyncReply<List<TypeTemplate>> getLinkTemplates(String link) {
    var reply = new AsyncReply<List<TypeTemplate>>();

    var l = DC.stringToBytes(link);

    (sendRequest(IIPPacketAction.LinkTemplates)
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
    var resource = _resources[id];
    var request = _resourceRequests[id];

    //print("fetch $id");

    if (request != null) {
      if (resource != null && (requestSequence?.contains(id) ?? false))
        return AsyncReply<DistributedResource>.ready(resource);
      return request;
    } else if (resource != null && !resource.distributedResourceSuspended)
      return new AsyncReply<DistributedResource>.ready(resource);

    var reply = new AsyncReply<DistributedResource>();
    _resourceRequests.add(id, reply);

    //print("AttachResource sent ${id}");

    var newSequence =
        requestSequence != null ? List<int>.from(requestSequence) : <int>[];

    newSequence.add(id);

    (sendRequest(IIPPacketAction.AttachResource)..addUint32(id)).done()
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
              Warehouse.getTemplateByClassId(classId, TemplateType.Wrapper);
          if (template?.definedType != null) {
            dr = Warehouse.createInstance(template?.definedType as Type);
            dr.internal_init(this, id, rt[1] as int, rt[2] as String);
          } else {
            dr = new DistributedResource();
            dr.internal_init(this, id, rt[1] as int, rt[2] as String);
          }
        } else
          dr = resource;

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

    (sendRequest(IIPPacketAction.ResourceChildren)
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

    (sendRequest(IIPPacketAction.ResourceParents)
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
      (sendRequest(IIPPacketAction.ClearAllAttributes)
            ..addUint32(resource.instance?.id as int))
          .done()
        ..then((ar) => rt.trigger(true))
        ..error((ex) => rt.triggerError(ex));
    else {
      var attrs = DC.stringArrayToBytes(attributes);
      (sendRequest(IIPPacketAction.ClearAttributes)
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

    (sendRequest(clearAttributes
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
      (sendRequest(IIPPacketAction.GetAllAttributes)
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
      (sendRequest(IIPPacketAction.GetAttributes)
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

      (sendRequest(IIPPacketAction.ResourceHistory)
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

    (sendRequest(IIPPacketAction.QueryLink)
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

    (sendRequest(IIPPacketAction.CreateResource)..addDC(pkt.toDC())).done()
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
    _unsubscrive(resource);
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

    if (info.receivers != null &&
        this._session != null) if (!info.receivers!(this._session!)) return;

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



  AsyncReply<dynamic> staticCall(Guid classId, int index, Map<UInt8, dynamic> parameters)
  {
      var pb = Codec.compose(parameters, this);

      var reply = AsyncReply<dynamic>();
      var c = _callbackCounter++;
      _requests.add(c, reply);


      sendParams()..addUint8((0x40 | IIPPacketAction.StaticCall))
      ..addUint32(c)
      ..addGuid(classId)
      ..addUint8(index)
      ..addDC(pb)
      ..done();

      return reply;
  }

    // AsyncReply<dynamic> Call(String procedureCall, params object[] parameters)
    // {
    //     var args = new Map<byte, object>();
    //     for (byte i = 0; i < parameters.Length; i++)
    //         args.Add(i, parameters[i]);
    //     return Call(procedureCall, args);
    // }

    AsyncReply<dynamic> call(String procedureCall, Map<UInt8, dynamic> parameters)
    {
        var pb = Codec.compose(parameters, this);

        var reply = new AsyncReply<dynamic>();
        var c = _callbackCounter++;
        _requests.add(c, reply);

        var callName = DC.stringToBytes(procedureCall);

        sendParams()..addUint8(0x40 | IIPPacketAction.ProcedureCall)
        ..addUint32(c)
        ..addUint16(callName.length)
        ..addDC(callName)
        ..addDC(pb)
        ..done();

        return reply;
    }

    void iipRequestKeepAlive(int callbackId, DateTime peerTime, int interval)
    {

        int jitter = 0;

        var now = DateTime.now().toUtc();

        if (_lastKeepAliveReceived != null)
        {
            var diff = now.difference(_lastKeepAliveReceived!).inMicroseconds;
            //Console.WriteLine("Diff " + diff + " " + interval);

            jitter =(diff -interval).abs();
        }

        sendParams()
            ..addUint8(0x80 | IIPPacketAction.KeepAlive)
            ..addUint32(callbackId)
            ..addDateTime(now)
            ..addUint32(jitter)
            ..done();

        _lastKeepAliveReceived = now;
    }

}
