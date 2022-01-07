/*
  Copyright (C) 2021 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.

  The following code is a derivative work of the code from the Yerase's TNEF
  Stream Reader which is licensed GPLv2.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <SOGo/RTFHandler.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <SoObjects/Mailer/NSData+SMIME.h>

#import <ytnef.h>

#import "SOGoTNEFMailBodyPart.h"

#define UPR_TO_ATTENDEES_STRING  0x823B
#define UPR_CC_ATTENDEES_STRING  0x823C
#define UPR_ALL_ATTENDEES_STRING 0x8238

/*
  SOGoTNEFMailBodyPart

  A specialized SOGoMailBodyPart subclass for application/ms-tnef attachments. Can
  be used to attach special SoMethods.

  See the superclass for more information on part objects.
*/

unsigned char GetRruleCount(unsigned char a, unsigned char b) {
  return ((a << 8) | b);
}

char *GetRruleDayname(unsigned char a) {
  static char daystring[25];

  *daystring = 0;

  if (a & 0x01) {
    strcat(daystring, "SU,");
  }
  if (a & 0x02) {
    strcat(daystring, "MO,");
  }
  if (a & 0x04) {
    strcat(daystring, "TU,");
  }
  if (a & 0x08) {
    strcat(daystring, "WE,");
  }
  if (a & 0x10) {
    strcat(daystring, "TH,");
  }
  if (a & 0x20) {
    strcat(daystring, "FR,");
  }
  if (a & 0x40) {
    strcat(daystring, "SA,");
  }

  if (strlen(daystring)) {
    daystring[strlen(daystring) - 1] = 0;
  }

  return (daystring);
}

unsigned char GetRruleMonthNum(unsigned char a, unsigned char b) {
  switch (a) {
    case 0x00:
      switch (b) {
        case 0x00:
          // Jan
          return (1);
        case 0xA3:
          // May
          return (5);
        case 0xAE:
          // Nov
          return (11);
      }
      break;
    case 0x60:
      switch (b) {
        case 0xAE:
          // Feb
          return (2);
        case 0x51:
          // Jun
          return (6);
      }
      break;
    case 0xE0:
      switch (b) {
        case 0x4B:
          // Mar
          return (3);
        case 0x56:
          // Sep
          return (9);
      }
      break;
    case 0x40:
      switch (b) {
        case 0xFA:
          // Apr
          return (4);
      }
      break;
    case 0x20:
      if (b == 0xFA) {
        // Jul
        return (7);
      }
      break;
    case 0x80:
      if (b == 0xA8) {
        // Aug
        return (8);
      }
      break;
    case 0xA0:
      if (b == 0xFF) {
        // Oct
        return (10);
      }
      break;
    case 0xC0:
      if (b == 0x56) {
        return (12);
      }
  }

  // Error
  return (0);
}

@implementation SOGoTNEFMailBodyPart

/* Overwritten methods */

- (id) init
{
  if ((self = [super init]))
    {
      debugOn = [[SOGoSystemDefaults sharedSystemDefaults] tnefDecoderDebugEnabled];
      part = nil;
      filename = nil;
      bodyParts = [[NGMimeMultipartBody alloc] init];
    }

  return self;
}

- (id) initWithName: (NSString *) _name
        inContainer: (id) _container
{
  self = [super initWithName: _name inContainer: _container];

  [self decodeBLOB];

  return self;
}

- (void) dealloc
{
  [part release];
  [filename release];
  [bodyParts release];

  [super dealloc];
}

- (id) lookupName: (NSString *) _key
	inContext: (id) _ctx
	  acquire: (BOOL) _flag
{
  NSArray *parts;
  int i;

  if ([self isBodyPartKey: _key])
    {
      // _key is an integer
      parts = [bodyParts parts];
      i = [_key intValue] - 1;

      if (i > -1 && i < [parts count])
        {
          [self setPart: [parts objectAtIndex: i]];
          return self;
        }
    }
  else if ([_key isEqualToString: [self filename]])
    {
      return self;
    }
  else if ([_key isEqualToString: @"asAttachment"])
    {
      [self setAsAttachment];
      return self;
    }

  /* Fallback to super class */
  return [super lookupName: _key inContext: _ctx acquire: _flag];
}

