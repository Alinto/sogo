/* SOGoEAlarmsNotifier.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <unistd.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMime/NGMimeBodyPart.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoUser.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoEMailAlarmsManager.h>

#import "SOGoEAlarmsNotifier.h"

@implementation SOGoEAlarmsNotifier

- (NSString *) _messageID
{
  static int pid = 0;
  static int sequence = 0;
  NSString *messageID, *pGUID;
  int timestamp;

  if (pid == 0)
    pid = getpid();
  sequence++;
  timestamp = (int) [[NSDate date] timeIntervalSince1970];
  pGUID = [[NSProcessInfo processInfo] globallyUniqueString];

  messageID = [NSString stringWithFormat: @"<%0X-%0X-%0X-%0X@%u>",
                        pid, timestamp, sequence, random(), [pGUID hash]];

  return [messageID lowercaseString];
}

- (NGMutableHashMap *) _headersForAlarm: (iCalAlarm *) alarm
                              withOwner: (SOGoUser *) owner
{
  NGMutableHashMap *headers;
  NSString *dateString, *subject, *fullName, *email;
  NSDictionary *identity;

  headers = [NGMutableHashMap hashMap];

  subject = [[alarm summary] asQPSubjectString: @"utf-8"];
  [headers addObject: subject forKey: @"Subject"];
  dateString = [[NSCalendarDate date] rfc822DateString];
  [headers addObject: dateString forKey: @"Date"];
  [headers addObject: @"1.0" forKey: @"MIME-Version"];
  [headers addObject: @"SOGo Alarms Notifier/1.0" forKey: @"User-Agent"];
  [headers addObject: @"high" forKey: @"Importance"];
  [headers addObject: @"1" forKey: @"X-Priority"];
  [headers setObject: @"text/plain; charset=\"utf-8\"" forKey: @"Content-Type"];
  [headers setObject: @"quoted-printable" forKey: @"Content-Transfer-Encoding"];

  identity = [owner primaryIdentity];
  fullName = [[identity objectForKey: @"fullName"] asQPSubjectString: @"utf-8"];
  if ([fullName length])
    email = [NSString stringWithFormat: @"%@ <%@>", fullName,
                [identity objectForKey: @"email"]];
  else
    email = [identity objectForKey: @"email"];
  [headers addObject: email forKey: @"From"];

  return headers;
}

- (void) _sendMessageWithHeaders: (NGMutableHashMap *) headers
                         content: (NSData *) content
                      toAttendee: (iCalPerson *) attendee
                            from: (NSString *) from
                      withMailer: (SOGoMailer *) mailer
{
  NGMimeMessage *message;
  NSString *to, *headerTo, *attendeeName;

  attendeeName = [[attendee cnWithoutQuotes] asQPSubjectString: @"utf-8"];
  if ([attendeeName length])
    headerTo = [NSString stringWithFormat: @"%@ <%@>", attendeeName,
                         [attendee rfc822Email]];
  else
    headerTo = [attendee rfc822Email];
  [headers setObject: headerTo forKey: @"To"];
  [headers setObject: [self _messageID] forKey: @"Message-Id"];
  message = [NGMimeMessage messageWithHeader: headers];
  [message setBody: content];
  to = [attendee rfc822Email];

  /* TODO: SMTP authentication for services */
  [mailer sendMimePart: message
          toRecipients: [NSArray arrayWithObject: to]
                sender: from
     withAuthenticator: nil inContext: nil];
}

- (void) _processAlarm: (iCalAlarm *) alarm
             withOwner: (NSString *) ownerId
{
  NGMutableHashMap *headers;
  NSArray *attendees;
  NSData *content, *qpContent;
  int count, max;
  SOGoMailer *mailer;
  NSString *from;
  SOGoUser *owner;

  owner = [SOGoUser userWithLogin: ownerId];
  mailer = [SOGoMailer mailerWithDomainDefaults: [owner domainDefaults]];

  headers = [self _headersForAlarm: alarm withOwner: owner];
  content = [[alarm comment] dataUsingEncoding: NSUTF8StringEncoding];
  qpContent = [content dataByEncodingQuotedPrintable];
  from = [[owner primaryIdentity] objectForKey: @"email"];

  attendees = [alarm attendees];
  max = [attendees count];
  for (count = 0; count < max; count++)
    [self _sendMessageWithHeaders: headers
                          content: qpContent
                       toAttendee: [attendees objectAtIndex: count]
                             from: from
                       withMailer: mailer];
}

- (BOOL) run
{
  SOGoEMailAlarmsManager *eaMgr;
  NSCalendarDate *startDate, *toDate;
  NSArray *alarms;
  NSMutableArray *owners;
  int count, max;

  [[SOGoProductLoader productLoader]
    loadProducts: [NSArray arrayWithObject: @"Appointments.SOGo"]];

  eaMgr = [NSClassFromString (@"SOGoEMailAlarmsManager")
                             sharedEMailAlarmsManager];

  startDate = [NSCalendarDate calendarDate];
  toDate = [startDate addYear: 0 month: 0 day: 0
                         hour: 0 minute: 0
                       second: -[startDate secondOfMinute]];
  alarms = [eaMgr scheduledAlarmsFromDate: [toDate addYear: 0 month: 0 day: 0
                                                      hour: 0 minute: -5
                                                    second: 0]
                                   toDate: toDate
                               withOwners: &owners];
  max = [alarms count];
  for (count = 0; count < max; count++)
    [self _processAlarm: [alarms objectAtIndex: count]
              withOwner: [owners objectAtIndex: count]];

  [eaMgr deleteAlarmsUntilDate: toDate];

  return YES;
}

@end
