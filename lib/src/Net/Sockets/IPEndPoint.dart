class IPEndPoint
{
    List<int> ip;
    int port;


  String getIP()
  {
    return ip.join(".");
    //return "${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}";
  }

  String get address => getIP();

    @override
  String toString() {
    return "${getIP()}:${port}";
  }


  IPEndPoint(this.ip, this.port)
  {
    
  }
}