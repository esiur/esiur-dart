import 'dart:js' as js;

import "esiur.dart" as esiur;

void main() {
  js.context['wh'] = esiur.Warehouse();
}
