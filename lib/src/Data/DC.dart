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

/**
 * Created by Ahmed Zamil on 6/10/2019.
 */


const UNIX_EPOCH = 621355968000000000;
const TWO_PWR_32 = (1 << 16) * (1 << 16);

class DC with IterableMixin<int>
{

    Uint8List _data;
    ByteData _dv;

    DC(int length)
    {
      _data = new Uint8List(length);
      _dv = ByteData.view(_data.buffer);
    }

    DC.fromUint8Array(Uint8List array)
    {
      _data = array;
      _dv = ByteData.view(_data.buffer);
    }

    DC.fromList(List<int> list)
    {
      _data = Uint8List.fromList(list);
      _dv = ByteData.view(_data.buffer);
    }

    operator [](index) => _data[index];
    operator []=(index,value) => _data[index] = value;
    int get length => _data.length;

    Iterator<int> get iterator => _data.iterator;

    static DC hexToBytes(String value)
    {
        // convert hex to Uint8Array
        var rt = new DC(value.length~/2);
        for(var i = 0; i < rt.length; i++)
            rt[i] = int.parse(value.substring(i*2, 2), radix: 16);
        return rt;
    }

    static DC boolToBytes(value)
    {
        var rt = new DC(1);
        rt.setBoolean(0, value);
        return rt;
    }


    static DC guidToBytes(Guid value)
    {
      var rt = new DC(16);
      rt.setGuid(0, value);
      return rt;
    }

    static DC guidArrayToBytes(List<Guid> value)
    {
      var rt = new DC(value.length * 16);
      for(var i = 0; i < value.length; i++)
        rt.setGuid(i * 16, value[i]);
      return rt;
    }

    static DC boolArrayToBytes(List<bool> value)
    {
      var rt = new DC(value.length);
      for(var i = 0; i < value.length; i++)
          rt[i] = value[i] ? 1 : 0;
      return rt;
    }

    static DC int8ToBytes(value)
    {
        var rt = new DC(1);
        rt.setInt8(0, value);
        return rt;
    }

    static DC int8ArrayToBytes(Int8List value)
    {
        var rt = new DC(value.length);
        for(var i = 0; i < value.length; i++)
          rt.setInt8(i, value[i]);
        return rt;
    }



    static DC uint8ToBytes(value)
    {
        var rt = new DC(1);
        rt.setUint8(0, value);
        return rt;
    }

    static DC uint8ArrayToBytes(Uint8List value)
    {
        var rt = new DC(value.length);
        for(var i = 0; i < value.length; i++)
          rt.setUint8(i, value[i]);
        return rt;
    }

    static DC charToBytes(int value)
    {
        var rt = new DC(2);
        rt.setChar(0, value);
        return rt;
    }

    static DC charArrayToBytes(Uint16List value)
    {
      var rt = new DC(value.length * 2);
      for(var i = 0; i < value.length; i++)
        rt.setChar(i*2, value[i]);
        
      return rt;
    }

    static DC int16ToBytes(int value)
    {
        var rt = new DC(2);
        rt.setInt16(0, value);
        return rt;
    }

    static DC int16ArrayToBytes(List<int> value)
    {
      var rt = new DC(value.length * 2);
      for(var i = 0; i < value.length; i++)
        rt.setInt16(i*2, value[i]);
      return rt;
    }

    static DC uint16ToBytes(int value)
    {
        var rt = new DC(2);
        rt.setUint16(0, value);
        return rt;
    }

    static DC uint16ArrayToBytes(Uint16List value)
    {
      var rt = new DC(value.length * 2);
      for(var i = 0; i < value.length; i++)
        rt.setUint16(i*2, value[i]);
      return rt;
    }

    static DC int32ToBytes(int value)
    {
        var rt = new DC(4);
        rt.setInt32(0, value);
        return rt;
    }

    static DC int32ArrayToBytes(Int32List value)
    {
      var rt = new DC(value.length * 4);
      for(var i = 0; i < value.length; i++)
        rt.setInt32(i*4, value[i]);
      return rt;
    }

    static DC uint32ToBytes(int value)
    {
        var rt = new DC(4);
        rt.setUint32(0, value);
        return rt;
    }

    static DC uint32ArrayToBytes(Uint32List value)
    {
        var rt = new DC(value.length * 4);
        for(var i = 0; i < value.length; i++)
          rt.setUint32(i*4, value[i]);
        return rt;
    }

    static DC float32ToBytes(double value)
    {
        var rt = new DC(4);
        rt.setFloat32(0, value);
        return rt;
    }

