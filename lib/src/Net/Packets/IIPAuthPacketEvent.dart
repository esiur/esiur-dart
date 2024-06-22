class IIPAuthPacketEvent
{
    static const int ErrorTerminate = 0xC0;
    static const int ErrorMustEncrypt = 0xC1;
    static const int ErrorRetry = 0xC2;

    static const int IndicationEstablished = 0xC8;

    static const int IAuthPlain = 0xD0;
    static const int IAuthHashed = 0xD1;
    static const int IAuthEncrypted = 0xD2;
}