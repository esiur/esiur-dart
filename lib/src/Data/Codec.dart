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
import 'DataType.dart';
import 'StructureComparisonResult.dart';
import 'dart:typed_data';
import 'Structure.dart';
import 'StructureMetadata.dart';
import '../Core/AsyncBag.dart';
import '../Core/AsyncReply.dart';
import 'DC.dart';
import 'BinaryList.dart';
import 'SizeObject.dart';
import 'NotModified.dart';
import 'ResourceComparisonResult.dart';
import 'PropertyValue.dart';
import 'KeyList.dart';
import '../Net/IIP/DistributedConnection.dart';
import '../Net/IIP/DistributedResource.dart';
import '../Resource/Warehouse.dart';
import '../Resource/IResource.dart';
import '../Resource/Template/PropertyTemplate.dart';
import '../Net/IIP/DistributedPropertyContext.dart';

class Codec
{
    /// <summary>
    /// Check if a DataType is an array
    /// </summary>
    /// <param name="type">DataType to check</param>
    /// <returns>True if DataType is an array, otherwise false</returns>
    static bool isArray(int type)
    {
        return ((type & 0x80) == 0x80) && (type != DataType.NotModified);
    }

    /// <summary>
    /// Get the element DataType
    /// </summary>
    /// <example>
    /// Passing UInt8Array will return UInt8 
    /// </example>
    /// <param name="type">DataType to get its element DataType</param>
    static int getElementType(int type)
    {
        return type & 0x7F;
    }

    /// <summary>
    /// Get DataType array of a given Structure
    /// </summary>
    /// <param name="structure">Structure to get its DataTypes</param>
    /// <param name="connection">Distributed connection is required in case a type is at the other end</param>
    static List<int> getStructureDateTypes(Structure structure, DistributedConnection connection)
    {
        var keys = structure.getKeys();
        var types = new List<int>(keys.length);

        for (var i = 0; i < keys.length; i++)
            types[i] = Codec.getDataType(structure[keys[i]], connection);
        return types;
    }

    /// <summary>
    /// Compare two structures
    /// </summary>
    /// <param name="initial">Initial structure to compare with</param>
    /// <param name="next">Next structure to compare with the initial</param>
    /// <param name="connection">DistributedConnection is required in case a structure holds items at the other end</param>
    static int compareStructures(Structure initial, Structure next, DistributedConnection connection)
    {
        if (next == null)
            return StructureComparisonResult.Null;

        if (initial == null)
            return StructureComparisonResult.Structure;

        if (next == initial)
            return StructureComparisonResult.Same;

        if (initial.length != next.length)
            return StructureComparisonResult.Structure;

        var previousKeys = initial.getKeys();
        var nextKeys = next.getKeys();

        for (var i = 0; i < previousKeys.length; i++)
            if (previousKeys[i] != nextKeys[i])
                return StructureComparisonResult.Structure;

        var previousTypes = getStructureDateTypes(initial, connection);
        var nextTypes = getStructureDateTypes(next, connection);

        for (var i = 0; i < previousTypes.length; i++)
            if (previousTypes[i] != nextTypes[i])
                return StructureComparisonResult.StructureSameKeys;

        return StructureComparisonResult.StructureSameTypes;
    }

    /// <summary>
    /// Compose an array of structures into an array of bytes
    /// </summary>
    /// <param name="structures">Array of Structure to compose</param>
    /// <param name="connection">DistributedConnection is required in case a structure in the array holds items at the other end</param>
    /// <param name="prependLength">If true, prepend the length as UInt32 at the beginning of the returned bytes array</param>
    /// <returns>Array of bytes in the network byte order</returns>
    static DC composeStructureArray(List<Structure> structures, DistributedConnection connection, [bool prependLength = false])
    {
        if (structures == null || structures?.length == 0)
            return prependLength ? new DC(4): new DC(0);

        var rt = new BinaryList();
        var comparsion = StructureComparisonResult.Structure;

        rt.addUint8(comparsion)
          .addDC(composeStructure(structures[0], connection, true, true, true));

        for (var i = 1; i < structures.length; i++)
        {
            comparsion = compareStructures(structures[i - 1], structures[i], connection);
            rt.addUint8(comparsion);

            if (comparsion == StructureComparisonResult.Structure)
                rt.addDC(composeStructure(structures[i], connection, true, true, true));
            else if (comparsion == StructureComparisonResult.StructureSameKeys)
                rt.addDC(composeStructure(structures[i], connection, false, true, true));
            else if (comparsion == StructureComparisonResult.StructureSameTypes)
                rt.addDC(composeStructure(structures[i], connection, false, false, true));
        }

        if (prependLength)
            rt.insertInt32(0, rt.length);

        return rt.toDC();
    }

