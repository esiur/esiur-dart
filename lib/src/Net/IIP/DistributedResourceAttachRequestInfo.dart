import '../../Core/AsyncReply.dart';
import 'DistributedResource.dart';

class DistributedResourceAttachRequestInfo {
  List<int> requestSequence;
  AsyncReply<DistributedResource> reply;

  DistributedResourceAttachRequestInfo(this.reply, this.requestSequence) {}
}
