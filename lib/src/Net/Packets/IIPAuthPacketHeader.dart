
import '../../Data/IntType.dart';

class IIPAuthPacketHeader
{
    static UInt8 Version = UInt8(0);
    static UInt8 Domain = UInt8(1);
    static UInt8 SupportedAuthentications  = UInt8(2);
    static UInt8 SupportedHashAlgorithms  = UInt8(3);
    static UInt8 SupportedCiphers  = UInt8(4);
    static UInt8 SupportedCompression = UInt8(5);
    static UInt8 SupportedPersonalAuth  = UInt8(6);
    static UInt8 Nonce = UInt8(7);
    static UInt8 Username  = UInt8(8);
    static UInt8 TokenIndex = UInt8(9);
    static UInt8 CertificateId  = UInt8(10);
    static UInt8 CachedCertificates  = UInt8(11);
    static UInt8 CipherType = UInt8(12);
    static UInt8 CipherKey = UInt8(13);
    static UInt8 SoftwareIdentity = UInt8(14);
    static UInt8 Referrer = UInt8(15);
    static UInt8 Time = UInt8(16);
    static UInt8 Certificate = UInt8(17);
    static UInt8 IPv4  = UInt8(18);
}