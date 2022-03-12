/*
* Copyright (c) 2019 Ahmed Kh. Zamil
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'dart:typed_data';
import 'dart:convert';
import 'BinaryList.dart';
import 'dart:collection';
import 'Guid.dart';

const bool kIsWeb = identical(0, 0.0);

/**
 * Created by Ahmed Zamil on 6/10/2019.
 */

const UNIX_EPOCH = 621355968000000000;
const TWO_PWR_32 = (1 << 16) * (1 << 16);

class DC with IterableMixin<int> {
  late Uint8List _data;
  late ByteData _dv;

  DC(int length) {
    _data = new Uint8List(length);
    _dv = ByteData.view(_data.buffer);
  }

  DC.fromUint8Array(Uint8List array) {
    _data = array;
    _dv = ByteData.view(_data.buffer);
  }

  DC.fromList(List<int> list) {
    _data = Uint8List.fromList(list);
    _dv = ByteData.view(_data.buffer);
  }

  String toHex([String separator = " ", int? offset, int? length]) {
    var start = offset ?? 0;
    var count = length ?? _data.length - start;

    if (count == 0) return "";

    var rt = _data[start].toRadixString(16).padLeft(2, '0');

    for (var i = start + 1; i < count; i++) {
      rt += separator + _data[i].toRadixString(16).padLeft(2, '0');
    }

    return rt;
  }

  DC.fromHex(String hex, [String separator = ' ']) {
    var list =
        hex.split(separator).map((e) => int.parse(e, radix: 16)).toList();
    _data = Uint8List.fromList(list);
    _dv = ByteData.view(_data.buffer);
  }

  int operator [](int index) => _data[index];
  operator []=(int index, int value) => _data[index] = value;
  int get length => _data.length;

  Iterator<int> get iterator => _data.iterator;

  static DC hexToBytes(String value) {
    // convert hex to Uint8Array
    var rt = new DC(value.length ~/ 2);
    for (var i = 0; i < rt.length; i++)
      rt[i] = int.parse(value.substring(i * 2, 2), radix: 16);
    return rt;
  }

  static DC boolToBytes(bool value) {
    var rt = new DC(1);
    rt.setBoolean(0, value);
    return rt;
  }

  static DC guidToBytes(Guid value) {
    var rt = new DC(16);
    rt.setGuid(0, value);
    return rt;
  }

  static DC int8ToBytes(int value) {
    var rt = new DC(1);
    rt.setInt8(0, value);
    return rt;
  }

  static DC int8ArrayToBytes(Int8List value) {
    var rt = new DC(value.length);
    for (var i = 0; i < value.length; i++) rt.setInt8(i, value[i]);
    return rt;
  }

  static DC uint8ToBytes(int value) {
    var rt = new DC(1);
    rt.setUint8(0, value);
    return rt;
  }

  static DC uint8ArrayToBytes(Uint8List value) {
    var rt = new DC(value.length);
    for (var i = 0; i < value.length; i++) rt.setUint8(i, value[i]);
    return rt;
  }

  static DC charToBytes(int value) {
    var rt = new DC(2);
    rt.setChar(0, value);
    return rt;
  }

  static DC int16ToBytes(int value, [Endian endian = Endian.little]) {
    var rt = new DC(2);
    rt.setInt16(0, value, endian);
    return rt;
  }

  static DC int16ArrayToBytes(Int16List value) {
    var rt = new DC(value.length * 2);
    for (var i = 0; i < value.length; i++) rt.setInt16(i * 2, value[i]);
    return rt;
  }

  static DC uint16ToBytes(int value, [Endian endian = Endian.little]) {
    var rt = new DC(2);
    rt.setUint16(0, value, endian);
    return rt;
  }

  static DC uint16ArrayToBytes(Uint16List value) {
    var rt = new DC(value.length * 2);
    for (var i = 0; i < value.length; i++) rt.setUint16(i * 2, value[i]);
    return rt;
  }

