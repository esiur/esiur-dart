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

import '../Data/IntType.dart';

import '../Data/TransmissionType.dart';
import '../Data/RepresentationType.dart';

import '../Data/Record.dart';

import '../Core/Tuple.dart';
import '../Data/IRecord.dart';

import '../Core/AsyncException.dart';
import '../Core/ErrorType.dart';
import '../Core/ExceptionCode.dart';

import '../Data/AutoList.dart';
import 'FactoryEntry.dart';
import 'Template/TemplateType.dart';
import 'Template/TypeTemplate.dart';
import '../Data/Guid.dart';
import '../Data/KeyList.dart';
import '../Security/Permissions/IPermissionsManager.dart';
import 'IResource.dart';
import 'Instance.dart';
import 'IStore.dart';
import '../Core/AsyncReply.dart';
import '../Core/AsyncBag.dart';
import 'ResourceTrigger.dart';

import '../Net/IIP/DistributedConnection.dart';

// Centeral Resource Issuer
class Warehouse {
  static AutoList<IStore, Instance> _stores = AutoList<IStore, Instance>();
  static Map<int, WeakReference<IResource>> _resources =
      new Map<int, WeakReference<IResource>>();
  static int resourceCounter = 0;

  static KeyList<TemplateType, KeyList<Guid, TypeTemplate>> _templates =
      _initTemplates(); //

  static KeyList<TemplateType, KeyList<Guid, TypeTemplate>> _initTemplates() {
    var rt = new KeyList<TemplateType, KeyList<Guid, TypeTemplate>>();

    rt.add(TemplateType.Resource, new KeyList<Guid, TypeTemplate>());
    rt.add(TemplateType.Record, new KeyList<Guid, TypeTemplate>());
    rt.add(TemplateType.Enum, new KeyList<Guid, TypeTemplate>());

    return rt;
  }

  static KeyList<Type, FactoryEntry> _factory = _getBuiltInTypes();

  static KeyList<String,
          AsyncReply<IStore> Function(String, Map<String, dynamic>?)>
      protocols = _getSupportedProtocols();

  static bool _warehouseIsOpen = false;

  static final _urlRegex = RegExp(r'^(?:([^\s|:]*):\/\/([^\/]*)\/?(.*))');

  /// <summary>
  /// Get a store by its name.
  /// </summary>
  /// <param name="name">Store instance name</param>
  /// <returns></returns>
  static IStore? getStore(String name) {
    for (var s in _stores) if (s.instance?.name == name) return s;
    return null;
  }

  /// <summary>
  /// Get a resource by instance Id.
  /// </summary>
  /// <param name="id">Instance Id</param>
  /// <returns></returns>
  static AsyncReply<IResource?> getById(int id) {
    if (_resources.containsKey(id))
      return new AsyncReply<IResource?>.ready(_resources[id]?.target);
    else
      return new AsyncReply<IResource?>.ready(null);
  }

  /// <summary>
  /// Open the warehouse.
  /// This function issues the initialize trigger to all stores and resources.
  /// </summary>
  /// <returns>True, if no problem occurred.</returns>
  static AsyncReply<bool> open() {
    var bag = new AsyncBag<bool>();

    for (var s in _stores) bag.add(s.trigger(ResourceTrigger.Initialize));

    bag.seal();

    var rt = new AsyncReply<bool>();
    bag.then((x) {
      for (var b in x)
        if (b == null || b == false) {
          rt.trigger(false);
          return;
        }

      var rBag = new AsyncBag<bool>();
      for (var rk in _resources.keys)
        rBag.add((_resources[rk] as IResource)
            .trigger(ResourceTrigger.SystemInitialized));

      rBag.seal();

      rBag.then((y) {
        for (var b in y)
          if (b == null || b == false) {
            rt.trigger(false);
            return;
          }

        rt.trigger(true);
        _warehouseIsOpen = true;
      });
    });

    return rt;
  }

