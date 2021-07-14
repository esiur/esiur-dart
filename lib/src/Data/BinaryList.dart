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
import 'DataType.dart';
import 'Guid.dart';

class BinaryList
{
    var _list = <int>[];

    int get length => _list.length;

    BinaryList addDateTime(DateTime value)
    {
        _list.addAll(DC.dateTimeToBytes(value));
        return this;
    }

    BinaryList insertDateTime(int position, DateTime value)
    {
        _list.insertAll(position, DC.dateTimeToBytes(value));
        return this;
    }


    BinaryList addDateTimeArray(List<DateTime> value)
    {
        _list.addAll(DC.dateTimeArrayToBytes(value));
        return this;
    }

    BinaryList insertDateTimeArray(int position, List<DateTime> value)
    {
        _list.insertAll(position, DC.dateTimeArrayToBytes(value));
        return this;
    }

    BinaryList addGuid(Guid value)
    {
        _list.addAll(DC.guidToBytes(value));
        return this;
    }

    BinaryList insertGuid(int position, Guid value)
    {
        _list.insertAll(position, DC.guidToBytes(value));
        return this;
    }

    BinaryList addGuidArray(List<Guid> value)
    {
        _list.addAll(DC.guidArrayToBytes(value));
        return this;
    }

    BinaryList insertGuidArray(int position, List<Guid> value)
    {
        _list.insertAll(position, DC.guidArrayToBytes(value));
        return this;
    }


    BinaryList addUint8Array(Uint8List value)
    {
        _list.addAll(value);
        return this;
    }

    BinaryList addDC(DC value)
    {
       _list.addAll(value.toArray());
       return this;
    }
    
    BinaryList insertUint8Array(int position, Uint8List value)
    {
        _list.insertAll(position, value);
        return this;
    }


    /*
    BinaryList addHex(String value)
    {
        return this.addUint8Array(DC.fromHex(value, null));
    }

    BinaryList insertHex(int position, String value)
    {
        return this.insertUint8Array(position, DC.fromHex(value, null));
    }
  */

    
    BinaryList addString(String value)
    {
        _list.addAll(DC.stringToBytes(value));
        return this;
    }

    BinaryList insertString(int position, String value)
    {
        _list.insertAll(position, DC.stringToBytes(value));
        return this;
    }

    BinaryList addStringArray(List<String> value)
    {
        _list.addAll(DC.stringArrayToBytes(value));
        return this;
    }

    BinaryList insertStringArray(int position, List<String> value)
    {
        _list.insertAll(position, DC.stringArrayToBytes(value));
        return this;
    }

    BinaryList insertUint8(int position, int value)
    {
        _list.insert(position, value);
        return this;
    }

    BinaryList addUint8(int value)
    {
        _list.add(value);
        return this;
    }

    BinaryList addInt8(int value)
    {
        _list.add(value);
        return this;
    }

    BinaryList insertInt8(int position, int value)
    {
        _list.insert(position, value);
        return this;
    }
    
    BinaryList addInt8Array(Int8List value)
    {
        _list.addAll(DC.int8ArrayToBytes(value));
        return this;
    }

    BinaryList insertInt8Array(int position, Int8List value)
    {
        _list.insertAll(position, DC.int8ArrayToBytes(value));
        return this;
    }


    BinaryList addChar(int value)
    {
        _list.addAll(DC.charToBytes(value));
        return this;
    }

    BinaryList InsertChar(int position, int value)
    {
        _list.insertAll(position, DC.charToBytes(value));
        return this;
    }

    BinaryList addCharArray(Uint16List value)
    {
        _list.addAll(DC.charArrayToBytes(value));
        return this;
    }

    BinaryList InsertCharArray(int position, Uint16List value)
    {
        _list.insertAll(position, DC.charArrayToBytes(value));
        return this;
    }


    BinaryList addBoolean(bool value)
    {
        _list.addAll(DC.boolToBytes(value));
        return this;
    }

    BinaryList insertBoolean(int position, bool value)
    {
        _list.insertAll(position, DC.boolToBytes(value));
        return this;
    }

    BinaryList addBooleanArray(List<bool> value)
    {
        _list.addAll(DC.boolToBytes(value));
        return this;
    }

    BinaryList insertBooleanArray(int position, List<bool> value)
    {
        _list.insertAll(position, DC.boolToBytes(value));
        return this;
    }

    BinaryList addUint16(int value)
    {
        _list.addAll(DC.uint16ToBytes(value));
        return this;
    }

    BinaryList insertUint16(int position, int value)
    {
        _list.insertAll(position, DC.uint16ToBytes(value));
        return this;
    }

    BinaryList addUint16Array(Uint16List value)
    {
        _list.addAll(DC.uint16ArrayToBytes(value));
        return this;
    }

    BinaryList insertUint16Array(int position, Uint16List value)
    {
        _list.insertAll(position, DC.uint16ArrayToBytes(value));
        return this;
    }


    BinaryList addInt16(int value)
    {
        _list.addAll(DC.int16ToBytes(value));
        return this;
    }

    BinaryList insertInt16(int position, int value)
    {
        _list.insertAll(position, DC.int16ToBytes(value));
        return this;
    }

  
    BinaryList addInt16Array(Int16List value)
    {
        _list.addAll(DC.int16ArrayToBytes(value));
        return this;
    }

    BinaryList insertInt16Array(int position, Int16List value)
    {
        _list.insertAll(position, DC.int16ArrayToBytes(value));
        return this;
    }

    BinaryList addUint32(int value)
    {
        _list.addAll(DC.uint32ToBytes(value));
        return this;
    }

