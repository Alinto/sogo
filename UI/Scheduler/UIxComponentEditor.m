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

#import <Foundation/NSValue.h>

#import <NGCards/iCalToDo.h>
#import <NGCards/iCalTrigger.h>

#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>

#import <Appointments/iCalAlarm+SOGo.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoTaskObject.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/WOResourceManager+SOGo.h>


#import "UIxComponentEditor.h"

#define componentReadableWritable  0
#define componentOwnerIsInvited    1
#define componentReadableOnly      2

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

- (BOOL) isChildOccurrence
{
  return [[self clientObject] isKindOfClass: [SOGoComponentOccurence class]];
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
- (NSNumber *) reply
{
  NSString *owner, *ownerEmail;
  SOGoUserManager *um;
  iCalPerson *ownerAsAttendee;
  iCalPersonPartStat participationStatus;

  um = [SOGoUserManager sharedUserManager];
  owner = [componentCalendar ownerInContext: context];
  ownerEmail = [um getEmailForUID: owner];
  ownerAsAttendee = [component findAttendeeWithEmail: (id)ownerEmail];
  participationStatus = [ownerAsAttendee participationStatus];

  return [NSNumber numberWithInt: participationStatus];
}

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

- (void) _handleAttendeesEdition
{
  NSMutableArray *newAttendees;
  NSUInteger count, max;
  NSString *currentEmail;
  iCalPerson *currentAttendee;
  NSString *json, *role, *partstat;
  NSDictionary *attendeesData;
  NSArray *attendees;
  NSDictionary *currentData;
  WORequest *request;

  request = [context request];
  json = [request formValueForKey: @"attendees"];
  if ([json length])
    {
      attendees = [NSArray array];
      attendeesData = [json objectFromJSONString];
      if (attendeesData && [attendeesData isKindOfClass: [NSDictionary class]])
	{
	  newAttendees = [NSMutableArray array];
	  attendees = [attendeesData allValues];
	  max = [attendees count];
	  for (count = 0; count < max; count++)
	    {
	      currentData = [attendees objectAtIndex: count];
	      currentEmail = [currentData objectForKey: @"email"];
              if ([currentEmail length] > 0)
                {
                  role = [[currentData objectForKey: @"role"] uppercaseString];
                  if (!role)
                    role = @"REQ-PARTICIPANT";
                  if ([role isEqualToString: @"NON-PARTICIPANT"])
                    partstat = @"";
                  else
                    {
                      partstat = [[currentData objectForKey: @"partstat"]
                                   uppercaseString];
                      if (!partstat)
                        partstat = @"NEEDS-ACTION";
                    }
                  currentAttendee = [component findAttendeeWithEmail: currentEmail];
                  if (!currentAttendee)
                    {
                      currentAttendee = [iCalPerson elementWithTag: @"attendee"];
                      [currentAttendee setCn: [currentData objectForKey: @"name"]];
                      [currentAttendee setEmail: currentEmail];
                      // [currentAttendee
                      //   setParticipationStatus: iCalPersonPartStatNeedsAction];
                    }
                  [currentAttendee
                    setRsvp: ([role isEqualToString: @"NON-PARTICIPANT"]
                              ? @"FALSE"
                              : @"TRUE")];
                  [currentAttendee setRole: role];
                  [currentAttendee setPartStat: partstat];
                  [newAttendees addObject: currentAttendee];
                }
	    }
	  [component setAttendees: newAttendees];
	}
      else
        {
	  //NSLog(@"Error scanning following JSON:\n%@", json);  
        }
    }
}

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

- (NSDictionary *) alarm
{
  NSArray *attendees;
  NSMutableDictionary *alarmData;
  NSString *ownerId, *email;
  iCalAlarm *anAlarm;
  iCalPerson *aAttendee;
  iCalTrigger *trigger;
  SOGoUser *owner;
  BOOL emailOrganizer, emailAttendees;
  int count, max;

  alarmData = nil;
  if ([component hasAlarms])
    {
      anAlarm = [component firstSupportedAlarm];
      trigger = [anAlarm trigger];
      if (![[trigger valueType] length] || [[trigger valueType] caseInsensitiveCompare: @"DURATION"] == NSOrderedSame)
        {
          alarmData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [[anAlarm action] lowercaseString], @"action",
                                           nil];
          [alarmData addEntriesFromDictionary: [trigger asDictionary]];

          emailOrganizer = NO;
          emailAttendees = NO;
          attendees = [anAlarm attendees];
          ownerId = [[self clientObject] ownerInContext: nil];
          owner = [SOGoUser userWithLogin: ownerId];
          email = [[owner defaultIdentity] objectForKey: @"email"];
          max = [attendees count];
          for (count = 0;
               !(emailOrganizer && emailAttendees)
                 && count < max;
               count++)
            {
              aAttendee = [attendees objectAtIndex: count];
              if ([[aAttendee rfc822Email] isEqualToString: email])
                emailOrganizer = YES;
              else
                emailAttendees = YES;
            }
          [alarmData setObject: [NSNumber numberWithBool: emailOrganizer] forKey: @"organizer"];
          [alarmData setObject: [NSNumber numberWithBool: emailAttendees] forKey: @"attendees"];
        }
    }

  return alarmData;
}