    /// <summary>
    /// Parse an array of structures
    /// </summary>
    /// <param name="data">Bytes array</param>
    /// <param name="offset">Zero-indexed offset</param>
    /// <param name="length">Number of bytes to parse</param>
    /// <param name="connection">DistributedConnection is required in case a structure in the array holds items at the other end</param>
    /// <returns>Array of structures</returns>
    static AsyncBag<Structure> parseStructureArray(DC data, int offset, int length, DistributedConnection connection)
    {
        var reply = new AsyncBag<Structure>();
        if (length == 0)
        {
            reply.seal();
            return reply;
        }

        var end = offset + length;

        var result = data[offset++];

        AsyncReply<Structure> previous = null;
        // string[] previousKeys = null;
        // DataType[] previousTypes = null;

        StructureMetadata metadata = new StructureMetadata();


        if (result == StructureComparisonResult.Null)
            previous = new AsyncReply<Structure>.ready(null);
        else if (result == StructureComparisonResult.Structure)
        {
            int cs = data.getUint32(offset);
            offset += 4;
            previous = parseStructure(data, offset, cs, connection, metadata);
            offset += cs;
        }

        reply.add(previous);


        while (offset < end)
        {
            result = data[offset++];

            if (result == StructureComparisonResult.Null)
                previous = new AsyncReply<Structure>.ready(null);
            else if (result == StructureComparisonResult.Structure)
            {
                int cs = data.getUint32(offset);
                offset += 4;
                previous = parseStructure(data, offset, cs, connection, metadata);// out previousKeys, out previousTypes);
                offset += cs;
            }
            else if (result == StructureComparisonResult.StructureSameKeys)
            {
                int cs = data.getUint32(offset);
                offset += 4;
                previous = parseStructure(data, offset, cs, connection, metadata, metadata.keys);
                offset += cs;
            }
            else if (result == StructureComparisonResult.StructureSameTypes)
            {
                int cs = data.getUint32(offset);
                offset += 4;
                previous = parseStructure(data, offset, cs, connection, metadata, metadata.keys, metadata.types);
                offset += cs;
            }

            reply.add(previous);
        }

        reply.seal();
        return reply;
    }

    /// <summary>
    /// Compose a structure into an array of bytes
    /// </summary>
    /// <param name="value">Structure to compose</param>
    /// <param name="connection">DistributedConnection is required in case an item in the structure is at the other end</param>
    /// <param name="includeKeys">Whether to include the structure keys</param>
    /// <param name="includeTypes">Whether to include each item DataType</param>
    /// <param name="prependLength">If true, prepend the length as UInt32 at the beginning of the returned bytes array</param>
    /// <returns>Array of bytes in the network byte order</returns>
    static DC composeStructure(Structure value, DistributedConnection connection, [bool includeKeys = true, bool includeTypes = true, bool prependLength = false])
    {
        var rt = new BinaryList();

        if (includeKeys)
        {
            for (var k in value.keys)
            {
                var key = DC.stringToBytes(k);
                rt.addUint8(key.length)
                  .addDC(key)
                  .addDC(compose(value[k], connection));
            }
        }
        else
        {
            for (var k in value.keys)
                rt.addDC(compose(value[k], connection, includeTypes));
        }

        if (prependLength)
            rt.insertInt32(0, rt.length);

        return rt.toDC(); //.toArray();
    }

