import 'IEventHandler.dart';

typedef DestroyedEvent(sender);

abstract class IDestructible extends IEventHandler {
  void destroy();
}
