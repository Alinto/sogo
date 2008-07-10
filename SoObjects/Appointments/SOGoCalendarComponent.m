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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGHashMap.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMail/NGMimeMessage.h>

#import <SoObjects/SOGo/iCalEntityObject+Utilities.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SoObjects/SOGo/SOGoMailer.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/WORequest+SOGo.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>

#import "SOGoAptMailICalReply.h"
#import "SOGoAptMailNotification.h"
#import "iCalEntityObject+SOGo.h"
#import "iCalPerson+SOGo.h"
#import "SOGoCalendarComponent.h"

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
      sendEMailNotifications
        = [ud boolForKey: @"SOGoAppointmentSendEMailNotifications"];
    }
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

- (void) _filterComponent: (iCalEntityObject *) component
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

- (NSString *) secureContentAsString
{
  iCalCalendar *tmpCalendar;
  iCalRepeatableEntityObject *tmpComponent;
//   NSArray *roles;
  SoSecurityManager *sm;
  NSString *iCalString;

//       uid = [[context activeUser] login];
//       roles = [self aclsForUser: uid];
//       if ([roles containsObject: SOGoCalendarRole_Organizer]
// 	  || [roles containsObject: SOGoCalendarRole_Participant]
// 	  || [roles containsObject: SOGoCalendarRole_ComponentViewer])
// 	calContent = content;
//       else if ([roles containsObject: SOGoCalendarRole_ComponentDAndTViewer])
// 	{
// 	  tmpCalendar = [[self calendar: NO] copy];
// 	  tmpComponent = (iCalRepeatableEntityObject *)
// 	    [tmpCalendar firstChildWithTag: [self componentTag]];
// 	  [self _filterComponent: tmpComponent];
// 	  calContent = [tmpCalendar versitString];
// 	  [tmpCalendar release];
// 	}
//       else
// 	calContent = nil;

  sm = [SoSecurityManager sharedSecurityManager];
  if (activeUserIsOwner
      || [[self ownerInContext: context] isEqualToString: [[context activeUser] login]]
      || ![sm validatePermission: SOGoCalendarPerm_ViewAllComponent
	      onObject: self inContext: context])
    iCalString = content;
  else if (![sm validatePermission: SOGoCalendarPerm_ViewDAndT
		onObject: self inContext: context])
    {
      tmpCalendar = [[self calendar: NO secure: NO] copy];
      tmpComponent = (iCalRepeatableEntityObject *)
	[tmpCalendar firstChildWithTag: [self componentTag]];
      [self _filterComponent: tmpComponent];
      iCalString = [tmpCalendar versitString];
      [tmpCalendar release];
    }
  else
    iCalString = nil;

  return iCalString;
}

- (NSString *) contentAsString
{
  NSString *secureContent;

  if ([[context request] isSoWebDAVRequest])
    secureContent = [self secureContentAsString];
  else
    secureContent = [super contentAsString];

  return secureContent;
}

- (NSString *) davCalendarData
{
  return [self contentAsString];
}

- (iCalCalendar *) calendar: (BOOL) create secure: (BOOL) secure
{
  NSString *componentTag;
  CardGroup *newComponent;
  iCalCalendar *calendar;
  NSString *iCalString;

  if (secure)
    iCalString = [self secureContentAsString];
  else
    iCalString = content;

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
	}
      else
	calendar = nil;
    }

  return calendar;
}

- (id) component: (BOOL) create secure: (BOOL) secure
{
  return [[self calendar: create secure: secure]
	   firstChildWithTag: [self componentTag]];
}

- (void) saveComponent: (iCalRepeatableEntityObject *) newObject
{
  NSString *newiCalString;

  newiCalString = [[newObject parent] versitString];

  [self saveContentString: newiCalString];
}

/* raw saving */

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
  uid = [_person uid];

  return ((uid)
          ? [NSString stringWithFormat:@"%@%@", baseURL, uid]
          : nil);
}

