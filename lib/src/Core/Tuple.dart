class Tuple {
  final List _list;
  const Tuple(this._list);
  operator [](int index) => _list[index];
  void operator []=(int index, value) {
    _list[index] = value;
  }

  int get length => _list.length;
}

class Tuple2<T1, T2> extends Tuple {
  Tuple2(T1 v1, T2 v2) : super([v1, v2]);
  T1 get value1 => _list[0] as T1;
  T2 get value2 => _list[1] as T2;
}

class Tuple3<T1, T2, T3> extends Tuple {
  Tuple3(T1 v1, T2 v2, T3 v3) : super([v1, v2, v3]);
  T1 get value1 => _list[0] as T1;
  T2 get value2 => _list[1] as T2;
  T3 get value3 => _list[2] as T3;
}

class Tuple4<T1, T2, T3, T4> extends Tuple {
  Tuple4(T1 v1, T2 v2, T3 v3, T4 v4) : super([v1, v2, v3, v4]);
  T1 get value1 => _list[0] as T1;
  T2 get value2 => _list[1] as T2;
  T3 get value3 => _list[2] as T3;
  T4 get value4 => _list[3] as T4;
}

class Tuple5<T1, T2, T3, T4, T5> extends Tuple {
  Tuple5(T1 v1, T2 v2, T3 v3, T4 v4, T5 v5) : super([v1, v2, v3, v4, v5]);
  T1 get value1 => _list[0] as T1;
  T2 get value2 => _list[1] as T2;
  T3 get value3 => _list[2] as T3;
  T4 get value4 => _list[3] as T4;
  T5 get value5 => _list[4] as T5;
}

class Tuple6<T1, T2, T3, T4, T5, T6> extends Tuple {
  Tuple6(T1 v1, T2 v2, T3 v3, T4 v4, T5 v5, T6 v6)
      : super([v1, v2, v3, v4, v5, v6]);
  T1 get value1 => _list[0] as T1;
  T2 get value2 => _list[1] as T2;
  T3 get value3 => _list[2] as T3;
  T4 get value4 => _list[3] as T4;
  T5 get value5 => _list[4] as T5;
  T6 get value6 => _list[5] as T6;
}

class Tuple7<T1, T2, T3, T4, T5, T6, T7> extends Tuple {
  Tuple7(T1 v1, T2 v2, T3 v3, T4 v4, T5 v5, T6 v6, T7 v7)
      : super([v1, v2, v3, v4, v5, v6, v5]);
  T1 get value1 => _list[0] as T1;
  T2 get value2 => _list[1] as T2;
  T3 get value3 => _list[2] as T3;
  T4 get value4 => _list[3] as T4;
  T5 get value5 => _list[4] as T5;
  T6 get value6 => _list[5] as T6;
  T7 get value7 => _list[6] as T7;
}
