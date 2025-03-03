import 'DC.dart';

class UUID {
  late DC _data;

  UUID(this._data) {}

  UUID.parse(String data) {
    _data = DC.fromHex(data, '');
  }

  DC get value => _data;

  bool operator ==(other) {
    if (other is UUID)
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
