class FactoryEntry {
  final Type type;
  final Function instanceCreator;
  final Function arrayCreator;

  FactoryEntry(this.type, this.instanceCreator, this.arrayCreator);
}
