/* SOGoEAlarmsNotifier.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2016 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSUserDefaults.h>

#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGMimeMessage.h>

#import <NGCards/iCalAlarm.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoCredentialsFile.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoUser.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoEMailAlarmsManager.h>

#import "SOGoEAlarmsNotifier.h"

@implementation SOGoEAlarmsNotifier

- (id) init
{
  if ((self = [super init]))
    {
      staticAuthenticator = nil;
    }
  return self;
}

- (void) dealloc
{
  [staticAuthenticator release];
  [super dealloc];
}

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

  messageID = [NSString stringWithFormat: @"<%0X-%0X-%0X-%0X@%lu>",
                        pid, timestamp, sequence, (unsigned int)random(), [pGUID hash]];

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

  [mailer sendMimePart: message
          toRecipients: [NSArray arrayWithObject: to]
                sender: from
     withAuthenticator: staticAuthenticator inContext: nil];
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

- (void) usage
{
  fprintf (stderr, "sogo-ealarms-notify [-p credentialFile] [-h]\n\n"
     "  -p credentialFile    Specify the file containing credentials to use for SMTP AUTH\n"
     "                       The file should contain a single line:\n"
     "                         username:password\n"
     "  -h                   This message\n"
     "\n"
     "This program should be configured to run every minute from a crontab.\n");
}

- (BOOL) run
{
  NSCalendarDate *startDate, *toDate;
  SOGoEMailAlarmsManager *eaMgr;
  NSMutableArray *metadata;
  iCalEntityObject *entity;
  SOGoCredentialsFile *cf;
  NSString *credsFilename;
  NSDictionary *d;
  NSArray *alarms;

  int count, max;

  if ([[NSUserDefaults standardUserDefaults] stringForKey: @"h"])
    {
      [self usage];
      return YES;
    }

  credsFilename = [[NSUserDefaults standardUserDefaults] stringForKey: @"p"];
  if (credsFilename)
    {
      cf = [SOGoCredentialsFile credentialsFromFile: credsFilename];
      if (!cf)
        return NO;
      staticAuthenticator =
          [SOGoStaticAuthenticator authenticatorWithUser: [cf username]
                                             andPassword: [cf password]];
      [staticAuthenticator retain];
    }

  [[SOGoProductLoader productLoader]
    loadProducts: [NSArray arrayWithObject: @"Appointments.SOGo"]];

  eaMgr = [NSClassFromString (@"SOGoEMailAlarmsManager")
                             sharedEMailAlarmsManager];

  metadata = [[NSMutableArray alloc] init];
  startDate = [NSCalendarDate calendarDate];
  toDate = [startDate addYear: 0 month: 0 day: 0
                         hour: 0 minute: 0
                       second: -[startDate secondOfMinute]];
  alarms = [eaMgr scheduledAlarmsFromDate: [toDate addYear: 0 month: 0 day: 0
                                                      hour: 0 minute: -5
                                                    second: 0]
                                   toDate: toDate
                               withMetadata: metadata];
  max = [alarms count];
  for (count = 0; count < max; count++)
    [self _processAlarm: [alarms objectAtIndex: count]
              withOwner: [[metadata objectAtIndex: count] objectForKey: @"owner"]];

  // We now update the next alarm date (if any, for recurring
  // events or tasks for example). This will also delete any emai
  // alarms that are no longer relevant
  max = [metadata count];

  for (count = 0; count < max; count++)
    {
      d = [metadata objectAtIndex: count];
      entity = [d objectForKey: @"entity"];
      [entity quickRecordFromContent: nil
			   container: [d objectForKey: @"container"]
		     nameInContainer: [[d objectForKey: @"record"] objectForKey: @"c_name"]];
    }


  return YES;
}

@end