  /// <summary>
  /// Close the warehouse.
  /// This function issues terminate trigger to all resources and stores.
  /// </summary>
  /// <returns>True, if no problem occurred.</returns>
  static AsyncReply<bool> close() {
    var bag = new AsyncBag<bool>();

    for (var resource in _resources.values) {
      var r = resource.target;
      if ((r != null) && !(r is IStore))
        bag.add(r.trigger(ResourceTrigger.Terminate));
    }

    for (var s in _stores) bag.add(s.trigger(ResourceTrigger.Terminate));

    for (var resource in _resources.values) {
      var r = resource.target;
      if ((r != null) && !(resource is IStore))
        bag.add(r.trigger(ResourceTrigger.SystemTerminated));
    }

    for (var store in _stores)
      bag.add(store.trigger(ResourceTrigger.SystemTerminated));

    bag.seal();

    var rt = new AsyncReply<bool>();
    bag.then((x) {
      for (var b in x)
        if (b == null || b == false) {
          rt.trigger(false);
          return;
        }

      rt.trigger(true);
    });

    return rt;
  }

  static List<IResource> qureyIn(
      List<String> path, int index, AutoList<IResource, Instance> resources) {
    List<IResource> rt = [];

    if (index == path.length - 1) {
      if (path[index] == "")
        for (var child in resources) rt.add(child);
      else
        for (var child in resources)
          if (child.instance?.name == path[index]) rt.add(child);
    } else
      for (var child in resources)
        if (child.instance?.name == path[index])
          rt.addAll(qureyIn(path, index + 1,
              child.instance?.children as AutoList<IResource, Instance>));

    return rt;
  }

  static AsyncReply<List<IResource>?> query(String? path) {
    if (path == null || path == "") {
      var roots =
          _stores.where((s) => s.instance?.parents.length == 0).toList();
      return new AsyncReply<List<IResource>?>.ready(roots);
    } else {
      var rt = new AsyncReply<List<IResource>>();
      get(path).then((x) {
        var p = path.split('/');

        if (x == null) {
          rt.trigger(qureyIn(p, 0, _stores));
        } else {
          var ar = qureyIn(p, 0, _stores).where((r) => r != x).toList();
          ar.insert(0, x);
          rt.trigger(ar);
        }
      });

      return rt;
    }
  }

  /// <summary>
  /// Get a resource by its path.
  /// Resource path is sperated by '/' character, e.g. "system/http".
  /// </summary>
  /// <param name="path"></param>
  /// <returns>Resource instance.</returns>
  static AsyncReply<T?> get<T extends IResource>(String path,
      [Map<String, dynamic>? attributes = null,
      IResource? parent = null,
      IPermissionsManager? manager = null]) {
    var rt = AsyncReply<T?>();

    // Should we create a new store ?
    if (_urlRegex.hasMatch(path)) {
      var url = _urlRegex.allMatches(path).first;

      if (protocols.containsKey(url[1])) {
        var handler = protocols[url[1]] as AsyncReply<IStore> Function(
            String, Map<String, dynamic>?);

        var getFromStore = () {
          handler(url[2] as String, attributes)
            ..then((store) {
              if ((url[3] as String).length > 0 && url[3] != "")
                store.get(url[3] as String)
                  ..then((r) {
                    rt.trigger(r as T);
                  })
                  ..error((e) => rt.triggerError(e));
              else
                rt.trigger(store as T);
            })
            ..error((e) {
              rt.triggerError(e);
              //Warehouse.remove(store);
            });
        };

        if (!_warehouseIsOpen)
          open()
            ..then((v) {
              if (v)
                getFromStore();
              else
                rt.trigger(null);
            });
        else
          getFromStore();

        return rt;
      }
    }

    query(path).then((rs) {
      if (rs != null && rs.length > 0)
        rt.trigger(rs[0] as T);
      else
        rt.trigger(null);
    });

    return rt;

/*
        var p = path.split('/');
        IResource res;

        for(IStore d in _stores)
            if (p[0] == d.instance.name)
            {
                var i = 1;
                res = d;
                while(p.length > i)
                {
                    var si = i;

                    for (IResource r in res.instance.children)
                        if (r.instance.name == p[i])
                        {
                            i++;
                            res = r;
                            break;
                        }

                    if (si == i)
                        // not found, ask the store
                        return d.get(path.substring(p[0].length + 1));
                }

                return new AsyncReply<IResource>.ready(res);
            }

        // Should we create a new store ?
        if (path.contains("://"))
        {
            var url = path.split("://");
            var hostname = url[1].split('/')[0];
            var pathname = url[1].split('/').skip(1).join("/");

            var rt = new AsyncReply<IResource>();

            if (protocols.containsKey(url[0]))
            {
                var handler = protocols[url[0]];

                var store = handler();
                put(store, url[0] + "://" + hostname, null, parent, null, 0, manager, attributes);


                store.trigger(ResourceTrigger.Open).then<dynamic>((x){
                    if (pathname.length > 0 && pathname != "")
                        store.get(pathname).then<dynamic>((r) => rt.trigger(r)
                            ).error((e) => 
                            
                            rt.triggerError(e)
                            
                            );
                    else
                        rt.trigger(store);
                }).error((e) {
                    rt.triggerError(e);
                    Warehouse.remove(store);
                });
            }

            return rt;
        }


        return new AsyncReply<IResource>.ready(null);
        */
  }

