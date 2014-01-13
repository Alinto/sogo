/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the Inverse inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#include "NSString+ActiveSync.h"

#include <Foundation/NSArray.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSDate.h>

@implementation NSString (ActiveSync)

- (int) activeSyncFolderType
{
  if ([self isEqualToString: @"inbox"])
    return 2;
  else if ([self isEqualToString: @"draft"])
    return 3;
  else if ([self isEqualToString: @"sent"])
    return 5;
  else if  ([self isEqualToString: @"trash"])
    return 4;

  return 12;
}

- (NSString *) realCollectionIdWithFolderType: (SOGoMicrosoftActiveSyncFolderType *) folderType;
{
  NSString *realCollectionId;

  *folderType = ActiveSyncGenericFolder;

  if ([self hasPrefix: @"vevent/"])
    {
      realCollectionId = [self substringFromIndex: 7];
      *folderType = ActiveSyncEventFolder;
    }
  else if ([self hasPrefix: @"vtodo/"])
    {
      realCollectionId = [self substringFromIndex: 6];
      *folderType = ActiveSyncTaskFolder;
    }
  else if ([self hasPrefix: @"vcard/"])
    {
      realCollectionId = [self substringFromIndex: 6];
      *folderType = ActiveSyncContactFolder;
    }
  else
    {
      // mail/
      realCollectionId = [self substringFromIndex: 5];
      *folderType = ActiveSyncMailFolder;
    }

  return realCollectionId;
}

//
// 2014-01-16T05:00:00.000Z
//
// See http://www.gnustep.org/resources/documentation/Developer/Base/Reference/NSCalendarDate.html#method$NSCalendarDate-initWithString$calendarFormat$ for the format details.
//
- (NSCalendarDate *) calendarDate
{
  id o;

  o = [NSCalendarDate dateWithString: self  calendarFormat: @"%Y%m%dT%H%M%SZ"];

  if (!o)
    o = [NSCalendarDate dateWithString: self  calendarFormat: @"%Y-%m-%dT%H:%M:%S.%FZ"];
  
  return o;
}

- (NSString *) _valueForParameter: (NSString *) theParameter
{
  NSArray *components;
  NSString *s;
  int i;

  components = [[[self componentsSeparatedByString: @"/"] lastObject] componentsSeparatedByString: @"&"];
  
  for (i = 0; i < [components count]; i++)
    {
      s = [components objectAtIndex: i];
      
      if ([[s uppercaseString] hasPrefix: theParameter])
        return [s substringFromIndex: [theParameter length]];
    }
  
  return nil;
}

//
// This method extracts the "DeviceId" from a URI:
//
// /SOGo/Microsoft-Server-ActiveSync?Cmd=FolderSync&User=sogo10&DeviceId=SEC17CD1A3E9E3F2&DeviceType=SAMSUNGSGHI317M
//
- (NSString *) deviceId
{
  NSString *s;

  s = [self _valueForParameter: @"DEVICEID="];
  
  if (!s)
    s = @"Unknown";

  return s;
}

//
//
//
- (NSString *) command
{
  NSString *s;
  
  s = [self _valueForParameter: @"CMD="];
  
  if (!s)
    s = @"Unknown";
  
  return s;
}

@end