    /// <summary>
    /// Parse a structure
    /// </summary>
    /// <param name="data">Bytes array</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="length">Number of bytes to parse.</param>
    /// <param name="connection">DistributedConnection is required in case a structure in the array holds items at the other end.</param>
    /// <param name="parsedKeys">Array to store keys in.</param>
    /// <param name="parsedTypes">Array to store DataTypes in.</param>
    /// <param name="keys">Array of keys, in case the data doesn't include keys</param>
    /// <param name="types">Array of DataTypes, in case the data doesn't include DataTypes</param>
    /// <returns>Structure</returns>
    static AsyncReply<Structure> parseStructure(DC data, int offset, int length, DistributedConnection connection,  [StructureMetadata metadata = null, List<String> keys = null, List<int> types = null])// out string[] parsedKeys, out DataType[] parsedTypes, string[] keys = null, DataType[] types = null)
    {
        var reply = new AsyncReply<Structure>();
        var bag = new AsyncBag<dynamic>();
        var keylist = new List<String>();
        var typelist = new List<int>();
        var sizeObject = new SizeObject();

        if (keys == null)
        {
            while (length > 0)
            {
                var len = data[offset++];
                keylist.add(data.getString(offset, len));
                offset += len;

                typelist.add(data[offset]);

                bag.add(Codec.parse(data, offset, connection, sizeObject));
                length -= sizeObject.size + len + 1;
                offset += sizeObject.size;
            }
        }
        else if (types == null)
        {
            keylist.addAll(keys);

            while (length > 0)
            {
                typelist.add(data[offset]);

                bag.add(Codec.parse(data, offset, connection, sizeObject));
                length -= sizeObject.size;
                offset += sizeObject.size;
            }
        }
        else
        {
            keylist.addAll(keys);
            typelist.addAll(types);

            var i = 0;
            while (length > 0)
            {
                bag.add(parse(data, offset, connection, sizeObject, types[i]));
                length -= sizeObject.size;
                offset += sizeObject.size;
                i++;
            }
        }

        bag.seal();

        bag.then((res)
        {
            // compose the list
            var s = new Structure();
            for (var i = 0; i < keylist.length; i++)
                s[keylist[i]] = res[i];
            reply.trigger(s);
        });

        if (metadata != null)
        {
            metadata.keys = keylist;
            metadata.types = typelist;
        }

        return reply;
    }

  

