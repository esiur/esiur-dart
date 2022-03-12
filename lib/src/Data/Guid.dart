import 'DC.dart';

class Guid {
  late DC _data;

  Guid(this._data) {}

  Guid.fromString(String data) {
    _data = DC.fromHex(data, '');
  }

  DC get value => _data;

  bool operator ==(other) {
    if (other is Guid)
      return _data.sequenceEqual(other._data);
    else
      return false;
  }

  @override
  String toString() {
    return _data.toHex('');
  }

  @override
  int get hashCode => _data.toString().hashCode;
}
