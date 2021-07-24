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
import '../../Data/Guid.dart';

import 'IIPPacketAction.dart';
import 'IIPPacketCommand.dart';
import 'IIPPacketEvent.dart';
import 'IIPPacketReport.dart';
import '../../Data/Codec.dart';
import '../../Data/DataType.dart';

class IIPPacket {
  int report = 0;

  int command = 0;

  int action = 0;

  int event = 0;

  int previousCommand = 0;

  int previousAction = 0;

  int previousEvent = 0;

  int resourceId = 0;
  int newResourceId = 0;

  int childId = 0;
  int storeId = 0;

  int resourceAge = 0;
  DC content = DC(0);
  int errorCode = 0;
  String errorMessage = "";
  String className = "";
  String resourceLink = "";
  Guid classId = Guid(DC(0));
  int methodIndex = 0;
  String methodName = "";
  int callbackId = 0;
  int progressValue = 0;
  int progressMax = 0;
  DateTime fromDate = DateTime(2000);
  DateTime toDate = DateTime(2000);
  int fromAge = 0;
  int toAge = 0;

  int _dataLengthNeeded = 0;
  int _originalOffset = 0;

  bool _notEnough(int offset, int ends, int needed) {
    if (offset + needed > ends) {
      _dataLengthNeeded = needed - (ends - offset);
      //_dataLengthNeeded = (needed - (ends - offset)) + (offset - _originalOffset);

      return true;
    } else
      return false;
  }

  int parse(DC data, int offset, int ends) {
    _originalOffset = offset;

    if (_notEnough(offset, ends, 1)) return -_dataLengthNeeded;

    previousCommand = command;

    command = (data[offset] >> 6);

    if (command == IIPPacketCommand.Event) {
      event = (data[offset++] & 0x3f);

      if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

      resourceId = data.getUint32(offset);
      offset += 4;
    } else if (command == IIPPacketCommand.Report) {
      report = (data[offset++] & 0x3f);

      if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

      callbackId = data.getUint32(offset);
      offset += 4;
    } else {
      previousAction = action;
      action = (data[offset++] & 0x3f);

      if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

      callbackId = data.getUint32(offset);
      offset += 4;
    }

    if (command == IIPPacketCommand.Event) {
      if (event == IIPPacketEvent.ResourceReassigned) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        newResourceId = data.getUint32(offset);
        offset += 4;
      } else if (event == IIPPacketEvent.ResourceDestroyed) {
        // nothing to parse
      } else if (event == IIPPacketEvent.ChildAdded ||
          event == IIPPacketEvent.ChildRemoved) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        childId = data.getUint32(offset);
        offset += 4;
      } else if (event == IIPPacketEvent.Renamed) {
        if (_notEnough(offset, ends, 2)) return -_dataLengthNeeded;

        var cl = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);

