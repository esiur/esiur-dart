import 'dart:core';

import '../Data/DC.dart';
import '../Data/AutoList.dart';
import './IStore.dart';
import './IResource.dart';
import '../Data/KeyList.dart';
import './StorageMode.dart';
import '../Data/ValueObject.dart';
import '../Core/IEventHandler.dart';
import '../Security/Permissions/Ruling.dart';
import '../Security/Permissions/IPermissionsManager.dart';
import '../Security/Permissions/ActionType.dart';
import 'EventOccurredInfo.dart';
import 'Template/TypeTemplate.dart';
import './Template/PropertyTemplate.dart';
import './Template/FunctionTemplate.dart';
import './Template/EventTemplate.dart';

import '../Security/Authority/Session.dart';
import './Template/MemberTemplate.dart';
import '../Data/PropertyValue.dart';
import 'Warehouse.dart';

import '../Core/PropertyModificationInfo.dart';

class Instance extends IEventHandler {
  String _name;

  late AutoList<IResource, Instance> _children;
  IResource _resource;
  IStore? _store;
  late AutoList<IResource, Instance> _parents;
  //bool inherit;
  late TypeTemplate _template;

  late AutoList<IPermissionsManager, Instance> _managers;

  late KeyList<String, dynamic> _attributes;

  List<int> _ages = <int>[];
  List<DateTime> _modificationDates = <DateTime>[];
  int _instanceAge;
  DateTime? _instanceModificationDate;

  int _id;

  /// <summary>
  /// Instance attributes are custom properties associated with the instance, a place to store information by IStore.
  /// </summary>
  KeyList<String, dynamic> get attributes => _attributes;

  @override
  String toString() => _name + " (" + (link ?? '') + ")";

  bool removeAttributes([List<String>? attributes = null]) {
    if (attributes == null)
      this._attributes.clear();
    else {
      for (var attr in attributes) this.attributes.remove(attr);
    }

    return true;
  }

  Map<String, dynamic> getAttributes([List<String>? attributes = null]) {
    var st = Map<String, dynamic>();

    if (attributes == null) {
      var clone = this.attributes.keys.toList();
      clone.add("managers");
      attributes = clone.toList();
    }

    for (var attr in attributes) {
      if (attr == "name")
        st["name"] = _name;
      else if (attr == "managers") {
        var mngrs = <Map<String, dynamic>>[];

        for (var i = 0; i < _managers.length; i++) {
          var mst = Map<String, dynamic>();
          mst["type"] = _managers[i].runtimeType;
          mst["settings"] = _managers[i].settings;

          mngrs.add(mst);
        }

        st["managers"] = mngrs;
      } else if (attr == "parents") {
        st["parents"] = _parents.toList();
      } else if (attr == "children") {
        st["children"] = _children.toList();
      } else if (attr == "childrenCount") {
        st["childrenCount"] = _children.count;
      } else if (attr == "type") {
        st["type"] = resource.runtimeType;
      } else
        st[attr] = _attributes[attr];
    }

    return st;
  }

  bool setAttributes(Map<String, dynamic> attributes,
      [bool clearAttributes = false]) {
    try {
      if (clearAttributes) _attributes.clear();

      for (var attrKey in attributes.keys)
        if (attrKey == "name")
          _name = attributes[attrKey] as String;
        else if (attrKey == "managers") {
          _managers.clear();

          var mngrs = attributes[attrKey] as List;
          // this is not implemented now, Flutter doesn't support mirrors, needs a workaround @ Warehouse.registerManager
          /*
                    for (var mngr in mngrs)
                    {
                        var m = mngr as Structure;
                        var type = Type.GetType(m["type"] as string);
                        if (Codec.implementsInterface<type, typeof(IPermissionsManager)))
                        {
                            var settings = m["settings"] as Structure;
                            var manager = Activator.CreateInstance(type) as IPermissionsManager;
                            manager.Initialize(settings, this.resource);
                            this.managers.Add(manager);
                        }
                        else
                            return false;
                    }
                    */
        } else {
          _attributes[attrKey] = attributes[attrKey];
        }
    } catch (ex) {
      return false;
    }

    return true;
  }