    static DC float32ArrayToBytes(Float32List value)
    {
        var rt = new DC(value.length * 4);
        for(var i = 0; i < value.length; i++)
          rt.setFloat32(i*4, value[i]);
        return rt;
    }

    static DC int64ToBytes(int value)
    {
        var rt = new DC(8);
        rt.setInt64(0, value);
        return rt;
    }

    static DC int64ArrayToBytes(Int64List value)
    {
        var rt = new DC(value.length * 8);
        for(var i = 0; i < value.length; i++)
          rt.setInt64(i*8, value[i]);
        return rt;
    }

    static DC uint64ToBytes(int value)
    {
        var rt = new DC(8);
        rt.setUint64(0, value);
        return rt;
    }

    static DC uint64ArrayToBytes(Uint64List value)
    {
        var rt = new DC(value.length * 8);
        for(var i = 0; i < value.length; i++)
          rt.setUint64(i*8, value[i]);
        return rt;
    }

    static DC float64ToBytes(double value)
    {
        var rt = new DC(8);
        rt.setFloat64(0, value);
        return rt;
    }

    static DC float64ArrayToBytes(Float64List value)
    {
        var rt = new DC(value.length * 8);
        for(var i = 0; i < value.length; i++)
          rt.setFloat64(i*8, value[i]);
        return rt;
    }

    static DC dateTimeToBytes(DateTime value)
    {
        var rt = new DC(8);
        rt.setDateTime(0, value);
        return rt;
    }


    
    static DC dateTimeArrayToBytes(List<DateTime> value)
    {
        var rt = new DC(value.length * 8);
        for(var i = 0; i < value.length; i++)
          rt.setDateTime(i*8, value[i]);
        return rt;
    }


    static DC stringToBytes(String value)
    {
        var bytes = utf8.encode(value);
        var rt = new DC.fromList(bytes);
        return rt;
    }

    static DC stringArrayToBytes(List<String> value)
    {
        var list = new BinaryList();
        for(var i = 0; i < value.length; i++)
        {
            var s = DC.stringToBytes(value[i]);
            list.addUint32(s.length).addUint8Array(s.toArray());
        }

        return list.toDC();
    }

    DC append(DC src, int offset, int length)
    {
        //if (!(src is DC))
          //  src = new DC(src);

        var appendix = src.clip(offset, length);
        var rt = new DC(this.length + appendix.length);
        rt.set(this, 0);
        rt.set(appendix, this.length);

        this._data = rt._data;
        this._dv = rt._dv;

        return this;
    }

    set(DC dc, int offset)
    {
       _data.setRange(offset, offset + dc.length, dc._data);
    }

    static combine(a, aOffset, aLength, b, bOffset, bLength)
    {
        if (!(a is DC))
            a = new DC(a);
        if (!(b is DC))
            b = new DC(b);

        a = a.clip(aOffset, aLength);
        b = b.clip(bOffset, bLength);

        var rt = new DC(a.length  + b.length);

        
        rt.set(a, 0);
        rt.set(b, a.length);
        return rt;
    }

    DC clip(offset, length)
    {
        return DC.fromUint8Array(Uint8List.fromList(_data.getRange(offset, offset + length).toList()));
    }

    getInt8(int offset)
    {
        return _dv.getInt8(offset);
    }

    getUint8(int offset)
    {
        return _data[offset];// this.dv.getUint8(offset);
    }

    getInt16(int offset)
    {
        return _dv.getInt16(offset);
    }

    getUint16(int offset)
    {
        return _dv.getUint16(offset);
    }

    getInt32(int offset)
    {
        return _dv.getInt32(offset);
    }

    getUint32(int offset)
    {
        return _dv.getUint32(offset);
    }

    getFloat32(int offset)
    {
        return _dv.getFloat32(offset);
    }

    getFloat64(int offset)
    {
        return _dv.getFloat64(offset);
    }

    setInt8(int offset, int value)
    {
        return _dv.setInt8(offset, value);
    }

    setUint8(int offset, int value)
    {
        return _dv.setUint8(offset, value);
    }

    setInt16(int offset, int value)
    {
        return _dv.setInt16(offset, value);
    }

    setUint16(int offset, int value)
    {
        return _dv.setUint16(offset, value);
    }

    setInt32(int offset, int value)
    {
        return _dv.setInt32(offset, value);
    }

    setUint32(int offset, int value)
    {
        return _dv.setUint32(offset, value);
    }

