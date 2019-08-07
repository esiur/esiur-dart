
import './MemberTemplate.dart';
import '../../Data/Guid.dart';
import '../../Data/DC.dart';
import './EventTemplate.dart';
import './PropertyTemplate.dart';
import './FunctionTemplate.dart';
import '../StorageMode.dart';

class ResourceTemplate
{
    Guid _classId;
    String _className;
    List<MemberTemplate> _members = new List<MemberTemplate>();
    List<FunctionTemplate> _functions = new List<FunctionTemplate>();
    List<EventTemplate> _events = new List<EventTemplate>();
    List<PropertyTemplate> _properties = new List<PropertyTemplate>();
    int _version;
    //bool isReady;

    DC _content;

    DC get content => _content;

/*
    MemberTemplate getMemberTemplate(MemberInfo member)
    {
        if (member is MethodInfo)
            return getFunctionTemplate(member.Name);
        else if (member is EventInfo)
            return getEventTemplate(member.Name);
        else if (member is PropertyInfo)
            return getPropertyTemplate(member.Name);
        else
            return null;
    }
    */

    EventTemplate getEventTemplateByName(String eventName)
    {
        for (var i in _events)
            if (i.name == eventName)
                return i;
        return null;
    }

    EventTemplate getEventTemplateByIndex(int index)
    {
        for (var i in _events)
            if (i.index == index)
                return i;
        return null;
    }

    FunctionTemplate getFunctionTemplateByName(String functionName)
    {
        for (var i in _functions)
            if (i.name == functionName)
                return i;
        return null;
    }
    
    FunctionTemplate getFunctionTemplateByIndex(int index)
    {
        for (var i in _functions)
            if (i.index == index)
                return i;
        return null;
    }

    PropertyTemplate getPropertyTemplateByIndex(int index)
    {
        for (var i in _properties)
            if (i.index == index)
                return i;
        return null;
    }

    PropertyTemplate getPropertyTemplateByName(String propertyName)
    {
        for (var i in _properties)
            if (i.name == propertyName)
                return i;
        return null;
    }

    Guid get classId => _classId;
    
    String get className => _className;
  
    List<MemberTemplate> get methods => _members;

    List<FunctionTemplate> get functions => _functions;
    
    List<EventTemplate> get events => _events;
    
    List<PropertyTemplate> get properties => _properties;
    
    ResourceTemplate()
    {

    }


