class IIPAuthPacketInitialize
{
    static int NoAuthNoAuth = 0x0; //0b00000000,
    static int NoAuthCredentials = 0x4; //0b00000100,
    static int NoAuthToken = 0x8; //0b00001000,
    static int NoAuthCertificate = 0xC; //0b00001100,
    static int CredentialsNoAuth = 0x10; //0b00010000,
    static int CredentialsCredentials = 0x14; //0b00010100,
    static int CredentialsToken = 0x18; //0b00011000,
    static int CredentialsCertificate = 0x1c; //0b00011100,
    static int TokenNoAuth = 0x20; //0b00100000,
    static int TokenCredentials = 0x24; //0b00100100,
    static int TokenToken = 0x28; //0b00101000,
    static int TokenCertificate = 0x2c; //0b00101100,
    static int CertificateNoAuth = 0x30; //0b00110000,
    static int CertificateCredentials = 0x34; // 0b00110100,
    static int CertificateToken = 0x38; //0b00111000,
    static int CertificateCertificate = 0x3c; //0b00111100,
}