  /// <summary>
  /// Put a resource in the warehouse.
  /// </summary>
  /// <param name="resource">Resource instance.</param>
  /// <param name="name">Resource name.</param>
  /// <param name="store">IStore that manages the resource. Can be null if the resource is a store.</param>
  /// <param name="parent">Parent resource. if not presented the store becomes the parent for the resource.</param>
  static AsyncReply<T?> put<T extends IResource>(String name, T resource,
      [IStore? store = null,
      IResource? parent = null,
      TypeTemplate? customTemplate = null,
      int age = 0,
      IPermissionsManager? manager = null,
      Map<String, dynamic>? attributes = null]) {
    var rt = AsyncReply<T?>();

    if (resource.instance != null) {
      rt.triggerError(Exception("Resource has a store."));
      return rt;
    }

    // @TODO: Trim left '/' char
    // var path = name.trimLeft().split("/");
    // if (path.length > 1)
    // {
    //     if (parent != null)
    //        rt.triggerError(Exception("Parent can't be set when using path in instance name"));

    //     Warehouse.get<IResource>(path.take(path.length - 1).join("/")).then((value){
    //         if (value == null)
    //             rt.triggerError(Exception("Can't find parent"));

    //         parent = value;

    //         store = store ?? parent.instance.store;

    //         var instanceName = path.last;

    //         if (store == null)
    //         {
    //             // assign parent as a store
    //             if (parent is IStore)
    //             {
    //                 store = (IStore)parent;
    //                 stores
    //                 List<WeakReference<IResource>> list;
    //                 if (stores.TryGetValue(store, out list))
    //                     lock (((ICollection)list).SyncRoot)
    //                         list.Add(resourceReference);
    //                 //stores[store].Add(resourceReference);
    //             }
    //             // assign parent's store as a store
    //             else if (parent != null)
    //             {
    //                 store = parent.instance.store;

    //                 List<WeakReference<IResource>> list;
    //                 if (stores.TryGetValue(store, out list))
    //                     lock (((ICollection)list).SyncRoot)
    //                         list.Add(resourceReference);

    //                 //stores[store].Add(resourceReference);
    //             }
    //             // assign self as a store (root store)
    //             else if (resource is IStore)
    //             {
    //                 store = resource;
    //             }
    //             else
    //                 throw new Exception("Can't find a store for the resource.");
    //         }

    //     });

    // }

    resource.instance = new Instance(
        resourceCounter++, name, resource, store, customTemplate, age);

    if (attributes != null) resource.instance?.setAttributes(attributes);

    if (manager != null) resource.instance?.managers.add(manager);

    if (store == parent) parent = null;

    if (parent == null) {
      if (!(resource is IStore)) store?.instance?.children.add(resource);
    } else
      parent.instance?.children.add(resource);

    var initResource = () {
      if (resource.instance == null) return;

      _resources[(resource.instance as Instance).id] = WeakReference(resource);

      if (_warehouseIsOpen) {
        resource.trigger(ResourceTrigger.Initialize)
          ..then((value) {
            if (resource is IStore)
              resource.trigger(ResourceTrigger.Open)
                ..then((value) {
                  rt.trigger(resource);
                })
                ..error((ex) {
                  Warehouse.remove(resource);
                  rt.triggerError(ex);
                });
            else
              rt.trigger(resource);
          })
          ..error((ex) {
            Warehouse.remove(resource);
            rt.triggerError(ex);
          });
      }
    };

    if (resource is IStore) {
      _stores.add(resource);
      initResource();
    } else {
      store?.put(resource)
        ?..then((value) {
          if (value)
            initResource();
          else
            rt.trigger(null);
        })
        ..error((ex) {
          Warehouse.remove(resource);
          rt.triggerError(ex);
        });
    }

    // return new name

    return rt;
  }

