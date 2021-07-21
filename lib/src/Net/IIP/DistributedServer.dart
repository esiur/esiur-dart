import '../../Resource/Template/TemplateDescriber.dart';

import '../../Resource/IResource.dart';
import '../../Core/AsyncReply.dart';
import '../../Resource/ResourceTrigger.dart';

import './EntryPoint.dart';

class DistributedServer extends IResource {
  @override
  void destroy() {
    this.emitArgs("destroy", []);
  }

  @override
  AsyncReply<bool> trigger(ResourceTrigger trigger) {
    return AsyncReply.ready(true);
  }

  EntryPoint entryPoint;

  @override
  getProperty(String name) => null;

  @override
  invoke(String name, List arguments) => null;

  @override
  setProperty(String name, value) => true;

  @override
  TemplateDescriber get template =>
      TemplateDescriber("Esiur.Net.IIP.DistributedServer");

}
