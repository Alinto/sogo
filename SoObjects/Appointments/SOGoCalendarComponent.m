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

#import <SoObjects/SOGo/AgenorUserManager.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>

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
      calContent = nil;
      isNew = NO;
    }

  return self;
}

- (void) dealloc
{
  if (calendar)
    [calendar release];
  if (calContent)
    [calContent release];
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

- (void) _filterPrivateComponent: (iCalEntityObject *) component
{
  [component setSummary: @""];
  [component setComment: @""];
  [component setUserComment: @""];
  [component setLocation: @""];
  [component setCategories: @""];
  [component setUrl: @""];
  [component removeAllAttendees];
  [component removeAllAlarms];
}

- (NSString *) contentAsString
{
  NSString *tmpContent, *email;
  iCalCalendar *tmpCalendar;
  iCalRepeatableEntityObject *tmpComponent;

  if (!calContent)
    {
      tmpContent = [super contentAsString];
      calContent = tmpContent;
      if ([tmpContent length] > 0)
        {
          tmpCalendar = [iCalCalendar parseSingleFromSource: tmpContent];
          tmpComponent = (iCalRepeatableEntityObject *) [tmpCalendar firstChildWithTag: [self componentTag]];
          if (![tmpComponent isPublic])
            {
              email = [[context activeUser] email];
              if (!([tmpComponent isOrganizer: email]
                    || [tmpComponent isParticipant: email]))
                {
                  //             content = tmpContent;
                  [self _filterPrivateComponent: tmpComponent];
                  calContent = [tmpCalendar versitString];
                }
            }
        }

      [calContent retain];
    }

  return calContent;
}

- (NSException *) saveContentString: (NSString *) contentString
                        baseVersion: (unsigned int) baseVersion
{
  NSException *result;

  result = [super saveContentString: contentString
                  baseVersion: baseVersion];
  if (!result && calContent)
    {
      [calContent release];
      calContent = nil;
    }

  return result;
}

- (iCalCalendar *) calendar: (BOOL) create
{
  NSString *iCalString, *componentTag;
  CardGroup *newComponent;

  if (!calendar)
    {
      iCalString = [self contentAsString];
      if ([iCalString length] > 0)
        calendar = [iCalCalendar parseSingleFromSource: iCalString];
      else
        {
          if (create)
            {
              calendar = [iCalCalendar groupWithTag: @"vcalendar"];
              [calendar setVersion: @"2.0"];
              [calendar setProdID: @"-//Inverse groupe conseil//SOGo 0.9//EN"];
              componentTag = [[self componentTag] uppercaseString];
              newComponent = [[calendar classForTag: componentTag]
                               groupWithTag: componentTag];
              [calendar addChild: newComponent];
              isNew = YES;
            }
        }
      if (calendar)
        [calendar retain];
    }

  return calendar;
}

- (iCalRepeatableEntityObject *) component: (BOOL) create
{
  return (iCalRepeatableEntityObject *)
    [[self calendar: create]
      firstChildWithTag: [self componentTag]];
}

- (BOOL) isNew
{
  return isNew;
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
  NSArray *traversalObjects;

  /* generate URL from traversal stack */
  traversalObjects = [context objectTraversalStack];
  if ([traversalObjects count] > 0)
    baseURL = [[traversalObjects objectAtIndex:0] baseURLInContext: context];
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

- (NSException *) changeParticipationStatus: (NSString *) _status
{
  iCalRepeatableEntityObject *component;
  iCalPerson *p;
  NSString *newContent;
  NSException *ex;
  NSString *myEMail;
  
  ex = nil;

  component = [self component: NO];
  if (component)
    {
      myEMail = [[context activeUser] email];
      p = [component findParticipantWithEmail: myEMail];
      if (p)
        {
	  // TODO: send iMIP reply mails?
          [p setPartStat: _status];
          newContent = [[component parent] versitString];
          if (newContent)
            {
              ex = [self saveContentString:newContent];
              if (ex)
                // TODO: why is the exception wrapped?
                /* Server Error */
                ex = [NSException exceptionWithHTTPStatus: 500
                                  reason: [ex reason]];
            }
          else
            ex
              = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                             reason: @"Could not generate iCalendar data ..."];
        }
      else
        ex = [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                          reason: @"user does not participate in this "
                          @"calendar component"];
    }
  else
    ex = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                      reason: @"unable to parse component record"];

  return ex;
}

