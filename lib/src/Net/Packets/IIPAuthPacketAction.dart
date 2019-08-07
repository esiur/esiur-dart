class IIPAuthPacketAction
{
    // Authenticate
    static const int AuthenticateHash = 0;


    //Challenge,
    //CertificateRequest,
    //CertificateReply,
    //EstablishRequest,
    //EstablishReply

    static const int NewConnection = 0x20;
    static const int ResumeConnection = 0x21;
    static const int ConnectionEstablished = 0x28;
}