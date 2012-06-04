/* SOGoCalendarComponent.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMail/NGMimeMessage.h>
#import <GDLContentStore/GCSFolder.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoGroup.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoWebDAVAclManager.h>
#import <SOGo/WORequest+SOGo.h>
#import <Appointments/SOGoAppointmentFolder.h>

#import "SOGoAptMailICalReply.h"
#import "SOGoAptMailNotification.h"
#import "SOGoAptMailReceipt.h"
#import "SOGoEMailAlarmsManager.h"
#import "iCalEntityObject+SOGo.h"
#import "iCalPerson+SOGo.h"
#import "iCalRepeatableEntityObject+SOGo.h"
#import "SOGoCalendarComponent.h"
#import "SOGoComponentOccurence.h"

@implementation SOGoCalendarComponent

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;
  NSString *nsD, *nsI;

  if (!aclManager)
    {
      nsD = @"DAV:";
      nsI = @"urn:inverse:params:xml:ns:inverse-dav";

      aclManager = [SOGoWebDAVAclManager new];

      [aclManager registerDAVPermission: davElement (@"read", nsD)
		  abstract: NO
                  withEquivalent: @"SOGoDAVReadPermission" /* hackish */
		  asChildOf: davElement (@"all", nsD)];
      [aclManager registerDAVPermission: davElement (@"view-whole-component", nsI)
		  abstract: NO
		  withEquivalent: SOGoCalendarPerm_ViewAllComponent
                  asChildOf: davElement (@"all", nsD)];
      [aclManager registerDAVPermission: davElement (@"view-date-and-time", nsI)
		  abstract: NO
		  withEquivalent: SOGoCalendarPerm_ViewDAndT
		  asChildOf: davElement (@"all", nsD)];
      [aclManager registerDAVPermission: davElement (@"read-current-user-privilege-set", nsD)
		  abstract: NO
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"all", nsD)];
      [aclManager registerDAVPermission: davElement (@"write", nsD)
		  abstract: NO
		  withEquivalent: SOGoCalendarPerm_ModifyComponent
		  asChildOf: davElement (@"all", nsD)];
      [aclManager
	registerDAVPermission: davElement (@"write-properties", nsD)
	abstract: YES
	withEquivalent: SoPerm_ChangePermissions /* hackish */
	asChildOf: davElement (@"write", nsD)];
      [aclManager
	registerDAVPermission: davElement (@"write-content", nsD)
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"write", nsD)];
      [aclManager
        registerDAVPermission: davElement (@"respond-to-component", nsI)
                     abstract: NO
               withEquivalent: SOGoCalendarPerm_RespondToComponent
                    asChildOf: davElement (@"write-content", nsD)];
      [aclManager registerDAVPermission: davElement (@"admin", nsI)
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", nsD)];
      [aclManager
	registerDAVPermission: davElement (@"read-acl", nsD)
	abstract: YES
	withEquivalent: SOGoPerm_ReadAcls
	asChildOf: davElement (@"admin", nsI)];
      [aclManager
	registerDAVPermission: davElement (@"write-acl", nsD)
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"admin", nsI)];
    }

  return aclManager;
}

- (id) init
{
  if ((self = [super init]))
    {
      fullCalendar = nil;
      safeCalendar = nil;
      originalCalendar = nil;
      componentTag = nil;
    }

  return self;
}

- (void) dealloc
{
  [fullCalendar release];
  [safeCalendar release];
  [originalCalendar release];
  [componentTag release];
  [super dealloc];
}

- (void) flush
{
  DESTROY(fullCalendar);
  DESTROY(safeCalendar);
  DESTROY(originalCalendar);
}

- (NSString *) davContentType
{
  return @"text/calendar";
}

- (NSString *) componentTag
{
  if (!componentTag)
    [self subclassResponsibility: _cmd];
  
  return componentTag;
}

- (void) setComponentTag: (NSString *) theTag
{
  ASSIGN(componentTag, theTag);
}