  static KeyList<Type, FactoryEntry> get typesFactory => _factory;

  static T createInstance<T>(Type type) {
    return _factory[type]?.instanceCreator.call() as T;
  }

  static List<T> createArray<T>(Type type) {
    return _factory[type]?.arrayCreator.call() as List<T>;
  }

  static AsyncReply<T> newResource<T extends IResource>(String name,
      [IStore? store = null,
      IResource? parent = null,
      IPermissionsManager? manager = null,
      Map<String, dynamic>? attributes = null,
      Map<String, dynamic>? properties = null]) {
    if (_factory[T] == null)
      throw Exception("No Instance Creator was found for type ${T}");

    var resource = _factory[T]?.instanceCreator.call() as T;

    if (properties != null) {
      dynamic d = resource;

      for (var i = 0; i < properties.length; i++)
        d[properties.keys.elementAt(i)] = properties.values.elementAt(i);
      //setProperty(resource, properties.keys.elementAt(i), properties.at(i));
    }

    var rt = AsyncReply<T>();

    put<T>(name, resource, store, parent, null, 0, manager, attributes)
      ..then((value) {
        if (value != null)
          rt.trigger(resource);
        else
          rt.triggerError(AsyncException(
              ErrorType.Management,
              ExceptionCode.GeneralFailure.index,
              "Can't put the resource")); // .trigger(null);
      })
      ..error((ex) => rt.triggerError(ex));

    return rt;

    /*
        var type = ResourceProxy.GetProxy<T>();
        var res = Activator.CreateInstance(type) as IResource;
        put(res, name, store, parent, null, 0, manager, attributes);
        return (T)res;
      */
  }

  /// <summary>
  /// Put a resource template in the templates warehouse.
  /// </summary>
  /// <param name="template">Resource template.</param>
  static void putTemplate(TypeTemplate template) {
    if (_templates[template.type]?.containsKey(template.classId) ?? false)
      throw Exception("Template with same class Id already exists.");

    _templates[template.type]?[template.classId] = template;
  }

  /// <summary>
  /// Get a template by type from the templates warehouse. If not in the warehouse, a new TypeTemplate is created and added to the warehouse.
  /// </summary>
  /// <param name="type">.Net type.</param>
  /// <returns>Resource template.</returns>
  static TypeTemplate? getTemplateByType(Type type) {
    
    // loaded ?
    for (var tmps in _templates.values)
      for (var tmp in tmps.values) if (tmp.definedType == type) return tmp;

    //try {
    var template = new TypeTemplate.fromType(type, true);
    return template;
    //} catch (ex) {
    //  return null;
    //}
  }

  /// <summary>
  /// Get a template by class Id from the templates warehouse. If not in the warehouse, a new TypeTemplate is created and added to the warehouse.
  /// </summary>
  /// <param name="classId">Class Id.</param>
  /// <returns>Resource template.</returns>
  static TypeTemplate? getTemplateByClassId(Guid classId,
      [TemplateType? templateType = null]) {
    if (templateType == null) {
      // look into resources
      var template = _templates[TemplateType.Resource]?[classId];
      if (template != null) return template;

      // look into records
      template = _templates[TemplateType.Record]?[classId];
      if (template != null) return template;

      // look into enums
      template = _templates[TemplateType.Enum]?[classId];
      return template;
    } else {
      return _templates[templateType]?[classId];
    }
  }

