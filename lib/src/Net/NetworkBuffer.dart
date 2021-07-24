/*
 
Copyright (c) 2019 Ahmed Kh. Zamil

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

import '../Data/DC.dart';
import 'dart:core';

class NetworkBuffer {
  DC _data = new DC(0);

  int _neededDataLength = 0;

  NetworkBuffer() {}

  bool get protected => _neededDataLength > _data.length;

  int get available => _data.length;

  void holdForNextWrite(DC src, int offset, int size) {
    holdFor(src, offset, size, size + 1);
  }

  void holdFor(DC src, int offset, int size, int needed) {
    //lock (syncLock)
    //{
    if (size >= needed) throw new Exception("Size >= Needed !");

    //trim = true;
    _data = DC.combine(src, offset, size, _data, 0, _data.length);
    _neededDataLength = needed;

    //}
  }

  void holdForNeeded(DC src, int needed) {
    holdFor(src, 0, src.length, needed);
  }

  bool protect(DC data, int offset, int needed) {
    int dataLength = _data.length - offset;

    // protection
    if (dataLength < needed) {
      holdFor(data, offset, dataLength, needed);
      return true;
    } else
      return false;
  }

  void write(DC src, int offset, int length) {
    //lock(syncLock)
    _data.append(src, offset, length);
  }

  bool get canRead {
    if (_data.length == 0) return false;
    if (_data.length < _neededDataLength) return false;

    return true;
  }

  DC? read() {
    //lock (syncLock)
    //{
    if (_data.length == 0) return null;

    DC? rt = null;

    if (_neededDataLength == 0) {
      rt = _data;
      _data = new DC(0);
    } else {
      if (_data.length >= _neededDataLength) {
        rt = _data;
        _data = new DC(0);
        _neededDataLength = 0;
        return rt;
      } else {
        return null;
      }
    }
    //}

    return rt;
  }
}
