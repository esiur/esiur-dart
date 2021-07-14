

import '../../Resource/IResource.dart';
import './DistributedConnection.dart';
import '../../Core/AsyncReply.dart';

abstract class EntryPoint extends IResource
{

      AsyncReply<List<IResource>> query(String path, DistributedConnection sender);
      bool create();
}