    /// <summary>
    /// Parse a value
    /// </summary>
    /// <param name="data">Bytes array</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="size">Output the number of bytes parsed</param>
    /// <param name="connection">DistributedConnection is required in case a structure in the array holds items at the other end.</param>
    /// <param name="dataType">DataType, in case the data is not prepended with DataType</param>
    /// <returns>Value</returns>
    static AsyncReply<dynamic> parse(DC data, int offset, DistributedConnection connection, [SizeObject sizeObject, int dataType = DataType.Unspecified])
    {

        bool isArray;
        int t;


        if (dataType == DataType.Unspecified)
        {
            sizeObject?.size = 1;
            dataType = data[offset++];
        }
        else
            sizeObject?.size = 0;

        t = dataType & 0x7F;

        isArray = (dataType & 0x80) == 0x80;

        var payloadSize = DataType.size(dataType);


        int contentLength = 0;

        // check if we have the enough data
        if (payloadSize == -1)
        {
            contentLength = data.getUint32(offset);
            offset += 4;
            sizeObject?.size += 4 + contentLength;
        }
        else
            sizeObject?.size += payloadSize;

        if (isArray)
        {
            switch (t)
            {
                // VarArray ?
                case DataType.Void:
                    return parseVarArray(data, offset, contentLength, connection);

                case DataType.Bool:
                    return new AsyncReply<List<bool>>.ready(data.getBooleanArray(offset, contentLength));

                case DataType.UInt8:
                    return new AsyncReply<Uint8List>.ready(data.getUint8Array(offset, contentLength));

                case DataType.Int8:
                    return new AsyncReply<Int8List>.ready(data.getInt8Array(offset, contentLength));

                case DataType.Char:
                    return new AsyncReply<List<String>>.ready(data.getCharArray(offset, contentLength));

                case DataType.Int16:
                    return new AsyncReply<Int16List>.ready(data.getInt16Array(offset, contentLength));

                case DataType.UInt16:
                    return new AsyncReply<Uint16List>.ready(data.getUint16Array(offset, contentLength));

                case DataType.Int32:
                    return new AsyncReply<Int32List>.ready(data.getInt32Array(offset, contentLength));

                case DataType.UInt32:
                    return new AsyncReply<Uint32List>.ready(data.getUint32Array(offset, contentLength));

                case DataType.Int64:
                    return new AsyncReply<Int64List>.ready(data.getInt64Array(offset, contentLength));

                case DataType.UInt64:
                    return new AsyncReply<Uint64List>.ready(data.getUint64Array(offset, contentLength));

                case DataType.Float32:
                    return new AsyncReply<Float32List>.ready(data.getFloat32Array(offset, contentLength));

                case DataType.Float64:
                    return new AsyncReply<Float64List>.ready(data.getFloat64Array(offset, contentLength));

                case DataType.String:
                    return new AsyncReply<List<String>>.ready(data.getStringArray(offset, contentLength));

                case DataType.Resource:
                case DataType.DistributedResource:
                    return parseResourceArray(data, offset, contentLength, connection);

                case DataType.DateTime:
                    return new AsyncReply<List<DateTime>>.ready(data.getDateTimeArray(offset, contentLength));

                case DataType.Structure:
                    return parseStructureArray(data, offset, contentLength, connection);
            }
        }
        else
        {
            switch (t)
            {
                case DataType.NotModified:
                    return new AsyncReply<NotModified>.ready(new NotModified());

                case DataType.Void:
                    return new AsyncReply<dynamic>.ready(null);

                case DataType.Bool:
                    return new AsyncReply<bool>.ready(data.getBoolean(offset));

                case DataType.UInt8:
                    return new AsyncReply<int>.ready(data[offset]);

                case DataType.Int8:
                    return new AsyncReply<int>.ready(data[offset]);

                case DataType.Char:
                    return new AsyncReply<String>.ready(data.getChar(offset));

                case DataType.Int16:
                    return new AsyncReply<int>.ready(data.getInt16(offset));

                case DataType.UInt16:
                    return new AsyncReply<int>.ready(data.getUint16(offset));

                case DataType.Int32:
                    return new AsyncReply<int>.ready(data.getInt32(offset));

                case DataType.UInt32:
                    return new AsyncReply<int>.ready(data.getUint32(offset));

                case DataType.Int64:
                    return new AsyncReply<int>.ready(data.getInt64(offset));

                case DataType.UInt64:
                    return new AsyncReply<int>.ready(data.getUint64(offset));

                case DataType.Float32:
                    return new AsyncReply<double>.ready(data.getFloat32(offset));

                case DataType.Float64:
                    return new AsyncReply<double>.ready(data.getFloat64(offset));

                case DataType.String:
                    return new AsyncReply<String>.ready(data.getString(offset, contentLength));

                case DataType.Resource:
                    return parseResource(data, offset);

                case DataType.DistributedResource:
                    return parseDistributedResource(data, offset, connection);

                case DataType.DateTime:
                    return new AsyncReply<DateTime>.ready(data.getDateTime(offset));

                case DataType.Structure:
                    return parseStructure(data, offset, contentLength, connection);
            }
        }


        return null;
    }

    /// <summary>
    /// Parse a resource
    /// </summary>
    /// <param name="data">Bytes array</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <returns>Resource</returns>
    static AsyncReply<IResource> parseResource(DC data, int offset)
    {
        return Warehouse.get(data.getUint32(offset));
    }