- (NSData *) fetchBLOB
{
  if (part)
    return [part body];

  return [super fetchBLOB];
}

- (NSString *) filename
{
  if (filename)
    return filename;
  else if (part)
    return nil; // don't try to fetch the filename from the IMAP body structure
  else
    return [super filename];
}

- (id) partInfo
{
  if (partInfo)
    return partInfo;
  else if (part)
    return nil; // don't try to fetch the info from the IMAP body structure
  else
    return [super partInfo];
}

/* New methods */

- (NGMimeMultipartBody *) bodyParts
{
  return bodyParts;
}

- (void) decodeBLOB
{
  NSData *data;
  NSEnumerator *list;
  NSString *messageClass;
  NSString *partName, *type, *subtype;
  NSString *value, *attendee;
  RTFHandler *handler;

  DWORD signature;
  DDWORD *classification;
  dtr datetime;
  TNEFStruct tnef;
  variableLength *attachmentName;
  variableLength *filedata;
  variableLength buf;

  [self setPart: nil];
  partName = nil;
  data = [self fetchBLOB];

  memcpy(&signature, [data bytes], sizeof(DWORD));
  if (TNEFCheckForSignature(signature) == 0)
    {
      TNEFInitialize(&tnef);
      tnef.Debug = 0;
      if (TNEFParseMemory((unsigned char *)[data bytes], [data length], &tnef) != -1)
        {
          messageClass = [NSString stringWithCString: tnef.messageClass];

          if (debugOn)
            {
              NSLog(@"TNEF message class: %@", messageClass);
              MAPIPrint(&tnef.MapiProperties);
            }

          if ([messageClass isEqualToString: @"IPM.Microsoft Mail.Note"])
            {
              if (tnef.subject.size > 0)
                {
                  data = nil;
                  filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, PR_BODY_HTML));
                  if (filedata != MAPI_UNDEFINED)
                    {
                      partName = [NSString stringWithFormat: @"%s.html", tnef.subject.data];
                      data = [NSData dataWithBytes: filedata->data length: filedata->size];
                    }
                  else
                    {
                      filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, PR_RTF_COMPRESSED));
                      if (filedata != MAPI_UNDEFINED)
                        {
                          buf.data = DecompressRTF(filedata, &(buf.size));
                          if (buf.data != NULL)
                            {
                              partName = [NSString stringWithFormat: @"%s.html", tnef.subject.data];
                              data = [NSData dataWithBytes: buf.data length: buf.size];

                              handler = [[RTFHandler alloc] initWithData: data];
                              AUTORELEASE(handler);
                              data = [handler parse]; // RTF to HTML
                            }
                        }
                    }

                  if ([data length])
                    {
                      [self bodyPartForData: data
                                   withType: @"text"
                                 andSubtype: @"html"];
                    }
                }
            }
          else if ([messageClass isEqualToString: @"IPM.Microsoft Schedule.MtgRespA"] || // tentative response
                   [messageClass isEqualToString: @"IPM.Microsoft Schedule.MtgRespP"] || // positive (accepted) response
                   [messageClass isEqualToString: @"IPM.Microsoft Schedule.MtgRespN"] || // negative (declined) response
                   [messageClass isEqualToString: @"IPM.Microsoft Schedule.MtgReq"])     // request (invitation)
            {
              // Meeting object -- construct text/calendar part

              // Parse HTML body, if any
              filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, PR_BODY_HTML));
              if (filedata != MAPI_UNDEFINED && filedata->size > 0)
                {
                  partName = [NSString stringWithFormat: @"%s.html", tnef.subject.data];
                  data = [NSData dataWithBytes: filedata->data length: filedata->size];
                  [self bodyPartForData: data
                               withType: @"text"
                             andSubtype: @"html"];
                }

              // Create ics attachment
              NSMutableString *vcalendar = [NSMutableString stringWithString: @"BEGIN:VCALENDAR\n"];
              BOOL isRequest = [messageClass isEqualToString: @"IPM.Microsoft Schedule.MtgReq"];

              if (isRequest)
                [vcalendar appendString: @"METHOD:REQUEST\n"];
              else
                [vcalendar appendString: @"METHOD:REPLY\n"];
              [vcalendar appendFormat: @"PRODID:-//Inverse inc./SOGo %@//EN\n", SOGoVersion];
              [vcalendar appendString: @"VERSION:2.0\n"];
              [vcalendar appendString: @"BEGIN:VEVENT\n"];

              // UID
              // TODO: Probably wrong, probably irrelevant
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, 0x3));
              if (filedata == MAPI_UNDEFINED)
                filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, 0x23));
              if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                {
                  int i;
                  [vcalendar appendString: @"UID:"];
                  for (i = 0; i < filedata->size; i++)
                    {
                      [vcalendar appendFormat: @"%02X", (unsigned char)filedata->data[i]];
                    }
                  [vcalendar appendString: @"\n"];
                }

              // Sequence
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_LONG, 0x8201));
              if (filedata != MAPI_UNDEFINED)
                {
                  [vcalendar appendFormat: @"SEQUENCE:%i\n", (int)*filedata->data];
                }

              // Attendee email
              if (isRequest)
                {
                  // Organizer
                  filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, PR_SENDER_SEARCH_KEY));
                  if (filedata == MAPI_UNDEFINED)
                    {
                      filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, PR_SENT_REPRESENTING_EMAIL_ADDRESS));
                    }
                  if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                    {
                      NSArray *components;
                      NSString *email, *cn;
                      email = [NSString stringWithUTF8String: (const char *)filedata->data];
                      components = [email componentsSeparatedByString: @":"];
                      email = [components objectAtIndex: 0];

                      if ([components count] > 1)
                        cn = [components objectAtIndex: 1];
                      else
                        {
                          filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, PR_SENT_REPRESENTING_NAME));
                          if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                            cn = [NSString stringWithUTF8String: (const char *)filedata->data];
                          else
                            cn = email;
                        }
                      [vcalendar appendFormat: @"ORGANIZER;cn=\"%@\":mailto:%@\n", cn, email];
                    }

                  // Attendees
                  filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_STRING8, UPR_TO_ATTENDEES_STRING));
                  if (filedata == MAPI_UNDEFINED)
                    {
                      filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, UPR_TO_ATTENDEES_STRING));
                    }
                  if (filedata == MAPI_UNDEFINED)
                    {
                      filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_STRING8, UPR_ALL_ATTENDEES_STRING));
                    }
                  if (filedata == MAPI_UNDEFINED)
                    {
                      filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, UPR_ALL_ATTENDEES_STRING));
                    }
                  if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                    {
                      // Required attendees
                      value = [NSString stringWithUTF8String: (const char *)filedata->data];
                      list = [[value componentsSeparatedByString: @";"] objectEnumerator];
                      while ((attendee = [list nextObject]))
                        {
                          attendee = [attendee stringByTrimmingSpaces];
                          [vcalendar appendFormat: @"ATTENDEE;PARTSTAT=NEEDS-ACTION;ROLE=REQ-PARTICIPANT;RSVP=TRUE;CN=\"%@\":MAILTO:%@\n",
                                     attendee, attendee];
                        }

                      // Optional attendees
                      filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_STRING8, UPR_CC_ATTENDEES_STRING));
                      if (filedata == MAPI_UNDEFINED)
                        {
                          filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, UPR_CC_ATTENDEES_STRING));
                        }
                      if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                        {
                          value = [NSString stringWithUTF8String: (const char *)filedata->data];
                          if ([value length])
                            {
                              list = [[value componentsSeparatedByString: @";"] objectEnumerator];
                              while ((attendee = [list nextObject]))
                                {
                                  attendee = [attendee stringByTrimmingSpaces];
                                  [vcalendar appendFormat: @"ATTENDEE;PARTSTAT=NEEDS-ACTION;ROLE=OPT-PARTICIPANT;RSVP=TRUE;CN=\"%@\":MAILTO:%@\n",
                                             attendee, attendee];
                                }
                            }
                        }
                    }
                }
              else
                {
                  // Meeting response
                  filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, PR_SENT_REPRESENTING_EMAIL_ADDRESS));
                  if (filedata == MAPI_UNDEFINED)
                    {
                      filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, PR_SENDER_SMTP_ADDRESS));
                    }
                  if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                    {
                      NSString *email, *cn, *partstat;
                      email = [NSString stringWithUTF8String: (const char *)filedata->data];
                      filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, PR_SENT_REPRESENTING_NAME));
                      if (filedata == MAPI_UNDEFINED)
                        {
                          filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, PR_SENDER_NAME));
                        }
                      if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                        cn = [NSString stringWithUTF8String: (const char *)filedata->data];
                      else
                        cn = email;

                      switch ([messageClass characterAtIndex: [messageClass length] - 1])
                        {
                        case 'N':
                          partstat = @"DECLINED";
                          break;
                        case 'A':
                          partstat = @"TENTATIVE";
                          break;
                        default:
                          partstat = @"ACCEPTED";
                        }
                      [vcalendar appendFormat: @"ATTENDEE;PARTSTAT=%@;CN=\"%@\":MAILTO:%@\n", partstat, cn, email];
                    }
                }

              // Summary
              filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_STRING8, PR_CONVERSATION_TOPIC));
              if (filedata == MAPI_UNDEFINED)
                {
                  filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, PR_CONVERSATION_TOPIC));
                }
              if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                {
                  [vcalendar appendFormat: @"SUMMARY:%@\n", [NSString stringWithUTF8String: (const char *)filedata->data]];
                }

              // Description
              filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_STRING8, 0x3fd9));
              if (filedata == MAPI_UNDEFINED)
                {
                  filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, 0x3fd9));
                }
              if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                {
                  [vcalendar appendFormat: @"DESCRIPTION:%@\n", [NSString stringWithUTF8String: (const char *)filedata->data]];
                }

              // Location
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_STRING8, 0x0002));
              if (filedata == MAPI_UNDEFINED)
                filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_STRING8, 0x8208));
              if (filedata == MAPI_UNDEFINED)
                filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, 0x0002));
              if (filedata == MAPI_UNDEFINED)
                filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_UNICODE, 0x8208));
              if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                {
                  [vcalendar appendFormat: @"LOCATION: %@\n", [NSString stringWithUTF8String: (const char *)filedata->data]];
                }

              // Date start
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_SYSTIME, 0x820d));
              if (filedata == MAPI_UNDEFINED)
                filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_SYSTIME, 0x8516));
              if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                {
                  MAPISysTimetoDTR(filedata->data, &datetime);
                  [vcalendar appendFormat: @"DTSTART:%04i%02i%02iT%02i%02i%02iZ\n",
                        datetime.wYear, datetime.wMonth, datetime.wDay, datetime.wHour, datetime.wMinute, datetime.wSecond];
                }

              // Date end
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_SYSTIME, 0x820e));
              if (filedata == MAPI_UNDEFINED)
                filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_SYSTIME, 0x8517));
              if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                {
                  MAPISysTimetoDTR(filedata->data, &datetime);
                  [vcalendar appendFormat: @"DTEND:%04i%02i%02iT%02i%02i%02iZ\n",
                        datetime.wYear, datetime.wMonth, datetime.wDay, datetime.wHour, datetime.wMinute, datetime.wSecond];
                }

              // Date stamp
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_SYSTIME, 0x8202));
              if (filedata == MAPI_UNDEFINED)
                filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_SYSTIME, 0x001a));
              if (filedata != MAPI_UNDEFINED && filedata->size > 1)
                {
                  MAPISysTimetoDTR(filedata->data, &datetime);
                  [vcalendar appendFormat: @"DTSTAMP:%04i%02i%02iT%02i%02i%02iZ\n",
                        datetime.wYear, datetime.wMonth, datetime.wDay, datetime.wHour, datetime.wMinute, datetime.wSecond];
                }

              // Classification
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_BOOLEAN, 0x8506));
              if (filedata != MAPI_UNDEFINED)
                {
                  classification = (DDWORD *)filedata->data;
                  if (*classification == 1)
                    [vcalendar appendString: @"CLASS:PRIVATE\n"];
                  else
                    [vcalendar appendString: @"CLASS:PUBLIC\n"];
                }

              // Repeating rule
              filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, 0x8216));
              if (filedata != MAPI_UNDEFINED && filedata->size >= 0x1F)
                {
                  NSMutableString *rrule = [NSMutableString string];
                  unsigned char *recurData = filedata->data;

                  // [vcalendar appendString: @"RRULE:FREQ="];
                  if (recurData[0x04] == 0x0A)
                    {
                      [rrule appendString: @"DAILY"];
                      if (recurData[0x16] == 0x23 || recurData[0x16] == 0x22 || recurData[0x16] == 0x21)
                        {
                          filedata = MAPIFindUserProp(&(tnef.MapiProperties), PROP_TAG(PT_I2, 0x0011));
                          if (filedata != MAPI_UNDEFINED)
                            [rrule appendFormat: @";INTERVAL=%d", *(filedata->data)];
                          if (recurData[0x16] == 0x22 || recurData[0x16] == 0x21)
                            [rrule appendFormat: @";COUNT=%d", GetRruleCount(recurData[0x1B], recurData[0x1A])];
                        }
                      else if (recurData[0x16] == 0x3E)
                        {
                          [rrule appendString: @";BYDAY=MO,TU,WE,TH,FR"];
                          if (recurData[0x1A] == 0x22 || recurData[0x1A] == 0x21)
                            [rrule appendFormat: @";COUNT=%d", GetRruleCount(recurData[0x1F], recurData[0x1E])];

                        }
                    }
                  else if (recurData[0x04] == 0x0B)
                    {
                      [rrule appendFormat: @"WEEKLY;INTERVAL=%d;BYDAY=%s", recurData[0x0E], GetRruleDayname(recurData[0x16])];
                      if (recurData[0x1A] == 0x22 || recurData[0x1A] == 0x21)
                        [rrule appendFormat: @";COUNT=%d", GetRruleCount(recurData[0x1F], recurData[0x1E])];
                    }
                  else if (recurData[0x04] == 0x0C)
                    {
                      [rrule appendString: @"MONTHLY"];
                      if (recurData[0x06] == 0x02)
                        {
                          [rrule appendFormat: @";INTERVAL=%d;BYMONTHDAY=%d", recurData[0x0E], recurData[0x16]];
                          if (recurData[0x1A] == 0x22 || recurData[0x1A] == 0x21)
                            [rrule appendFormat: @";COUNT=%d", GetRruleCount(recurData[0x1F], recurData[0x1E])];
                        }
                      else if (recurData[0x06] == 0x03)
                        {
                          [rrule appendFormat: @";BYDAY=%s;BYSETPOS=%d;INTERVAL=%d",
                                     GetRruleDayname(recurData[0x16]),
                                     recurData[0x1A] == 0x05 ? -1 : recurData[0x1A],
                                     recurData[0x0E]];
                          if (recurData[0x1E] == 0x22 || recurData[0x1E] == 0x21)
                            [rrule appendFormat: @";COUNT=%d", GetRruleCount(recurData[0x23], recurData[0x22])];
                        }
                    }
                  else if (recurData[0x04] == 0x0D)
                    {
                      [rrule appendFormat: @"YEARLY;BYMONTH=%d", GetRruleMonthNum(recurData[0x0A], recurData[0x0B])];
                      if (recurData[0x06] == 0x02)
                          [rrule appendFormat: @";BYMONTHDAY=%d", recurData[0x16]];
                      else if (recurData[0x06] == 0x03)
                        [rrule appendFormat: @";BYDAY=%s;BYSETPOS=%d",
                               GetRruleDayname(recurData[0x16]),
                               recurData[0x1A] == 0x05 ? -1 : recurData[0x1A]];
                      if (recurData[0x1E] == 0x22 || recurData[0x1E] == 0x21)
                        [rrule appendFormat: @";COUNT=%d", GetRruleCount(recurData[0x23], recurData[0x22])];
                    }

                  if ([rrule length])
                    [vcalendar appendFormat: @"RRULE:FREQ=%@\n", rrule];
                }

              [vcalendar appendString: @"END:VEVENT\n"];
              [vcalendar appendString: @"END:VCALENDAR"];

              if (debugOn)
                NSLog(@"TNEF reconstructed vCalendar:\n%@", vcalendar);

              [self bodyPartForData: [vcalendar dataUsingEncoding: NSUTF8StringEncoding]
                           withType: @"text"
                         andSubtype: @"calendar"];

            }
          // Other classes to handle:
          //
          //   IPM.Contact
          //   IPM.Task
          //   IPM.Microsoft Schedule.MtgCncl
          //   IPM.Appointment
          //

          Attachment *p;
          BOOL isObject, isRealAttachment;

          p = tnef.starting_attach.next;
          while (p != NULL)
            {
              if (p->FileData.size > 0)
                {
                  isObject = YES;

                  // See if the contents are stored as "attached data" inside the MAPI blocks.
                  filedata = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_OBJECT, PR_ATTACH_DATA_OBJ));
                  if (filedata == MAPI_UNDEFINED)
                    {
                      // Nope, standard TNEF stuff.
                      filedata = &(p->FileData);
                      isObject = NO;
                    }

                  // See if this is an embedded TNEF stream.
                  isRealAttachment = YES;

                  TNEFStruct emb_tnef;
                  DWORD object_signature;

                  if (isObject)
                    {
                      // This is an "embedded object", so skip the 16-byte identifier first.
                      memcpy(&object_signature, filedata->data + 16, sizeof(DWORD));
                      if (TNEFCheckForSignature(object_signature) == 0) {
                        TNEFInitialize(&emb_tnef);
                        emb_tnef.Debug = tnef.Debug;
                        if (TNEFParseMemory(filedata->data + 16, filedata->size - 16, &emb_tnef) != -1)
                          {
                            isRealAttachment = NO;
                          }
                        TNEFFree(&emb_tnef);
                      }
                    }
                  else
                    {
                      memcpy(&object_signature, filedata->data, sizeof(DWORD));
                      if (TNEFCheckForSignature(object_signature) == 0) {
                        TNEFInitialize(&emb_tnef);
                        emb_tnef.Debug = tnef.Debug;
                        if (TNEFParseMemory(filedata->data, filedata->size, &emb_tnef) != -1)
                          {
                            isRealAttachment = NO;
                          }
                        TNEFFree(&emb_tnef);
                      }
                    }
                  if (isRealAttachment)
                    {
                      // Ok, it's not an embedded stream, so now we process it.
                      attachmentName = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_ATTACH_LONG_FILENAME));
                      if (attachmentName == MAPI_UNDEFINED)
                        {
                          attachmentName = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_DISPLAY_NAME));
                          if (attachmentName == MAPI_UNDEFINED)
                            {
                              attachmentName = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_ATTACH_TRANSPORT_NAME));
                              if (attachmentName == MAPI_UNDEFINED)
                                {
                                  attachmentName = &(p->Title);
                                }
                            }
                        }

                      // MAPIPrint(&p->MAPI);

                      variableLength *prop;

                      if (attachmentName->size > 1)
                        {
                          partName = [NSString stringWithUTF8String: (const char *)attachmentName->data];

                          type = @"application";
                          subtype = @"octet-stream";

                          prop = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_UNICODE, PR_ATTACH_MIME_TAG));
                          if (prop != MAPI_UNDEFINED)
                            {
                              NSString *mime = [NSString stringWithUTF8String: (const char *)prop->data];
                              NSArray *pair = [mime componentsSeparatedByString: @"/"];
                              if ([pair count] == 2)
                                {
                                  type = [pair objectAtIndex: 0];
                                  subtype = [pair objectAtIndex: 1];
                                }
                              else
                                {
                                  [self warnWithFormat: @"Unexpected MIME type %@", mime];
                                }
                            }
                          else
                            {
                              prop = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_ATTACH_EXTENSION));
                              if (prop != MAPI_UNDEFINED)
                                {
                                  NSString *ext = [NSString stringWithUTF8String: (const char *)prop->data];
                                  if ([ext caseInsensitiveCompare: @".txt"] == NSOrderedSame)
                                    {
                                      type = @"text";
                                      subtype = @"plain";
                                    }
                                  else
                                    {
                                      [self warnWithFormat: @"Unidentified extension %@", ext];
                                    }
                                }
                            }

                          NSString *cid = partName;
                          prop = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_UNICODE, 0x3712)); // PR_CONTENT_IDENTIFIER?
                          if (prop != MAPI_UNDEFINED)
                            {
                              cid = [NSString stringWithUTF8String: (const char *)prop->data];
                            }

                          NSData *attachment;
                          if (isObject)
                            attachment = [NSData dataWithBytes: filedata->data + 16 length: filedata->size - 16];
                          else
                            attachment = [NSData dataWithBytes: filedata->data length: filedata->size];

                          [self bodyPartForAttachment: attachment
                                             withName: partName
                                              andType: type
                                           andSubtype: subtype
                                         andContentId: cid];

                          // count++;
                        }
                    } // if isRealAttachment
                } // if size>0
              p = p->next;
            }
        }
      TNEFFree(&tnef);
    }
}

