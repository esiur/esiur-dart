
import 'MemberType.dart';
import '../../Data/DC.dart';
import 'TypeTemplate.dart';

class MemberTemplate
{
    
    int get index => _index;
    String get name => _name;
    MemberType get type => _type;

    TypeTemplate _template;
    String _name;
    MemberType _type;
    int _index;

    TypeTemplate get template => _template;

    MemberTemplate(this._template, this._type, this._index, this._name)
    {
    }

    String get fullname => _template.className + "." + _name;

    DC compose()
    {
        return DC.stringToBytes(_name);
    }
}