- (void) _filterComponent: (iCalEntityObject *) component
{
  NSString *type, *summary;
  int classification;

  type = @"vtodo";
  classification = 0;

  if ([component isKindOfClass: [iCalEvent class]])
    type = @"vevent";
  
  if ([component symbolicAccessClass] == iCalAccessPrivate)
    classification = 1;
  else if ([component symbolicAccessClass] == iCalAccessConfidential)
    classification = 2;

  summary = [self labelForKey: [NSString stringWithFormat: @"%@_class%d",
                                         type, classification]
                    inContext: context];
  [component setSummary: summary];
  [component setComment: @""];
  [component setUserComment: @""];
  [component setLocation: @""];
  [component setCategories: [NSArray array]];
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
      tmpCalendar = [[self calendar: NO secure: NO] mutableCopy];
      tmpComponent = (iCalRepeatableEntityObject *)
	[tmpCalendar firstChildWithTag: [self componentTag]];
      [self _filterComponent: tmpComponent];
      
      // We add an additional header here to inform clients (if necessary) that
      // we churned the content of the calendar.
      [tmpComponent addChild: [CardElement simpleElementWithTag: @"X-SOGo-Secure"
					   value: @"YES"]];
      iCalString = [tmpCalendar versitString];
      [tmpCalendar release];
    }
  else
    iCalString = nil;

  return iCalString;
}

static inline BOOL _occurenceHasID (iCalRepeatableEntityObject *occurence,
                                    NSString *recID)
{
  unsigned int seconds, recSeconds;
  
  seconds = [recID intValue];
  recSeconds = [[occurence recurrenceId] timeIntervalSince1970];

  return (seconds == recSeconds);
}

- (iCalRepeatableEntityObject *) lookupOccurence: (NSString *) recID
{
  iCalRepeatableEntityObject *component, *occurence, *currentOccurence;
  NSArray *occurences;
  unsigned int count, max;

  occurence = nil;

  component = [self component: NO secure: NO];
  if ([component hasRecurrenceRules])
    {
      occurences = [[self calendar: NO secure: NO] allObjects];
      max = [occurences count];
      count = 1; // skip master event
      while (!occurence && count < max)
	{
	  currentOccurence = [occurences objectAtIndex: count];
	  if (_occurenceHasID (currentOccurence, recID))
	    occurence = currentOccurence;
	  else
	    count++;
	}
    }
  else if (_occurenceHasID (component, recID))
    /* The "master" event could be that occurrence. */
    occurence = component;

  return occurence;
}

- (SOGoComponentOccurence *) occurence: (iCalRepeatableEntityObject *) component
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (iCalRepeatableEntityObject *) newOccurenceWithID: (NSString *) recID
{
  iCalRepeatableEntityObject *masterOccurence, *newOccurence;
  iCalCalendar *calendar;
  NSCalendarDate *recDate;
  NSTimeZone *timeZone;

  recDate = [NSCalendarDate dateWithTimeIntervalSince1970: [recID intValue]];
  masterOccurence = [self component: NO secure: NO];
  timeZone = [[[context activeUser] userDefaults] timeZone];
  [recDate setTimeZone: timeZone];

  if ([masterOccurence doesOccurOnDate: recDate])
    {
      newOccurence = [masterOccurence mutableCopy];
      [newOccurence autorelease];
      [newOccurence removeAllRecurrenceRules];
      [newOccurence removeAllExceptionRules];
      [newOccurence removeAllExceptionDates];
      [newOccurence setOrganizer: nil];
      [newOccurence setRecurrenceId: recDate];

      calendar = [masterOccurence parent];
      [calendar addChild: newOccurence];
    }
  else
    newOccurence = nil;

  return newOccurence;
}

- (id) toManyRelationshipKeys
{
  return nil;
}

- (id) toOneRelationshipKeys
{
  NSMutableArray *keys;
  NSArray *occurences;
  NSCalendarDate *recID;
  unsigned int count, max, seconds;

  keys = [NSMutableArray array];
  [keys addObject: @"master"];
  occurences = [[self calendar: NO secure: NO] allObjects];
  max = [occurences count];
  for (count = 1; count < max; count++)
    {
      recID = [[occurences objectAtIndex: count] recurrenceId];
      if (recID)
	{
	  seconds = [recID timeIntervalSince1970];
	  [keys addObject: [NSString stringWithFormat: @"occurence%d",
				     seconds]];
	}
    }

  return keys;
}