- (void) setPart: (NGMimeBodyPart *) newPart
{
  ASSIGN (part, newPart);
  if (newPart)
    {
      [self setFilename: [[newPart bodyInfo] filename]];
      [self setPartInfo: [newPart bodyInfo]];
    }
  else
    {
      [self setFilename: nil];
      [self setPartInfo: nil];
    }
}

- (void) setFilename: (NSString *) newFilename
{
  ASSIGN (filename, newFilename);
}

- (void) setPartInfo: (id) newPartInfo
{
  ASSIGN (partInfo, newPartInfo);
}

- (NSString *) contentDispositionForAttachmentWithName: (NSString *) _name
                                               andSize: (NSNumber *) _size
                                        andContentType: (NSString *) _type
{
  NSString *cdtype, *cd;

  if (([_type caseInsensitiveCompare: @"image"]    == NSOrderedSame) ||
      ([_type caseInsensitiveCompare: @"message"]  == NSOrderedSame))
    cdtype = @"inline";
  else
    cdtype = @"attachment";

  cd = [NSString stringWithFormat: @"%@; filename=\"%@\"; size=%i;",
                 cdtype, [_name stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""], [_size intValue]];

  return cd;
}

- (NGMimeBodyPart *) bodyPartForData: (NSData *)   _data
                            withType: (NSString *) _type
                          andSubtype: (NSString *) _subtype
{
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  NSData           *content;
  id                body;

  if (_data == nil) return nil;

  /* check attachment */

  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity: 4] autorelease];

  // Content-Type
  [map setObject: [NSString stringWithFormat: @"%@/%@", _type, _subtype]
          forKey: @"content-type"];

  /* prepare body content */

  content = [NSData dataWithBytes: [_data bytes] length: [_data length]];
  [map setObject: [NSNumber numberWithInt: [content length]]
          forKey: @"content-length"];

  /* Note: the -init method will create a temporary file! */
  body = [[[NGMimeFileData alloc] initWithBytes: [content bytes]
                                         length: [content length]] autorelease];

  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader: map] autorelease];
  [bodyPart setBody: body];
  [bodyParts addBodyPart: bodyPart];

  return bodyPart;
}