    /// <summary>
    /// Parse a DistributedResource
    /// </summary>
    /// <param name="data">Bytes array</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="connection">DistributedConnection is required.</param>
    /// <returns>DistributedResource</returns>
    static AsyncReply<DistributedResource> parseDistributedResource(DC data, int offset, DistributedConnection connection)
    {
        //var g = data.GetGuid(offset);
        //offset += 16;

        // find the object
        var iid = data.getUint32(offset);

        return connection.fetch(iid);// Warehouse.Get(iid);
    }

    /// <summary>
    /// Check if a resource is local to a given connection.
    /// </summary>
    /// <param name="resource">Resource to check.</param>
    /// <param name="connection">DistributedConnection to check if the resource is local to it.</param>
    /// <returns>True, if the resource owner is the given connection, otherwise False.</returns>
    static bool isLocalResource(IResource resource, DistributedConnection connection)
    {
        if (resource is DistributedResource)
            if ((resource as DistributedResource).connection == connection)
                return true;
            
        return false;
    }

    /// <summary>
    /// Compare two resources
    /// </summary>
    /// <param name="initial">Initial resource to make comparison with.</param>
    /// <param name="next">Next resource to compare with the initial.</param>
    /// <param name="connection">DistributedConnection is required to check locality.</param>
    /// <returns>Null, same, local, distributed or same class distributed.</returns>

    static int compareResources(IResource initial, IResource next, DistributedConnection connection)
    {
        if (next == null)
            return ResourceComparisonResult.Null;
        else if (next == initial)
            return ResourceComparisonResult.Same;
        else if (isLocalResource(next, connection))
            return ResourceComparisonResult.Local;
        else
            return ResourceComparisonResult.Distributed;
    }

    /// <summary>
    /// Compose a resource
    /// </summary>
    /// <param name="resource">Resource to compose.</param>
    /// <param name="connection">DistributedConnection is required to check locality.</param>
    /// <returns>Array of bytes in the network byte order.</returns>
    static DC composeResource(IResource resource, DistributedConnection connection)
    {
        if (isLocalResource(resource, connection))
            return DC.uint32ToBytes((resource as DistributedResource).id);
        else
        {
            return new BinaryList().addGuid(resource.instance.template.classId).addUint32(resource.instance.id).toDC();
            //return BinaryList.ToBytes(resource.Instance.Template.ClassId, resource.Instance.Id);
        }
    }

    /// <summary>
    /// Compose an array of resources
    /// </summary>
    /// <param name="resources">Array of resources.</param>
    /// <param name="connection">DistributedConnection is required to check locality.</param>
    /// <param name="prependLength">If True, prepend the length of the output at the beginning.</param>
    /// <returns>Array of bytes in the network byte order.</returns>

    static DC composeResourceArray(List<IResource> resources, DistributedConnection connection, [bool prependLength = false])
    {
        if (resources == null || resources?.length == 0)
            return prependLength ? new DC(4) : new DC(0);

        var rt = new BinaryList();
        var comparsion = compareResources(null, resources[0], connection);

        rt.addUint8(comparsion);

        if (comparsion == ResourceComparisonResult.Local)
            rt.addUint32((resources[0] as DistributedResource).id);
        else if (comparsion == ResourceComparisonResult.Distributed)
            rt.addUint32(resources[0].instance.id);
        
        for (var i = 1; i < resources.length; i++)
        {
            comparsion = compareResources(resources[i - 1], resources[i], connection);
            rt.addUint8(comparsion);
            if (comparsion == ResourceComparisonResult.Local)
                rt.addUint32((resources[i] as DistributedResource).id);
            else if (comparsion == ResourceComparisonResult.Distributed)
                rt.addUint32(resources[i].instance.id);
        }

        if (prependLength)
            rt.insertInt32(0, rt.length);

        return rt.toDC();
    }