- (id) lookupName: (NSString *) lookupName
        inContext: (id) localContext
          acquire: (BOOL) acquire
{
  id obj;
  iCalRepeatableEntityObject *occurence;
  NSString *recID;
  BOOL isNewOccurence;

  obj = [super lookupName: lookupName
	       inContext: localContext
	       acquire: acquire];
  if (!obj)
    {
      if ([lookupName isEqualToString: @"master"])
	obj = [self occurence: [self component: NO secure: NO]];
      else if ([lookupName hasPrefix: @"occurence"])
	{
	  recID = [lookupName substringFromIndex: 9];
	  occurence = [self lookupOccurence: recID];
	  if (occurence)
            isNewOccurence = NO;
          else
	    {
	      occurence = [self newOccurenceWithID: recID];
	      isNewOccurence = YES;
	    }
	  if (occurence)
	    {
	      obj = [self occurence: occurence];
	      if (isNewOccurence)
		[obj setIsNew: isNewOccurence];
	    }
	}
    }

  return obj;
}

- (NSString *) _secureContentWithoutAlarms
{
  iCalCalendar *calendar;
  NSArray *allComponents;
  iCalEntityObject *currentComponent;
  NSUInteger count, max;

  calendar = [self calendar: NO secure: YES];
  allComponents = [calendar childrenWithTag: [self componentTag]];
  max = [allComponents count];
  for (count = 0; count < max; count++)
    {
      currentComponent = [allComponents objectAtIndex: count];
      [currentComponent removeAllAlarms];
    }

  return [calendar versitString];
}

- (NSString *) contentAsString
{
  NSString *secureContent;

  if ([[context request] isSoWebDAVRequest])
    {
      if ([container showCalendarAlarms])
        secureContent = [self secureContentAsString];
      else
        secureContent = [self _secureContentWithoutAlarms];
    }
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
  iCalRepeatableEntityObject *newComponent;
  iCalCalendar **calendar, *returnedCopy;
  NSString *iCalString, *tag, *prodID;

  if (secure)
    calendar = &safeCalendar;
  else
    calendar = &fullCalendar;

  if (!*calendar)
    {
      if (secure)
	iCalString = [self secureContentAsString];
      else
	iCalString = content;

      if ([iCalString length] > 0)
	{
	  ASSIGN (*calendar, [iCalCalendar parseSingleFromSource: iCalString]);
	  if (!secure)
	    originalCalendar = [*calendar copy];
	}
      else
	{
	  if (create)
	    {
	      ASSIGN (*calendar, [iCalCalendar groupWithTag: @"vcalendar"]);
	      [*calendar setVersion: @"2.0"];
              prodID = [NSString stringWithFormat:
                                   @"-//Inverse inc./SOGo %@//EN",
                                 SOGoVersion];
              [*calendar setProdID: prodID];
	      tag = [[self componentTag] uppercaseString];
	      newComponent = [[*calendar classForTag: tag]
			       groupWithTag: tag];
	      [newComponent setUid: [self globallyUniqueObjectId]];
	      [*calendar addChild: newComponent];
	    }
	}
    }

  returnedCopy = [*calendar mutableCopy];
  [returnedCopy autorelease];

  return returnedCopy;
}

- (id) component: (BOOL) create secure: (BOOL) secure
{
  return [[self calendar: create secure: secure]
	   firstChildWithTag: [self componentTag]];
}

//
// Returs "YES" if a a group was decomposed among attendees.
//
- (BOOL) expandGroupsInEvent: (iCalEvent *) theEvent
{
  NSMutableArray *allAttendees;
  NSEnumerator *enumerator;
  NSString *organizerEmail, *domain;
  iCalPerson *currentAttendee;
  SOGoGroup *group;
  BOOL doesIncludeGroup;
  unsigned int i;

  domain = [[context activeUser] domain];
  organizerEmail = [[theEvent organizer] rfc822Email];
  doesIncludeGroup = NO;
  allAttendees = [NSMutableArray arrayWithArray: [theEvent attendees]];
  enumerator = [[theEvent attendees] objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      group = [SOGoGroup groupWithEmail: [currentAttendee rfc822Email]
                               inDomain: domain];
      if (group)
	{
	  iCalPerson *person;
	  NSArray *members;
	  SOGoUser *user;
	  
	  // We did decompose a group...
	  [allAttendees removeObject: currentAttendee];

	  members = [group members];
	  for (i = 0; i < [members count]; i++)
	    {
	      user = [members objectAtIndex: i];
	      doesIncludeGroup = YES;

	      // If the organizer is part of the group, we skip it from
	      // the addition to the attendees' list
	      if ([user hasEmail: organizerEmail])
		continue;
	      
	      person = [self iCalPersonWithUID: [user login]];
	      [person setTag: @"ATTENDEE"];
	      [person setParticipationStatus: [currentAttendee participationStatus]];
	      [person setRsvp: [currentAttendee rsvp]];
	      [person setRole: [currentAttendee role]];
			    
	      if (![allAttendees containsObject: person])
		[allAttendees addObject: person];
	    }
	}
    }

  if (doesIncludeGroup)
    [theEvent setAttendees: allAttendees];
  
  return doesIncludeGroup;
}

