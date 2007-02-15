/* SOGoCalendarComponent.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGMime/NGMime.h>
#import <NGMail/NGMail.h>
#import <NGMail/NGSendMail.h>

#import <SOGo/AgenorUserManager.h>
#import <SOGo/SOGoPermissions.h>

#import "common.h"

#import "SOGoAptMailNotification.h"
#import "SOGoCalendarComponent.h"

static NSString *mailTemplateDefaultLanguage = nil;
static BOOL sendEMailNotifications = NO;

@implementation SOGoCalendarComponent

+ (void) initialize
{
  NSUserDefaults      *ud;
  static BOOL         didInit = NO;
  
  if (!didInit)
    {
      didInit = YES;
  
      ud = [NSUserDefaults standardUserDefaults];
      mailTemplateDefaultLanguage = [[ud stringForKey:@"SOGoDefaultLanguage"]
                                      retain];
      if (!mailTemplateDefaultLanguage)
        mailTemplateDefaultLanguage = @"French";

      sendEMailNotifications
        = [ud boolForKey: @"SOGoAppointmentSendEMailNotifications"];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      calendar = nil;
    }

  return self;
}

- (void) dealloc
{
  if (calendar)
    [calendar release];
  [super dealloc];
}

- (NSString *) davContentType
{
  return @"text/calendar";
}

- (NSString *) componentTag
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (iCalCalendar *) calendar
{
  NSString *iCalString;

  if (!calendar)
    {
      iCalString = [self contentAsString];
      if (iCalString)
        {
          calendar = [iCalCalendar parseSingleFromSource: iCalString];
          [calendar retain];
        }
    }

  return calendar;
}

- (iCalRepeatableEntityObject *) component
{
  return (iCalRepeatableEntityObject *)
    [[self calendar]
      firstChildWithTag: [self componentTag]];
}

/* raw saving */

- (NSException *) primarySaveContentString: (NSString *) _iCalString
{
  return [super saveContentString: _iCalString];
}

- (NSException *) primaryDelete
{
  return [super delete];
}

- (NSException *) deleteWithBaseSequence: (int) a
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSException *) delete
{
  return [self deleteWithBaseSequence:0];
}

/* EMail Notifications */
- (NSString *) homePageURLForPerson: (iCalPerson *) _person
{
  NSString *baseURL;
  NSString *uid;
  WOContext *ctx;
  NSArray *traversalObjects;

  /* generate URL from traversal stack */
  ctx = [[WOApplication application] context];
  traversalObjects = [ctx objectTraversalStack];
  if ([traversalObjects count] > 0)
    baseURL = [[traversalObjects objectAtIndex:0] baseURLInContext:ctx];
  else
    {
      baseURL = @"http://localhost/";
      [self warnWithFormat:@"Unable to create baseURL from context!"];
    }
  uid = [[AgenorUserManager sharedUserManager]
          getUIDForEmail: [_person rfc822Email]];

  return ((uid)
          ? [NSString stringWithFormat:@"%@%@", baseURL, uid]
          : nil);
}

- (BOOL) sendEMailNotifications
{
  return sendEMailNotifications;
}

