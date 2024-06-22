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
import 'package:esiur/esiur.dart';

import '../../Data/DC.dart';
import 'IIPAuthPacketAction.dart';
import 'IIPAuthPacketCommand.dart';
import '../../Security/Authority/AuthenticationMethod.dart';
import 'IIPAuthPacketEvent.dart';

class IIPAuthPacket {
  int command = 0;
  int initialization = 0;
  int acknowledgement = 0;
  int action = 0;
  int event = 0;

  AuthenticationMethod localMethod = AuthenticationMethod.None;
  AuthenticationMethod remoteMethod = AuthenticationMethod.None;

  int errorCode = 0;
  String message = "";

  int publicKeyAlgorithm = 0;
  int hashAlgorithm = 0;

  DC? certificate;
  DC? challenge;
  DC? asymetricEncryptionKey;
  DC? sessionId;

  TransmissionType? dataType;

  int reference = 0;

  int _dataLengthNeeded = 0;

  bool _notEnough(int offset, int ends, int needed) {
    if (offset + needed > ends) {
      _dataLengthNeeded = needed - (ends - offset);
      return true;
    } else
      return false;
  }

  toString() {
    return command.toString() + " " + action.toString();
  }

  int parse(DC data, int offset, int ends) {

    var oOffset = offset;

    if (_notEnough(offset, ends, 1)) 
      return -_dataLengthNeeded;

    command = (data[offset] >> 6);

    if (command == IIPAuthPacketCommand.Initialize) {

      localMethod = AuthenticationMethod.values[((data[offset] >> 4) & 0x3)];
      remoteMethod = AuthenticationMethod.values[((data[offset] >> 2) & 0x3)];

      initialization = (data[offset++] & 0xFC); // remove last two reserved LSBs

      if (_notEnough(offset, ends, 1)) 
          return -_dataLengthNeeded;

      var parsed = TransmissionType.parse(data, offset, ends);

      if (parsed.type == null) 
          return -parsed.size;

      dataType = parsed.type;
      offset += parsed.size;

    } else if (command == IIPAuthPacketCommand.Acknowledge) {

      localMethod = AuthenticationMethod.values[((data[offset] >> 4) & 0x3)];
      remoteMethod = AuthenticationMethod.values[((data[offset] >> 2) & 0x3)];

      acknowledgement =
          (data[offset++] & 0xFC); // remove last two reserved LSBs

      if (_notEnough(offset, ends, 1)) 
          return -_dataLengthNeeded;

      var parsed = TransmissionType.parse(data, offset, ends);

      if (parsed.type == null) 
          return -parsed.size;

      dataType = parsed.type;
      offset += parsed.size;

    } else if (command == IIPAuthPacketCommand.Action) {

      action = (data[offset++]);
      if (action == IIPAuthPacketAction.AuthenticateHash ||
          action == IIPAuthPacketAction.AuthenticatePublicHash ||
          action == IIPAuthPacketAction.AuthenticatePrivateHash ||
          action == IIPAuthPacketAction.AuthenticatePublicPrivateHash) {

        if (_notEnough(offset, ends, 3)) 
            return -_dataLengthNeeded;

        hashAlgorithm = data[offset++];

        var hashLength = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, hashLength)) 
            return -_dataLengthNeeded;

        challenge = data.clip(offset, hashLength);
        offset += hashLength;

      } else if (action == IIPAuthPacketAction.AuthenticatePrivateHashCert ||
          action == IIPAuthPacketAction.AuthenticatePublicPrivateHashCert) {

        if (_notEnough(offset, ends, 3)) 
            return -_dataLengthNeeded;

        hashAlgorithm = data[offset++];

        var hashLength = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, hashLength)) 
            return -_dataLengthNeeded;

        challenge = data.clip(offset, hashLength);
        offset += hashLength;

        if (_notEnough(offset, ends, 2)) 
            return -_dataLengthNeeded;

        var certLength = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, certLength)) 
            return -_dataLengthNeeded;

        certificate = data.clip(offset, certLength);

        offset += certLength;

      } else if (action == IIPAuthPacketAction.IAuthPlain) {
        
        if (_notEnough(offset, ends, 5)) 
            return -_dataLengthNeeded;

        reference = data.getUint32(offset);
        offset += 4;

        var parsed = TransmissionType.parse(data, offset, ends);

        if (parsed.type == null) 
            return -parsed.size;

        dataType = parsed.type;
        offset += parsed.size;

      } else if (action == IIPAuthPacketAction.IAuthHashed) {

        if (_notEnough(offset, ends, 7)) 
            return -_dataLengthNeeded;

        reference = data.getUint32(offset);
        offset += 4;

        hashAlgorithm = data[offset++];

        var cl = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, cl)) 
            return -_dataLengthNeeded;

        challenge = data.clip(offset, cl);

        offset += cl;

      } else if (action == IIPAuthPacketAction.IAuthEncrypted) {

        if (_notEnough(offset, ends, 7)) 
            return -_dataLengthNeeded;

        reference = data.getUint32(offset);
        offset += 4;

        publicKeyAlgorithm = data[offset++];

        var cl = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, cl)) 
            return -_dataLengthNeeded;

        challenge = data.clip(offset, cl);

        offset += cl;

      } else if (action == IIPAuthPacketAction.EstablishNewSession) {
        // Nothing here
      } else if (action == IIPAuthPacketAction.EstablishResumeSession) {

        if (_notEnough(offset, ends, 1)) 
            return -_dataLengthNeeded;

        var sessionLength = data[offset++];

        if (_notEnough(offset, ends, sessionLength)) 
            return -_dataLengthNeeded;

        sessionId = data.clip(offset, sessionLength);

        offset += sessionLength;

      } else if (action == IIPAuthPacketAction.EncryptKeyExchange) {

        if (_notEnough(offset, ends, 2)) 
            return -_dataLengthNeeded;

        var keyLength = data.getUint16(offset);

        offset += 2;

        if (_notEnough(offset, ends, keyLength)) 
            return -_dataLengthNeeded;

        asymetricEncryptionKey = data.clip(offset, keyLength);

        offset += keyLength;

      } else if (action == IIPAuthPacketAction.RegisterEndToEndKey ||
          action == IIPAuthPacketAction.RegisterHomomorphic) {

        if (_notEnough(offset, ends, 3)) 
            return -_dataLengthNeeded;

        publicKeyAlgorithm = data[offset++];

        var keyLength = data.getUint16(offset);

        offset += 2;

        if (_notEnough(offset, ends, keyLength)) 
            return -_dataLengthNeeded;

        asymetricEncryptionKey = data.clip(offset, keyLength);

        offset += keyLength;

      }
    } else if (command == IIPAuthPacketCommand.Event) {

      event = data[offset++];

      if (event == IIPAuthPacketEvent.ErrorTerminate ||
          event == IIPAuthPacketEvent.ErrorMustEncrypt ||
          event == IIPAuthPacketEvent.ErrorRetry) {

        if (_notEnough(offset, ends, 3)) 
            return -_dataLengthNeeded;

        errorCode = data[offset++];
        var msgLength = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, msgLength)) 
            return -_dataLengthNeeded;

        message = data.getString(offset, msgLength);

        offset += msgLength;

      } else if (event == IIPAuthPacketEvent.IndicationEstablished) {

        if (_notEnough(offset, ends, 1)) 
            return -_dataLengthNeeded;

        var sessionLength = data[offset++];

        if (_notEnough(offset, ends, sessionLength)) 
            return -_dataLengthNeeded;

        sessionId = data.clip(offset, sessionLength);

        offset += sessionLength;

      } else if (event == IIPAuthPacketEvent.IAuthPlain ||
          event == IIPAuthPacketEvent.IAuthHashed ||
          event == IIPAuthPacketEvent.IAuthEncrypted) {

        if (_notEnough(offset, ends, 1)) 
            return -_dataLengthNeeded;

        var parsed = TransmissionType.parse(data, offset, ends);

        if (parsed.type == null) 
            return -parsed.size;

        dataType = parsed.type;
        offset += parsed.size;
      }
    }

    return offset - oOffset;
  }
}