- (BOOL) sendEMailNotifications
{
  return sendEMailNotifications;
}

- (NSTimeZone *) timeZoneForUser: (NSString *) email
{
  NSString *uid;

  uid = [[LDAPUserManager sharedUserManager] getUIDForEmail: email];

  return [[SOGoUser userWithLogin: uid roles: nil] timeZone];
}

- (void) sendEMailUsingTemplateNamed: (NSString *) _pageName
                        forOldObject: (iCalRepeatableEntityObject *) _oldObject
                        andNewObject: (iCalRepeatableEntityObject *) _newObject
                         toAttendees: (NSArray *) _attendees
{
  NSString *pageName;
  NSString *senderEmail, *shortSenderEmail, *email, *iCalString;
  WOApplication *app;
  unsigned i, count;
  iCalPerson *attendee;
  NSString *recipient, *language;
  SOGoAptMailNotification *p;
  NSString *mailDate, *subject, *text, *header;
  NGMutableHashMap *headerMap;
  NGMimeMessage *msg;
  NGMimeBodyPart *bodyPart;
  NGMimeMultipartBody *body;
  SOGoUser *currentUser;

  if (sendEMailNotifications
      && [_newObject isStillRelevant])
    {
      count = [_attendees count];
      if (count)
	{
	  /* sender */
	  currentUser = [context activeUser];
	  shortSenderEmail = [[currentUser allEmails] objectAtIndex: 0];
	  senderEmail = [NSString stringWithFormat: @"%@ <%@>",
				  [currentUser cn], shortSenderEmail];

	  NSLog (@"sending '%@' from %@",
		 [(iCalCalendar *) [_newObject parent] method], senderEmail);

	  /* generate iCalString once */
	  iCalString = [[_newObject parent] versitString];
  
	  /* get WOApplication instance */
	  app = [WOApplication application];

	  /* generate dynamic message content */

	  for (i = 0; i < count; i++)
	    {
	      attendee = [_attendees objectAtIndex: i];
	      if (![[attendee uid] isEqualToString: owner])
		{
		  /* construct recipient */
		  recipient = [attendee mailAddress];
		  email = [attendee rfc822Email];

		  NSLog (@"recipient: %@", recipient);
		  language = [[context activeUser] language];
#warning this could be optimized in a class hierarchy common with the	\
  SOGoObject acl notification mechanism
		  /* create page name */
		  pageName = [NSString stringWithFormat: @"SOGoAptMail%@%@",
				       language, _pageName];
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
		  [headerMap setObject: senderEmail forKey: @"from"];
		  [headerMap setObject: recipient forKey: @"to"];
		  mailDate = [[NSCalendarDate date] rfc822DateString];
		  [headerMap setObject: mailDate forKey: @"date"];
		  [headerMap setObject: subject forKey: @"subject"];
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
		  [[SOGoMailer sharedMailer]
		    sendMimePart: msg
		    toRecipients: [NSArray arrayWithObject: email]
		    sender: shortSenderEmail];
		}
	    }
	}
    }
}

