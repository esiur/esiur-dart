class IntType<T extends num> {
  T _value;

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

  
  IntType<T> operator +(IntType<T> other) {
    if (this is Int8)
      return new Int8(this._value + other._value as int) as IntType<T>;
    else if (this is UInt8)
      return new UInt8(this._value + other._value as int) as IntType<T>;
    else if (this is Int16)
      return new Int16(this._value + other._value as int) as IntType<T>;
    else if (this is UInt16)
      return new UInt16(this._value + other._value as int) as IntType<T>;
    else if (this is Int32)
      return new Int32(this._value + other._value as int) as IntType<T>;
    else if (this is UInt32)
      return new UInt32(this._value + other._value as int) as IntType<T>;

    return new IntType(this._value + other._value as int) as IntType<T>;
  }



  IntType<T> operator -(IntType<T> other) {
    if (this is Int8)
      return new Int8(this._value - other._value as int) as IntType<T>;
    else if (this is UInt8)
      return new UInt8(this._value - other._value as int) as IntType<T>;
    else if (this is Int16)
      return new Int16(this._value - other._value as int) as IntType<T>;
    else if (this is UInt16)
      return new UInt16(this._value - other._value as int) as IntType<T>;
    else if (this is Int32)
      return new Int32(this._value - other._value as int) as IntType<T>;
    else if (this is UInt32)
      return new UInt32(this._value - other._value as int) as IntType<T>;

    return new IntType(this._value - other._value as int) as IntType<T>;
  }

  T toNum() => _value;

  @override
  String toString() => _value.toString();

  @override
  int get hashCode => _value.hashCode;
}

class Int32 extends IntType<int> {
  Int32(int value) : super(value);
}

class Int16 extends IntType<int> {
  Int16(int value) : super(value);
}

class Int8 extends IntType<int> {
  Int8(int value) : super(value);
}

class UInt32 extends IntType<int> {
  UInt32(int value) : super(value);
}

class UInt16 extends IntType<int> {
  UInt16(int value) : super(value);
}

class UInt8 extends IntType<int> {
  UInt8(int value) : super(value);
}

class Float32 extends IntType<double> {
  Float32(double value) : super(value);
}


extension IntTypeCasting on int {
  T cast<T>() {
    switch(T){
      case Int8: return Int8(this) as T;
      case UInt8: return UInt8(this) as T;
      case Int16: return Int16(this) as T;
      case UInt16: return UInt16(this) as T;
      case Int32: return Int32(this) as T;
      case UInt32: return UInt32(this) as T;
    }

    return IntType(this) as T;
  }
}

extension Float32Casting on double {
  T cast<T>() {

    if (T == Float32)
      return Float32(this) as T;
    return IntType(this) as T;
  }
}
