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

import '../Data/AutoList.dart';
import 'FactoryEntry.dart';
import 'Template/TemplateType.dart';
import 'Template/TypeTemplate.dart';
import '../Data/Guid.dart';
import '../Data/KeyList.dart';
import '../Data/Structure.dart';
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
  static AutoList<IResource, Instance> _stores =
      new AutoList<IResource, Instance>(null);
  static Map<int, IResource> _resources = new Map<int, IResource>();
  static int resourceCounter = 0;

  static KeyList<TemplateType, KeyList<Guid, TypeTemplate>> _templates =
      _initTemplates(); //

  static _initTemplates() {
    var rt = new KeyList<TemplateType, KeyList<Guid, TypeTemplate>>();

    rt.add(TemplateType.Unspecified, new KeyList<Guid, TypeTemplate>());
    rt.add(TemplateType.Resource, new KeyList<Guid, TypeTemplate>());
    rt.add(TemplateType.Record, new KeyList<Guid, TypeTemplate>());
    rt.add(TemplateType.Wrapper, new KeyList<Guid, TypeTemplate>());

    return rt;
  }

  static KeyList<Type, FactoryEntry> _factory = _getBuiltInTypes();

  static KeyList<String, AsyncReply<IStore> Function(String, dynamic)>
      protocols = _getSupportedProtocols();

  static bool _warehouseIsOpen = false;

  static final _urlRegex = RegExp(r'^(?:([^\s|:]*):\/\/([^\/]*)\/?(.*))');

  /// <summary>
  /// Get a store by its name.
  /// </summary>
  /// <param name="name">Store instance name</param>
  /// <returns></returns>
  static IStore getStore(String name) {
    for (var s in _stores) if (s.instance.name == name) return s;
    return null;
  }

  /// <summary>
  /// Get a resource by instance Id.
  /// </summary>
  /// <param name="id">Instance Id</param>
  /// <returns></returns>
  static AsyncReply<IResource> getById(int id) {
    if (_resources.containsKey(id))
      return new AsyncReply<IResource>.ready(_resources[id]);
    else
      return new AsyncReply<IResource>.ready(null);
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
        if (!b) {
          rt.trigger(false);
          return;
        }

      var rBag = new AsyncBag<bool>();
      for (var rk in _resources.keys)
        rBag.add(_resources[rk].trigger(ResourceTrigger.SystemInitialized));

      rBag.seal();

      rBag.then((y) {
        for (var b in y)
          if (!b) {
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

    for (var resource in _resources.values)
      if (!(resource is IStore))
        bag.add(resource.trigger(ResourceTrigger.Terminate));

    for (var s in _stores) bag.add(s.trigger(ResourceTrigger.Terminate));

    for (var resource in _resources.values)
      if (!(resource is IStore))
        bag.add(resource.trigger(ResourceTrigger.SystemTerminated));

    for (var store in _stores)
      bag.add(store.trigger(ResourceTrigger.SystemTerminated));

    bag.seal();

    var rt = new AsyncReply<bool>();
    bag.then((x) {
      for (var b in x)
        if (!b) {
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
          if (child.instance.name == path[index]) rt.add(child);
    } else
      for (var child in resources)
        if (child.instance.name == path[index])
          rt.addAll(qureyIn(path, index + 1, child.instance.children));

    return rt;
  }

  static AsyncReply<List<IResource>> query(String path) {
    if (path == null || path == "") {
      var roots = _stores.where((s) => s.instance.parents.length == 0).toList();
      return new AsyncReply<List<IResource>>.ready(roots);
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
  static AsyncReply<T> get<T extends IResource>(String path,
      [attributes = null,
      IResource parent = null,
      IPermissionsManager manager = null]) {
    var rt = AsyncReply<T>();

    // Should we create a new store ?
    if (_urlRegex.hasMatch(path)) {
      var url = _urlRegex.allMatches(path).first;

      if (protocols.containsKey(url[1])) {
        var handler = protocols[url[1]];

        var getFromStore = () {
          handler(url[2], attributes).then<IStore>((store) {
            if (url[3].length > 0 && url[3] != "")
              store.get(url[3]).then<dynamic>((r) {
                rt.trigger(r);
              }).error((e) => rt.triggerError(e));
            else
              rt.trigger(store as T);
          }).error((e) {
            rt.triggerError(e);
            //Warehouse.remove(store);
          });
        };

        if (!_warehouseIsOpen)
          open().then((v) {
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
        rt.trigger(rs[0]);
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
  static AsyncReply<T> put<T extends IResource>(String name, T resource,
      [IStore store = null,
      IResource parent = null,
      TypeTemplate customTemplate = null,
      int age = 0,
      IPermissionsManager manager = null,
      attributes = null]) {
    var rt = AsyncReply<T>();

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

    if (attributes != null)
      resource.instance.setAttributes(Structure.fromMap(attributes));

    if (manager != null) resource.instance.managers.add(manager);

    if (store == parent) parent = null;

    if (parent == null) {
      if (!(resource is IStore)) store.instance.children.add(resource);
    } else
      parent.instance.children.add(resource);

    var initResource = () {
      _resources[resource.instance.id] = resource;

      if (_warehouseIsOpen) {
        resource.trigger(ResourceTrigger.Initialize).then<dynamic>((value) {
          if (resource is IStore)
            resource.trigger(ResourceTrigger.Open).then<dynamic>((value) {
              rt.trigger(resource);
            }).error((ex) {
              Warehouse.remove(resource);
              rt.triggerError(ex);
            });
          else
            rt.trigger(resource);
        }).error((ex) {
          Warehouse.remove(resource);
          rt.triggerError(ex);
        });
      }
    };

    if (resource is IStore) {
      _stores.add(resource);
      initResource();
    } else {
      store.put(resource).then<dynamic>((value) {
        if (value)
          initResource();
        else
          rt.trigger(null);
      }).error((ex) {
        Warehouse.remove(resource);
        rt.triggerError(ex);
      });
    }

    // return new name

    return rt;
  }

  static T createInstance<T>(Type T) {
    return _factory[T].instanceCreator.call();
  }

  static List<T> createArray<T>(Type T) {
    return _factory[T].arrayCreator.call();
  }

  static AsyncReply<T> newResource<T extends IResource>(String name,
      [IStore store = null,
      IResource parent = null,
      IPermissionsManager manager = null,
      attributes = null,
      properties = null]) {
    var resource = _factory[T].instanceCreator.call();

    if (properties != null) {
      dynamic d = resource;

      for (var i = 0; i < properties.length; i++)
        d[properties.keys.elementAt(i)] = properties.at(i);
      //setProperty(resource, properties.keys.elementAt(i), properties.at(i));
    }

    var rt = AsyncReply<T>();

    put<T>(name, resource, store, parent, null, 0, manager, attributes)
        .then<IResource>((value) {
      if (value != null)
        rt.trigger(resource);
      else
        rt.trigger(null);
    }).error((ex) => rt.triggerError(ex));

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
    _templates[template.type][template.classId] = template;
  }

  /// <summary>
  /// Get a template by type from the templates warehouse. If not in the warehouse, a new TypeTemplate is created and added to the warehouse.
  /// </summary>
  /// <param name="type">.Net type.</param>
  /// <returns>Resource template.</returns>
  static TypeTemplate getTemplateByType(Type type) {
    // loaded ?
    for (var tmps in _templates.values)
      for (var tmp in tmps.values) if (tmp.definedType == type) return tmp;

    //if (tmp.className == type.toString()) return tmp;

    var template = new TypeTemplate.fromType(type, true);

    return template;
  }

  /// <summary>
  /// Get a template by class Id from the templates warehouse. If not in the warehouse, a new TypeTemplate is created and added to the warehouse.
  /// </summary>
  /// <param name="classId">Class Id.</param>
  /// <returns>Resource template.</returns>
  static TypeTemplate getTemplateByClassId(Guid classId,
      [TemplateType templateType = TemplateType.Unspecified]) {
    if (templateType == TemplateType.Unspecified) {
      // look in resources
      var template = _templates[TemplateType.Resource][classId];
      if (template != null) return template;

      // look in records
      template = _templates[TemplateType.Record][classId];
      if (template != null) return template;

      // look in wrappers
      template = _templates[TemplateType.Wrapper][classId];
      return template;
    } else {
      return _templates[templateType][classId];
    }
  }

  /// <summary>
  /// Get a template by class name from the templates warehouse. If not in the warehouse, a new TypeTemplate is created and added to the warehouse.
  /// </summary>
  /// <param name="className">Class name.</param>
  /// <returns>Resource template.</returns>
  static TypeTemplate getTemplateByClassName(String className,
      [TemplateType templateType = TemplateType.Unspecified]) {
    if (templateType == TemplateType.Unspecified) {
      // look in resources
      var template = _templates[TemplateType.Resource]
          .values
          .firstWhere((x) => x.className == className);
      if (template != null) return template;

      // look in records
      template = _templates[TemplateType.Record]
          .values
          .firstWhere((x) => x.className == className);
      if (template != null) return template;

      // look in wrappers
      template = _templates[TemplateType.Wrapper]
          .values
          .firstWhere((x) => x.className == className);
      return template;
    } else {
      return _templates[templateType]
          .values
          .firstWhere((x) => x.className == className);
    }
  }

  static bool remove(IResource resource) {
    if (resource.instance == null) return false;

    if (_resources.containsKey(resource.instance.id))
      _resources.remove(resource.instance.id);
    else
      return false;

    if (resource is IStore) {
      _stores.remove(resource);

      // remove all objects associated with the store
      var toBeRemoved =
          _resources.values.where((x) => x.instance.store == resource);
      for (var o in toBeRemoved) remove(o);

      // StoreDisconnected?.Invoke(resource as IStore);
    }

    if (resource.instance.store != null)
      resource.instance.store.remove(resource);

    resource.destroy();

    return true;
  }

  static KeyList<String, AsyncReply<IStore> Function(String, dynamic)>
      _getSupportedProtocols() {
    var rt =
        new KeyList<String, AsyncReply<IStore> Function(String, dynamic)>();
    rt.add(
        "iip",
        (String name, attributes) =>
            Warehouse.newResource<DistributedConnection>(
                name, null, null, null, attributes));
    return rt;
  }

  static defineCreator(
      Type type, Function instanceCreator, Function arrayCreator) {
    _factory.add(type, FactoryEntry(type, instanceCreator, arrayCreator));
  }

  static KeyList<Type, FactoryEntry> _getBuiltInTypes() {
    var rt = KeyList<Type, FactoryEntry>();
    rt.add(
        DistributedConnection,
        FactoryEntry(DistributedConnection, () => DistributedConnection(),
            () => DistributedConnection()));
    return rt;
  }
}