#warning fix this when sendEmailUsing blabla has been cleaned up
- (void) sendIMIPReplyForEvent: (iCalRepeatableEntityObject *) event
			    to: (iCalPerson *) recipient
{
  NSString *pageName, *language, *mailDate, *email;
  WOApplication *app;
  iCalPerson *attendee;
  NSString *iCalString;
  SOGoAptMailICalReply *p;
  NGMutableHashMap *headerMap;
  NGMimeMessage *msg;
  NGMimeBodyPart *bodyPart;
  NGMimeMultipartBody *body;
  NSData *bodyData;
  SOGoUser *ownerUser;

  if (sendEMailNotifications)
    {
      /* get WOApplication instance */
      app = [WOApplication application];

      ownerUser = [SOGoUser userWithLogin: owner roles: nil];
      language = [ownerUser language];
      /* create page name */
      pageName
	= [NSString stringWithFormat: @"SOGoAptMail%@ICalReply", language];
      /* construct message content */
      p = [app pageWithName: pageName inContext: context];
      [p setApt: event];

      attendee = [event findParticipant: ownerUser];
      [p setAttendee: attendee];

      /* construct message */
      headerMap = [NGMutableHashMap hashMapWithCapacity: 5];

      /* NOTE: multipart/alternative seems like the correct choice but
       * unfortunately Thunderbird doesn't offer the rich content alternative
       * at all. Mail.app shows the rich content alternative _only_
       * so we'll stick with multipart/mixed for the time being.
       */
      [headerMap setObject: @"multipart/mixed" forKey: @"content-type"];
      [headerMap setObject: [attendee mailAddress] forKey: @"from"];
      [headerMap setObject: [recipient mailAddress] forKey: @"to"];
      mailDate = [[NSCalendarDate date] rfc822DateString];
      [headerMap setObject: mailDate forKey: @"date"];
      [headerMap setObject: [p getSubject] forKey: @"subject"];
      msg = [NGMimeMessage messageWithHeader: headerMap];

      NSLog (@"sending 'REPLY' from %@ to %@",
	     [attendee mailAddress], [recipient mailAddress]);

      /* multipart body */
      body = [[NGMimeMultipartBody alloc] initWithPart: msg];

      /* text part */
      headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
      [headerMap setObject: @"text/plain; charset=utf-8"
		 forKey: @"content-type"];
      bodyPart = [NGMimeBodyPart bodyPartWithHeader: headerMap];
      bodyData = [[p getBody] dataUsingEncoding: NSUTF8StringEncoding];
      [bodyPart setBody: bodyData];

      /* attach text part to multipart body */
      [body addBodyPart: bodyPart];

      /* calendar part */
      headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
      [headerMap setObject: @"text/calendar; method=REPLY; charset=utf-8"
		 forKey: @"content-type"];
      bodyPart = [NGMimeBodyPart bodyPartWithHeader: headerMap];
      iCalString = [[event parent] versitString];
      [bodyPart setBody: [iCalString dataUsingEncoding: NSUTF8StringEncoding]];

      /* attach calendar part to multipart body */
      [body addBodyPart: bodyPart];

      /* attach multipart body to message */
      [msg setBody: body];
      [body release];

      /* send the damn thing */
      email = [recipient rfc822Email];
      [[SOGoMailer sharedMailer]
	sendMimePart: msg
	toRecipients: [NSArray arrayWithObject: email]
	sender: [attendee rfc822Email]];
    }
}

- (void) sendResponseToOrganizer
{
  iCalPerson *organizer, *attendee;
  iCalEvent *event;
  SOGoUser *ownerUser;

  event = [[self component: NO secure: NO] itipEntryWithMethod: @"reply"];
  ownerUser = [SOGoUser userWithLogin: owner roles: nil];
  if (![event userIsOrganizer: ownerUser])
    {
      organizer = [event organizer];
      attendee = [event findParticipant: ownerUser];
      [event setAttendees: [NSArray arrayWithObject: attendee]];
      [self sendIMIPReplyForEvent: event to: organizer];
    }
}

// - (BOOL) isOrganizerOrOwner: (SOGoUser *) user
// {
//   BOOL isOrganizerOrOwner;
//   iCalRepeatableEntityObject *component;
//   NSString *organizerEmail;

//   component = [self component: NO];
//   organizerEmail = [[component organizer] rfc822Email];
//   if (component && [organizerEmail length] > 0)
//     isOrganizerOrOwner = [user hasEmail: organizerEmail];
//   else
//     isOrganizerOrOwner
//       = [[container ownerInContext: context] isEqualToString: [user login]];

//   return isOrganizerOrOwner;
// }