  static DC int32ToBytes(int value, [Endian endian = Endian.little]) {
    var rt = new DC(4);
    rt.setInt32(0, value, endian);
    return rt;
  }

  static DC int32ArrayToBytes(Int32List value) {
    var rt = new DC(value.length * 4);
    for (var i = 0; i < value.length; i++) rt.setInt32(i * 4, value[i]);
    return rt;
  }

  static DC uint32ToBytes(int value, [Endian endian = Endian.little]) {
    var rt = new DC(4);
    rt.setUint32(0, value, endian);
    return rt;
  }

  static DC uint32ArrayToBytes(Uint32List value) {
    var rt = new DC(value.length * 4);
    for (var i = 0; i < value.length; i++) rt.setUint32(i * 4, value[i]);
    return rt;
  }

  static DC float32ToBytes(double value, [Endian endian = Endian.little]) {
    var rt = new DC(4);
    rt.setFloat32(0, value, endian);
    return rt;
  }

  static DC float32ArrayToBytes(Float32List value) {
    var rt = new DC(value.length * 4);
    for (var i = 0; i < value.length; i++) rt.setFloat32(i * 4, value[i]);
    return rt;
  }

  static DC int64ToBytes(int value, [Endian endian = Endian.little]) {
    var rt = new DC(8);
    rt.setInt64(0, value, endian);
    return rt;
  }

  static DC int64ArrayToBytes(Int64List value) {
    var rt = new DC(value.length * 8);
    for (var i = 0; i < value.length; i++) rt.setInt64(i * 8, value[i]);
    return rt;
  }

  static DC uint64ToBytes(int value, [Endian endian = Endian.little]) {
    var rt = new DC(8);
    rt.setUint64(0, value, endian);
    return rt;
  }

  static DC uint64ArrayToBytes(Uint64List value) {
    var rt = new DC(value.length * 8);
    for (var i = 0; i < value.length; i++) rt.setUint64(i * 8, value[i]);
    return rt;
  }

  static DC float64ToBytes(double value, [Endian endian = Endian.little]) {
    var rt = new DC(8);
    rt.setFloat64(0, value, endian);
    return rt;
  }

  static DC float64ArrayToBytes(Float64List value) {
    var rt = new DC(value.length * 8);
    for (var i = 0; i < value.length; i++) rt.setFloat64(i * 8, value[i]);
    return rt;
  }

  static DC dateTimeToBytes(DateTime value, [Endian endian = Endian.little]) {
    var rt = new DC(8);
    rt.setDateTime(0, value, endian);
    return rt;
  }

  static DC dateTimeArrayToBytes(List<DateTime> value, [Endian endian = Endian.little]) {
    var rt = new DC(value.length * 8);
    for (var i = 0; i < value.length; i++) rt.setDateTime(i * 8, value[i], endian);
    return rt;
  }

  static DC stringToBytes(String value) {
    var bytes = utf8.encode(value);
    var rt = new DC.fromList(bytes);
    return rt;
  }

  DC append(DC src, int offset, int length) {
    //if (!(src is DC))
    //  src = new DC(src);

    var appendix = src.clip(offset, length);
    var rt = new DC(this.length + appendix.length);
    rt.set(this, 0, 0, this.length);
    rt.set(appendix, 0, this.length, appendix.length);

    this._data = rt._data;
    this._dv = rt._dv;

    return this;
  }

  void set(DC src, int srcOffset, int dstOffset, int length) {
    _data.setRange(dstOffset, dstOffset + length, src._data, srcOffset);
  }

  static DC combine(a, int aOffset, int aLength, b, int bOffset, int bLength) {
    if (!(a is DC)) a = DC.fromList(a as List<int>);
    if (!(b is DC)) b = DC.fromList(b as List<int>);

    a = a.clip(aOffset, aLength);
    b = b.clip(bOffset, bLength);

    var rt = new DC(a.length + b.length);

    rt.set(a, 0, 0, a.length);
    rt.set(b, 0, a.length, b.length);
    return rt;
  }