- (NSArray *) attachUrls
{
  NSMutableArray *attachUrls;
  NSArray *values;
  NSString *attachUrl;
  NSUInteger count, max;

  values = [component attach];
  max = [values count];
  if (max > 0)
    {
      attachUrls = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          attachUrl = [values objectAtIndex: count];
          if ([attachUrl length] > 0)
            [attachUrls addObject: [NSDictionary dictionaryWithObject: attachUrl forKey: @"value"]];
        }
    }
  else
    attachUrls = nil;

  return attachUrls;
}

- (void) setAttributes: (NSDictionary *) data
{
  NSArray *values;
  NSCalendarDate *now;
  NSMutableArray *attachUrls;
  NSMutableDictionary *dataWithOwner;
  NSString *owner;
  NSUInteger i;
  SOGoAppointmentFolders *folders;
  id destinationCalendar, o;

  now = [NSCalendarDate calendarDate];
  owner = [componentCalendar ownerInContext: context];

  // Append the calendar's owner to the data as it's required when setting alarms
  dataWithOwner = [NSMutableDictionary dictionaryWithDictionary: data];
  [dataWithOwner setObject: owner forKey: @"owner"];
  [component setAttributes: dataWithOwner inContext: context];

  destinationCalendar = [data objectForKey: @"destinationCalendar"];
  if ([destinationCalendar isKindOfClass: [NSString class]])
    {
      folders = [[context activeUser] calendarsFolderInContext: context];
      componentCalendar = [folders lookupName: [destinationCalendar stringValue]
                                    inContext: context
                                      acquire: 0];
      [componentCalendar retain];

    }

  [self _handleOrganizer];

  if ([[data objectForKey: @"attachUrls"] isKindOfClass: [NSArray class]])
    {
      values = [component childrenWithTag: @"attach"];
      [component removeChildren: values];
      values = [data objectForKey: @"attachUrls"];
      attachUrls = [NSMutableArray arrayWithCapacity: [values count]];
      for (i = 0; i < [values count]; i++)
        {
          o = [values objectAtIndex: i];
          if ([o isKindOfClass: [NSDictionary class]])
            {
              [attachUrls addObject: [o objectForKey: @"value"]];
            }
        }
    }
  else
    {
      attachUrls = nil;
    }
  [component setAttach: attachUrls];

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


- (int) ownerIsAttendee: (SOGoUser *) ownerUser
       andClientObject: (SOGoContentObject
                         <SOGoComponentOccurence> *) clientObject
{
 BOOL isOrganizer;
 iCalPerson *ownerAttendee;
 int rc;

 rc = 0;

 isOrganizer = [component userIsOrganizer: ownerUser];
 if (isOrganizer)
   isOrganizer = ![ownerUser hasEmail: [[component organizer] sentBy]];

 if (!isOrganizer && ![[component tag] isEqualToString: @"VTODO"])
   {
     ownerAttendee = [component userAsAttendee: ownerUser];
     if (ownerAttendee)
       rc = 1;
   }

 return rc;
}

- (int) delegateIsAttendee: (SOGoUser *) ownerUser
          andClientObject: (SOGoContentObject
                            <SOGoComponentOccurence> *) clientObject
{
 SoSecurityManager *sm;
 iCalPerson *ownerAttendee;
 int rc;

 rc = componentReadableWritable;

 sm = [SoSecurityManager sharedSecurityManager];
 if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
                    onObject: clientObject
                   inContext: context])
   rc = [self ownerIsAttendee: ownerUser
              andClientObject: clientObject];
 else if (![sm validatePermission: SOGoCalendarPerm_RespondToComponent
                         onObject: clientObject
                        inContext: context])
   {
     ownerAttendee = [component userAsAttendee: ownerUser];
     if ([[ownerAttendee rsvp] isEqualToString: @"true"]
         && ![component userIsOrganizer: ownerUser])
       rc = componentOwnerIsInvited;
     else
       rc = componentReadableOnly;
   }
 else
   rc = componentReadableOnly;

 return rc;
}

- (int) getEventRWType
{
  SOGoContentObject <SOGoComponentOccurence> *clientObject;
  SOGoUser *ownerUser;
  int rc;

  clientObject = [self clientObject];
  ownerUser = [SOGoUser userWithLogin: [clientObject ownerInContext: context]];
  if ([[clientObject container] isKindOfClass: [SOGoWebAppointmentFolder class]])
    rc = componentReadableOnly;
  else
    {
      if ([ownerUser isEqual: [context activeUser]])
        rc = [self ownerIsAttendee: ownerUser
                   andClientObject: clientObject];
      else
        rc = [self delegateIsAttendee: ownerUser
                      andClientObject: clientObject];
    }

  return rc;
}

- (BOOL) isReadOnly
{
 return [self getEventRWType] != componentReadableWritable;
}
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

- (BOOL) userHasRSVP
{
  return ([self getEventRWType] == componentOwnerIsInvited);
}

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

  [content appendFormat: @"%@", [[self clientObject] contentAsString]];
  [response setHeader: @"text/plain; charset=utf-8" 
            forKey: @"content-type"];
  [response appendContentString: content];

  return response;
}

+ (NSArray *) reminderValues
{
  return reminderValues;
}

@end
