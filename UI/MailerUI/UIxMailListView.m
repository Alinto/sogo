/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2009 Inverse inc.

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

/*
  UIxMailListView
  
  This component represent a list of mails and is attached to an SOGoMailFolder
  object.
*/

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>

#import <EOControl/EOQualifier.h>

#import <SoObjects/Mailer/SOGoDraftsFolder.h>
#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/Mailer/SOGoSentFolder.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserDefaults.h>

#import "UIxMailListView.h"

#define messagesPerPage 50

@implementation UIxMailListView

- (id) init
{
  SOGoUser *user;

  if ((self = [super init]))
    {
      qualifier = nil;
      user = [context activeUser];
      ASSIGN (dateFormatter, [user dateFormatterInContext: context]);
      ASSIGN (userTimeZone, [user timeZone]);
      folderType = 0;
      currentColumn = nil;
    }

  return self;
}

- (void) dealloc 
{
  [qualifier release];
  [sortedUIDs release];
  [messages release];
  [message release];
  [dateFormatter release];
  [userTimeZone release];
  [currentColumn release];
  [super dealloc];
}

/* accessors */

- (void) setMessage: (id) _msg
{
  ASSIGN (message, _msg);
}

- (id) message 
{
  return message;
}

- (NSString *) messageDate
{
  NSCalendarDate *messageDate;

  messageDate = [[message valueForKey: @"envelope"] date];
  [messageDate setTimeZone: userTimeZone];

  return [dateFormatter formattedDateAndTime: messageDate];
}