  DC clip(int offset, int length) {
    return DC.fromUint8Array(
        Uint8List.fromList(_data.getRange(offset, offset + length).toList()));
  }

  int getInt8(int offset) {
    return _dv.getInt8(offset);
  }

  int getUint8(int offset) {
    return _data[offset]; // this.dv.getUint8(offset);
  }

  int getInt16(int offset, [Endian endian = Endian.little]) {
    return _dv.getInt16(offset, endian);
  }

  int getUint16(int offset, [Endian endian = Endian.little]) {
    return _dv.getUint16(offset, endian);
  }

  int getInt32(int offset, [Endian endian = Endian.little]) {
    return _dv.getInt32(offset, endian);
  }

  int getUint32(int offset, [Endian endian = Endian.little]) {
    return _dv.getUint32(offset, endian);
  }

  double getFloat32(int offset, [Endian endian = Endian.little]) {
    return _dv.getFloat32(offset, endian);
  }

  double getFloat64(int offset, [Endian endian = Endian.little]) {
    return _dv.getFloat64(offset, endian);
  }

  void setInt8(int offset, int value) {
    return _dv.setInt8(offset, value);
  }

  void setUint8(int offset, int value) {
    return _dv.setUint8(offset, value);
  }

  void setInt16(int offset, int value, [Endian endian = Endian.little]) {
    return _dv.setInt16(offset, value, endian);
  }

  void setUint16(int offset, int value, [Endian endian = Endian.little]) {
    return _dv.setUint16(offset, value, endian);
  }

  void setInt32(int offset, int value, [Endian endian = Endian.little]) {
    return _dv.setInt32(offset, value, endian);
  }

  void setUint32(int offset, int value, [Endian endian = Endian.little]) {
    return _dv.setUint32(offset, value, endian);
  }

  void setFloat32(int offset, double value, [Endian endian = Endian.little]) {
    return _dv.setFloat32(offset, value, endian);
  }

  void setFloat64(int offset, double value, [Endian endian = Endian.little]) {
    return _dv.setFloat64(offset, value, endian);
  }

  Int8List getInt8Array(int offset, int length) {
    return _data.buffer.asInt8List(offset, length);
  }

  Uint8List getUint8Array(int offset, int length) {
    return _data.buffer.asUint8List(offset, length);
  }

  Int16List getInt16Array(int offset, int length) {
    return _data.buffer.asInt16List(offset, length);
  }

  Uint16List getUint16Array(int offset, int length) {
    return _data.buffer.asUint16List(offset, length);
  }

  Int32List getInt32Array(int offset, int length) {
    return _data.buffer.asInt32List(offset, length);
  }

  Uint32List getUint32Array(int offset, int length) {
    return _data.buffer.asUint32List(offset, length);
  }

  Float32List getFloat32Array(int offset, int length) {
    return _data.buffer.asFloat32List(offset, length);
  }

  Float64List getFloat64Array(int offset, int length) {
    return _data.buffer.asFloat64List(offset, length);
  }

  //Int64List
  getInt64Array(int offset, int length) {
    if (kIsWeb) {
      var rt = <int>[];
      for (var i = offset; i < length; i += 4) rt.add(this.getInt64(offset));
      return rt;
    } else {
      return _data.buffer.asInt64List(offset, length);
    }
  }

  //Uint64List
  getUint64Array(int offset, int length) {
    if (kIsWeb) {
      var rt = <int>[];
      for (var i = offset; i < length; i += 4) rt.add(this.getUint64(offset));
      return rt;
    } else {
      return _data.buffer.asUint64List(offset, length);
    }
  }

  bool getBoolean(int offset) {
    return this.getUint8(offset) > 0;
  }

