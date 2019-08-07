import 'DistributedConnection.dart';
class DistributedPropertyContext
{
    dynamic value;
    DistributedConnection connection;
    dynamic Function(DistributedConnection) method;


    DistributedPropertyContext(this.method)
    {

    }

    DistributedPropertyContext.setter(this.value, this.connection)
    {

    }
}