  /// <summary>
  /// Get a template by class name from the templates warehouse. If not in the warehouse, a new TypeTemplate is created and added to the warehouse.
  /// </summary>
  /// <param name="className">Class name.</param>
  /// <returns>Resource template.</returns>
  static TypeTemplate? getTemplateByClassName(String className,
      [TemplateType? templateType = null]) {
    if (templateType == null) {
      // look into resources
      var template = _templates[TemplateType.Resource]
          ?.values
          .firstWhere((x) => x.className == className);
      if (template != null) return template;

      // look into records
      template = _templates[TemplateType.Record]
          ?.values
          .firstWhere((x) => x.className == className);
      if (template != null) return template;

      // look into wrappers
      template = _templates[TemplateType.Enum]
          ?.values
          .firstWhere((x) => x.className == className);
      return template;
    } else {
      return _templates[templateType]
          ?.values
          .firstWhere((x) => x.className == className);
    }
  }

  static bool remove(IResource resource) {
    if (resource.instance == null) return false;

    if (_resources.containsKey(resource.instance?.id))
      _resources.remove(resource.instance?.id);
    else
      return false;

    if (resource is IStore) {
      _stores.remove(resource);

      // remove all objects associated with the store
      //var toBeRemoved =
      //  _resources.values.where((x) => x.target?.instance?.store == resource);

      var toBeRemoved = <IResource>[];
      for (var wr in _resources.values) {
        var r = wr.target;
        if (r != null && r.instance?.store == resource) toBeRemoved.add(r);
      }

      for (var o in toBeRemoved) remove(o);

      // StoreDisconnected?.Invoke(resource as IStore);
    }

    if (resource.instance?.store != null)
      resource.instance?.store?.remove(resource);

    resource.destroy();

    resource.instance = null;
    
    return true;
  }

  static KeyList<String,
          AsyncReply<IStore> Function(String, Map<String, dynamic>?)>
      _getSupportedProtocols() {
    var rt = new KeyList<String,
        AsyncReply<IStore> Function(String, Map<String, dynamic>?)>();
    rt
      ..add(
          "iip",
          (String name, Map<String, dynamic>? attributes) =>
              Warehouse.newResource<DistributedConnection>(
                  name, null, null, null, attributes))
      ..add("iipws", (String name, Map<String, dynamic>? attributes) {
        if (attributes == null) attributes = {};
        attributes['ws'] = true;
        return Warehouse.newResource<DistributedConnection>(
            name, null, null, null, attributes);
      })
      ..add("iipwss", (String name, Map<String, dynamic>? attributes) {
        if (attributes == null) attributes = {};
        attributes['wss'] = true;
        return Warehouse.newResource<DistributedConnection>(
            name, null, null, null, attributes);
      });

    return rt;
  }

  static List<FactoryEntry> _getTypeEntries<T>(
      Function instanceCreator, RepresentationType representationType) {
    return [
      FactoryEntry<T>(instanceCreator, representationType),
      FactoryEntry<T?>(instanceCreator, representationType.toNullable()),
      FactoryEntry<List<T>>(
          () => <T>[],
          RepresentationType(RepresentationTypeIdentifier.TypedList, false,
              null, [representationType])),
      FactoryEntry<List<T>?>(
          () => <T>[],
          RepresentationType(RepresentationTypeIdentifier.TypedList, true, null,
              [representationType])),
      FactoryEntry<List<T?>>(
          () => <T?>[],
          RepresentationType(RepresentationTypeIdentifier.TypedList, false,
              null, [representationType.toNullable()])),
      FactoryEntry<List<T?>?>(
          () => <T?>[],
          RepresentationType(RepresentationTypeIdentifier.TypedList, true, null,
              [representationType.toNullable()])),
    ];
  }

  static void defineType<T>(
      Function instanceCreator, RepresentationType representationType) {
    var entries = _getTypeEntries<T>(instanceCreator, representationType);
    entries.forEach((e) {
      _factory.add(e.type, e);
    });
  }

