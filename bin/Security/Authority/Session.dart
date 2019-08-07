/*
 
Copyright (c) 2019 Ahmed Kh. Zamil

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/
import '../../Data/DC.dart';
import 'Authentication.dart';
import '../../Data/KeyList.dart';

class Session
{
    Authentication get localAuthentication => _localAuth;
    Authentication get remoteAuthentication => _remoteAuth;

    // public Source Source { get; }
    DC id;

    //DateTime get creation => _creation;

    //public DateTime Modification { get; }
    final KeyList<String, dynamic> variables =  new KeyList<String, dynamic>();

      //KeyList<string, object> Variables { get; }
    //IStore Store { get; }

    //string id;
    Authentication _localAuth, _remoteAuth;
    

    Session(Authentication localAuthentication, Authentication remoteAuthentication)
    {
          
        this._localAuth = localAuthentication;
        this._remoteAuth = remoteAuthentication;
    }
}