- (void) sendEMailUsingTemplateNamed: (NSString *) _pageName
                        forOldObject: (iCalRepeatableEntityObject *) _oldObject
                        andNewObject: (iCalRepeatableEntityObject *) _newObject
                         toAttendees: (NSArray *) _attendees
{
  NSString *pageName;
  iCalPerson *organizer;
  NSString *cn, *sender, *iCalString;
  NGSendMail *sendmail;
  WOApplication *app;
  unsigned i, count;
  iCalPerson *attendee;
  NSString *recipient;
  SOGoAptMailNotification *p;
  NSString *subject, *text, *header;
  NGMutableHashMap *headerMap;
  NGMimeMessage *msg;
  NGMimeBodyPart *bodyPart;
  NGMimeMultipartBody *body;

  if ([_attendees count])
    {
      /* sender */

      organizer = [_newObject organizer];
      cn = [organizer cnWithoutQuotes];
      if (cn)
        sender = [NSString stringWithFormat:@"%@ <%@>",
                           cn,
                           [organizer rfc822Email]];
      else
        sender = [organizer rfc822Email];

      /* generate iCalString once */
      iCalString = [[_newObject parent] versitString];
  
      /* get sendmail object */
      sendmail = [NGSendMail sharedSendMail];

      /* get WOApplication instance */
      app = [WOApplication application];

      /* generate dynamic message content */

      count = [_attendees count];
      for (i = 0; i < count; i++)
        {
          attendee = [_attendees objectAtIndex:i];

          /* construct recipient */
          cn = [attendee cn];
          if (cn)
            recipient = [NSString stringWithFormat: @"%@ <%@>",
                                  cn,
                                  [attendee rfc822Email]];
          else
            recipient = [attendee rfc822Email];

          /* create page name */
          // TODO: select user's default language?
          pageName = [NSString stringWithFormat: @"SOGoAptMail%@%@",
                               mailTemplateDefaultLanguage,
                               _pageName];
          /* construct message content */
          p = [app pageWithName: pageName inContext: [WOContext context]];
          [p setNewApt: _newObject];
          [p setOldApt: _oldObject];
          [p setHomePageURL: [self homePageURLForPerson: attendee]];
          [p setViewTZ: [self userTimeZone: cn]];
          subject = [p getSubject];
          text = [p getBody];

          /* construct message */
          headerMap = [NGMutableHashMap hashMapWithCapacity: 5];
          
          /* NOTE: multipart/alternative seems like the correct choice but
           * unfortunately Thunderbird doesn't offer the rich content alternative
           * at all. Mail.app shows the rich content alternative _only_
           * so we'll stick with multipart/mixed for the time being.
           */
          [headerMap setObject: @"multipart/mixed" forKey: @"content-type"];
          [headerMap setObject: sender forKey: @"From"];
          [headerMap setObject: recipient forKey: @"To"];
          [headerMap setObject: [NSCalendarDate date] forKey: @"date"];
          [headerMap setObject: subject forKey: @"Subject"];
          msg = [NGMimeMessage messageWithHeader: headerMap];

          /* multipart body */
          body = [[NGMimeMultipartBody alloc] initWithPart: msg];
    
          /* text part */
          headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
          [headerMap setObject: @"text/plain; charset=utf-8"
                     forKey: @"content-type"];
          bodyPart = [NGMimeBodyPart bodyPartWithHeader: headerMap];
          [bodyPart setBody: [text dataUsingEncoding: NSUTF8StringEncoding]];

          /* attach text part to multipart body */
          [body addBodyPart: bodyPart];
    
          /* calendar part */
          header = [NSString stringWithFormat: @"text/calendar; method=%@;"
                             @" charset=utf-8",
                             [(iCalCalendar *) [_newObject parent] method]];
          headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
          [headerMap setObject:header forKey: @"content-type"];
          bodyPart = [NGMimeBodyPart bodyPartWithHeader: headerMap];
          [bodyPart setBody: [iCalString dataUsingEncoding: NSUTF8StringEncoding]];

          /* attach calendar part to multipart body */
          [body addBodyPart: bodyPart];
    
          /* attach multipart body to message */
          [msg setBody: body];
          [body release];

          /* send the damn thing */
          [sendmail sendMimePart: msg
                    toRecipients: [NSArray arrayWithObject: [attendee rfc822Email]]
                    sender: [organizer rfc822Email]];
        }
    }
}

- (NSString *) roleOfUser: (NSString *) login
                inContext: (WOContext *) context
{
  AgenorUserManager *um;
  iCalRepeatableEntityObject *component;
  NSString *role, *email;

  um = [AgenorUserManager sharedUserManager];
  email = [um getEmailForUID: login];

  component = [self component];
  if ([component isOrganizer: email])
    role = SOGoRole_Organizer;
  else if ([component isParticipant: email])
    role = SOGoRole_Participant;
  else if ([[[self container] ownerInContext: nil] isEqualToString: login])
    role = SoRole_Owner;
  else
    role = nil;

  return role;
}

@end