  void setBoolean(int offset, bool value) {
    this.setUint8(offset, value ? 1 : 0);
  }

  String getChar(int offset) {
    return String.fromCharCode(this.getUint16(offset));
  }

  void setChar(int offset, int value) {
    this.setUint16(offset, value); //value.codeUnitAt(0));
  }

  String getHex(int offset, int length) {
    var rt = "";
    for (var i = offset; i < offset + length; i++) {
      var h = _data[i].toRadixString(16);
      rt += h.length == 1 ? "0" + h : h;
    }

    return rt;
  }

  /*
    List<T> toList<T>(offset, length)
    {
        var rt = new List<T>();
        for(var i = 0; i < length; i++)
          rt[i] = _data[offset+i] as T;
        return rt;
    }*/

  Uint8List toArray() => _data;

  String getString(int offset, int length) {
    var bytes = clip(offset, length)._data; // toList(offset, length);
    var str = utf8.decode(bytes);
    return str;
  }

  int getInt64(int offset, [Endian endian = Endian.little]) {
    if (kIsWeb) {
      if (endian == Endian.big) {
        var bi = BigInt.from(0);

        bi |= BigInt.from(getUint8(offset++)) << 56;
        bi |= BigInt.from(getUint8(offset++)) << 48;
        bi |= BigInt.from(getUint8(offset++)) << 40;
        bi |= BigInt.from(getUint8(offset++)) << 32;
        bi |= BigInt.from(getUint8(offset++)) << 24;
        bi |= BigInt.from(getUint8(offset++)) << 16;
        bi |= BigInt.from(getUint8(offset++)) << 8;
        bi |= BigInt.from(getUint8(offset++));

        return bi.toInt();
      } else {
        var bi = BigInt.from(0);

        bi |= BigInt.from(getUint8(offset++));
        bi |= BigInt.from(getUint8(offset++)) << 8;
        bi |= BigInt.from(getUint8(offset++)) << 16;
        bi |= BigInt.from(getUint8(offset++)) << 24;
        bi |= BigInt.from(getUint8(offset++)) << 32;
        bi |= BigInt.from(getUint8(offset++)) << 40;
        bi |= BigInt.from(getUint8(offset++)) << 48;
        bi |= BigInt.from(getUint8(offset++)) << 56;

        return bi.toInt();
      }

      //var l = this.getUint32(offset);
      //var h = this.getUint32(offset + 4);
      //return h * TWO_PWR_32 + ((l >= 0) ? l : TWO_PWR_32 + l);
    } else {
      return _dv.getUint64(offset);
    }
  }

  int getUint64(int offset, [Endian endian = Endian.little]) {
     if (kIsWeb) {
      if (endian == Endian.big) {
        var bi = BigInt.from(0);

        bi |= BigInt.from(getUint8(offset++)) << 56;
        bi |= BigInt.from(getUint8(offset++)) << 48;
        bi |= BigInt.from(getUint8(offset++)) << 40;
        bi |= BigInt.from(getUint8(offset++)) << 32;
        bi |= BigInt.from(getUint8(offset++)) << 24;
        bi |= BigInt.from(getUint8(offset++)) << 16;
        bi |= BigInt.from(getUint8(offset++)) << 8;
        bi |= BigInt.from(getUint8(offset++));

        return bi.toInt();
      } else {
        var bi = BigInt.from(0);

        bi |= BigInt.from(getUint8(offset++));
        bi |= BigInt.from(getUint8(offset++)) << 8;
        bi |= BigInt.from(getUint8(offset++)) << 16;
        bi |= BigInt.from(getUint8(offset++)) << 24;
        bi |= BigInt.from(getUint8(offset++)) << 32;
        bi |= BigInt.from(getUint8(offset++)) << 40;
        bi |= BigInt.from(getUint8(offset++)) << 48;
        bi |= BigInt.from(getUint8(offset++)) << 56;

        return bi.toInt();
      }

      //var l = this.getUint32(offset);
      //var h = this.getUint32(offset + 4);
      //return h * TWO_PWR_32 + ((l >= 0) ? l : TWO_PWR_32 + l);
    } else {
      return _dv.getUint64(offset);
    }
    // if (kIsWeb) {
    //   print("getUint64");
    //   var l = this.getUint32(offset);
    //   var h = this.getUint32(offset + 4);
    //   return h * TWO_PWR_32 + ((l >= 0) ? l : TWO_PWR_32 + l);
    // } else {
    //   return _dv.getInt64(offset);
    // }
  }