    /// <summary>
    /// Parse an array of bytes into array of resources
    /// </summary>
    /// <param name="data">Array of bytes.</param>
    /// <param name="length">Number of bytes to parse.</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="connection">DistributedConnection is required to fetch resources.</param>
    /// <returns>Array of resources.</returns>
    static AsyncBag<IResource> parseResourceArray(DC data, int offset, int length, DistributedConnection connection)
    {
        //print("parseResourceArray ${offset} ${length}");

        var reply = new AsyncBag<IResource>();
        if (length == 0)
        {
            reply.seal();
            return reply;
        }

        var end = offset + length;

        // 
        var result = data[offset++];

        AsyncReply<IResource> previous = null;

        if (result == ResourceComparisonResult.Null)
            previous = new AsyncReply<IResource>.ready(null);
        else if (result == ResourceComparisonResult.Local)
        {
            previous = Warehouse.get(data.getUint32(offset));
            offset += 4;
        }
        else if (result == ResourceComparisonResult.Distributed)
        {
            previous = connection.fetch(data.getUint32(offset));
            offset += 4;
        }

        reply.add(previous);


        while (offset < end)
        {
            result = data[offset++];

            AsyncReply<IResource> current = null;

            if (result == ResourceComparisonResult.Null)
            {
                current = new AsyncReply<IResource>.ready(null);
            }
            else if (result == ResourceComparisonResult.Same)
            {
                current = previous;
            }
            else if (result == ResourceComparisonResult.Local)
            {
                current = Warehouse.get(data.getUint32(offset));
                offset += 4;
            }
            else if (result == ResourceComparisonResult.Distributed)
            {
                current = connection.fetch(data.getUint32(offset));
                offset += 4;
            }

            reply.add(current);

            previous = current;
        }

        reply.seal();
        return reply;
    }

    /// <summary>
    /// Compose an array of variables
    /// </summary>
    /// <param name="array">Variables.</param>
    /// <param name="connection">DistributedConnection is required to check locality.</param>
    /// <param name="prependLength">If True, prepend the length as UInt32 at the beginning of the output.</param>
    /// <returns>Array of bytes in the network byte order.</returns>
    static DC composeVarArray(List array, DistributedConnection connection, [bool prependLength = false])
    {
        var rt = new BinaryList();

        for (var i = 0; i < array.length; i++)
            rt.addDC(compose(array[i], connection));

        if (prependLength)
            rt.insertUint32(0, rt.length);

        return rt.toDC();
    }
    

    /// <summary>
    /// Parse an array of bytes into an array of varialbes.
    /// </summary>
    /// <param name="data">Array of bytes.</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="length">Number of bytes to parse.</param>
    /// <param name="connection">DistributedConnection is required to fetch resources.</param>
    /// <returns>Array of variables.</returns>
    static AsyncBag<dynamic> parseVarArray(DC data, int offset, int length, DistributedConnection connection)
    {
        var rt = new AsyncBag<dynamic>();
        var sizeObject = new SizeObject();

        while (length > 0)
        {
            rt.add(parse(data, offset, connection, sizeObject));

            if (sizeObject.size > 0)
            {
                offset += sizeObject.size;
                length -= sizeObject.size;
            }
            else
                throw new Exception("Error while parsing structured data");

        }

        rt.seal();
        return rt;
    }

    /// <summary>
    /// Compose an array of property values.
    /// </summary>
    /// <param name="array">PropertyValue array.</param>
    /// <param name="connection">DistributedConnection is required to check locality.</param>
    /// <param name="prependLength">If True, prepend the length as UInt32 at the beginning of the output.</param>
    /// <returns>Array of bytes in the network byte order.</returns>
    /// //, bool includeAge = true
    static DC composePropertyValueArray(List<PropertyValue> array, DistributedConnection connection, [bool prependLength = false])
    {
        var rt = new BinaryList();

        for (var i = 0; i < array.length; i++)
            rt.addDC(composePropertyValue(array[i], connection));
        if (prependLength)
            rt.insertUint32(0, rt.length);

        return rt.toDC();
    }

    /// <summary>
    /// Compose a property value.
    /// </summary>
    /// <param name="propertyValue">Property value</param>
    /// <param name="connection">DistributedConnection is required to check locality.</param>
    /// <returns>Array of bytes in the network byte order.</returns>
    static DC composePropertyValue(PropertyValue propertyValue, DistributedConnection connection)//, bool includeAge = true)
    {

        return new BinaryList()
            .addUint64(propertyValue.age)
            .addDateTime(propertyValue.date)
            .addDC(compose(propertyValue.value, connection))
            .toDC();
    }


