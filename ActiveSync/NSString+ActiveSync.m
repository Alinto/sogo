/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#include "NSString+ActiveSync.h"

#include <Foundation/NSArray.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSTimeZone.h>

#include <SOGo/NSString+Utilities.h>
#include <SOGo/NSData+Crypto.h>

#include <NGExtensions/NGBase64Coding.h>
#include <NGExtensions/NSString+misc.h>

static NSArray *easCommandCodes = nil;
static NSArray *easCommandParameters = nil;

@implementation NSString (ActiveSync)

- (NSString *) sanitizedServerIdWithType: (SOGoMicrosoftActiveSyncFolderType) folderType
{
  if (folderType == ActiveSyncEventFolder)
    {
      int len;

      len = [self length];

      if (len > 4 && [self hasSuffix: @".ics"])
        return [self substringToIndex: len-4];
      else
        return [NSString stringWithFormat: @"%@.ics", self];
    }
  
  return self;
}

- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  NSString *s;

  s = [self safeString];

  return [s stringByEscapingHTMLString];
}

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
  NSString *realCollectionId, *v;

  *folderType = ActiveSyncGenericFolder;
  v = [self stringByUnescapingURL];

  if ([v hasPrefix: @"vevent/"])
    {
      realCollectionId = [v substringFromIndex: 7];
      *folderType = ActiveSyncEventFolder;
    }
  else if ([v hasPrefix: @"vtodo/"])
    {
      realCollectionId = [v substringFromIndex: 6];
      *folderType = ActiveSyncTaskFolder;
    }
  else if ([v hasPrefix: @"vcard/"])
    {
      realCollectionId = [v substringFromIndex: 6];
      *folderType = ActiveSyncContactFolder;
    }
  else if ([v hasPrefix: @"mail/"])
    {
      realCollectionId = [[v stringByUnescapingURL] substringFromIndex: 5];
      *folderType = ActiveSyncMailFolder;
    }
  else
    {
      realCollectionId = nil;
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
  NSString *s;
  id o;

  // We force parsing in the GMT timezone. If we don't do that, the date will be parsed
  // in the default timezone.
  s = [NSString stringWithFormat: @"%@ GMT", self];
  o = [NSCalendarDate dateWithString: s  calendarFormat: @"%Y%m%dT%H%M%SZ %Z"];

  if (!o)
    o = [NSCalendarDate dateWithString: s  calendarFormat: @"%Y-%m-%dT%H:%M:%S.%FZ %Z"];
 
  return o;
}