  /*
    public Structure GetAttributes()
    {
        var st = new Structure();
        foreach (var a in attributes.Keys)
            st[a] = attributes[a];

        st["name"] = name;

        var mngrs = new List<Structure>();

        foreach (var manager in managers)
        {
            var mngr = new Structure();
            mngr["settings"] = manager.Settings;
            mngr["type"] = manager.GetType().FullName;
            mngrs.Add(mngr);
        }

        st["managers"] = mngrs;

        return st;
    }*/

  /// <summary>
  /// Get the age of a given property index.
  /// </summary>
  /// <param name="index">Zero-based property index.</param>
  /// <returns>Age.</returns>
  int getAge(int index) {
    if (index < _ages.length)
      return _ages[index];
    else
      return 0;
  }

  /// <summary>
  /// Set the age of a property.
  /// </summary>
  /// <param name="index">Zero-based property index.</param>
  /// <param name="value">Age.</param>
  void setAge(int index, int value) {
    if (index < _ages.length) {
      _ages[index] = value;
      if (value > _instanceAge) _instanceAge = value;
    }
  }

  /// <summary>
  /// Set the modification date of a property.
  /// </summary>
  /// <param name="index">Zero-based property index.</param>
  /// <param name="value">Modification date.</param>
  void setModificationDate(int index, DateTime value) {
    if (index < _modificationDates.length) {
      _modificationDates[index] = value;
      if (_instanceModificationDate == null ||
          value.millisecondsSinceEpoch >
              (_instanceModificationDate as DateTime).millisecondsSinceEpoch)
        _instanceModificationDate = value;
    }
  }

  /// <summary>
  /// Get modification date of a specific property.
  /// </summary>
  /// <param name="index">Zero-based property index</param>
  /// <returns>Modification date.</returns>
  DateTime getModificationDate(int index) {
    if (index < _modificationDates.length)
      return _modificationDates[index];
    else
      return new DateTime(0);
  }

  /// <summary>
  /// Load property value (used by stores)
  /// </summary>
  /// <param name="name">Property name</param>
  /// <param name="age">Property age</param>
  /// <param name="value">Property value</param>
  /// <returns></returns>
  bool loadProperty(
      String name, int age, DateTime modificationDate, dynamic value) {
    /*
        var pt = _template.getPropertyTemplate(name);

        if (pt == null)
            return false;

        if (pt.info.propertyType == typeof(DistributedPropertyContext))
            return false;
    
        try
        {
            if (pt.into.canWrite)
                pt.info.setValue(resource, DC.CastConvert(value, pt.Info.PropertyType));
        }
        catch(ex)
        {
            // 
        }

        setAge(pt.index, age);
        setModificationDate(pt.index, modificationDate);

      */
    return true;
  }

  /// <summary>
  /// Age of the instance, incremented by 1 in every modification.
  /// </summary>
  int get age => _instanceAge;
  // this must be internal
  set age(int value) => _instanceAge = value;

  /// <summary>
  /// Last modification date.
  /// </summary>
  DateTime? get modificationDate => _instanceModificationDate;

  /// <summary>
  /// Instance Id.
  /// </summary>
  int get id => _id;

  /// <summary>
  /// Import properties from bytes array.
  /// </summary>
  /// <param name="properties"></param>
  /// <returns></returns>
  bool deserialize(List<PropertyValue> properties) {
    for (var i = 0; i < properties.length; i++) {
      var pt = _template.getPropertyTemplateByIndex(i);
      if (pt != null) {
        var pv = properties[i];
        loadProperty(pt.name, pv.age, pv.date, pv.value);
      }
    }

    return true;
  }