- (iCalPerson *) findParticipantWithUID: (NSString *) uid
{
  iCalEntityObject *component;
  SOGoUser *user;

  user = [SOGoUser userWithLogin: uid roles: nil];
  component = [self component: NO secure: NO];

  return [component findParticipant: user];
}

- (iCalPerson *) iCalPersonWithUID: (NSString *) uid
{
  iCalPerson *person;
  LDAPUserManager *um;
  NSDictionary *contactInfos;

  um = [LDAPUserManager sharedUserManager];
  contactInfos = [um contactInfosForUserWithUIDorEmail: uid];

  person = [iCalPerson new];
  [person autorelease];
  [person setCn: [contactInfos objectForKey: @"cn"]];
  [person setEmail: [contactInfos objectForKey: @"c_email"]];

  return person;
}

- (NSArray *) getUIDsForICalPersons: (NSArray *) iCalPersons
{
  iCalPerson *currentPerson;
  NSEnumerator *persons;
  NSMutableArray *uids;
  NSString *uid;

  uids = [NSMutableArray array];

  persons = [iCalPersons objectEnumerator];
  currentPerson = [persons nextObject];
  while (currentPerson)
    {
      uid = [currentPerson uid];
      if (uid)
	[uids addObject: uid];
      currentPerson = [persons nextObject];
    }

  return uids;
}

- (NSString *) _roleOfOwner: (iCalRepeatableEntityObject *) component
{
  NSString *role;
  iCalPerson *organizer;
  SOGoUser *ownerUser;

  if (component)
    {
      organizer = [component organizer];
      if ([[organizer rfc822Email] length] > 0)
	{
	  ownerUser = [SOGoUser userWithLogin: owner roles: nil];
	  if ([component userIsOrganizer: ownerUser])
	    role = SOGoCalendarRole_Organizer;
	  else if ([component userIsParticipant: ownerUser])
	    role = SOGoCalendarRole_Participant;
	  else
	    role = SOGoRole_None;
	}
      else
	role = SOGoCalendarRole_Organizer;
    }
  else
    role = SOGoCalendarRole_Organizer;

  return role;
}

- (NSString *) _compiledRoleForOwner: (NSString *) ownerRole
			     andUser: (NSString *) userRole
{
  NSString *role;

  if ([userRole isEqualToString: SOGoCalendarRole_ComponentModifier]
      || ([userRole isEqualToString: SOGoCalendarRole_ComponentResponder]
	  && [ownerRole isEqualToString: SOGoCalendarRole_Participant]))
    role = ownerRole;
  else
    role = SOGoRole_None;

  return role;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSMutableArray *roles;
  NSArray *superAcls;
  iCalRepeatableEntityObject *component;
  NSString *accessRole, *ownerRole;
  SOGoUser *aclUser;

  roles = [NSMutableArray array];
  superAcls = [super aclsForUser: uid];
  if ([superAcls count] > 0)
    [roles addObjectsFromArray: superAcls];

  component = [self component: NO secure: NO];
  ownerRole = [self _roleOfOwner: component];
  if ([owner isEqualToString: uid])
    [roles addObject: ownerRole];
  else
    {
      if (component)
	{
	  aclUser = [SOGoUser userWithLogin: uid roles: nil];
	  if ([component userIsOrganizer: aclUser])
	    [roles addObject: SOGoCalendarRole_Organizer];
	  else if ([component userIsParticipant: aclUser])
	    [roles addObject: SOGoCalendarRole_Participant];
	  accessRole = [container roleForComponentsWithAccessClass:
				    [component symbolicAccessClass]
				  forUser: uid];
	  if ([accessRole length] > 0)
	    {
	      [roles addObject: accessRole];
	      [roles addObject: [self _compiledRoleForOwner: ownerRole
				      andUser: accessRole]];
	    }
	}
      else if ([roles containsObject: SOGoRole_ObjectCreator])
	[roles addObject: SOGoCalendarRole_Organizer];
    }

  return roles;
}

@end