        offset += cl;
      } else if (event == IIPPacketEvent.PropertyUpdated ||
          event == IIPPacketEvent.EventOccurred) {
        if (_notEnough(offset, ends, 2)) return -_dataLengthNeeded;

        methodIndex = data[offset++];

        var dt = data[offset++];
        var size = DataType.size(dt);

        if (size < 0) {
          if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

          var cl = data.getUint32(offset);
          offset += 4;

          if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

          content = data.clip(offset - 5, cl + 5);
          offset += cl;
        } else {
          if (_notEnough(offset, ends, size)) return -_dataLengthNeeded;

          content = data.clip(offset - 1, size + 1);
          offset += size;
        }
      }
      // else if (event == IIPPacketEvent.EventOccurred)
      // {
      //     if (_notEnough(offset, ends, 5))
      //         return -_dataLengthNeeded;

      //     methodIndex = data[offset++];

      //     var cl = data.getUint32( offset);
      //     offset += 4;

      //     if (_notEnough(offset, ends, cl))
      //         return -_dataLengthNeeded;

      //     content = data.clip(offset, cl);
      //     offset += cl;

      // }
      // Attribute
      else if (event == IIPPacketEvent.AttributesUpdated) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        var cl = data.getUint32(offset);
        offset += 4;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);

        offset += cl;
      }
    } else if (command == IIPPacketCommand.Request) {
      if (action == IIPPacketAction.AttachResource) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
      } else if (action == IIPPacketAction.ReattachResource) {
        if (_notEnough(offset, ends, 12)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;

        resourceAge = data.getUint64(offset);
        offset += 8;
      } else if (action == IIPPacketAction.DetachResource) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
      } else if (action == IIPPacketAction.CreateResource) {
        if (_notEnough(offset, ends, 12)) return -_dataLengthNeeded;

        storeId = data.getUint32(offset);
        offset += 4;
        resourceId = data.getUint32(offset);
        offset += 4;

        var cl = data.getUint32(offset);
        offset += 4;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);
      } else if (action == IIPPacketAction.DeleteResource) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
      } else if (action == IIPPacketAction.AddChild ||
          action == IIPPacketAction.RemoveChild) {
        if (_notEnough(offset, ends, 8)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
        childId = data.getUint32(offset);
        offset += 4;
      } else if (action == IIPPacketAction.RenameResource) {
        if (_notEnough(offset, ends, 6)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
        var cl = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);
        offset += cl;
      } else if (action == IIPPacketAction.TemplateFromClassName) {
        if (_notEnough(offset, ends, 1)) return -_dataLengthNeeded;

        var cl = data[offset++];

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        className = data.getString(offset, cl);
        offset += cl;
      } else if (action == IIPPacketAction.TemplateFromClassId) {
        if (_notEnough(offset, ends, 16)) return -_dataLengthNeeded;

        classId = data.getGuid(offset);
        offset += 16;
      } else if (action == IIPPacketAction.TemplateFromResourceId) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
      } else if (action == IIPPacketAction.QueryLink ||
          action == IIPPacketAction.LinkTemplates) {
        if (_notEnough(offset, ends, 2)) return -_dataLengthNeeded;

        var cl = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        resourceLink = data.getString(offset, cl);
        offset += cl;
      } else if (action == IIPPacketAction.ResourceChildren ||
          action == IIPPacketAction.ResourceParents) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
      } else if (action == IIPPacketAction.ResourceHistory) {
        if (_notEnough(offset, ends, 20)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;

        fromDate = data.getDateTime(offset);
        offset += 8;

        toDate = data.getDateTime(offset);
        offset += 8;
      } else if (action == IIPPacketAction.InvokeFunctionArrayArguments ||
          action == IIPPacketAction.InvokeFunctionNamedArguments) {
        if (_notEnough(offset, ends, 9)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;

        methodIndex = data[offset++];

        var cl = data.getUint32(offset);
        offset += 4;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);
        offset += cl;
      } else if (action == IIPPacketAction.Listen ||
          action == IIPPacketAction.Unlisten) {
        if (_notEnough(offset, ends, 5)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;

        methodIndex = data[offset++];
      }
      // else if (action == IIPPacketAction.GetProperty)
      // {
      //     if (_notEnough(offset, ends, 5))
      //         return -_dataLengthNeeded;

      //     resourceId = data.getUint32(offset);
      //     offset += 4;

      //     methodIndex = data[offset++];

      // }
      // else if (action == IIPPacketAction.GetPropertyIfModified)
      // {
      //     if (_notEnough(offset, ends, 9))
      //         return -_dataLengthNeeded;

      //     resourceId = data.getUint32(offset);
      //     offset += 4;

      //     methodIndex = data[offset++];

      //     resourceAge = data.getUint64(offset);
      //     offset += 8;

      // }
      else if (action == IIPPacketAction.SetProperty) {
        if (_notEnough(offset, ends, 6)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;

        methodIndex = data[offset++];

        var dt = data[offset++];
        var size = DataType.size(dt);

        if (size < 0) {
          if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

          var cl = data.getUint32(offset);
          offset += 4;

          if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

          content = data.clip(offset - 5, cl + 5);
          offset += cl;
        } else {
          if (_notEnough(offset, ends, size)) return -_dataLengthNeeded;

          content = data.clip(offset - 1, size + 1);
          offset += size;
        }
      }
      // Attributes
      else if (action == IIPPacketAction.UpdateAllAttributes ||
          action == IIPPacketAction.GetAttributes ||
          action == IIPPacketAction.UpdateAttributes ||
          action == IIPPacketAction.ClearAttributes) {
        if (_notEnough(offset, ends, 8)) return -_dataLengthNeeded;

        resourceId = data.getUint32(offset);
        offset += 4;
        var cl = data.getUint32(offset);
        offset += 4;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);
        offset += cl;
      }
    } else if (command == IIPPacketCommand.Reply) {
      if (action == IIPPacketAction.AttachResource ||
          action == IIPPacketAction.ReattachResource) {
        if (_notEnough(offset, ends, 26)) return -_dataLengthNeeded;

        classId = data.getGuid(offset);
        offset += 16;

        resourceAge = data.getUint64(offset);
        offset += 8;

        var cl = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        resourceLink = data.getString(offset, cl);
        offset += cl;

        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        cl = data.getUint32(offset);
        offset += 4;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);
        offset += cl;
      } else if (action == IIPPacketAction.DetachResource) {
        // nothing to do
      } else if (action == IIPPacketAction.CreateResource) {
        if (_notEnough(offset, ends, 20)) return -_dataLengthNeeded;

        //ClassId = data.GetGuid(offset);
        //offset += 16;

        resourceId = data.getUint32(offset);
        offset += 4;
      } else if (action == IIPPacketAction.DetachResource) {
        // nothing to do
      }
      // Inquire
      else if (action == IIPPacketAction.TemplateFromClassName ||
          action == IIPPacketAction.TemplateFromClassId ||
          action == IIPPacketAction.TemplateFromResourceId ||
          action == IIPPacketAction.QueryLink ||
          action == IIPPacketAction.ResourceChildren ||
          action == IIPPacketAction.ResourceParents ||
          action == IIPPacketAction.ResourceHistory ||
          action == IIPPacketAction.LinkTemplates
          // Attribute
          ||
          action == IIPPacketAction.GetAllAttributes ||
          action == IIPPacketAction.GetAttributes) {
        if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

        var cl = data.getUint32(offset);
        offset += 4;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        content = data.clip(offset, cl);
        offset += cl;
      } else if (action == IIPPacketAction.InvokeFunctionArrayArguments ||
          action == IIPPacketAction.InvokeFunctionNamedArguments)
      //|| action == IIPPacketAction.GetProperty
      //|| action == IIPPacketAction.GetPropertyIfModified)
      {
        if (_notEnough(offset, ends, 1)) return -_dataLengthNeeded;

        var dt = data[offset++];
        var size = DataType.size(dt);

        if (size < 0) {
          if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

          var cl = data.getUint32(offset);
          offset += 4;

          if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

          content = data.clip(offset - 5, cl + 5);
          offset += cl;
        } else {
          if (_notEnough(offset, ends, size)) return -_dataLengthNeeded;

          content = data.clip(offset - 1, size + 1);
          offset += size;
        }
      } else if (action == IIPPacketAction.SetProperty ||
          action == IIPPacketAction.Listen ||
          action == IIPPacketAction.Unlisten) {
        // nothing to do
      }
    } else if (command == IIPPacketCommand.Report) {
      if (report == IIPPacketReport.ManagementError) {
        if (_notEnough(offset, ends, 2)) return -_dataLengthNeeded;

        errorCode = data.getUint16(offset);
        offset += 2;
      } else if (report == IIPPacketReport.ExecutionError) {
        if (_notEnough(offset, ends, 2)) return -_dataLengthNeeded;

        errorCode = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, 2)) return -_dataLengthNeeded;

        var cl = data.getUint16(offset);
        offset += 2;

        if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

        errorMessage = data.getString(offset, cl);
        offset += cl;
      } else if (report == IIPPacketReport.ProgressReport) {
        if (_notEnough(offset, ends, 8)) return -_dataLengthNeeded;

        progressValue = data.getInt32(offset);
        offset += 4;
        progressMax = data.getInt32(offset);
        offset += 4;
      } else if (report == IIPPacketReport.ChunkStream) {
        if (_notEnough(offset, ends, 1)) return -_dataLengthNeeded;

        var dt = data[offset++];
        var size = DataType.size(dt);

        if (size < 0) {
          if (_notEnough(offset, ends, 4)) return -_dataLengthNeeded;

          var cl = data.getUint32(offset);
          offset += 4;

          if (_notEnough(offset, ends, cl)) return -_dataLengthNeeded;

          content = data.clip(offset - 5, cl + 5);
          offset += cl;
        } else {
          if (_notEnough(offset, ends, size)) return -_dataLengthNeeded;

          content = data.clip(offset - 1, size + 1);
          offset += size;
        }
      }
    }

    return offset - _originalOffset;
  }

  toString() {
    var rt = command.toString();

    if (command == IIPPacketCommand.Event) {
      rt += " " + event.toString();
    } else if (command == IIPPacketCommand.Request) {
      rt += " " + action.toString();
      if (action == IIPPacketAction.AttachResource) {
        rt +=
            " CID: " + callbackId.toString() + " RID: " + resourceId.toString();
      }
    } else if (command == IIPPacketCommand.Reply)
      rt += " " + action.toString();
    else if (command == IIPPacketCommand.Report) rt += " " + report.toString();

    return rt;
  }
}