//
// Priorities are defined like this:
//
// X-Priority: 1 (Highest)
// X-Priority: 2 (High)
// X-Priority: 3 (Normal)
// X-Priority: 4 (Low)
// X-Priority: 5 (Lowest)
//
// Sometimes, the MUAs don't send over the string in () so we ignore it.
//
- (NSString *) messagePriority
{
  NSString *result;
  NSData *data;
    
  data = [message objectForKey: @"header"];
  result = @"";

  if (data)
    {
      NSString *s;
      
      s = [[NSString alloc] initWithData: data
			    encoding: NSASCIIStringEncoding];

      if (s)
	{
	  NSRange r;

	  [s autorelease];
	  r = [s rangeOfString: @":"];

	  if (r.length)
	    {
	      s = [[s substringFromIndex: r.location+1]
		    stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

	      if ([s hasPrefix: @"1"]) result = [self labelForKey: @"highest"];
	      else if ([s hasPrefix: @"2"]) result = [self labelForKey: @"high"];
	      else if ([s hasPrefix: @"4"]) result = [self labelForKey: @"low"];
	      else if ([s hasPrefix: @"5"]) result = [self labelForKey: @"lowest"];
	    }
	}
    }
  
  return result;
}

- (NSString *) messageSubject
{
  id baseSubject;
  NSString *subject;

  baseSubject = [[message valueForKey: @"envelope"] subject];
  subject = [baseSubject decodedSubject];
  if (![subject length])
    subject = [self labelForKey: @"Untitled"];

  return subject;
}

- (BOOL) showToAddress 
{
  SOGoMailFolder *co;

  if (!folderType)
    {
      co = [self clientObject];
      if ([co isKindOfClass: [SOGoSentFolder class]]
	  || [co isKindOfClass: [SOGoDraftsFolder class]])
	folderType = 1;
      else
	folderType = -1;
    }

  return (folderType == 1);
}

/* title */

- (NSString *) objectTitle 
{
  return [[self clientObject] nameInContainer];
}

- (NSString *) panelTitle 
{
  NSString *s;
  
  s = [self labelForKey:@"View Mail Folder"];
  s = [s stringByAppendingString:@": "];
  s = [s stringByAppendingString:[self objectTitle]];
  return s;
}

/* derived accessors */

- (BOOL) isMessageDeleted 
{
  NSArray *flags;
  
  flags = [[self message] valueForKey:@"flags"];
  return [flags containsObject:@"deleted"];
}

- (BOOL) isMessageRead 
{
  NSArray *flags;
  
  flags = [[self message] valueForKey:@"flags"];
  return [flags containsObject:@"seen"];
}

- (NSString *) messageUidString 
{
  return [[[self message] valueForKey:@"uid"] stringValue];
}

- (NSString *) messageRowStyleClass 
{
  NSString *rowClass;

  rowClass = [self isMessageDeleted]? @"mailer_listcell_deleted" : @"mailer_listcell_regular";

  if (![self isMessageRead])
    rowClass = [rowClass stringByAppendingString: @" mailer_unreadmail"];
  
  return rowClass;
}

- (NSString *) messageSubjectCellStyleClass 
{
  NSArray *flags;
  NSString *cellClass = @"messageSubjectColumn ";

  flags = [[self message] valueForKey:@"flags"];

  if ([flags containsObject: @"answered"])
    {
      if ([flags containsObject: @"$forwarded"])
	cellClass = [cellClass stringByAppendingString: @"mailer_forwardedrepliedmailsubject"];
      else
	cellClass = [cellClass stringByAppendingString: @"mailer_repliedmailsubject"];
    }
  else if ([flags containsObject: @"$forwarded"])
    cellClass = [cellClass stringByAppendingString: @"mailer_forwardedmailsubject"];
  else
    cellClass = [cellClass stringByAppendingString: @"mailer_readmailsubject"];

  return cellClass;
}

- (BOOL) hasMessageAttachment 
{
  NSArray *parts;
  NSEnumerator *dispositions;
  NSDictionary *currentDisp;
  BOOL hasAttachment;

  hasAttachment = NO;

  parts = [[message objectForKey: @"body"] objectForKey: @"parts"];
  if ([parts count] > 1)
    {
      dispositions = [[parts objectsForKey: @"disposition"
			     notFoundMarker: nil] objectEnumerator];
      while (!hasAttachment
	     && (currentDisp = [dispositions nextObject]))
	hasAttachment = ([[currentDisp objectForKey: @"type"] length]);
    }

  return hasAttachment;
}

/* fetching messages */

- (NSArray *) fetchKeys 
{
  /* Note: see SOGoMailManager.m for allowed IMAP4 keys */
  static NSArray *keys = nil;

  if (!keys)
    keys = [[NSArray alloc] initWithObjects: @"UID",
    			    @"FLAGS", @"ENVELOPE", @"RFC822.SIZE",
    			    @"BODYSTRUCTURE", @"BODY.PEEK[HEADER.FIELDS (X-PRIORITY)]", nil];
  return keys;
}

- (NSString *) defaultSortKey 
{
  return @"ARRIVAL";
}

- (NSString *) imap4SortKey 
{
  NSString *sort;
  
  sort = [[context request] formValueForKey: @"sort"];

  if (![sort length])
    sort = [self defaultSortKey];

  return [sort uppercaseString];
}

- (NSString *) imap4SortOrdering 
{
  NSString *sort, *ascending;

  sort = [self imap4SortKey];

  ascending = [[context request] formValueForKey: @"asc"];
  if (![ascending boolValue])
    sort = [@"REVERSE " stringByAppendingString: sort];

  return sort;
}

- (NSRange) fetchRange 
{
  if (firstMessageNumber == 0)
    return NSMakeRange(0, messagesPerPage);
  return NSMakeRange(firstMessageNumber - 1, messagesPerPage);
}

- (NSArray *) sortedUIDs 
{
  EOQualifier *fetchQualifier, *notDeleted;

  if (!sortedUIDs)
    {
      notDeleted = [EOQualifier qualifierWithQualifierFormat:
				  @"(not (flags = %@))",
				@"deleted"];
      if (qualifier)
	{
	  fetchQualifier = [[EOAndQualifier alloc] initWithQualifiers:
						     notDeleted, qualifier,
						   nil];
	  [fetchQualifier autorelease];
	}
      else
	fetchQualifier = notDeleted;

      sortedUIDs
        = [[self clientObject] fetchUIDsMatchingQualifier: fetchQualifier
			       sortOrdering: [self imap4SortOrdering]];
      [sortedUIDs retain];
    }

  return sortedUIDs;
}

- (unsigned int) totalMessageCount 
{
  return [sortedUIDs count];
}

- (BOOL) showsAllMessages 
{
  return ([[self sortedUIDs] count] <= [self fetchRange].length) ? YES : NO;
}

- (NSRange) fetchBlock 
{
  NSRange  r;
  unsigned len;
  NSArray  *uids;
  
  r    = [self fetchRange];
  uids = [self sortedUIDs];
  
  /* only need to restrict if we have a lot */
  if ((len = [uids count]) <= r.length) {
    r.location = 0;
    r.length   = len;
    return r;
  }
  
  if (len < r.location) {
    // TODO: CHECK CONDITION (< vs <=)
    /* out of range, recover at first block */
    r.location = 0;
    return r;
  }
  
  if (r.location + r.length > len)
    r.length = len - r.location;
  return r;
}

- (unsigned int) firstMessageNumber 
{
  return [self fetchBlock].location + 1;
}

- (unsigned int) lastMessageNumber 
{
  NSRange r;
  
  r = [self fetchBlock];
  return r.location + r.length;
}

- (BOOL) hasPrevious 
{
  return [self fetchBlock].location == 0 ? NO : YES;
}

- (BOOL) hasNext 
{
  NSRange r = [self fetchBlock];
  return r.location + r.length >= [[self sortedUIDs] count] ? NO : YES;
}

- (unsigned int) nextFirstMessageNumber 
{
  return [self firstMessageNumber] + [self fetchRange].length;
}

- (unsigned int) lastFirstMessageNumber 
{
  unsigned int max, modulo;

  if (!sortedUIDs)
    [self sortedUIDs];

  max = [sortedUIDs count];
  modulo = (max % messagesPerPage);
  if (modulo == 0)
    modulo = messagesPerPage;

  return (max + 1 - modulo);
}

- (unsigned int) prevFirstMessageNumber 
{
  NSRange  r;
  unsigned idx;
  
  idx = [self firstMessageNumber];
  r   = [self fetchRange];
  if (idx > r.length)
    return (idx - r.length);
  return 1;
}

- (NSArray *) messages 
{
  NSMutableArray *unsortedMsgs;
  NSMutableDictionary *map;
  NSDictionary *msgs;
  NSArray *uids;

  unsigned len, i, count;
  NSRange r;
  
  if (!messages)
    {
      r = [self fetchBlock];
      uids = [self sortedUIDs];
      len = [uids count];
      
      // only need to restrict if we have a lot
      if (len > r.length)
	{
	  uids = [uids subarrayWithRange: r];
	  len = [uids count];
	}

      // Don't assume the IMAP server return the messages in the
      // same order as the specified list of UIDs (specially true for
      // dovecot).
      msgs = (NSDictionary *) [[self clientObject] fetchUIDs: uids
						   parts: [self fetchKeys]];
      unsortedMsgs = [msgs objectForKey: @"fetch"];
      count = [unsortedMsgs count];

      messages = [NSMutableArray arrayWithCapacity: count];
      
      // We build our uid->message map from our FETCH response
      map = [[NSMutableDictionary alloc] initWithCapacity: count];
      
      for (i = 0; i < count; i++)
	[map setObject: [unsortedMsgs objectAtIndex: i]
	     forKey: [[unsortedMsgs objectAtIndex: i] objectForKey: @"uid"]];
      
      for (i = 0; i < len; i++)
	{
	  [(NSMutableArray *)messages addObject: [map objectForKey: [uids objectAtIndex: i]]];
	}
      
      RELEASE(map);
      RETAIN(messages);
    }

  return messages;
}

/* URL processing */

- (NSString *) messageViewTarget
{
  return [NSString stringWithFormat: @"SOGo_msg_%@",
                   [self messageUidString]];
}

- (NSString *) messageViewURL 
{
  // TODO: noframe only when view-target is empty
  // TODO: markread only if the message is unread
  NSString *s;
  
  s = [[self messageUidString] stringByAppendingString:@"/view?noframe=1"];
  if (![self isMessageRead]) s = [s stringByAppendingString:@"&markread=1"];
  return s;
}
- (NSString *) markReadURL 
{
  return [@"markMessageRead?uid=" stringByAppendingString:
	     [self messageUidString]];
}
- (NSString *) markUnreadURL 
{
  return [@"markMessageUnread?uid=" stringByAppendingString:
	     [self messageUidString]];
}

/* JavaScript */

- (NSString *)msgRowID
{
  return [@"row_" stringByAppendingString:[self messageUidString]];
}

- (NSString *)msgDivID
{
  return [@"div_" stringByAppendingString:[self messageUidString]];
}

- (NSString *)msgIconReadImgID
{
  return [@"readdiv_" stringByAppendingString:[self messageUidString]];
}

- (NSString *)msgIconUnreadImgID
{
  return [@"unreaddiv_" stringByAppendingString:[self messageUidString]];
}

/* error redirects */

- (id) redirectToViewWithError: (id) _error 
{
  // TODO: DUP in UIxMailAccountView
  // TODO: improve, localize
  // TODO: there is a bug in the treeview which preserves the current URL for
  //       the active object (displaying the error again)
  id url;
  
  if (![_error isNotNull])
    return [self redirectToLocation:@"view"];
  
  if ([_error isKindOfClass:[NSException class]])
    _error = [_error reason];
  else if ([_error isKindOfClass:[NSString class]])
    _error = [_error stringValue];
  
  url = [_error stringByEscapingURL];
  url = [@"view?error=" stringByAppendingString:url];
  return [self redirectToLocation:url];
}

/* actions */

- (int) firstMessageOfPageFor: (int) messageNbr
{
  NSArray *messageNbrs;
  int nbrInArray;
  int firstMessage;

  messageNbrs = [self sortedUIDs];
  nbrInArray
    = [messageNbrs indexOfObject: [NSNumber numberWithInt: messageNbr]];
  if (nbrInArray > -1)
    firstMessage = ((int) (nbrInArray / messagesPerPage)
                    * messagesPerPage) + 1;
  else
    firstMessage = 1;

  return firstMessage;
}

- (void) _setQualifierForCriteria: (NSString *) criteria
			 andValue: (NSString *) value
{
  [qualifier release];

  if ([criteria isEqualToString: @"subject"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			       @"(subject doesContain: %@)", value];
  else if ([criteria isEqualToString: @"sender"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			       @"(from doesContain: %@)", value];
  else if ([criteria isEqualToString: @"subject_or_sender"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			       @"((subject doesContain: %@)"
			     @" OR (from doesContain: %@))",
			     value, value];
  else if ([criteria isEqualToString: @"to_or_cc"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			       @"((to doesContain: %@)"
			     @" OR (cc doesContain: %@))",
			     value, value];
  else if ([criteria isEqualToString: @"entire_message"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			       @"(body doesContain: %@)", value];
  else
    qualifier = nil;

  [qualifier retain];
}

- (id) defaultAction 
{
  WORequest *request;
  NSString *specificMessage, *searchCriteria, *searchValue;
  SOGoMailFolder *co;

  request = [context request];

  co = [self clientObject];
  [co flushMailCaches];
  [co expungeLastMarkedFolder];

  specificMessage = [request formValueForKey: @"pageforuid"];
  searchCriteria = [request formValueForKey: @"search"];
  searchValue = [request formValueForKey: @"value"];
  if ([searchValue length])
    [self _setQualifierForCriteria: searchCriteria
	  andValue: searchValue];

  firstMessageNumber
    = ((specificMessage)
       ? [self firstMessageOfPageFor: [specificMessage intValue]]
       : [[request formValueForKey:@"idx"] intValue]);

  return self;
}

- (id) getMailAction 
{
  // TODO: we might want to flush the caches?
  id client;

  if ((client = [self clientObject]) == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"did not find mail folder"];
  }

  if (![client respondsToSelector:@selector(flushMailCaches) ]) 
    {
      return [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                          reason:
                            @"invalid client object (does not support flush)"];
    }

  [client flushMailCaches];

  return [self redirectToLocation:@"view"];
}

- (NSString *) msgLabels
{
  NSMutableArray *labels;
  NSEnumerator *flags;
  NSString *currentFlag;

  labels = [NSMutableArray new];
  [labels autorelease];

  flags = [[message objectForKey: @"flags"] objectEnumerator];
  while ((currentFlag = [flags nextObject]))
    if ([currentFlag hasPrefix: @"$label"])
      [labels addObject: [currentFlag substringFromIndex: 1]];

  return [labels componentsJoinedByString: @" "];
}

- (NSDictionary *) columnsMetaData
{
  NSMutableDictionary *columnsMetaData;
  NSArray *tmpColumns, *tmpKeys;

  columnsMetaData = [NSMutableDictionary dictionaryWithCapacity:8];
  
  tmpKeys = [NSArray arrayWithObjects: @"headerClass", @"headerId", @"value",
		     nil];
  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell sortableTableHeader",
	       @"subjectHeader", @"Subject", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
					    forKeys: tmpKeys]
		   forKey: @"Subject"];

  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell messageFlagColumn",
	       @"invisibleHeader", @"Invisible", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
					    forKeys: tmpKeys]
		   forKey: @"Invisible"];

  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell messageFlagColumn",
	       @"attachmentHeader", @"Attachment", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects:
					      tmpColumns
					    forKeys: tmpKeys]
		   forKey: @"Attachment"];

  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell", @"messageFlagHeader",
	       @"Unread", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns forKeys: tmpKeys] forKey: @"Unread"];

  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell sortableTableHeader",
	       @"toHeader", @"To", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns forKeys: tmpKeys] forKey: @"To"];

  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell sortableTableHeader",
	       @"fromHeader", @"From", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
					    forKeys: tmpKeys]
		   forKey: @"From"];
  
  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell sortableTableHeader",
	       @"dateHeader", @"Date", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
					    forKeys: tmpKeys]
		   forKey: @"Date"];
  
  tmpColumns
    = [NSArray arrayWithObjects: @"tbtv_headercell", @"priorityHeader",
	       @"Priority", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
					    forKeys: tmpKeys]
		   forKey: @"Priority"];
  
  return columnsMetaData;
}