    /// <summary>
    /// Parse property value.
    /// </summary>
    /// <param name="data">Array of bytes.</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="connection">DistributedConnection is required to fetch resources.</param>
    /// <param name="cs">Output content size.</param>
      /// <returns>PropertyValue.</returns>
    static AsyncReply<PropertyValue> parsePropertyValue(DC data, int offset, SizeObject sizeObject, DistributedConnection connection)
    {
        var reply = new AsyncReply<PropertyValue>();

        var age = data.getUint64(offset);
        offset += 8;

        DateTime date = data.getDateTime(offset);
        offset += 8;

        parse(data, offset, connection, sizeObject).then((value)
        {
            reply.trigger(new PropertyValue(value, age, date));
        });

        sizeObject.size += 16;
        
        return reply;
    }


    /// <summary>
    /// Parse resource history
    /// </summary>
    /// <param name="data">Array of bytes.</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="length">Number of bytes to parse.</param>
    /// <param name="resource">Resource</param>
    /// <param name="fromAge">Starting age.</param>
    /// <param name="toAge">Ending age.</param>
    /// <param name="connection">DistributedConnection is required to fetch resources.</param>
    /// <returns></returns>
    static AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>> parseHistory(DC data, int offset, int length, IResource resource, DistributedConnection connection)
    {

        var list = new KeyList<PropertyTemplate, List<PropertyValue>>();

        var reply = new AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>>();

        var bagOfBags = new AsyncBag<List<PropertyValue>>();

        var ends = offset + length;

        //var sizeObject = new SizeObject();

        while (offset < ends)
        {
            var index = data[offset++];
            var pt = resource.instance.template.getPropertyTemplateByIndex(index);
            list.add(pt, null);
            var cs = data.getUint32(offset);
            offset += 4;
            bagOfBags.add(parsePropertyValueArray(data, offset, cs, connection));
            offset += cs;
        }

        bagOfBags.seal();

        bagOfBags.then((x)
        {
            for(var i = 0; i < list.length; i++)
                list[list.keys.elementAt(i)] = x[i];

            reply.trigger(list);
        });

        return reply;
        
    }

    /// <summary>
    /// Compose resource history
    /// </summary>
    /// <param name="history">History</param>
    /// <param name="connection">DistributedConnection is required to fetch resources.</param>
    /// <returns></returns>
    static DC composeHistory(KeyList<PropertyTemplate, List<PropertyValue>> history,
                                        DistributedConnection  connection, [bool prependLength = false])
    {
        var rt = new BinaryList();

        for (var i = 0; i < history.length; i++)
            rt.addUint8(history.keys.elementAt(i).index)
              .addDC(composePropertyValueArray(history.values.elementAt(i), connection, true));

        if (prependLength)
            rt.insertInt32(0, rt.length);

        return rt.toDC();
    }

    /// <summary>
    /// Parse an array of PropertyValue.
    /// </summary>
    /// <param name="data">Array of bytes.</param>
    /// <param name="offset">Zero-indexed offset.</param>
    /// <param name="length">Number of bytes to parse.</param>
    /// <param name="connection">DistributedConnection is required to fetch resources.</param>
    /// <param name="ageIncluded">Whether property age is represented in the data.</param>
    /// <returns></returns>
    static AsyncBag<PropertyValue> parsePropertyValueArray(DC data, int offset, int length, DistributedConnection connection)//, bool ageIncluded = true)
    {

      //print("parsePropertyValueArray ${offset} ${length}");

        var rt = new AsyncBag<PropertyValue>();

        var sizeObject = new SizeObject();

        while (length > 0)
        {

            rt.add(parsePropertyValue(data, offset, sizeObject, connection));

            if (sizeObject.size > 0)
            {
                offset += sizeObject.size;
                length -= sizeObject.size;
            }
            else
                throw new Exception("Error while parsing ValueInfo structured data");
        }

        rt.seal();
        return rt;
    }