- (NSString *) _valueForParameter: (NSString *) theParameter
{
  NSMutableArray *components;
  NSString *s;
  int i;

  components = [NSMutableArray arrayWithArray: [[[self componentsSeparatedByString: @"?"] lastObject] componentsSeparatedByString: @"&"]];

  // We handle BASE64 encoded queryStrings. See http://msdn.microsoft.com/en-us/library/ee160227%28v=exchg.80%29.aspx for details.
  if ([components count] == 1)
    {
      NSString *deviceType, *parameterValue;
      NSData *queryString;
      
      int cmd_code, deviceid_length, policy_length, devicetype_length, parameter_code, parameter_length, i;
      const char* qs_bytes;
     
      queryString = [[components objectAtIndex: 0] dataByDecodingBase64];

      if (![queryString length])
        return nil;

      qs_bytes = (const char*)[queryString bytes];

      if (!easCommandCodes)
        {
          easCommandCodes = [NSArray arrayWithObjects:@"Sync", @"SendMail", @"SmartForward", @"SmartReply", @"GetAttachment", @"na", @"na", @"na", @"na",
                                     @"FolderSync", @"FolderCreate", @"FolderDelete", @"FolderUpdate", @"MoveItems", @"GetItemEstimate", @"MeetingResponse",
                                     @"Search", @"Settings", @"Ping", @"ItemOperations", @"Provision", @"ResolveRecipients", @"ValidateCert", nil];
          RETAIN(easCommandCodes);
        }

      if (!easCommandParameters)
        {
          easCommandParameters = [NSArray arrayWithObjects:@"AttachmentName", @"CollectionId", @"na", @"ItemId", @"LongId", @"na", @"Occurrence", @"Options", @"User", nil];
          RETAIN(easCommandParameters);
        }

      // Command code, 1 byte, ie.: cmd=
      cmd_code = qs_bytes[1];
      [components addObject: [NSString stringWithFormat: @"cmd=%@", [easCommandCodes objectAtIndex: cmd_code]]];

      // Device ID length and Device ID (variable)
      deviceid_length = qs_bytes[4];
      [components addObject: [NSString stringWithFormat: @"deviceId=%@", [[NSData encodeDataAsHexString: [queryString subdataWithRange: NSMakeRange(5, deviceid_length)]] uppercaseString]]];

      // Device type length and type (variable)
      policy_length = qs_bytes[5+deviceid_length];
      devicetype_length = qs_bytes[5+deviceid_length+1+policy_length];
      deviceType = [[NSString alloc] initWithData: [queryString subdataWithRange: NSMakeRange(5+deviceid_length+1+policy_length+1, devicetype_length)]
                                         encoding: NSASCIIStringEncoding];
      AUTORELEASE(deviceType);

      [components addObject: [NSString stringWithFormat: @"deviceType=%@", deviceType]];                                      

      // Command Parameters
      i = 5+deviceid_length+1+policy_length+1+devicetype_length;
      
      while (i < [queryString length])
        {
          parameter_code = qs_bytes[i];
          parameter_length = qs_bytes[i+1];
          parameterValue = [[NSString alloc] initWithData: [queryString subdataWithRange: NSMakeRange(i+1+1, parameter_length)]
                                                 encoding: NSASCIIStringEncoding];
          
          AUTORELEASE(parameterValue);
          
          // parameter_code 7 == Options
          // http://msdn.microsoft.com/en-us/library/ee237789(v=exchg.80).aspx
          if (parameter_code == 7)
            [components addObject: [NSString stringWithFormat: @"%@=%@", [easCommandParameters objectAtIndex: parameter_code],
                                             ([parameterValue isEqualToString: @"\001"]) ? @"SaveInSent" : @"AcceptMultiPart"]];
          else
            [components addObject: [NSString stringWithFormat: @"%@=%@", [easCommandParameters objectAtIndex: parameter_code], parameterValue]];
          
          i = i + 1 + 1 + parameter_length;
        }
    }
  
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
// This method extracts the "DeviceType" from a URI:
//
// /SOGo/Microsoft-Server-ActiveSync?Cmd=FolderSync&User=sogo10&DeviceId=SEC17CD1A3E9E3F2&DeviceType=SAMSUNGSGHI317M
//
- (NSString *) deviceType
{
  NSString *s;

  s = [self _valueForParameter: @"DEVICETYPE="];

  if (!s)
    s = @"Unknown";

  return s;
}

// This method extracts the "AttachmentName" from a URI:
//
// /SOGo/Microsoft-Server-ActiveSync?Cmd=GetAttachment&User=sogo&DeviceId=HTCa04b4932597acd3f2dc1a918b9728&DeviceType=htcvision&AttachmentName=mail/TestFldr/8/2
//
- (NSString *) attachmentName
{
  NSString *s;

  s = [self _valueForParameter: @"ATTACHMENTNAME="];

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

- (NSString *) itemid
{
  NSString *s;

  s = [self _valueForParameter: @"ITEMID="];

  if (!s)
    s = @"Unknown";

  return s;
}

- (NSString *) collectionid
{
  NSString *s;

  s = [self _valueForParameter: @"COLLECTIONID="];

  if (!s)
    s = @"Unknown";

  return s;
}

- (BOOL) acceptsMultiPart
{
  NSString *s;

  s = [self _valueForParameter: @"OPTIONS="];

  if (s && [s rangeOfString: @"AcceptMultiPart" options: NSCaseInsensitiveSearch].location != NSNotFound)
    return YES;

  return NO;
}


//
// FIXME: combine with our OpenChange code.
//
- (char) _decodeHexByte: (char) byteChar
{
  char newByte;

  if (byteChar >= 48 && byteChar <= 57)
    newByte = (uint8_t) byteChar - 48;
  else if (byteChar >= 65 && byteChar <= 70)
    newByte = (uint8_t) byteChar - 55;
  else if (byteChar >= 97 && byteChar <= 102)
    newByte = (uint8_t) byteChar - 87;
  else
    newByte = -1;

  return newByte;
}

//
// FIXME: combine with our OpenChange code.
//
- (BOOL) _decodeHexByte: (uint8_t *) byte
                  atPos: (NSUInteger) pos
{
  BOOL error = NO;
  char newByte;
  unichar byteChar;

  byteChar = [self characterAtIndex: pos];
  if (byteChar < 256)
    {
      newByte = [self _decodeHexByte: (char) byteChar];
      if (newByte == -1)
        error = YES;
      else
        *byte = newByte;
    }
  else
    error = YES;

  return error;
}

//
// FIXME: combine with our OpenChange code.
//
- (BOOL) _decodeHexPair: (uint8_t *) byte
                  atPos: (NSUInteger) pos
{
  BOOL error;
  uint8_t lowValue, highValue;

  error = [self _decodeHexByte: &highValue atPos: pos];
  if (!error)
    {
      error = [self _decodeHexByte: &lowValue atPos: pos + 1];
      if (!error)
        *byte = highValue << 4 | lowValue;
    }

  return error;
}

//
// FIXME: combine with our OpenChange code.
//
- (NSData *) convertHexStringToBytes
{
  NSUInteger count, strLen, bytesLen;
  uint8_t *bytes, *currentByte;
  NSData *decoded = nil;
  BOOL error = NO;

  strLen = [self length];
  if ((strLen % 2) == 0)
    {
      bytesLen = strLen / 2;
      bytes = NSZoneCalloc (NULL, bytesLen, sizeof (uint8_t));
      currentByte = bytes;
      for (count = 0; !error && count < strLen; count += 2)
        {
          error = [self _decodeHexPair: currentByte atPos: count];
          currentByte++;
        }
      if (error)
        NSZoneFree (NULL, bytes);
      else
        decoded = [NSData dataWithBytesNoCopy: bytes
                                       length: bytesLen
                                 freeWhenDone: YES];
    }

  return decoded;
}

@end
