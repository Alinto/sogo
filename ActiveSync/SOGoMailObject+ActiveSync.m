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
#include "SOGoMailObject+ActiveSync.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTimeZone.h>


#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#include "NSDate+ActiveSync.h"

#include "../SoObjects/Mailer/NSString+Mail.h"
#include <SOGo/SOGoUser.h>


@implementation SOGoMailObject (ActiveSync)

- (NSString *) _emailAddressesFrom: (NSArray *) enveloppeAddresses
{
  NSMutableArray *addresses;
  NSString *rc;
  NGImap4EnvelopeAddress *address;
  NSString *email;
  int i, max;

  rc = nil;
  max = [enveloppeAddresses count];

  if (max > 0)
    {
      addresses = [NSMutableArray array];
      for (i = 0; i < max; i++)
        {
          address = [enveloppeAddresses objectAtIndex: i];
          email = [address email];
          
          if (email)
            [addresses addObject: email];
        }
      rc = [addresses componentsJoinedByString: @", "];
    }

  return rc;
}

//
//
//
- (NSData *) _preferredBodyDataInMultipartUsingType: (int) theType
{
  NSString *key, *plainKey, *htmlKey, *type, *subtype;
  NSDictionary *textParts, *part;
  NSEnumerator *e;
  NSData *d;

  textParts = [self fetchPlainTextParts];
  e = [textParts keyEnumerator];
  plainKey = nil;
  htmlKey = nil;
  d = nil;

  while ((key = [e nextObject]))
    {
      part = [self lookupInfoForBodyPart: key];
      type = [part valueForKey: @"type"];
      subtype = [part valueForKey: @"subtype"];
      
      if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"html"])
        htmlKey = key;
      else if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"plain"])
        plainKey = key;
    }

  if (theType == 2)
    {
      d = [[self fetchPlainTextParts] objectForKey: htmlKey];
    }
  else if (theType == 1)
    {
      d = [[self fetchPlainTextParts] objectForKey: plainKey];
    }

  return d;
}

//
//
//
- (NSData *) _preferredBodyDataUsingType: (int) theType
                              nativeType: (int *) theNativeType
{
  NSString *type, *subtype, *encoding;
  NSData *d;
  
  type = [[[self bodyStructure] valueForKey: @"type"] lowercaseString];
  subtype = [[[self bodyStructure] valueForKey: @"subtype"] lowercaseString];

  d = nil;
  
  // We determine the native type
  if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"plain"])
    *theNativeType = 1;
  else if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"html"])
    *theNativeType = 2;
  else if ([type isEqualToString: @"multipart"])
    *theNativeType = 4;

  // We get the right part based on the preference
  if (theType == 1 || theType == 2)
    {
      if ([type isEqualToString: @"text"])
        {
          d = [[self fetchPlainTextParts] objectForKey: @""];
          
          // We check if we have base64 encoded parts. If so, we just
          // un-encode them before using them
          encoding = [[self lookupInfoForBodyPart: @""] objectForKey: @"encoding"];

          if ([encoding caseInsensitiveCompare: @"base64"] == NSOrderedSame)
            d = [d dataByDecodingBase64];

          // Check if we must convert html->plain
          if (theType == 1 && [subtype isEqualToString: @"html"])
            {
              NSString *s;
              
              s = [[NSString alloc] initWithData: d  encoding: NSUTF8StringEncoding];
              AUTORELEASE(s);

              s = [s htmlToText];
              d = [s dataUsingEncoding: NSUTF8StringEncoding];
            }
        }
      else if ([type isEqualToString: @"multipart"])
        {
          d = [self _preferredBodyDataInMultipartUsingType: theType];
        }
    }
  else if (theType == 4)
    {
      d = [self content];
    }

  return d;
}