    setFloat32(int offset, double value)
    {
        return _dv.setFloat32(offset, value);
    }

    setFloat64(int offset, double value)
    {
        return _dv.setFloat64(offset, value);
    }

    Int8List getInt8Array(int offset, int length)
    {
        return _data.buffer.asInt8List(offset, length);
    }

    Uint8List getUint8Array(int offset, int length)
    {
        return _data.buffer.asUint8List(offset, length);
    }

    Int16List getInt16Array(int offset, int length)
    {
        return _data.buffer.asInt16List(offset, length);
    }

    Uint16List getUint16Array(int offset, int length)
    {
        return _data.buffer.asUint16List(offset, length);
    }

    Int32List getInt32Array(int offset, int length)
    {
        return _data.buffer.asInt32List(offset, length);
    }

    Uint32List getUint32Array(int offset, int length)
    {
      return _data.buffer.asUint32List(offset, length);
    }

    Float32List getFloat32Array(int offset, int length)
    {
      return _data.buffer.asFloat32List(offset, length);
    }

    Float64List getFloat64Array(int offset, int length)
    {
      return _data.buffer.asFloat64List(offset, length);
    }

    Int64List getInt64Array(int offset, int length)
    {
      return _data.buffer.asInt64List(offset, length);
    }

    Uint64List getUint64Array(int offset, int length)
    {
      return _data.buffer.asUint64List(offset, length);
    }

    bool getBoolean(int offset)
    {
        return this.getUint8(offset) > 0;
    }

    setBoolean(int offset, bool value)
    {
        this.setUint8(offset, value ? 1: 0);
    }

    List<bool> getBooleanArray(int offset, int length)
    {
        var rt = new List<bool>();
        for(var i = 0; i < length; i++)
            rt.add(this.getBoolean(offset+i));
        return rt;
    }

    String getChar(int offset)
    {
        return String.fromCharCode(this.getUint16(offset));
    }

    setChar(int offset, int value)
    {
        this.setUint16(offset, value); //value.codeUnitAt(0));
    }

    List<String> getCharArray(int offset, int length)
    {
        var rt = new List<String>();
        for(var i = 0; i < length; i+=2)
            rt.add(this.getChar(offset+i));
        return rt;
    }

    String getHex(offset, length)
    {
        var rt = "";
        for(var i = offset; i < offset + length; i++) {
            var h = this[i].toString(16);
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
  

    String getString(offset, length)
    {
        var bytes = clip(offset, length)._data;// toList(offset, length);
        var str = utf8.decode(bytes);
        return str;
    }

    List<String> getStringArray(offset, length)
    {
        var rt = List<String>();
        var i = 0;

        while (i < length)
        {
            var cl = this.getUint32(offset + i);
            i += 4;
            rt.add(this.getString(offset + i, cl));
            i += cl;
        }

        return rt;
    }

    getInt64(offset)
    {
      return _dv.getUint64(offset);
    }

    getUint64(offset)
    {
      return _dv.getInt64(offset);
    }

    void setInt64(offset, value)
    {
      _dv.setInt64(offset, value);
    }

    void setUint64(offset, value)
    {
    
       _dv.setUint64(offset, value);
    }

    setDateTime(offset, DateTime value)
    {
        // Unix Epoch
        var ticks = UNIX_EPOCH + (value.millisecondsSinceEpoch * 10000);
        this.setUint64(offset, ticks);
    }

    DateTime getDateTime(int offset)
    {
        var ticks = this.getUint64(offset);
        // there are 10,000 ticks in a millisecond
        return DateTime.fromMillisecondsSinceEpoch((ticks-UNIX_EPOCH)~/10000);
    }

    List<DateTime> getDateTimeArray(int offset, int length)
    {
        var rt = new List<DateTime>();
        for(var i = 0; i < length; i+=8)
            rt.add(this.getDateTime(offset+i));
        return rt;
    }
    
    Guid getGuid(int offset)
    {
        return new Guid(this.clip(offset, 16));
    }

    setGuid(int offset, Guid guid)
    {
        set(guid.value, offset);
    }

    List<Guid> getGuidArray(int offset, int length)
    {
        var rt = [];
        for(var i = 0; i < length; i+=16)
            rt.add(this.getGuid(offset+i));
        return rt;
    }

    bool sequenceEqual(ar)
    {
        if (ar.length != this.length)
            return false;
        else
        {
            for(var i = 0; i < this.length; i++)
                if (ar[i] != this[i])
                    return false;
        }

        return true;
    }
}