- (void) _updateRecurrenceIDsWithEvent: (iCalRepeatableEntityObject*) newEvent
{
  iCalRepeatableEntityObject *oldMaster, *currentComponent;
  iCalDateTime *currentDate;
  int deltaSecs;
  NSArray *components, *dates;
  NSMutableArray *newDates;
  unsigned int count, max;
  NSCalendarDate *recID, *newDate;

  // Compute time interval from previous event definition.
  if (!originalCalendar)
    {
      if (content)
	ASSIGN (originalCalendar, [iCalCalendar parseSingleFromSource: content]);
      else
	[self warnWithFormat: @"content not available, we will crash"];
    }

  oldMaster = (iCalRepeatableEntityObject *)
    [originalCalendar firstChildWithTag: [self componentTag]];
  deltaSecs = [[newEvent startDate]
		timeIntervalSinceDate: [oldMaster startDate]];

  components = [[newEvent parent] events];
  max = [components count];

  if (max > 0)
    {
      // Update recurrence-id attribute of occurences.
      for (count = 1; count < max; count++)
	{
	  currentComponent = [components objectAtIndex: count];
	  recID = [[currentComponent recurrenceId] addTimeInterval: deltaSecs];
	  [currentComponent setRecurrenceId: recID];
	}

      // Update exception dates in master vEvent.
      currentComponent = [components objectAtIndex: 0];
      dates = [currentComponent childrenWithTag: @"exdate"];
      max = [dates count];
      if (max > 0)
	{
	  newDates = [NSMutableArray arrayWithCapacity: max];
	  for (count = 0; count < max; count++)
	    {
	      currentDate = [dates objectAtIndex: count];
	      newDate = [[currentDate dateTime] addTimeInterval: deltaSecs];
	      [newDates addObject: newDate];
	    }
	  [currentComponent removeAllExceptionDates];
	  for (count = 0; count < max; count++)
	    [currentComponent addToExceptionDates: [newDates objectAtIndex: count]];
	}
    }
}

- (void) updateComponent: (iCalRepeatableEntityObject *) newObject
{
  NSString *newUid;

  if (!isNew
      && [newObject isRecurrent])
    // We update an repeating event -- update exception dates
    // and recurrence-ids.
    [self _updateRecurrenceIDsWithEvent: newObject];

  // As much as we can, we try to use c_name == c_uid in order
  // to avoid tricky scenarios with some CalDAV clients. For example,
  // if Alice invites Bob (both use SOGo) and Bob accepts the invitation
  // using Lightning before having refreshed his calendar, he'll end up
  // with a duplicate of the event in his database tables.
  if (isNew)
    {
      newUid = nameInContainer;
      
      if ([newUid hasSuffix: @".ics"])
	newUid = [newUid substringToIndex: [newUid length]-4];
      [newObject setUid: newUid];
    }

  if ([[SOGoSystemDefaults sharedSystemDefaults] enableEMailAlarms])
    {
      SOGoEMailAlarmsManager *eaMgr;
      
      eaMgr = [SOGoEMailAlarmsManager sharedEMailAlarmsManager];
      [eaMgr handleAlarmsInCalendar: [newObject parent]
	     fromComponent: self];
    }
}

