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
import '../../Data/DC.dart';
import 'IIPAuthPacketAction.dart';
import 'IIPAuthPacketCommand.dart';
import 'IIPAuthPacketMethod.dart';

class IIPAuthPacket
{

    int command;
    int action;

    int errorCode;
    String errorMessage;

    int localMethod;

    DC sourceInfo;

    DC hash;

    DC sessionId;

    int remoteMethod;

    String domain;

    int certificateId;

    String localUsername;

    String remoteUsername;

    DC localPassword;

    DC remotePassword;

    DC localToken;

    DC remoteToken;

    DC asymetricEncryptionKey;

    DC localNonce;

    DC remoteNonce;

    int _dataLengthNeeded;

    bool _notEnough(int offset, int ends, int needed)
    {
        if (offset + needed > ends)
        {
            _dataLengthNeeded = needed - (ends - offset);
            return true;
        }
        else
            return false;
    }

    toString()
    {
        return command.toString() + " " + action.toString(); 
    }

    int parse(DC data, int offset, int ends)
    {
        var oOffset = offset;

        if (_notEnough(offset, ends, 1))
            return -_dataLengthNeeded;

        command = (data[offset] >> 6);

        if (command == IIPAuthPacketCommand.Action)
        {
            action = (data[offset++] & 0x3f);

            if (action == IIPAuthPacketAction.AuthenticateHash)
            {
                if (_notEnough(offset, ends, 32))
                    return -_dataLengthNeeded;

                hash = data.clip(offset, 32);

                //var hash = new byte[32];
                //Buffer.BlockCopy(data, (int)offset, hash, 0, 32);
                //Hash = hash;

                offset += 32;
            }
            else if (action == IIPAuthPacketAction.NewConnection)
            {
                if (_notEnough(offset, ends, 2))
                    return -_dataLengthNeeded;

                var length = data.getUint16(offset);

                offset += 2;

                if (_notEnough(offset, ends, length))
                    return -_dataLengthNeeded;

                sourceInfo = data.clip(offset, length);

                //var sourceInfo = new byte[length];
                //Buffer.BlockCopy(data, (int)offset, sourceInfo, 0, length);
                //SourceInfo = sourceInfo;

                offset += 32;
            }
            else if (action == IIPAuthPacketAction.ResumeConnection
                  || action == IIPAuthPacketAction.ConnectionEstablished)
            {
                //var sessionId = new byte[32];

                if (_notEnough(offset, ends, 32))
                    return -_dataLengthNeeded;

                sessionId = data.clip(offset, 32);

                //Buffer.BlockCopy(data, (int)offset, sessionId, 0, 32);
                //SessionId = sessionId;

                offset += 32;
            }
        }
        else if (command == IIPAuthPacketCommand.Declare)
        {
            remoteMethod = ((data[offset] >> 4) & 0x3);
            localMethod = ((data[offset] >> 2) & 0x3);
            var encrypt = ((data[offset++] & 0x2) == 0x2);


            if (_notEnough(offset, ends, 1))
                return -_dataLengthNeeded;

            var domainLength = data[offset++];
            if (_notEnough(offset, ends, domainLength))
                return -_dataLengthNeeded;

            var domain = data.getString(offset, domainLength);

            this.domain = domain;

            offset += domainLength;
        

            if (remoteMethod == IIPAuthPacketMethod.Credentials)
            {
                if (localMethod == IIPAuthPacketMethod.None)
                {
                    if (_notEnough(offset, ends, 33))
                        return -_dataLengthNeeded;


                    remoteNonce = data.clip(offset, 32);

                    offset += 32;
                    
                    var length = data[offset++];

                    if (_notEnough(offset, ends, length))
                        return -_dataLengthNeeded;

                      remoteUsername = data.getString(offset, length);

                      
                    offset += length;
                }
            }

            if (encrypt)
            {
                if (_notEnough(offset, ends, 2))
                    return -_dataLengthNeeded;

                var keyLength = data.getUint16(offset);

                offset += 2;

                if (_notEnough(offset, ends, keyLength))
                    return -_dataLengthNeeded;

    
                asymetricEncryptionKey = data.clip(offset, keyLength);

                offset += keyLength;
            }
        }
        else if (command == IIPAuthPacketCommand.Acknowledge)
        {
            remoteMethod  = ((data[offset] >> 4) & 0x3);
            localMethod = ((data[offset] >> 2) & 0x3);
            var encrypt = ((data[offset++] & 0x2) == 0x2);

            if (_notEnough(offset, ends, 1))
                return -_dataLengthNeeded;


            if (remoteMethod == IIPAuthPacketMethod.Credentials)
            {
                if (localMethod == IIPAuthPacketMethod.None)
                {
                    if (_notEnough(offset, ends, 32))
                        return -_dataLengthNeeded;

                    remoteNonce = data.clip(offset, 32);
                    offset += 32;

                  }
            }

            if (encrypt)
            {
                if (_notEnough(offset, ends, 2))
                    return -_dataLengthNeeded;

                var keyLength = data.getUint16(offset);

                offset += 2;

                if (_notEnough(offset, ends, keyLength))
                    return -_dataLengthNeeded;

                asymetricEncryptionKey = data.clip(offset, keyLength);

                offset += keyLength;
            }
        }
        else if (command == IIPAuthPacketCommand.Error)
        {
            if (_notEnough(offset, ends, 4))
                return -_dataLengthNeeded;

            offset++;
            errorCode = data[offset++];


            var cl = data.getUint16(offset);
            offset += 2;

            if (_notEnough(offset, ends, cl))
                return -_dataLengthNeeded;

            errorMessage = data.getString(offset, cl);
            offset += cl;

        }


        return offset - oOffset;

    }

}