- (NSArray *) columnsDisplayOrder
{
  NSMutableArray *userDefinedOrder;
  NSArray *defaultsOrder;
  NSUserDefaults *ud;
  unsigned int i;

  ud = [[context activeUser] userSettings];
  defaultsOrder = [ud arrayForKey: @"SOGoMailListViewColumnsOrder"];
  if (![defaultsOrder count])
    {
      defaultsOrder = [[NSUserDefaults standardUserDefaults]
			arrayForKey: @"SOGoMailListViewColumnsOrder"];
      if (![defaultsOrder count])
	defaultsOrder = [NSArray arrayWithObjects: @"Invisible",
				 @"Attachment", @"Subject", @"From",
				 @"Unread", @"Date", @"Priority", nil];
    }
  userDefinedOrder = [NSMutableArray arrayWithArray: defaultsOrder];

  if ([self showToAddress])
    {
      i = [userDefinedOrder indexOfObject: @"From"];
      if (i != NSNotFound)
	[userDefinedOrder replaceObjectAtIndex: i withObject: @"To"];
    }
  else
    {
      i = [userDefinedOrder indexOfObject: @"To"];
      if (i != NSNotFound)
	[userDefinedOrder replaceObjectAtIndex: i withObject: @"From"];
    }

  return [[self columnsMetaData] objectsForKeys: userDefinedOrder
				 notFoundMarker: @""];
}

- (NSString *) columnTitle
{
  return [self labelForKey: [currentColumn objectForKey: @"value"]];
}

@end

/* UIxMailListView */
