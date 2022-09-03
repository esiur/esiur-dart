class TemplateDescriber {
  final List<Prop>? properties;
  final List<Evt>? events;
  final List<Func>? functions;
  final List<Const>? constants;

  final String nameSpace;
  final int version;
  final Type? parent;
  final String? annotation;

  const TemplateDescriber(this.nameSpace,
      {this.parent,
      this.properties,
      this.functions,
      this.events,
      this.constants,
      this.version = 0,
      this.annotation = null});
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
  //final bool isNullable;
  final String? readAnnotation;
  final String? writeAnnotation;
  final bool recordable;

  const Prop(this.name, this.type,
      [this.readAnnotation = null,
      this.writeAnnotation = null,
      this.recordable = false]);
}

class Evt {
  final String name;
  final bool listenable;
  final Type type;
  //final bool isNullable;
  final String? annotation;
  const Evt(this.name, this.type, [this.listenable = false, this.annotation]);
}

class Const {
  final String name;
  final Type type;
  //final bool isNullable;
  final String? annotation;
  final value;

  const Const(this.name, this.type, this.value, [this.annotation]);
}

class Func {
  final String name;
  final Type returnType;
  final List<Arg> args;
  //final bool isNullable;
  final String? annotation;
  final bool isStatic;
  const Func(this.name, this.returnType, this.args,
      [this.annotation = null, this.isStatic = false]);
}

class Arg {
  final String name;
  final Type type;
  //final bool isNullable;
  final bool optional;
  const Arg(this.name, this.type, this.optional);
}
