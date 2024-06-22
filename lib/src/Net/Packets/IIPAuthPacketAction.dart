class IIPAuthPacketAction
{
    static const int NewConnection = 0x20;
    static const int ResumeConnection = 0x21;
    static const int ConnectionEstablished = 0x28;

    static const int AuthenticateHash = 0x80;
    static const int AuthenticatePublicHash = 0x81;
    static const int AuthenticatePrivateHash = 0x82;
    static const int AuthenticatePublicPrivateHash = 0x83;

    static const int AuthenticatePrivateHashCert = 0x88;
    static const int AuthenticatePublicPrivateHashCert = 0x89;

    static const int IAuthPlain = 0x90;
    static const int IAuthHashed = 0x91;
    static const int IAuthEncrypted = 0x92;


    static const int EstablishNewSession = 0x98;
    static const int EstablishResumeSession = 0x99;

    static const int EncryptKeyExchange = 0xA0;

    static const int RegisterEndToEndKey = 0xA8;
    static const int RegisterHomomorphic = 0xA9;
}