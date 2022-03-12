class IntType {
  int _value = 0;

  bool operator ==(Object other) {
    if (other is IntType)
      return this._value == other._value;
    else if (other is int) return this._value == other;

    return false;
  }

  IntType(this._value);

  bool operator >(IntType other) {
    return this._value > other._value;
  }

  bool operator <(IntType other) {
    return this._value < other._value;
  }

  bool operator >=(IntType other) {
    return this._value >= other._value;
  }

  bool operator <=(IntType other) {
    return this._value <= other._value;
  }

  operator +(IntType other) {
    this._value += other._value;
  }

  operator -(IntType other) {
    this._value -= other._value;
  }

  int toInt() => _value;

  @override
  String toString() => _value.toString();

  @override
  int get hashCode => _value.hashCode;
}

class Int32 extends IntType {
  Int32(int value) : super(value);
}

class Int16 extends IntType {
  Int16(int value) : super(value);
}

class Int8 extends IntType {
  Int8(int value) : super(value);
}

class UInt32 extends IntType {
  UInt32(int value) : super(value);
}

class UInt16 extends IntType {
  UInt16(int value) : super(value);
}

class UInt8 extends IntType {
  UInt8(int value) : super(value);
}