- (NGMimeBodyPart *) bodyPartForAttachment: (NSData *)   _data
                                  withName: (NSString *) _name
                                   andType: (NSString *) _type
                                andSubtype: (NSString *) _subtype
                              andContentId: (NSString *) _cid
{
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  NSData           *content;
  NSString         *s;
  id body;

  if (_name == nil) return nil;

  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity: 4] autorelease];

  // Content-Type
  [map setObject: [NSString stringWithFormat: @"%@/%@", _type, _subtype]
          forKey: @"content-type"];

  // Content-Id
  [map setObject: _cid
          forKey: @"content-id"];

  // Content-Disposition
  s = [self contentDispositionForAttachmentWithName: _name
                                            andSize: [NSNumber numberWithLong: [_data length]]
                                     andContentType: _type];
  NGMimeContentDispositionHeaderField *o;
  o = [[NGMimeContentDispositionHeaderField alloc] initWithString: s];
  [map setObject: o forKey: @"content-disposition"];
  [o release];

  /* prepare body content */

  content = [NSData dataWithBytes: [_data bytes] length: [_data length]];
  [map setObject: [NSNumber numberWithInt: [content length]]
          forKey: @"content-length"];

  /* Note: the -init method will create a temporary file! */
  body = [[NGMimeFileData alloc] initWithBytes: [content bytes]
                                        length: [content length]];

  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader: map] autorelease];
  [bodyPart setBody: body];

  [body release];
  [bodyParts addBodyPart: bodyPart];

  return bodyPart;
}

@end /* SOGoTNEFMailBodyPart */
