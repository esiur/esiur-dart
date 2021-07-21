import '../../Data/DataType.dart';

class TemplateDescriber {
  final List<Prop> properties;
  final List<Evt> events;
  final List<Func> functions;
  final String nameSpace;
  final int version;

  TemplateDescriber(this.nameSpace,
      {this.properties, this.functions, this.events, this.version = 0});
}

// class Property<T> {
//   T _value;

//   Function(T) _setter;
//   Function() _getter;
//   Function(Property) notifier;

//   IResource resource;

//   operator <<(other) {
//     set(other);
//   }

//   void set(T value) {
//     if (_setter != null)
//       _setter(value);
//     else
//       _value = value;

//     if (notifier != null) notifier.call(this);
//   }

//   T get() {
//     if (_getter != null)
//       return _getter();
//     else
//       return _value;
//   }

//   Property([Function() getter, Function(T) setter]) {}
// }

class Prop {
  final String name;
  final Type type;
  final bool isArray;
  final String readAnnotation;
  final String writeAnnotation;
  Prop(this.name, this.type, this.isArray,
      [this.readAnnotation = null, this.writeAnnotation = null]);
}

class Evt {
  final String name;
  final bool listenable;
  final Type type;
  final bool isArray;
  final String annotation;

  Evt(this.name, this.type, this.isArray,
      [this.listenable = false, this.annotation]);
}

class Func {
  final String name;
  final Type returnType;
  final List<Arg> argsType;
  final bool isArray;
  final String annotation;

  Func(this.name, this.returnType, this.isArray, this.argsType,
      [this.annotation = null]);
}

class Arg {
  final String name;
  final Type type;
  final bool isArray;

  Arg(this.name, this.type, this.isArray);
}