//
//
//
- (NSString *) activeSyncRepresentation
{
  NSMutableString *s;
  NSData *d;
  id value;

  int preferredBodyType, nativeBodyType;

  s = [NSMutableString string];

  // From
  value = [self _emailAddressesFrom: [[self envelope] from]];
  if (value)
    [s appendFormat: @"<From xmlns=\"Email:\">%@</From>", [value stringByEscapingHTMLString]];
  
  // To - "The value of this element contains one or more e-mail addresses.
  // If there are multiple e-mail addresses, they are separated by commas."
  value = [self _emailAddressesFrom: [[self envelope] to]];
  if (value)
    [s appendFormat: @"<To xmlns=\"Email:\">%@</To>", [value stringByEscapingHTMLString]];
  
  // DisplayTo
  [s appendFormat: @"<DisplayTo xmlns=\"Email:\">\"%@\"</DisplayTo>", [[context activeUser] login]];

  // Cc - same syntax as the To field
  value = [self _emailAddressesFrom: [[self envelope] cc]];
  if (value)
    [s appendFormat: @"<Cc xmlns=\"Email:\">%@</Cc>", [value stringByEscapingHTMLString]];

  // Subject
  value = [self decodedSubject];
  if (value)
    {
      [s appendFormat: @"<Subject xmlns=\"Email:\">%@</Subject>", [value stringByEscapingHTMLString]];
      [s appendFormat: @"<ThreadTopic xmlns=\"Email:\">%@</ThreadTopic>", [value stringByEscapingHTMLString]];
    }
  
  // DateReceived
  value = [self date];
  if (value)
    [s appendFormat: @"<DateReceived xmlns=\"Email:\">%@</DateReceived>", [value activeSyncRepresentationWithoutSeparators]];
    
  // Importance - FIXME
  [s appendFormat: @"<Importance xmlns=\"Email:\">%@</Importance>", @"1"];
  
  // Read
  [s appendFormat: @"<Read xmlns=\"Email:\">%d</Read>", ([self read] ? 1 : 0)];
  
  // MesssageClass
  [s appendFormat: @"<MessageClass xmlns=\"Email:\">%@</MessageClass>", @"IPM.Note"];
  //[s appendFormat: @"<MessageClass xmlns=\"Email:\">%@</MessageClass>", @"IPM.Schedule.Meeting.Request"];
  
  //
  // TEST
  //
#if 0
  id foo = [self lookupImap4BodyPartKey: @"2" inContext: self->context];
  NSData *calendarData;
  iCalCalendar *calendar;
  iCalEvent *event;

  calendarData = [foo fetchBLOB];
  calendar = [iCalCalendar parseSingleFromSource: calendarData];
  event = [[calendar events] lastObject];

  if ([event timeStampAsDate])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[event timeStampAsDate] activeSyncRepresentation]];
  else if ([event created])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[event created] activeSyncRepresentation]];
  
  [s appendString: @"<MeetingRequest xmlns=\"Email:\">"];
  
  // StartTime -- http://msdn.microsoft.com/en-us/library/ee157132(v=exchg.80).aspx
  if ([event startDate])
    [s appendFormat: @"<StartTime xmlns=\"Email:\">%@</StartTime>", [[event startDate] activeSyncRepresentation]];
  
  // EndTime -- http://msdn.microsoft.com/en-us/library/ee157945(v=exchg.80).aspx
  if ([event endDate])
    [s appendFormat: @"<EndTime xmlns=\"Email:\">%@</EndTime>", [[event endDate] activeSyncRepresentation]];

  // Timezone
  iCalTimeZone *tz;

  tz = [(iCalDateTime *)[event firstChildWithTag: @"dtstart"] timeZone];

  if (!tz)
    tz = [iCalTimeZone timeZoneForName: @"Europe/London"];

  [s appendFormat: @"<TimeZone xmlns=\"Email:\">%@</TimeZone>", [[tz activeSyncRepresentation] stringByReplacingString: @"\n" withString: @""]];;

  [s appendFormat: @"<InstanceType xmlns=\"Email:\">%d</InstanceType>", 0];
  [s appendFormat: @"<Organizer xmlns=\"Email:\">%@</Organizer>", @"sogo3@example.com"];
  [s appendFormat: @"<ResponseRequested xmlns=\"Email:\">%d</ResponseRequested>", 1];

  [s appendString: @"</MeetingRequest>"];
