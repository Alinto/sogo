/* UIxComponentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2015 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalByDayMask.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/iCalTrigger.h>

#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>

#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentOccurence.h>
#import <Appointments/SOGoTaskObject.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/WOResourceManager+SOGo.h>

#import "../../Main/SOGo.h"

#import "UIxComponentEditor.h"
#import "UIxDatePicker.h"

static NSArray *reminderItems = nil;
static NSArray *reminderValues = nil;

@implementation UIxComponentEditor

+ (void) initialize
{
  if (!reminderItems && !reminderValues)
    {
      reminderItems = [NSArray arrayWithObjects:
			       @"5_MINUTES_BEFORE",
			       @"10_MINUTES_BEFORE",
			       @"15_MINUTES_BEFORE",
			       @"30_MINUTES_BEFORE",
			       @"45_MINUTES_BEFORE",
			       @"-",
			       @"1_HOUR_BEFORE",
			       @"2_HOURS_BEFORE",
			       @"5_HOURS_BEFORE",
			       @"15_HOURS_BEFORE",
			       @"-",
			       @"1_DAY_BEFORE",
			       @"2_DAYS_BEFORE",
			       @"1_WEEK_BEFORE",
			       @"-",
			       @"CUSTOM",
			       nil];
      reminderValues = [NSArray arrayWithObjects:
				@"-PT5M",
				@"-PT10M",
				@"-PT15M",
				@"-PT30M",
				@"-PT45M",
				@"",
				@"-PT1H",
				@"-PT2H",
				@"-PT5H",
				@"-PT15H",
				@"",
				@"-P1D",
				@"-P2D",
				@"-P1W",
				@"",
				@"",
				nil];

      [reminderItems retain];
      [reminderValues retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      component = nil;
      componentCalendar = nil;
    }

  return self;
}

- (void) dealloc
{
  [component release];
  [componentCalendar release];

  [super dealloc];
}

- (void) setClientObject: (id)_client
{
  [super setClientObject: _client]; // WOComponent+SoObjects

  component = [[self clientObject] occurence];
  [[component parent] retain];

  componentCalendar = [[self clientObject] container];
  if ([componentCalendar isKindOfClass: [SOGoCalendarComponent class]])
    componentCalendar = [componentCalendar container];
  [componentCalendar retain];
}

//- (NSString *) title
//{
//  SOGoCalendarComponent *co;
//  NSString *tag;
//
//  co = [self clientObject];
//  if ([co isNew] && [co isKindOfClass: [SOGoCalendarComponent class]])
//    {
//      tag = [co componentTag];
//      if ([tag isEqualToString: @"vevent"])
//        [self setTitle: [self labelForKey: @"New Event"]];
//      else if ([tag isEqualToString: @"vtodo"])
//        [self setTitle: [self labelForKey: @"New Task"]];
//    }
//
//  return title;
//}

// - (BOOL) canBeOrganizer
// {
//   NSString *owner;
//   SOGoObject <SOGoComponentOccurence> *co;
//   SOGoUser *currentUser;
//   BOOL hasOrganizer;
//   SoSecurityManager *sm;

//   co = [self clientObject];
//   owner = [co ownerInContext: context];
//   currentUser = [context activeUser];

//   hasOrganizer = ([[organizer value: 0] length] > 0);

//   sm = [SoSecurityManager sharedSecurityManager];
  
//   return ([co isNew]
// 	  || (([owner isEqualToString: [currentUser login]]
// 	       || ![sm validatePermission: SOGoCalendarPerm_ModifyComponent
// 		       onObject: co
// 		       inContext: context])
// 	      && (!hasOrganizer || [component userIsOrganizer: currentUser])));
// }

//- (void) setOrganizerIdentity: (NSDictionary *) newOrganizerIdentity
//{
//  ASSIGN (organizerIdentity, newOrganizerIdentity);
//}

// - (NSDictionary *) organizerIdentity
// {
//   NSArray *allIdentities;
//   NSEnumerator *identities;
//   NSDictionary *currentIdentity;
//   NSString *orgEmail;

//   orgEmail = [organizer rfc822Email];
//   if (!organizerIdentity)
//     {
//       if ([orgEmail length])
// 	{
// 	  allIdentities = [[context activeUser] allIdentities];
// 	  identities = [allIdentities objectEnumerator];
// 	  while (!organizerIdentity
// 		 && ((currentIdentity = [identities nextObject])))
// 	    if ([[currentIdentity objectForKey: @"email"]
// 		  caseInsensitiveCompare: orgEmail]
// 		== NSOrderedSame)
// 	      ASSIGN (organizerIdentity, currentIdentity);
// 	}
//     }

//   return organizerIdentity;
// }

//- (void) setComment: (NSString *) _value
//{
//#warning should we do the same for "location" and "summary"? What about ContactsUI?
//  ASSIGN (comment, [_value stringByReplacingString: @"\r\n" withString: @"\n"]);
//}
//
//- (NSString *) comment
//{
//  return [comment stringByReplacingString: @"\n" withString: @"\r\n"];
//}

// TODO: Expose this method to the JSON API or centralize in UIxPreferences
- (NSArray *) categoryList
{
  NSMutableArray *categoryList;
  NSArray *categoryLabels;
  SOGoUserDefaults *defaults;

  defaults = [[context activeUser] userDefaults];
  categoryLabels = [defaults calendarCategories];
  if (!categoryLabels)
    categoryLabels = [[self labelForKey: @"category_labels"]
                       componentsSeparatedByString: @","];
  categoryList = [NSMutableArray arrayWithCapacity: [categoryLabels count] + 1];
  [categoryList addObjectsFromArray:
                  [categoryLabels sortedArrayUsingSelector:
                                    @selector (localizedCaseInsensitiveCompare:)]];

  return categoryList;
}

//- (NSArray *) repeatList
//{
//  static NSArray *repeatItems = nil;
//
//  if (!repeatItems)
//    {
//      repeatItems = [NSArray arrayWithObjects: @"DAILY",
//                             @"WEEKLY",
//                             @"BI-WEEKLY",
//                             @"EVERY WEEKDAY",
//                             @"MONTHLY",
//                             @"YEARLY",
//                             @"-",
//                             @"CUSTOM",
//                             nil];
//      [repeatItems retain];
//    }
//
//  return repeatItems;
//}

//- (NSString *) repeatLabel
//{
//  NSString *rc;
//
//  if ([self repeat])
//    rc = [self labelForKey: [NSString stringWithFormat: @"repeat_%@", [self repeat]]];
//  else
//    rc = [self labelForKey: @"repeat_NEVER"];
//
//  return rc;
//}

//- (NSString *) reminder
//{
//  if ([[self clientObject] isNew])
//    {
//      NSString *value;
//      NSUInteger index;
//      
//      value = [userDefaults calendarDefaultReminder];
//      index = [reminderValues indexOfObject: value];
//      
//      if (index != NSNotFound)
//        return [reminderItems objectAtIndex: index];
//      
//      return @"NONE";
//    }
//
//  return reminder;
//}

//- (NSString *) itemReminderText
//{
//  NSString *text;
//
//  if ([item isEqualToString: @"-"])
//    text = item;
//  else
//    text = [self labelForKey: [NSString stringWithFormat: @"reminder_%@", item]];
//
//  return text;
//}

//- (NSString *) itemReplyText
//{
//  NSString *word;
//
//  switch ([item intValue])
//    {
//    case iCalPersonPartStatAccepted: 
//      word = @"ACCEPTED";
//      break;
//    case iCalPersonPartStatDeclined:
//      word = @"DECLINED";
//      break;
//    case iCalPersonPartStatNeedsAction:
//      word = @"NEEDS-ACTION";
//      break;
//    case iCalPersonPartStatTentative:
//      word = @"TENTATIVE";
//      break;
//    case iCalPersonPartStatDelegated:
//      word = @"DELEGATED";
//      break;
//    default:
//      word = @"UNKNOWN";
//    }
//
//  return [self labelForKey: [NSString stringWithFormat: @"partStat_%@", word]];
//}

//- (NSArray *) replyList
//{
//  return [NSArray arrayWithObjects: 
//                    [NSNumber numberWithInt: iCalPersonPartStatAccepted], 
//	   [NSNumber numberWithInt: iCalPersonPartStatDeclined],
//	   [NSNumber numberWithInt: iCalPersonPartStatNeedsAction],
//	   [NSNumber numberWithInt: iCalPersonPartStatTentative],
//	   [NSNumber numberWithInt: iCalPersonPartStatDelegated],
//		  nil];
//}
//
//- (NSNumber *) reply
//{
//  iCalPersonPartStat participationStatus;
//
//  participationStatus = [ownerAsAttendee participationStatus];
//
//  return [NSNumber numberWithInt: participationStatus];
//}

///* priorities */
//
//- (NSArray *) priorities
//{
//  /* 0 == undefined
//     9 == low
//     5 == medium
//     1 == high
//  */
//  static NSArray *priorities = nil;
//
//  if (!priorities)
//    {
//      priorities = [NSArray arrayWithObjects: @"9", @"5", @"1", nil];
//      [priorities retain];
//    }
//
//  return priorities;
//}

