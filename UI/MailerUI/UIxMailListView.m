/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
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
*/

/*
  UIxMailListView
  
  This component represent a list of mails and is attached to an SOGoMailFolder
  object.
*/

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>

#import <EOControl/EOQualifier.h>

#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "UIxMailListView.h"

#define messagesPerPage 50
static int attachmentFlagSize = 8096;

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
  [super dealloc];
}

/* accessors */

- (void) setMessage: (id) _msg
{
  ASSIGN(message, _msg);
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

- (BOOL) showToAddress 
{
  NSString *ftype;
  
  ftype = [[self clientObject] valueForKey:@"outlookFolderClass"];
  return [ftype isEqual:@"IPF.Sent"];
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
  return [self isMessageDeleted]
    ? @"mailer_listcell_deleted"
    : @"mailer_listcell_regular";
}

- (NSString *) messageSubjectCellStyleClass 
{
  return ([self isMessageRead]
	  ? @"mailer_readmailsubject"
	  : @"mailer_unreadmailsubject");
}

- (BOOL) hasMessageAttachment 
{
  /* we detect attachments by size ... */
  unsigned size;
  
  size = [[[self message] valueForKey:@"size"] intValue];
  return size > attachmentFlagSize;
}

/* fetching messages */

- (NSArray *) fetchKeys 
{
  /* Note: see SOGoMailManager.m for allowed IMAP4 keys */
  static NSArray *keys = nil;
  if (keys == nil) {
    keys = [[NSArray alloc] initWithObjects: @"UID",
			      @"FLAGS", @"ENVELOPE", @"RFC822.SIZE", nil];
  }
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
  if (!sortedUIDs)
    {
      sortedUIDs
        = [[self clientObject] fetchUIDsMatchingQualifier: qualifier
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
  NSArray  *uids;
  NSArray  *msgs;
  NSRange  r;
  unsigned len;
  
  if (messages != nil)
    return messages;

  r    = [self fetchBlock];
  uids = [self sortedUIDs];
  if ((len = [uids count]) > r.length)
    /* only need to restrict if we have a lot */
    uids = [uids subarrayWithRange:r];
  
  msgs = [[self clientObject] fetchUIDs: uids parts: [self fetchKeys]];
  messages = [[msgs valueForKey: @"fetch"] retain];

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

/* active message */

- (SOGoMailObject *) lookupActiveMessage 
{
  NSString *uid;
  
  if ((uid = [[context request] formValueForKey: @"uid"]) == nil)
    return nil;

  return [[self clientObject] lookupName: uid
			      inContext: context
			      acquire: NO];
}

/* actions */

- (BOOL) isJavaScriptRequest 
{
  return [[[context request] formValueForKey:@"jsonly"] boolValue];
}

- (id) javaScriptOK 
{
  WOResponse *r;

  r = [context response];
  [r setStatus:200 /* OK */];
  return r;
}

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
			       @"(subject doesContain: %@)",
			     value];
  else if ([criteria isEqualToString: @"sender"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			     @"(from doesContain: %@)",
			     value];
  else if ([criteria isEqualToString: @"subject_or_sender"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			       @"(subject doesContain: %@) OR "
			     @"(from doesContain: %@)",
			     value, value];
  else if ([criteria isEqualToString: @"to_or_cc"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			       @"(to doesContain: %@) OR "
			     @"(cc doesContain: %@)",
			     value, value];
  else if ([criteria isEqualToString: @"entire_message"])
    qualifier = [EOQualifier qualifierWithQualifierFormat:
			     @"(message doesContain: %@)",
			     value];
  else
    qualifier = nil;

  [qualifier retain];
}

- (id) defaultAction 
{
  WORequest *request;
  NSString *specificMessage, *searchCriteria, *searchValue;

  request = [context request];

  [[self clientObject] flushMailCaches];

  specificMessage = [request formValueForKey: @"pageforuid"];
  searchCriteria = [request formValueForKey: @"search"];
  searchValue = [request formValueForKey: @"value"];
  if ([searchCriteria length] > 0
      && [searchValue length] > 0)
    [self _setQualifierForCriteria: searchCriteria
	  andValue: searchValue];

  firstMessageNumber
    = ((specificMessage)
       ? [self firstMessageOfPageFor: [specificMessage intValue]]
       : [[request formValueForKey:@"idx"] intValue]);

  return self;
}

- (id) viewAction 
{
  return [self defaultAction];
}

- (id) markMessageUnreadAction 
{
  NSException *error;
  
  if ((error = [[self lookupActiveMessage] removeFlags:@"seen"]) != nil)
    // TODO: improve error handling
    return error;

  if ([self isJavaScriptRequest])
    return [self javaScriptOK];
  
  return [self redirectToLocation:@"view"];
}

- (id) markMessageReadAction 
{
  NSException *error;
  
  if ((error = [[self lookupActiveMessage] addFlags:@"seen"]) != nil)
    // TODO: improve error handling
    return error;
  
  if ([self isJavaScriptRequest])
    return [self javaScriptOK];
  
  return [self redirectToLocation:@"view"];
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

@end

/* UIxMailListView */
