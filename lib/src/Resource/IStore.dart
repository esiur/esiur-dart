/*
 
Copyright (c) 2017 Ahmed Kh. Zamil

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

import './IResource.dart';
import '../Core/AsyncReply.dart';
import '../Data/KeyList.dart';
import './Template/PropertyTemplate.dart';
import '../Data/PropertyValue.dart';

// old 
// abstract class IStore extends IResource
// new
abstract class IStore implements IResource
{
    AsyncReply<IResource> get(String path);
    AsyncReply<IResource> retrieve(int iid);
    AsyncReply<bool> put(IResource resource);
    String link(IResource resource);
    bool record(IResource resource, String propertyName, dynamic value, int age, DateTime dateTime);
    bool modify(IResource resource, String propertyName, dynamic value, int age, DateTime dateTime);
    bool remove(IResource resource);

    AsyncReply<KeyList<PropertyTemplate, List<PropertyValue>>> getRecord(IResource resource, DateTime fromDate, DateTime toDate);
}