//- (NSArray *) classificationClasses
//{
//  static NSArray *classes = nil;
//  
//  if (!classes)
//    {
//      classes = [NSArray arrayWithObjects: @"PUBLIC",
//                         @"CONFIDENTIAL", @"PRIVATE", nil];
//      [classes retain];
//    }
//  
//  return classes;
//}

/* helpers */

//- (BOOL) isWriteableClientObject
//{
//  return [[self clientObject]
//	   respondsToSelector: @selector(saveCompontent:)];
//}
//
///* access */
//
//- (BOOL) canEditComponent
//{
//  return ([[context activeUser] hasEmail: [organizer rfc822Email]]);
//}
//
///* response generation */
//

// - (NSString *) iCalParticipantsAndResourcesStringFromQueryParameters
// {
//   NSString *s;
  
//   s = [self iCalParticipantsStringFromQueryParameters];
//   return [s stringByAppendingString:
//               [self iCalResourcesStringFromQueryParameters]];
// }

// - (NSString *) iCalParticipantsStringFromQueryParameters
// {
//   static NSString *iCalParticipantString = @"ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;CN=\"%@\":MAILTO:%@\r\n";
  
//   return [self iCalStringFromQueryParameter: @"ps"
//                format: iCalParticipantString];
// }

// - (NSString *) iCalResourcesStringFromQueryParameters
// {
//   static NSString *iCalResourceString = @"ATTENDEE;ROLE=NON-PARTICIPANT;CN=\"%@\":MAILTO:%@\r\n";