- (NSException *) saveComponent: (iCalRepeatableEntityObject *) newObject
{
  NSString *newiCalString;

  newiCalString = [[newObject parent] versitString];

  [self saveContentString: newiCalString];

  return nil;
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

- (NSTimeZone *) timeZoneForUser: (NSString *) email
{
  NSString *uid;
  SOGoUserDefaults *ud;

  uid = [[SOGoUserManager sharedUserManager] getUIDForEmail: email];
  ud = [[SOGoUser userWithLogin: uid] userDefaults];

  return [ud timeZone];
}

- (NGMimeBodyPart *) _bodyPartForICalObject: (iCalRepeatableEntityObject *) object
{
  NGMimeBodyPart *bodyPart;
  NGMutableHashMap *headerMap;
  NSString *iCalString, *header, *charset;
  NSData *objectData;
  iCalCalendar *parent;

  parent = [object parent];
  iCalString = [NSString stringWithFormat: @"%@\r\n", [parent versitString]];
  if ([iCalString canBeConvertedToEncoding: NSISOLatin1StringEncoding])
    {
      objectData = [iCalString dataUsingEncoding: NSISOLatin1StringEncoding];
      charset = @"ISO-8859-1";
    }
  else
    {
      objectData = [iCalString dataUsingEncoding: NSUTF8StringEncoding];
      charset = @"UTF-8";
    }

  header = [NSString stringWithFormat: @"text/calendar; method=%@;"
                     @" charset=\"%@\"",
                     [(iCalCalendar *) [object parent] method], charset];
  headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
  [headerMap setObject: header forKey: @"content-type"];
  [headerMap setObject: @"quoted-printable"
                forKey: @"content-transfer-encoding"];
  bodyPart = [NGMimeBodyPart bodyPartWithHeader: headerMap];
  [bodyPart setBody: [objectData dataByEncodingQuotedPrintable]];

  return bodyPart;
}

- (void) sendEMailUsingTemplateNamed: (NSString *) newPageName
			   forObject: (iCalRepeatableEntityObject *) object
		      previousObject: (iCalRepeatableEntityObject *) previousObject
                         toAttendees: (NSArray *) attendees
                            withType: (NSString *) msgType
{
  NSString *pageName;
  NSString *senderEmail, *shortSenderEmail, *email;
  WOApplication *app;
  unsigned i, count;
  iCalPerson *attendee;
  NSString *recipient;
  SOGoAptMailNotification *p;
  NSString *mailDate, *subject, *text;
  NGMutableHashMap *headerMap;
  NGMimeMessage *msg;
  NGMimeBodyPart *bodyPart, *eventBodyPart;
  NGMimeMultipartBody *body;
  SOGoUser *ownerUser;
  SOGoDomainDefaults *dd;

  ownerUser = [SOGoUser userWithLogin: owner];
  dd = [ownerUser domainDefaults];
  if ([dd appointmentSendEMailNotifications] && [object isStillRelevant])
    {
      count = [attendees count];
      if (count)
	{
	  /* sender */
	  //currentUser = [context activeUser];
	  //shortSenderEmail = [[currentUser allEmails] objectAtIndex: 0];
	  //  senderEmail = [NSString stringWithFormat: @"%@ <%@>",
	  //			  [ownerUser cn], shortSenderEmail];
	  shortSenderEmail = [[object organizer] rfc822Email];
	  if (![shortSenderEmail length])
	    shortSenderEmail = [[previousObject organizer] rfc822Email];
	  senderEmail = [[object organizer] mailAddress];
// 	  NSLog (@"sending '%@' from %@",
// 		 [(iCalCalendar *) [object parent] method], senderEmail);
	  /* generate iCalString once */

          /* calendar part */
          eventBodyPart = [self _bodyPartForICalObject: object];

	  /* get WOApplication instance */
	  app = [WOApplication application];

	  /* generate dynamic message content */

	  for (i = 0; i < count; i++)
	    {
	      attendee = [attendees objectAtIndex: i];
	      // Don't send a notification to the event organizer nor a deletion
	      // notification to an attendee who already declined the invitation.
	      if (![[attendee uid] isEqualToString: owner] &&
		  !([[attendee partStat] compare: @"DECLINED"] == NSOrderedSame &&
		    [newPageName compare: @"Deletion"] == NSOrderedSame))
		{
		  /* construct recipient */
		  recipient = [attendee mailAddress];
		  email = [attendee rfc822Email];

#warning this could be optimized in a class hierarchy common with the	\
  SOGoObject acl notification mechanism
		  /* create page name */
		  pageName = [NSString stringWithFormat: @"SOGoAptMail%@",
                                       newPageName];
		  /* construct message content */
		  p = [app pageWithName: pageName inContext: context];
		  [p setApt: (iCalEvent *) object];
		  [p setPreviousApt: (iCalEvent *) previousObject];
		  
		  if ([[object organizer] cn] && [[[object organizer] cn] length])
		    {
		      [p setOrganizerName: [[object organizer] cn]];
		    }
		  else
		    {
		      [p setOrganizerName: [ownerUser cn]];
		    }

		  subject = [[p getSubject] asQPSubjectString: @"UTF-8"];
		  text = [p getBody];

		  /* construct message */
		  headerMap = [NGMutableHashMap hashMapWithCapacity: 5];
          
		  /* NOTE: multipart/alternative seems like the correct choice but
		   * unfortunately Thunderbird doesn't offer the rich content alternative
		   * at all. Mail.app shows the rich content alternative _only_
		   * so we'll stick with multipart/mixed for the time being.
		   */
#warning SOPE is just plain stupid here - if you change the case of keys, it will break the encoding of fields
		  [headerMap setObject: @"multipart/mixed" forKey: @"content-type"];
		  [headerMap setObject: @"1.0" forKey: @"MIME-Version"];
		  [headerMap setObject: senderEmail forKey: @"from"];
		  [headerMap setObject: recipient forKey: @"to"];
		  mailDate = [[NSCalendarDate date] rfc822DateString];
		  [headerMap setObject: mailDate forKey: @"date"];
		  [headerMap setObject: subject forKey: @"subject"];
                  if ([msgType length] > 0)
                    [headerMap setObject: msgType forKey: @"x-sogo-message-type"];
		  msg = [NGMimeMessage messageWithHeader: headerMap];

		  /* multipart body */
		  body = [[NGMimeMultipartBody alloc] initWithPart: msg];

		  /* text part */
		  headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
		  [headerMap setObject: @"text/plain; charset=\"UTF-8\""
			     forKey: @"content-type"];
		  bodyPart = [NGMimeBodyPart bodyPartWithHeader: headerMap];
		  [bodyPart setBody: [text dataUsingEncoding: NSUTF8StringEncoding]];

		  /* attach text part to multipart body */
		  [body addBodyPart: bodyPart];
    
		  /* attach calendar part to multipart body */
		  [body addBodyPart: eventBodyPart];
    
		  /* attach multipart body to message */
		  [msg setBody: body];
		  [body release];

		  /* send the damn thing */
		  [[SOGoMailer mailerWithDomainDefaults: dd]
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
			  from: (SOGoUser *) from
			    to: (iCalPerson *) recipient
{
  NSString *pageName, *mailDate, *email;
  WOApplication *app;
  iCalPerson *attendee;
  SOGoAptMailICalReply *p;
  NGMutableHashMap *headerMap;
  NGMimeMessage *msg;
  NGMimeBodyPart *bodyPart;
  NGMimeMultipartBody *body;
  NSData *bodyData;
  SOGoDomainDefaults *dd;

  dd = [from domainDefaults];
  if ([dd appointmentSendEMailNotifications])
    {
      /* get WOApplication instance */
      app = [WOApplication application];

      /* create page name */
      pageName = @"SOGoAptMailICalReply";
      /* construct message content */
      p = [app pageWithName: pageName inContext: context];
      [p setApt: (iCalEvent *) event];

      attendee = [event userAsAttendee: from];
      [p setAttendee: attendee];

      /* construct message */
      headerMap = [NGMutableHashMap hashMapWithCapacity: 5];

      /* NOTE: multipart/alternative seems like the correct choice but
       * unfortunately Thunderbird doesn't offer the rich content alternative
       * at all. Mail.app shows the rich content alternative _only_
       * so we'll stick with multipart/mixed for the time being.
       */
#warning SOPE is just plain stupid here - if you change the case of keys, it will break the encoding of fields
      [headerMap setObject: [attendee mailAddress] forKey: @"from"];
      [headerMap setObject: [recipient mailAddress] forKey: @"to"];
      mailDate = [[NSCalendarDate date] rfc822DateString];
      [headerMap setObject: mailDate forKey: @"date"];
      [headerMap setObject: [[p getSubject] asQPSubjectString: @"UTF-8"]
                    forKey: @"subject"];
      [headerMap setObject: @"1.0" forKey: @"MIME-Version"];
      [headerMap setObject: @"multipart/mixed" forKey: @"content-type"];
      [headerMap setObject: @"calendar:invitation-reply" forKey: @"x-sogo-message-type"];
      msg = [NGMimeMessage messageWithHeader: headerMap];

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

      /* attach calendar part to multipart body */
      [body addBodyPart: [self _bodyPartForICalObject: event]];

      /* attach multipart body to message */
      [msg setBody: body];
      [body release];

      /* send the damn thing */
      email = [recipient rfc822Email];
      [[SOGoMailer mailerWithDomainDefaults: dd]
	sendMimePart: msg
	toRecipients: [NSArray arrayWithObject: email]
	sender: [attendee rfc822Email]];
    }
}

- (void) sendResponseToOrganizer: (iCalRepeatableEntityObject *) newComponent
			    from: (SOGoUser *) from
{
  iCalPerson *organizer, *attendee;
  iCalEvent *event;
  SOGoUser *ownerUser;

  event = [newComponent itipEntryWithMethod: @"reply"];
  ownerUser = [SOGoUser userWithLogin: owner];
  if (![event userIsOrganizer: ownerUser])
    {
      organizer = [event organizer];
      attendee = [event userAsAttendee: ownerUser];
      [event setAttendees: [NSArray arrayWithObject: attendee]];
      [self sendIMIPReplyForEvent: event from: from to: organizer];
    }
}

- (void) sendReceiptEmailUsingTemplateNamed: (NSString *) template
                                  forObject: (iCalRepeatableEntityObject *) object
                                         to: (NSArray *) attendees
{
  NSString *pageName, *mailDate, *mailText, *fullSenderEmail, *senderEmail;
  SOGoAptMailReceipt *page;
  NGMutableHashMap *headerMap;
  NGMimeMessage *msg;
  SOGoUser *currentUser;
  SOGoDomainDefaults *dd;
  NSDictionary *identity;

  currentUser = [context activeUser];
  if ([[currentUser userDefaults] appointmentSendEMailReceipts]
      && [attendees count])
    {
      pageName = [NSString stringWithFormat: @"SOGoAptMail%@Receipt",
                           template];
      page = [[WOApplication application] pageWithName: pageName
                                             inContext: context];
      [page setApt: (iCalEvent *) object];
      [page setRecipients: attendees];

      identity = [currentUser primaryIdentity];

      /* construct message */
#warning SOPE is just plain stupid here - if you change the case of keys, it will break the encoding of fields
      headerMap = [NGMutableHashMap hashMapWithCapacity: 5];
      fullSenderEmail = [identity keysWithFormat: @"%{fullName} <%{email}>"];
      [headerMap setObject: fullSenderEmail forKey: @"from"];
      [headerMap setObject: fullSenderEmail forKey: @"to"];
      mailDate = [[NSCalendarDate date] rfc822DateString];
      [headerMap setObject: mailDate forKey: @"date"];
      [headerMap setObject: [page getSubject] forKey: @"subject"];
      [headerMap setObject: @"1.0" forKey: @"MIME-Version"];
      [headerMap setObject: @"text/plain; charset=utf-8"
                    forKey: @"content-type"];
      msg = [NGMimeMessage messageWithHeader: headerMap];

      /* text part */
      mailText = [page getBody];
      [msg setBody: [mailText dataUsingEncoding: NSUTF8StringEncoding]];

      /* send the damn thing */
      senderEmail = [identity objectForKey: @"email"];
      dd = [currentUser domainDefaults];
      [[SOGoMailer mailerWithDomainDefaults: dd]
		    sendMimePart: msg
		    toRecipients: [NSArray arrayWithObject: senderEmail]
                          sender: senderEmail];
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

  user = [SOGoUser userWithLogin: uid];
  component = [self component: NO secure: NO];

  return [component userAsAttendee: user];
}

- (iCalPerson *) iCalPersonWithUID: (NSString *) uid
{
  iCalPerson *person;
  SOGoUserManager *um;
  NSDictionary *contactInfos;

  um = [SOGoUserManager sharedUserManager];
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
  while ((currentPerson = [persons nextObject]))
    {
      uid = [currentPerson uid];
      if (uid)
	[uids addObject: uid];
    }

  return uids;
}

- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder
{
  return [self copyComponent: [self calendar: NO secure: NO]
		    toFolder: newFolder];
}

- (NSException *) copyComponent: (iCalCalendar *) calendar
		       toFolder: (SOGoGCSFolder *) newFolder
{
  NSArray *elements;
  NSString *newUID;
  unsigned int count, max;
  SOGoCalendarComponent *newComponent;

  newUID = [self globallyUniqueObjectId];
  elements = [calendar allObjects];
  max = [elements count];
  for (count = 0; count < max; count++)
    [[elements objectAtIndex: count] setUid: newUID];

  newComponent = [[self class] objectWithName:
				 [NSString stringWithFormat: @"%@.ics", newUID]
			       inContainer: newFolder];

  return [newComponent saveContentString: [calendar versitString]];
}

#warning Should we not remove the concept of Organizer and Participant roles?
- (NSString *) _roleOfOwner: (iCalRepeatableEntityObject *) component
{
  NSString *role;
  iCalPerson *organizer;
  SOGoUser *ownerUser;

  if (isNew)
    role = SOGoCalendarRole_Organizer;
  else
    {
      organizer = [component organizer];
      if ([[organizer rfc822Email] length] > 0)
	{
	  ownerUser = [SOGoUser userWithLogin: owner];
	  if ([component userIsOrganizer: ownerUser])
	    role = SOGoCalendarRole_Organizer;
	  else if ([component userIsAttendee: ownerUser])
	    role = SOGoCalendarRole_Participant;
	  else
	    role = SOGoRole_None;
	}
      else
	role = SOGoCalendarRole_Organizer;
    }

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
      if (isNew)
        {
          if ([roles containsObject: SOGoRole_ObjectCreator])
            [roles addObject: SOGoCalendarRole_Organizer];
        }
      else
        {
          if (component)
            {
              aclUser = [SOGoUser userWithLogin: uid];
              if ([component userIsOrganizer: aclUser])
                [roles addObject: SOGoCalendarRole_Organizer];
              else if ([component userIsAttendee: aclUser])
                [roles addObject: SOGoCalendarRole_Participant];
              accessRole
                = [container roleForComponentsWithAccessClass: [component symbolicAccessClass]
                                                      forUser: uid];
              if ([accessRole length] > 0)
                {
                  [roles addObject: accessRole];
                  [roles addObject: [self _compiledRoleForOwner: ownerRole
                                                        andUser: accessRole]];
                }
            }
        }
    }

  return roles;
}

- (void) snoozeAlarm: (unsigned int) minutes
{
  NSDictionary *quickFields;
  GCSFolder *folder;
  unsigned int nextAlarm;

  folder = [[self container] ocsFolder];
  if (!folder)
    {
      [self errorWithFormat:@"(%s): missing folder for update!",
            __PRETTY_FUNCTION__];
      return;
    }

  nextAlarm = [[NSCalendarDate calendarDate] timeIntervalSince1970]  + minutes * 60;
  quickFields = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: nextAlarm]
                                            forKey: @"c_nextalarm"];

  [folder updateQuickFields: quickFields
                whereColumn: @"c_name"
                  isEqualTo: nameInContainer];
}

/* SOGoComponentOccurence protocol */

- (iCalRepeatableEntityObject *) occurence
{
  return [self component: YES secure: NO];
}

#warning alarms: we do not handle occurrences
- (NSException *) prepareDelete
{
  if ([[SOGoSystemDefaults sharedSystemDefaults] enableEMailAlarms])
    {
      SOGoEMailAlarmsManager *eaMgr;
      
      eaMgr = [SOGoEMailAlarmsManager sharedEMailAlarmsManager];
      [eaMgr deleteAlarmsFromComponent: self];
    }

  return nil;
}

- (id) PUTAction: (WOContext *) localContext
{
  WORequest *rq;
  iCalCalendar *putCalendar;

  rq = [localContext request];
  putCalendar = [iCalCalendar parseSingleFromSource: [rq contentAsString]];

  if ([[SOGoSystemDefaults sharedSystemDefaults] enableEMailAlarms])
    {
      SOGoEMailAlarmsManager *eaMgr;

      eaMgr = [SOGoEMailAlarmsManager sharedEMailAlarmsManager];
      [eaMgr handleAlarmsInCalendar: putCalendar
	     fromComponent: self];
    }

  return [super PUTAction: localContext];
}

// /* Overriding this method dramatically speeds up PROPFIND request, but may
//    otherwise be a bad idea... Wait and see. */
// - (NSDictionary*) valuesForKeys: (NSArray*)keys
// {
//   NSMutableDictionary *values;

//   values = [NSMutableDictionary dictionaryWithCapacity: [keys count]];
//   [values setObject: [self davCreationDate] forKey: @"davCreationDate"];
//   [values setObject: [self davContentLength] forKey: @"davContentLength"];
//   [values setObject: [self davLastModified] forKey: @"davLastModified"];
//   [values setObject: @"text/calendar" forKey: @"davContentType"];
//   [values setObject: [self baseURL] forKey: @"davURL"];

//   return values;
// }

@end