    ResourceTemplate.fromType(Type type)
    {

    }
    
/*
    ResourceTemplate(Type type)
    {

        type = ResourceProxy.GetBaseType(type);

        // set guid

        var typeName = Encoding.UTF8.GetBytes(type.FullName);
        var hash = SHA256.Create().ComputeHash(typeName).Clip(0, 16);

        classId = new Guid(hash);
        className = type.FullName;


#if NETSTANDARD1_5
        PropertyInfo[] propsInfo = type.GetTypeInfo().GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        EventInfo[] eventsInfo = type.GetTypeInfo().GetEvents(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        MethodInfo[] methodsInfo = type.GetTypeInfo().GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);

#else
        PropertyInfo[] propsInfo = type.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        EventInfo[] eventsInfo = type.GetEvents(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
        MethodInfo[] methodsInfo = type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
#endif

        //byte currentIndex = 0;

        byte i = 0;

        foreach (var pi in propsInfo)
        {
            var ps = (ResourceProperty[])pi.GetCustomAttributes(typeof(ResourceProperty), true);
            if (ps.Length > 0)
            {
                var pt = new PropertyTemplate(this, i++, pi.Name, ps[0].ReadExpansion, ps[0].WriteExpansion, ps[0].Storage);
                pt.Info = pi;
                properties.Add(pt);
            }
        }

        i = 0;

        foreach (var ei in eventsInfo)
        {
            var es = (ResourceEvent[])ei.GetCustomAttributes(typeof(ResourceEvent), true);
            if (es.Length > 0)
            {
                var et = new EventTemplate(this, i++, ei.Name, es[0].Expansion);
                events.Add(et);
            }
        }

        i = 0;
        foreach (MethodInfo mi in methodsInfo)
        {
            var fs = (ResourceFunction[])mi.GetCustomAttributes(typeof(ResourceFunction), true);
            if (fs.Length > 0)
            {
                var ft = new FunctionTemplate(this, i++, mi.Name, mi.ReturnType == typeof(void), fs[0].Expansion);
                functions.Add(ft);
            }
        }

        // append signals
        for (i = 0; i < events.Count; i++)
            members.Add(events[i]);
        // append slots
        for (i = 0; i < functions.Count; i++)
            members.Add(functions[i]);
        // append properties
        for (i = 0; i < properties.Count; i++)
            members.Add(properties[i]);

        // bake it binarily
        var b = new BinaryList();
        b.AddGuid(classId)
            .AddUInt8((byte)className.Length)
            .AddString(className)
            .AddInt32(version)
            .AddUInt16((ushort)members.Count);


        foreach (var ft in functions)
            b.AddUInt8Array(ft.Compose());
        foreach (var pt in properties)
            b.AddUInt8Array(pt.Compose());
        foreach (var et in events)
            b.AddUInt8Array(et.Compose());

        content = b.ToArray();
    }

*/

    
    ResourceTemplate.parse(DC data, [int offset = 0, int contentLength])
    {

        // cool Dart feature
        contentLength ??= data.length;

        
        int ends = offset + contentLength;

        int oOffset = offset;

        // start parsing...
        
        //var od = new ResourceTemplate();
        _content = data.clip(offset, contentLength);

        _classId = data.getGuid(offset);
        offset += 16;
        _className = data.getString(offset + 1, data[offset]);
        offset += data[offset] + 1;

        _version = data.getInt32(offset);
        offset += 4;

        var methodsCount = data.getUint16(offset);
        offset += 2;
            
        var functionIndex = 0;
        var propertyIndex = 0;
        var eventIndex = 0;

        for (int i = 0; i < methodsCount; i++)
        {
            var type = data[offset] >> 5;

            if (type == 0) // function
            {
                String expansion = null;
                var hasExpansion = ((data[offset] & 0x10) == 0x10);
                var isVoid = ((data[offset++] & 0x08) == 0x08);
                var name = data.getString(offset + 1, data[offset]);
                offset += data[offset] + 1;
                
                if (hasExpansion) // expansion ?
                {
                    var cs = data.getUint32(offset);
                    offset += 4;
                    expansion = data.getString(offset, cs);  
                    offset += cs;
                }

                var ft = new FunctionTemplate(this, functionIndex++, name, isVoid, expansion);

                _functions.add(ft);
            }
            else if (type == 1)    // property
            {

                String readExpansion = null, writeExpansion = null;

                var hasReadExpansion = ((data[offset] & 0x8) == 0x8);
                var hasWriteExpansion = ((data[offset] & 0x10) == 0x10);
                var recordable = ((data[offset] & 1) == 1);
                var permission = (data[offset++] >> 1) & 0x3;
                var name = data.getString(offset + 1, data[offset]);
                
                offset += data[offset] + 1;

                if (hasReadExpansion) // expansion ?
                {
                    var cs = data.getUint32(offset);
                    offset += 4;
                    readExpansion = data.getString(offset, cs);
                    offset += cs;
                }

                if (hasWriteExpansion) // expansion ?
                {
                    var cs = data.getUint32(offset);
                    offset += 4;
                    writeExpansion = data.getString(offset, cs);
                    offset += cs;
                }

                var pt = new PropertyTemplate(this, propertyIndex++, name, readExpansion, writeExpansion, recordable ? StorageMode.Recordable : StorageMode.Volatile);

                _properties.add(pt);
            }
            else if (type == 2) // Event
            {

                String expansion = null;
                var hasExpansion = ((data[offset++] & 0x10) == 0x10);

                var name = data.getString(offset + 1, data[offset]);// Encoding.ASCII.GetString(data, (int)offset + 1, (int)data[offset]);
                offset += data[offset] + 1;

                if (hasExpansion) // expansion ?
                {
                    var cs = data.getUint32(offset);
                    offset += 4;
                    expansion = data.getString(offset, cs);
                    offset += cs;
                }

                var et = new EventTemplate(this, eventIndex++, name, expansion);

                _events.add(et);

            }
        }

        // append signals
        for (int i = 0; i < _events.length; i++)
            _members.add(_events[i]);
        // append slots
        for (int i = 0; i < _functions.length; i++)
            _members.add(_functions[i]);
        // append properties
        for (int i = 0; i < _properties.length; i++)
            _members.add(_properties[i]);

    }
}

