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

/**
 * Created by Ahmed Zamil on 26/07/2019.
 */

import '../Core/AsyncReply.dart';
import 'dart:typed_data';
import 'DC.dart';
import 'Guid.dart';

class BinaryList {
  var _list = <int>[];

  int get length => _list.length;

  void addDateTime(DateTime value, [Endian endian = Endian.little]) {
    _list.addAll(DC.dateTimeToBytes(value, endian));
  }

  void insertDateTime(int position, DateTime value,
      [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.dateTimeToBytes(value, endian));
  }

  void addDateTimeArray(List<DateTime> value, [Endian endian = Endian.little]) {
    _list.addAll(DC.dateTimeArrayToBytes(value, endian));
  }

  void insertDateTimeArray(int position, List<DateTime> value,
      [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.dateTimeArrayToBytes(value, endian));
  }

  void addGuid(Guid value) {
    _list.addAll(DC.guidToBytes(value));
  }

  void insertGuid(int position, Guid value) {
    _list.insertAll(position, DC.guidToBytes(value));
  }

  void addUint8Array(Uint8List value) {
    _list.addAll(value);
  }

  void addDC(DC value) {
    _list.addAll(value.toArray());
  }

  void insertUint8Array(int position, Uint8List value) {
    _list.insertAll(position, value);
  }

  void addString(String value) {
    _list.addAll(DC.stringToBytes(value));
  }

  void insertString(int position, String value) {
    _list.insertAll(position, DC.stringToBytes(value));
  }

  void insertUint8(int position, int value) {
    _list.insert(position, value);
  }

  void addUint8(int value) {
    _list.add(value);
  }

  void addInt8(int value) {
    _list.add(value);
  }

  void insertInt8(int position, int value) {
    _list.insert(position, value);
  }

  void addChar(int value) {
    _list.addAll(DC.charToBytes(value));
  }

  void insertChar(int position, int value) {
    _list.insertAll(position, DC.charToBytes(value));
  }

  void addBoolean(bool value) {
    _list.addAll(DC.boolToBytes(value));
  }

  void insertBoolean(int position, bool value) {
    _list.insertAll(position, DC.boolToBytes(value));
  }

  void addUint16(int value, [Endian endian = Endian.little]) {
    _list.addAll(DC.uint16ToBytes(value, endian));
  }

  void insertUint16(int position, int value, [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.uint16ToBytes(value, endian));
  }

  void addInt16(int value, [Endian endian = Endian.little]) {
    _list.addAll(DC.int16ToBytes(value, endian));
  }

  void insertInt16(int position, int value, [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.int16ToBytes(value, endian));
  }

  void addUint32(int value, [Endian endian = Endian.little]) {
    _list.addAll(DC.uint32ToBytes(value, endian));
  }

  void insertUint32(int position, int value, [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.uint32ToBytes(value, endian));
  }

  void addInt32(int value, [Endian endian = Endian.little]) {
    _list.addAll(DC.int32ToBytes(value, endian));
  }

  void insertInt32(int position, int value, [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.int32ToBytes(value, endian));
  }

  void addUint64(int value, [Endian endian = Endian.little]) {
    _list.addAll(DC.uint64ToBytes(value, endian));
  }

  void insertUint64(int position, int value, [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.uint64ToBytes(value, endian));
  }

  void addInt64(int value, [Endian endian = Endian.little]) {
    _list.addAll(DC.int64ToBytes(value, endian));
  }

  void insertInt64(int position, int value, [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.int64ToBytes(value, endian));
  }

  void addFloat32(double value, [Endian endian = Endian.little]) {
    _list.addAll(DC.float32ToBytes(value, endian));
  }

  void insertFloat32(int position, double value,
      [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.float32ToBytes(value, endian));
  }

  void addFloat64(double value, [Endian endian = Endian.little]) {
    _list.addAll(DC.float64ToBytes(value, endian));
  }

  void insertFloat64(int position, double value,
      [Endian endian = Endian.little]) {
    _list.insertAll(position, DC.float64ToBytes(value, endian));
  }

  /// <summary>
  /// Convert the _list to an array of bytes
  /// </summary>
  /// <returns>Bytes array</returns>
  Uint8List toArray() {
    return Uint8List.fromList(_list);
  }

  DC toDC() {
    return new DC.fromUint8Array(toArray());
  }

  AsyncReply<dynamic> done() {
    return AsyncReply.ready(null);
  }
}