//   return [self iCalStringFromQueryParameter: @"rs"
//                format: iCalResourceString];
// }

// - (NSString *) iCalStringFromQueryParameter: (NSString *) _qp
//                                      format: (NSString *) _format
// {
//   LDAPUserManager *um;
//   NSMutableString *iCalRep;
//   NSString *s;

//   um = [LDAPUserManager sharedUserManager];
//   iCalRep = (NSMutableString *)[NSMutableString string];
//   s = [self queryParameterForKey:_qp];
//   if(s && [s length] > 0) {
//     NSArray *es;
//     NSUInteger i, count;
    
//     es = [s componentsSeparatedByString: @","];
//     count = [es count];
//     for(i = 0; i < count; i++) {
//       NSString *email, *cn;
      
//       email = [es objectAtIndex:i];
//       cn = [um getCNForUID:[um getUIDForEmail:email]];
//       [iCalRep appendFormat:_format, cn, email];
//     }
//   }
//   return iCalRep;
// }

/* contact editor compatibility */

/*- (NSString *) urlButtonClasses
{
  NSString *classes;

  if ([url length])
    classes = @"button";
  else
    classes = @"button _disabled";

  return classes;
}*/

- (void) _handleOrganizer
{
  NSString *owner, *login, *currentEmail;
  iCalPerson *organizer;
  BOOL isOwner;

  //owner = [[self clientObject] ownerInContext: context];
  owner = [componentCalendar ownerInContext: context];
  login = [[context activeUser] login];
  isOwner = [owner isEqualToString: login];
  currentEmail = [[[context activeUser] allEmails] objectAtIndex: 0];

  if ([[component attendees] count] > 0)
    {
      SOGoUser *user;
      id identity;

      organizer = [iCalPerson elementWithTag: @"organizer"];
      [component setOrganizer: organizer];

      user = [SOGoUser userWithLogin: owner roles: nil];
      identity = [user defaultIdentity];
      [organizer setCn: [identity objectForKey: @"fullName"]]; 
      [organizer setEmail: [identity  objectForKey: @"email"]];

      if (!isOwner)
        {
          NSString *quotedEmail;
	  
          quotedEmail = [NSString stringWithFormat: @"\"MAILTO:%@\"",
                                  currentEmail];
          [organizer setValue: 0 ofAttribute: @"SENT-BY"
                           to: quotedEmail];
        }
    }
  else
    {
      organizer = nil;
    }
  [component setOrganizer: organizer];

  // In case of a new component, if the current user isn't the owner of the calendar, we
  // add the "X-SOGo-Component-Created-By: <email address>" attribute
  if ([[self clientObject] isNew] &&
      !isOwner &&
      [currentEmail length])
    {
      [component addChild: [CardElement simpleElementWithTag: @"X-SOGo-Component-Created-By"
                                                       value: currentEmail]];
    }
}