    BinaryList insertUint32(int position, int value)
    {
        _list.insertAll(position, DC.uint32ToBytes(value));
        return this;
    }

    BinaryList addUint32Array(Uint32List value)
    {
        _list.addAll(DC.uint32ArrayToBytes(value));
        return this;
    }
    BinaryList InsertUint32Array(int position, Uint32List value)
    {
        _list.insertAll(position, DC.uint32ArrayToBytes(value));
        return this;
    }


    BinaryList addInt32(int value)
    {
        _list.addAll(DC.int32ToBytes(value));
        return this;
    }

    BinaryList insertInt32(int position, int value)
    {
        _list.insertAll(position, DC.int32ToBytes(value));
        return this;
    }

    BinaryList addInt32Array(Int32List value)
    {
        _list.addAll(DC.int32ArrayToBytes(value));
        return this;
    }

    BinaryList insertInt32Array(int position, Int32List value)
    {
        _list.insertAll(position, DC.int32ArrayToBytes(value));
        return this;
    }


    BinaryList addUint64(int value)
    {
        _list.addAll(DC.uint64ToBytes(value));
        return this;
    }

    BinaryList insertUint64(int position, int value)
    {
        _list.insertAll(position, DC.uint64ToBytes(value));
        return this;
    }

    BinaryList addUint64Array(Uint64List value)
    {
        _list.addAll(DC.uint64ArrayToBytes(value));
        return this;
    }

    BinaryList InsertUint64Array(int position, Uint64List value)
    {
        _list.insertAll(position, DC.uint64ArrayToBytes(value));
        return this;
    }

    BinaryList addInt64(int value)
    {
        _list.addAll(DC.int64ToBytes(value));
        return this;
    }

    BinaryList insertInt64(int position, int value)
    {
        _list.insertAll(position, DC.int64ToBytes(value));
        return this;
    }

    BinaryList addInt64Array(Int64List value)
    {
        _list.addAll(DC.int64ArrayToBytes(value));
        return this;
    }

    BinaryList insertInt64Array(int position, Int64List value)
    {
        _list.insertAll(position, DC.int64ArrayToBytes(value));
        return this;
    }

    BinaryList addFloat32(double value)
    {
        _list.addAll(DC.float32ToBytes(value));
        return this;
    }

    BinaryList insertFloat32(int position, double value)
    {
        _list.insertAll(position, DC.float32ToBytes(value));
        return this;
    }

    BinaryList addFloat32Array(Float32List value)
    {
        _list.addAll(DC.float32ArrayToBytes(value));
        return this;
    }

    BinaryList insertFloat32Array(int position, Float32List value)
    {
        _list.insertAll(position, DC.float32ArrayToBytes(value));
        return this;
    }


    BinaryList addFloat64(double value)
    {
        _list.addAll(DC.float64ToBytes(value));
        return this;
    }

    BinaryList insertFloat64(int position, double value)
    {
        _list.insertAll(position, DC.float64ToBytes(value));
        return this;
    }

    BinaryList addFloat64Array(Float64List value)
    {
        _list.addAll(DC.float64ArrayToBytes(value));
        return this;
    }

    BinaryList insertFloat64Array(int position, Float64List value)
    {
        _list.insertAll(position, DC.float64ArrayToBytes(value));
        return this;
    }



    BinaryList add(type, value)
    {
        switch (type)
        {
            case DataType.Bool:
                addBoolean(value);
                return this;
            case DataType.BoolArray:
                addBooleanArray(value);
                return this;
            case DataType.UInt8:
                addUint8(value);
                return this;
            case DataType.UInt8Array:
                addUint8Array(value);
                return this;
            case DataType.Int8:
                addInt8(value);
                return this;
            case DataType.Int8Array:
                addInt8Array(value);
                return this;
            case DataType.Char:
                addChar(value);
                return this;
            case DataType.CharArray:
                addCharArray(value);
                return this;
            case DataType.UInt16:
                addUint16(value);
                return this;
            case DataType.UInt16Array:
                addUint16Array(value);
                return this;
            case DataType.Int16:
                addInt16(value);
                return this;
            case DataType.Int16Array:
                addInt16Array(value);
                return this;
            case DataType.UInt32:
                addUint32(value);
                return this;
            case DataType.UInt32Array:
                addUint32Array(value);
                return this;
            case DataType.Int32:
                addInt32(value);
                return this;
            case DataType.Int32Array:
                addInt32Array(value);
                return this;
            case DataType.UInt64:
                addUint64(value);
                return this;
            case DataType.UInt64Array:
                addUint64Array(value);
                return this;
            case DataType.Int64:
                addInt64(value);
                return this;
            case DataType.Int64Array:
                addInt64Array(value);
                return this;

            case DataType.Float32:
                addFloat32(value);
                return this;
            case DataType.Float32Array:
                addFloat32Array(value);
                return this;

            case DataType.Float64:
                addFloat64(value);
                return this;
            case DataType.Float64Array:
                addFloat64Array(value);
                return this;

            case DataType.String:
                addString(value);
                return this;
            case DataType.StringArray:
                addStringArray(value);
                return this;

            case DataType.DateTime:
                addDateTime(value);
                return this;
            case DataType.DateTimeArray:
                addDateTimeArray(value);
                return this;

            default:
                throw new Exception("Not Implemented " + type.ToString());
                //return this;
        }
    }
    /// <summary>
    /// Convert the _list to an array of bytes
    /// </summary>
    /// <returns>Bytes array</returns>
    Uint8List toArray()
    {
        return Uint8List.fromList(_list);
    }


    DC toDC()
    {
      return new DC.fromUint8Array(toArray());
    }
    
    
    AsyncReply<dynamic> done()
    {
        return null;
        //
    }
    

}