class IIPPacketEvent
{
    // Event Manage
    static const int ResourceReassigned = 0;
    static const int ResourceDestroyed = 1;
    static const int ChildAdded = 2;
    static const int ChildRemoved = 3;
    static const int Renamed = 4;
    // Event Invoke
    static const int PropertyUpdated = 0x10;
    static const int EventOccurred = 0x11;

    // Attribute
    static const int AttributesUpdated = 0x18;
}