    /// <summary>
    /// Compose a variable
    /// </summary>
    /// <param name="value">Value to compose.</param>
    /// <param name="connection">DistributedConnection is required to check locality.</param>
    /// <param name="prependType">If True, prepend the DataType at the beginning of the output.</param>
    /// <returns>Array of bytes in the network byte order.</returns>
    static DC compose(dynamic value, DistributedConnection connection, [bool prependType = true])
    {

        if (value is Function(DistributedConnection))
            value = Function.apply(value, [connection]);
        else if (value is DistributedPropertyContext)
            value = (value as DistributedPropertyContext).method(connection);
        
        var type = getDataType(value, connection);
        var rt = new BinaryList();

        switch (type)
        {
          
            case DataType.Void:
                // nothing to do;
                break;

            case DataType.String:
                var st = DC.stringToBytes(value);
                rt.addInt32(st.length).addDC(st);
                break;

            case DataType.Resource:
                rt.addUint32((value as DistributedResource).id);
                break;

            case DataType.DistributedResource:
                rt.addUint32((value as IResource).instance.id);
                break;

            case DataType.Structure:
                rt.addDC(composeStructure(value, connection, true, true, true));
                break;

            case DataType.VarArray:
                rt.addDC(composeVarArray(value, connection, true));
                break;

            case DataType.ResourceArray:
                rt.addDC(composeResourceArray(value, connection, true));
                break;

            case DataType.StructureArray:
                rt.addDC(composeStructureArray(value, connection, true));
                break;

            default:
                rt.add(type, value);
                if (DataType.isArray(type))
                    rt.insertInt32(0, rt.length);
                break;
        }

        if (prependType)
            rt.insertUint8(0, type);

        return rt.toDC();
    }

    /// <summary>
    /// Get the DataType of a given value.
    /// This function is needed to compose a value.
    /// </summary>
    /// <param name="value">Value to find its DataType.</param>
    /// <param name="connection">DistributedConnection is required to check locality of resources.</param>
    /// <returns>DataType.</returns>
    static int getDataType(value, DistributedConnection connection)
    {
        if (value == null)
            return DataType.Void;

        if (value is bool)
          return DataType.Bool;
        else if (value is List<bool>)
          return DataType.BoolArray;
        else if (value is int)
          return DataType.Int64;
        else if (value is List<int> || value is Int64List)
          return DataType.Int64Array;
        else if (value is double)
          return DataType.Float64;
        else if (value is List<double>)
          return DataType.Float64Array;
        else if (value is String)
          return DataType.String;
        else if (value is List<String>)
          return DataType.StringArray;
        else if (value is Uint8List)
          return DataType.UInt8Array;
        else if (value is Int8List)
          return DataType.Int8Array;
        else if (value is Uint16List)
          return DataType.UInt16Array;
        else if (value is Int16List)
          return DataType.Int16Array;
        else if (value is Uint32List)
          return DataType.UInt32Array;
        else if (value is Int32List)
          return DataType.Int32Array;
        else if (value is Uint64List)
          return DataType.Int64Array;
        else if (value is DateTime)
          return DataType.DateTime;
        else if (value is List<DateTime>)
          return DataType.DateTimeArray;
        else if (value is IResource)
          return isLocalResource(value, connection) ? DataType.Resource : DataType.DistributedResource;
        else if (value is List<IResource>)
          return DataType.ResourceArray;
        else if (value is Structure)
          return DataType.Structure;
        else if (value is List<Structure>)
          return DataType.StructureArray;
        else if (value is List)
          return DataType.VarArray;
        else
          return DataType.Void;
    }

    /// <summary>
    /// Check if a type implements an interface
    /// </summary>
    /// <param name="type">Sub-class type.</param>
    /// <param name="iface">Super-interface type.</param>
    /// <returns>True, if <paramref name="type"/> implements <paramref name="iface"/>.</returns>
  static bool implementsInterface<type, ifac>() => _DummyClass<type>() is _DummyClass<ifac>;
}

// related to implementsInterface
class _DummyClass<T> { }