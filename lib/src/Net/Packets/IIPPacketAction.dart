class IIPPacketAction {
  // Request Manage
  static const int AttachResource = 0x0;
  static const int ReattachResource = 0x1;
  static const int DetachResource = 0x2;
  static const int CreateResource = 0x3;
  static const int DeleteResource = 0x4;
  static const int AddChild = 0x5;
  static const int RemoveChild = 0x6;
  static const int RenameResource = 0x7;

  // Request Inquire
  static const int TemplateFromClassName = 0x8;
  static const int TemplateFromClassId = 0x9;
  static const int TemplateFromResourceId = 0xA;
  static const int QueryLink = 0xB;
  static const int ResourceHistory = 0xC;
  static const int ResourceChildren = 0xD;
  static const int ResourceParents = 0xE;
  static const int LinkTemplates = 0xF;

  // Request Invoke
  static const int InvokeFunction = 0x10;
  static const int Reserved = 0x11;
  static const int Listen = 0x12;
  static const int Unlisten = 0x13;
  static const int SetProperty = 0x14;

  // Request Attribute
  static const int GetAllAttributes = 0x18;
  static const int UpdateAllAttributes = 0x19;
  static const int ClearAllAttributes = 0x1A;
  static const int GetAttributes = 0x1B;
  static const int UpdateAttributes = 0x1C;
  static const int ClearAttributes = 0x1D;
}