  void setInt64(int offset, int value, [Endian endian = Endian.little]) {
    if (kIsWeb) {
      var bi = BigInt.from(value);
      var byte = BigInt.from(0xFF);

      if (endian == Endian.big) {
        _dv.setUint8(offset++, ((bi >> 56) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 48) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 40) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 32) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 24) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 16) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 8) & byte).toInt());
        _dv.setUint8(offset++, (bi & byte).toInt());
      } else {
        _dv.setUint8(offset++, ((bi) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 8) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 16) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 24) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 32) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 40) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 48) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 56) & byte).toInt());
      }
    } else {
      _dv.setInt64(offset, value, endian);
    }
  }

  void setUint64(int offset, int value, [Endian endian = Endian.little]) {
    if (kIsWeb) {
      // BigInt a = 33 as BigInt;

      // int l = BigInt value & 0xFFFFFFFF;
      // int h = value >> 32;

      // int h = (value % TWO_PWR_32) | 0;
      // int l = ((value / TWO_PWR_32)) | 0;
      // _dv.setInt32(offset, h, endian);
      // _dv.setInt32(offset + 4, l, endian);
      var bi = BigInt.from(value);
      var byte = BigInt.from(0xFF);

      if (endian == Endian.big) {
        _dv.setUint8(offset++, ((bi >> 56) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 48) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 40) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 32) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 24) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 16) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 8) & byte).toInt());
        _dv.setUint8(offset++, (bi & byte).toInt());
      } else {
        _dv.setUint8(offset++, ((bi) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 8) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 16) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 24) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 32) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 40) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 48) & byte).toInt());
        _dv.setUint8(offset++, ((bi >> 56) & byte).toInt());
      }
    } else {
      _dv.setUint64(offset, value, endian);
    }
  }

  void setDateTime(int offset, DateTime value, [Endian endian = Endian.little]) {
    // Unix Epoch
    var ticks = UNIX_EPOCH + (value.millisecondsSinceEpoch * 10000);
    this.setUint64(offset, ticks, endian);
  }

  DateTime getDateTime(int offset, [Endian endian = Endian.little]) {
    var ticks = this.getUint64(offset, endian);
    // there are 10,000 ticks in a millisecond
    return DateTime.fromMillisecondsSinceEpoch((ticks - UNIX_EPOCH) ~/ 10000);
  }

  Guid getGuid(int offset) {
    return new Guid(this.clip(offset, 16));
  }

  void setGuid(int offset, Guid guid) {
    set(guid.value, 0, offset, 16);
  }

  bool sequenceEqual(ar) {
    if (ar.length != this.length)
      return false;
    else {
      for (var i = 0; i < this.length; i++) if (ar[i] != this[i]) return false;
    }

    return true;
  }

  List<String> getStringArray(int offset, int length) {
    List<String> rt = [];
    var i = 0;

    while (i < length) {
      var cl = this.getUint32(offset + i);
      i += 4;
      rt.add(this.getString(offset + i, cl));
      i += cl;
    }

    return rt;
  }

  static DC stringArrayToBytes(List<String> value) {
    var list = new BinaryList();
    for (var i = 0; i < value.length; i++) {
      var s = DC.stringToBytes(value[i]);
      list
        ..addUint32(s.length)
        ..addUint8Array(s.toArray());
    }

    return list.toDC();
  }
}