- (void) setAttributes: (NSDictionary *) data
{
  NSCalendarDate *now;

  now = [NSCalendarDate calendarDate];

  [component setAttributes: data inContext: context];

  [self _handleOrganizer];

  if ([[self clientObject] isNew])
    {
      [component setCreated: now];
      [component setTimeStampAsDate: now];
    }
  [component setLastModified: now];
}

//#warning the following methods probably share some code...
//- (NSString *) _toolbarForOwner: (SOGoUser *) ownerUser
//		andClientObject: (SOGoContentObject
//				  <SOGoComponentOccurence> *) clientObject
//{
//  NSString *toolbarFilename;
//  BOOL isOrganizer;
//
//  // We determine if we're the organizer of the component beeing modified.
//  // If we created an event on behalf of someone else -userIsOrganizer will
//  // return us YES. This is OK because we're in the SENT-BY. But, Alice
//  // should be able to accept/decline an invitation if she created the event
//  // in Bob's calendar and added herself in the attendee list.
//  isOrganizer = [component userIsOrganizer: ownerUser];
//
//  if (isOrganizer)
//    isOrganizer = ![ownerUser hasEmail: [[component organizer] sentBy]];
//
//  if ([componentCalendar isKindOfClass: [SOGoWebAppointmentFolder class]]
//      || ([component userIsAttendee: ownerUser]
//	  && !isOrganizer
//	  // Lightning does not manage participation status within tasks,
//	  // so we also ignore the participation status of tasks in the
//	  // web interface.
//	  && ![[component tag] isEqualToString: @"VTODO"]))
//    toolbarFilename = @"SOGoEmpty.toolbar";
//  else
//    {
//      if ([clientObject isKindOfClass: [SOGoAppointmentObject class]]
//	  || [clientObject isKindOfClass: [SOGoAppointmentOccurence class]])
//        toolbarFilename = @"SOGoAppointmentObject.toolbar";
//      else
//        toolbarFilename = @"SOGoTaskObject.toolbar";
//    }
//
//  return toolbarFilename;
//}
//
//- (NSString *) _toolbarForDelegate: (SOGoUser *) ownerUser
//		   andClientObject: (SOGoContentObject
//				     <SOGoComponentOccurence> *) clientObject
//{
//  SoSecurityManager *sm;
//  NSString *toolbarFilename;
//
//  sm = [SoSecurityManager sharedSecurityManager];
//
//  if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
//                     onObject: clientObject
//                    inContext: context])
//    toolbarFilename = [self _toolbarForOwner: ownerUser
//                             andClientObject: clientObject];
//  else
//    toolbarFilename = @"SOGoEmpty.toolbar";
//
//  return toolbarFilename;
//}
//
//- (NSString *) toolbar
//{
//  SOGoContentObject <SOGoComponentOccurence> *clientObject;
//  NSString *toolbarFilename;
//  SOGoUser *ownerUser;
//
//  clientObject = [self clientObject];
//  ownerUser = [SOGoUser userWithLogin: [clientObject ownerInContext: context]
//			roles: nil];
//
//  if ([ownerUser isEqual: [context activeUser]])
//    toolbarFilename = [self _toolbarForOwner: ownerUser
//			    andClientObject: clientObject];
//  else
//    toolbarFilename = [self _toolbarForDelegate: ownerUser
//			    andClientObject: clientObject];
//
//
//  return toolbarFilename;
//}
//
//
//- (int) ownerIsAttendee: (SOGoUser *) ownerUser
//        andClientObject: (SOGoContentObject
//                          <SOGoComponentOccurence> *) clientObject
//{
//  BOOL isOrganizer;
//  iCalPerson *ownerAttendee;
//  int rc;
//
//  rc = 0;
//
//  isOrganizer = [component userIsOrganizer: ownerUser];
//  if (isOrganizer)
//    isOrganizer = ![ownerUser hasEmail: [[component organizer] sentBy]];
//
//  if (!isOrganizer && ![[component tag] isEqualToString: @"VTODO"])
//    {
//      ownerAttendee = [component userAsAttendee: ownerUser];
//      if (ownerAttendee)
//        rc = 1;
//    }
//
//  return rc;
//}
//
//- (int) delegateIsAttendee: (SOGoUser *) ownerUser
//           andClientObject: (SOGoContentObject
//                             <SOGoComponentOccurence> *) clientObject
//{
//  SoSecurityManager *sm;
//  iCalPerson *ownerAttendee;
//  int rc;
//
//  rc = 0;
//
//  sm = [SoSecurityManager sharedSecurityManager];
//  if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
//                     onObject: clientObject
//                    inContext: context])
//    rc = [self ownerIsAttendee: ownerUser
//               andClientObject: clientObject];
//  else if (![sm validatePermission: SOGoCalendarPerm_RespondToComponent
//                          onObject: clientObject
//                         inContext: context])
//    {
//      ownerAttendee = [component userAsAttendee: ownerUser];
//      if ([[ownerAttendee rsvp] isEqualToString: @"true"]
//          && ![component userIsOrganizer: ownerUser])
//        rc = 1;
//      else
//        rc = 2;
//    }
//  else
//    rc = 2; // not invited, just RO
//
//  return rc;
//}
//
//- (int) getEventRWType
//{
//  SOGoContentObject <SOGoComponentOccurence> *clientObject;
//  SOGoUser *ownerUser;
//  int rc;
//
//  clientObject = [self clientObject];
//  ownerUser
//    = [SOGoUser userWithLogin: [clientObject ownerInContext: context]];
//  if ([componentCalendar isKindOfClass: [SOGoWebAppointmentFolder class]])
//    rc = 2;
//  else
//    {
//      if ([ownerUser isEqual: [context activeUser]])
//        rc = [self ownerIsAttendee: ownerUser
//                   andClientObject: clientObject];
//      else
//        rc = [self delegateIsAttendee: ownerUser
//                      andClientObject: clientObject];
//    }
//
//  return rc;
//}
//
//- (BOOL) eventIsReadOnly
//{
//  return [self getEventRWType] != 0;
//}
//
//- (NSString *) emailAlarmsEnabled
//{
//  SOGoSystemDefaults *sd;
//
//  sd = [SOGoSystemDefaults sharedSystemDefaults];
//
//  return ([sd enableEMailAlarms]
//          ? @"true"
//          : @"false");
//}
//
//- (BOOL) userHasRSVP
//{
//  return ([self getEventRWType] == 1);
//}

//- (unsigned int) firstDayOfWeek
//{
//  SOGoUserDefaults *ud;
//
//  ud = [[context activeUser] userDefaults];
//
//  return [ud firstDayOfWeek];
//}

// returns the raw content of the object
- (WOResponse *) rawAction
{
  NSMutableString *content;
  WOResponse *response;

  content = [NSMutableString string];
  response = [context response];

  [content appendFormat: [[self clientObject] contentAsString]];
  [response setHeader: @"text/plain; charset=utf-8" 
            forKey: @"content-type"];
  [response appendContentString: content];

  return response;
}

@end