  static KeyList<Type, FactoryEntry> _getBuiltInTypes() {
    var rt = KeyList<Type, FactoryEntry>();

    var types = <FactoryEntry>[
      FactoryEntry<DistributedConnection>(
          () => DistributedConnection(), RepresentationType.Void)
    ];

    types
      ..addAll(_getTypeEntries<Int8>(() => 0,
          RepresentationType(RepresentationTypeIdentifier.Int8, false)))
      ..addAll(_getTypeEntries<UInt8>(() => 0,
          RepresentationType(RepresentationTypeIdentifier.UInt8, false)))
      ..addAll(_getTypeEntries<Int16>(() => 0,
          RepresentationType(RepresentationTypeIdentifier.Int16, false)))
      ..addAll(_getTypeEntries<UInt16>(() => 0,
          RepresentationType(RepresentationTypeIdentifier.UInt16, false)))
      ..addAll(_getTypeEntries<Int32>(() => 0,
          RepresentationType(RepresentationTypeIdentifier.Int32, false)))
      ..addAll(_getTypeEntries<UInt32>(() => 0,
          RepresentationType(RepresentationTypeIdentifier.UInt32, false)))
      ..addAll(_getTypeEntries<int>(() => 0,
          RepresentationType(RepresentationTypeIdentifier.Int64, false)))
      ..addAll(_getTypeEntries<bool>(() => false,
          RepresentationType(RepresentationTypeIdentifier.Bool, false)))
      ..addAll(_getTypeEntries<double>(() => 0.0,
          RepresentationType(RepresentationTypeIdentifier.Float64, false)))
      ..addAll(_getTypeEntries<String>(() => "",
          RepresentationType(RepresentationTypeIdentifier.String, false)))
      ..addAll(_getTypeEntries<DateTime>(() => DateTime.now(),
          RepresentationType(RepresentationTypeIdentifier.DateTime, false)))
      ..addAll(_getTypeEntries<Record>(() => Record(),
          RepresentationType(RepresentationTypeIdentifier.Record, false)))
      ..addAll(_getTypeEntries<IResource>(() => null,
          RepresentationType(RepresentationTypeIdentifier.Resource, false)))
      ..addAll(_getTypeEntries<List>(() => [],
          RepresentationType(RepresentationTypeIdentifier.List, false)))
      ..addAll(_getTypeEntries<Map>(() => Map(),
          RepresentationType(RepresentationTypeIdentifier.Map, false)))
      ..addAll(_getTypeEntries<Map<String, dynamic>>(
          () => Map<String, dynamic>,
          RepresentationType(
              RepresentationTypeIdentifier.TypedMap, false, null, [
            RepresentationType(RepresentationTypeIdentifier.String, false),
            RepresentationType.Dynamic
          ])))
      ..addAll(_getTypeEntries<Map<int, dynamic>>(
          () => Map<int, dynamic>(),
          RepresentationType(
              RepresentationTypeIdentifier.TypedMap, false, null, [
            RepresentationType(RepresentationTypeIdentifier.Int64, false),
            RepresentationType.Dynamic
          ])))
      ..addAll(_getTypeEntries<Map<Int32, dynamic>>(
          () => Map<Int32, dynamic>(),
          RepresentationType(
              RepresentationTypeIdentifier.TypedMap, false, null, [
            RepresentationType(RepresentationTypeIdentifier.Int32, false),
            RepresentationType.Dynamic
          ])))
      ..addAll(_getTypeEntries<Map<UInt8, dynamic>>(
          () => Map<UInt8, dynamic>(),
          RepresentationType(
              RepresentationTypeIdentifier.TypedMap, false, null, [
            RepresentationType(RepresentationTypeIdentifier.UInt8, false),
            RepresentationType.Dynamic
          ])))
      ..addAll(
          _getTypeEntries<dynamic>(() => Object(), RepresentationType.Dynamic));

    types.forEach((element) {
      rt.add(element.type, element);
    });

    return rt;
  }
}
