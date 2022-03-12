 import '../Security/Authority/Session.dart';
import 'IResource.dart';
import 'Template/EventTemplate.dart';

class EventOccurredInfo {
  final EventTemplate eventTemplate;

  String get name => eventTemplate.name;

  final IResource resource;
  final dynamic value;

  final issuer;
  final bool Function(Session)? receivers;

  EventOccurredInfo(this.resource, this.eventTemplate, this.value, this.issuer,
      this.receivers) {}
}
