class IIPAuthPacketAcknowledge
{
    static const int NoAuthNoAuth = 0x40; // 0b01000000,
    static const int NoAuthCredentials = 0x44; // 0b01000100,
    static const int NoAuthToken = 0x48; //0b01001000,
    static const int NoAuthCertificate = 0x4c; //0b01001100,
    static const int CredentialsNoAuth = 0x50; //0b01010000,
    static const int CredentialsCredentials = 0x54; //0b01010100,
    static const int CredentialsToken = 0x58; //0b01011000,
    static const int CredentialsCertificate = 0x5c; //0b01011100,
    static const int TokenNoAuth = 0x60; //0b01100000,
    static const int TokenCredentials = 0x64; //0b01100100,
    static const int TokenToken = 0x68; //0b01101000,
    static const int TokenCertificate = 0x6c; //0b01101100,
    static const int CertificateNoAuth = 0x70; //0b01110000,
    static const int CertificateCredentials = 0x74; //0b01110100,
    static const int CertificateToken = 0x78; //0b01111000,
    static const int CertificateCertificate = 0x7c; // 0b01111100,
}