- (BOOL) sendEMailNotifications
{
  return sendEMailNotifications;
}

- (NSTimeZone *) timeZoneForUser: (NSString *) email
{
  NSString *uid;

  uid = [[AgenorUserManager sharedUserManager] getUIDForEmail: email];

  return [[SOGoUser userWithLogin: uid andRoles: nil] timeZone];
}

- (void) sendEMailUsingTemplateNamed: (NSString *) _pageName
                        forOldObject: (iCalRepeatableEntityObject *) _oldObject
                        andNewObject: (iCalRepeatableEntityObject *) _newObject
                         toAttendees: (NSArray *) _attendees
{
  NSString *pageName;
  iCalPerson *organizer;
  NSString *cn, *email, *sender, *iCalString;
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
	  email = [attendee rfc822Email];
          if (cn)
            recipient = [NSString stringWithFormat: @"%@ <%@>",
                                  cn, email];
          else
            recipient = email;

          /* create page name */
          // TODO: select user's default language?
          pageName = [NSString stringWithFormat: @"SOGoAptMail%@%@",
                               mailTemplateDefaultLanguage,
                               _pageName];
          /* construct message content */
          p = [app pageWithName: pageName inContext: context];
          [p setNewApt: _newObject];
          [p setOldApt: _oldObject];
          [p setHomePageURL: [self homePageURLForPerson: attendee]];
          [p setViewTZ: [self timeZoneForUser: email]];
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
                    toRecipients: [NSArray arrayWithObject: email]
                    sender: [organizer rfc822Email]];
        }
    }
}

- (NSArray *) rolesOfUser: (NSString *) login
{
  AgenorUserManager *um;
  iCalRepeatableEntityObject *component;
  NSMutableArray *sogoRoles;
  NSString *email;
  SOGoUser *user;

  sogoRoles = [NSMutableArray new];
  [sogoRoles autorelease];

  um = [AgenorUserManager sharedUserManager];
  email = [um getEmailForUID: login];

  component = [self component: NO];
  if (component)
    {
      if ([component isOrganizer: email])
        [sogoRoles addObject: SOGoRole_Organizer];
      else if ([component isParticipant: email])
        [sogoRoles addObject: SOGoRole_Participant];
      else if ([[container ownerInContext: context] isEqualToString: login])
        [sogoRoles addObject: SoRole_Owner];
    }
  else
    {
      user = [SOGoUser userWithLogin: login andRoles: nil];
      [sogoRoles addObjectsFromArray: [user rolesForObject: container
                                            inContext: context]];
    }

  return sogoRoles;
}

- (BOOL) isOrganizer: (NSString *) email
             orOwner: (NSString *) login
{
  BOOL isOrganizerOrOwner;
  iCalRepeatableEntityObject *component;
  NSString *organizerEmail;

  component = [self component: NO];
  organizerEmail = [[component organizer] rfc822Email];
  if (component && [organizerEmail length] > 0)
    isOrganizerOrOwner
      = ([organizerEmail caseInsensitiveCompare: email] == NSOrderedSame);
  else
    isOrganizerOrOwner
      = [[container ownerInContext: context] isEqualToString: login];

  return isOrganizerOrOwner;
}

- (BOOL) isParticipant: (NSString *) email
{
  BOOL isParticipant;
  iCalRepeatableEntityObject *component;

  component = [self component: NO];
  if (component)
    isParticipant = [component isParticipant: email];
  else
    isParticipant = NO;

  return isParticipant;
}

@end
