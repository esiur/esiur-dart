import 'ExceptionCode.dart';
import 'ErrorType.dart';

class AsyncException implements Exception {
  AsyncException(this.type, this.code, this.message);

  final ErrorType type;
  final int code;
  final String message;

  static toAsyncException(Exception ex) => ex is AsyncException
      ? ex
      : new AsyncException(ErrorType.Exception, 0, ex.toString());

  String errMsg() {
    if (type == ErrorType.Management) {
      return ExceptionCode.values.elementAt(code).toString() +
          ": " +
          (message ?? "");
    } else {
      return code.toString() + ": " + message;
    }
  }

  @override
  String toString() => errMsg();
}