  /// <summary>
  /// Export all properties with ResourceProperty attributed as bytes array.
  /// </summary>
  /// <returns></returns>
  List<PropertyValue> serialize() {
    List<PropertyValue> props = <PropertyValue>[];

    for (var pt in _template.properties) {
      //   var rt = pt.info.getValue(resource, null);
      // props.add(new PropertyValue(rt, _ages[pt.index], _modificationDates[pt.index]));
    }

    return props;
  }
  /*
    public bool Deserialize(byte[] data, uint offset, uint length)
    {

        var props = Codec.ParseValues(data, offset, length);
        Deserialize(props);
        return true;
    }
    */
  /*
    public byte[] Serialize(bool includeLength = false, DistributedConnection sender = null)
    {

        //var bl = new BinaryList();
        List<object> props = new List<object>();

        foreach (var pt in template.Properties)
        {

            var pi = resource.GetType().GetProperty(pt.Name);

            var rt = pi.GetValue(resource, null);

            // this is a cool hack to let the property know the sender
            if (rt is Func<DistributedConnection, object>)
                rt = (rt as Func<DistributedConnection, object>)(sender);

            props.Add(rt);

          }

        if (includeLength)
        {
            return Codec.Compose(props.ToArray(), false);
        }
        else
        {
            var rt = Codec.Compose(props.ToArray(), false);
            return DC.Clip(rt, 4, (uint)(rt.Length - 4));
        }
    }

    public byte[] StorageSerialize()
    {

        var props = new List<object>();

        foreach(var pt in  template.Properties)
        {
            if (!pt.Storable)
                continue;

            var pi = resource.GetType().GetProperty(pt.Name);

            if (!pi.CanWrite)
                continue;

            var rt = pi.GetValue(resource, null);

            props.Add(rt);

          }

        return Codec.Compose(props.ToArray(), false);
    }
    */

  /// <summary>
  /// If True, the instance can be stored to disk.
  /// </summary>
  /// <returns></returns>
  bool isStorable() {
    return false;
  }

  void emitModification(PropertyTemplate pt, dynamic value) {
    _instanceAge++;
    var now = DateTime.now().toUtc();

    _ages[pt.index] = _instanceAge;
    _modificationDates[pt.index] = now;

    if (pt.recordable) {
      _store?.record(_resource, pt.name, value, _ages[pt.index], now);
    } else {
      _store?.modify(_resource, pt.name, value, _ages[pt.index], now);
    }

    var pmInfo = PropertyModificationInfo(_resource, pt, value, _instanceAge);

    emitArgs("PropertyModified", [pmInfo]);
    //_resource.emitArgs("modified", [pt.name, value]);
    _resource.emitArgs(":${pt.name}", [value]);

    _resource.emitProperty(pmInfo);
  }

  /// <summary>
  /// Notify listeners that a property was modified.
  /// </summary>
  /// <param name="propertyName"></param>
  /// <param name="newValue"></param>
  /// <param name="oldValue"></param>
  modified(String propertyName) {
    var valueObject = new ValueObject();
    if (getPropertyValue(propertyName, valueObject)) {
      var pt = _template.getPropertyTemplateByName(propertyName);
      if (pt != null) emitModification(pt, valueObject.value);
    }
  }

  emitResourceEvent(issuer, bool Function(Session)? receivers,
      EventTemplate eventTemplate, dynamic value) {
    emitArgs("EventOccurred", [
      EventOccurredInfo(_resource, eventTemplate, value, issuer, receivers)
    ]);
  }

  /// <summary>
  /// Get the value of a given property by name.
  /// </summary>
  /// <param name="name">Property name</param>
  /// <param name="value">Output value</param>
  /// <returns>True, if the resource has the property.</returns>
  bool getPropertyValue(String name, ValueObject valueObject) {
    var pt = _template.getPropertyTemplateByName(name);

    /*
        if (pt != null && pt.info != null)
        {
            valueObject.value = pt.info.getValue(_resource, null);
            return true;

        }*/

    valueObject.value = null;
    return false;
  }

  /*
    public bool Inherit
    {
        get { return inherit; }
    }*/

  /// <summary>
  /// List of parents.
  /// </summary>
  AutoList<IResource, Instance> get parents => _parents;

  /// <summary>
  /// Store responsible for creating and keeping the resource.
  /// </summary>
  IStore? get store => _store;

  /// <summary>
  /// List of children.
  /// </summary>
  AutoList<IResource, Instance> get children => _children;

  /// <summary>
  /// The unique and permanent link to the resource.
  /// </summary>
  String? get link {
    if (_store != null)
      return _store?.link(_resource);
    else {
      var l = <String>[];

      var p = _resource;

      while (true) {
        if (p.instance != null) break;
        var pi = p.instance as Instance;

        l.insert(0, pi.name);

        if (pi.parents.count == 0) break;

        p = pi.parents.first;
      }

      return l.join("/");
    }
  }

  /// <summary>
  /// Instance name.
  /// </summary>
  String get name => _name;
  set name(value) => name = value;

