import 'DC.dart';

class Guid
{
  DC _data;

  Guid(DC data)
  {
    _data = data;
  }

  DC get value => _data; 

  @override
  String toString() {
    return _data.getString(0, _data.length);
  }
}