#endif
  //
  // TEST
  //


  // Reply-To - FIXME
  //NSArray *replyTo = [[message objectForKey: @"envelope"] replyTo];
  //if ([replyTo count])
  //  [s appendFormat: @"<Reply-To xmlns=\"Email:\">%@</Reply-To>", [addressFormatter stringForArray: replyTo]];
  
  // InternetCPID - 65001 == UTF-8, we use this all the time for now.
  [s appendFormat: @"<InternetCPID xmlns=\"Email:\">%@</InternetCPID>", @"65001"];
          
  // Body - namespace 17
  preferredBodyType = [[context objectForKey: @"BodyPreferenceType"] intValue];

  nativeBodyType = 1;
  d = [self _preferredBodyDataUsingType: preferredBodyType  nativeType: &nativeBodyType];
  
  if (d)
    {
      NSString *content;
      int len;

      content = [[NSString alloc] initWithData: d  encoding: NSUTF8StringEncoding];
      AUTORELEASE(content);
  
      content = [content stringByEscapingHTMLString];
      len = [content length];
      
      [s appendString: @"<Body xmlns=\"AirSyncBase:\">"];
      [s appendFormat: @"<Type>%d</Type>", preferredBodyType];
      [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", len];
      [s appendFormat: @"<Truncated>%d</Truncated>", 0];
      [s appendFormat: @"<Data>%@</Data>", content];
      [s appendString: @"</Body>"];
    }

  // Attachments -namespace 16
  NSArray *attachmentKeys = [self fetchFileAttachmentKeys];
  if ([attachmentKeys count])
    {
      int i;
      
      [s appendString: @"<Attachments xmlns=\"AirSyncBase:\">"];
      
      for (i = 0; i < [attachmentKeys count]; i++)
        {
          value = [attachmentKeys objectAtIndex: i];

          [s appendString: @"<Attachment>"];
          [s appendFormat: @"<DisplayName>%@</DisplayName>", [[value objectForKey: @"filename"] stringByEscapingHTMLString]];

          // FileReference must be a unique identifier across the whole store. We use the following structure:
          // mail/<foldername>/<message UID/<pathofpart>
          // mail/INBOX/2          
          [s appendFormat: @"<FileReference>mail/%@/%@/%@</FileReference>", [[[self container] relativeImap4Name] stringByEscapingURL], [self nameInContainer], [value objectForKey: @"path"]];

          [s appendFormat: @"<Method>%d</Method>", 1]; // See: http://msdn.microsoft.com/en-us/library/ee160322(v=exchg.80).aspx
          [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", [[value objectForKey: @"size"] intValue]];
          //[s appendFormat: @"<IsInline>%d</IsInline>", 1];
          [s appendString: @"</Attachment>"];
        }

      [s appendString: @"</Attachments>"];
    }
  
  // ContentClass
  [s appendFormat: @"<ContentClass xmlns=\"Email:\">%@</ContentClass>", @"urn:content-classes:message"];
  //[s appendFormat: @"<ContentClass xmlns=\"Email:\">%@</ContentClass>", @"urn:content-classes:calendarmessage"];
  
  // Flags
  [s appendString: @"<Flag xmlns=\"Email:\">"];
  [s appendFormat: @"<FlagStatus>%d</FlagStatus>", 0];
  [s appendString: @"</Flag>"];
  
  // FIXME - support these in the future
  //[s appendString: @"<ConversationId xmlns=\"Email2:\">foobar</ConversationId>"];
  //[s appendString: @"<ConversationIndex xmlns=\"Email2:\">zot=</ConversationIndex>"];
  
  // NativeBodyType -- http://msdn.microsoft.com/en-us/library/ee218276(v=exchg.80).aspx
  // This is a required child element.
  // 1 -> plain/text, 2 -> HTML and 3 -> RTF
  if (nativeBodyType == 4)
    nativeBodyType = 1;

  [s appendFormat: @"<NativeBodyType xmlns=\"AirSyncBase:\">%d</NativeBodyType>", nativeBodyType];
  
  return s;
}

//
//
//
- (void) takeActiveSyncValues: (NSDictionary *) theValues
{
  id o;

  if ((o = [theValues objectForKey: @"Flag"]))
    {
      o = [o objectForKey: @"FlagStatus"];
      
      if ([o intValue])
        [self addFlags: @"\\Flagged"];
      else
        [self removeFlags: @"\\Flagged"];
      
    }
}

@end