  /// <summary>
  /// Resource managed by this instance.
  /// </summary>
  IResource get resource => _resource;

  /// <summary>
  /// Resource template describes the properties, functions and events of the resource.
  /// </summary>
  TypeTemplate get template => _template;

  /// <summary>
  /// Check for permission.
  /// </summary>
  /// <param name="session">Caller sessions.</param>
  /// <param name="action">Action type</param>
  /// <param name="member">Function, property or event to check for permission.</param>
  /// <param name="inquirer">Permission inquirer.</param>
  /// <returns>Ruling.</returns>
  Ruling applicable(Session session, ActionType action, MemberTemplate? member,
      [dynamic inquirer = null]) {
    for (var i = 0; i < _managers.length; i++) {
      var r = _managers[i]
          .applicable(this.resource, session, action, member, inquirer);
      if (r != Ruling.DontCare) return r;
    }

    return Ruling.DontCare;
  }

  /// <summary>
  /// Execution managers.
  /// </summary>
  AutoList<IPermissionsManager, Instance> get managers => _managers;

  /// <summary>
  /// Create new instance.
  /// </summary>
  /// <param name="id">Instance Id.</param>
  /// <param name="name">Name of the instance.</param>
  /// <param name="resource">Resource to manage.</param>
  /// <param name="store">Store responsible for the resource.</param>
  Instance(this._id, this._name, this._resource, this._store,
      [TypeTemplate? customTemplate = null, this._instanceAge = 0]) {
    _attributes = new KeyList<String, dynamic>(this);
    _children = new AutoList<IResource, Instance>(this);
    _parents = new AutoList<IResource, Instance>(this);
    _managers = new AutoList<IPermissionsManager, Instance>(this);

    _children.on("add", children_OnAdd);
    _children.on("remove", children_OnRemoved);
    _parents.on("add", parents_OnAdd);
    _parents.on("remove", parents_OnRemoved);

    resource.on("destroy", resource_OnDestroy);

    if (customTemplate != null)
      _template = customTemplate;
    else
      _template = Warehouse.getTemplateByType(resource.runtimeType)!;

    // set ages
    for (int i = 0; i < _template.properties.length; i++) {
      _ages.add(0);
      _modificationDates.add(new DateTime(0)); //DateTime.MinValue);
    }

    /*
        // connect events
        Type t = resource.runtimeType;

        var events = t.GetTypeInfo().GetEvents(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);

        foreach (var evt in events)
        {
            //if (evt.EventHandlerType != typeof(ResourceEventHanlder))
            //    continue;


            if (evt.EventHandlerType == typeof(ResourceEventHanlder))
            {
                var ca = (ResourceEvent[])evt.GetCustomAttributes(typeof(ResourceEvent), true);
                if (ca.Length == 0)
                    continue;

                ResourceEventHanlder proxyDelegate = (args) => EmitResourceEvent(null, null, evt.Name, args);
                evt.AddEventHandler(resource, proxyDelegate);

            }
            else if (evt.EventHandlerType == typeof(CustomResourceEventHanlder))
            {
                var ca = (ResourceEvent[])evt.GetCustomAttributes(typeof(ResourceEvent), true);
                if (ca.Length == 0)
                    continue;

                CustomResourceEventHanlder proxyDelegate = (issuer, receivers, args) => EmitResourceEvent(issuer, receivers, evt.Name, args);
                evt.AddEventHandler(resource, proxyDelegate);
            }
      

        }
        */
  }

  void children_OnRemoved(Instance parent, IResource value) {
    value.instance?.parents.remove(_resource);
  }

  void children_OnAdd(Instance parent, IResource value) {
    if (value.instance != null) {
      var ins = value.instance as Instance;
      if (ins.parents.contains(_resource))
        value.instance?.parents.add(_resource);
    }
  }

  void parents_OnRemoved(Instance parent, IResource value) {
    value.instance?.children.remove(_resource);
  }

  void parents_OnAdd(Instance parent, IResource value) {
    if (value.instance != null) {
      var ins = value.instance as Instance;
      if (!ins.children.contains(_resource))
        value.instance?.children.add(_resource);
    }
  }

  void resource_OnDestroy(sender) {
    emitArgs("resourceDestroyed", [sender]);
  }
}
