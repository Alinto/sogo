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

#define messagesPerPage 50

#include "common.h"
#include <SoObjects/Mailer/SOGoMailFolder.h>
#include <SoObjects/Mailer/SOGoMailObject.h>
#include <NGObjWeb/SoObject+SoDAV.h>

#import "UIxMailListView.h"

static int attachmentFlagSize = 8096;

@implementation UIxMailListView


- (void) dealloc 
{
  [self->qualifier  release];
  [self->sortedUIDs release];
  [self->messages   release];
  [self->message    release];
  [super dealloc];
}

/* notifications */

- (void) sleep 
{
  [self->qualifier  release]; self->qualifier  = nil;
  [self->sortedUIDs release]; self->sortedUIDs = nil;
  [self->messages   release]; self->messages   = nil;
  [self->message    release]; self->message    = nil;
  [super sleep];
}

/* accessors */

- (void)setMessage:(id)_msg
{
  ASSIGN(self->message, _msg);
}

- (id) message 
{
  return self->message;
}

- (void) setQualifier: (EOQualifier *) _msg 
{
  ASSIGN(self->qualifier, _msg);
}

- (EOQualifier *) qualifier 
{
  return self->qualifier;
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

- (NSString *) messageCellStyleClass 
{
  return [self isMessageDeleted]
    ? @"mailer_listcell_deleted"
    : @"mailer_listcell_regular";
}

- (NSString *) messageSubjectCellStyleClass 
{
  return [NSString stringWithFormat: @"%@ %@",
		   [self messageCellStyleClass],
		   ([self isMessageRead]
		    ? @"mailer_readmailsubject"
		    : @"mailer_unreadmailsubject")];
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
    keys = [[NSArray alloc] initWithObjects:
			      @"FLAGS", @"ENVELOPE", @"RFC822.SIZE", nil];
  }
  return keys;
}

- (NSString *) defaultSortKey 
{
  return @"DATE";
}

- (NSString *) imap4SortKey 
{
  NSString *sort;
  
  sort = [[[self context] request] formValueForKey:@"sort"];
  
  if ([sort length] == 0)
    sort = [self defaultSortKey];
  return [sort uppercaseString];
}

- (BOOL) isSortedDescending 
{
  NSString *desc;
  
  desc = [[[self context] request] formValueForKey:@"desc"];
  if(!desc)
    return NO;
  return [desc boolValue] ? YES : NO;
}

- (NSString *) imap4SortOrdering 
{
  NSString *sort;
  
  sort = [self imap4SortKey];
  if(![self isSortedDescending])
    return sort;
  return [@"REVERSE " stringByAppendingString:sort];
}

- (NSRange) fetchRange 
{
  if (self->firstMessageNumber == 0)
    return NSMakeRange(0, messagesPerPage);
  return NSMakeRange(self->firstMessageNumber - 1, messagesPerPage);
}

- (NSArray *) sortedUIDs 
{
  if (self->sortedUIDs != nil)
    return self->sortedUIDs;
  
  self->sortedUIDs 
    = [[[self clientObject] fetchUIDsMatchingQualifier:[self qualifier]
			    sortOrdering:[self imap4SortOrdering]] retain];

  return self->sortedUIDs;
}

- (unsigned int) totalMessageCount 
{
  return [self->sortedUIDs count];
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
  
  if (self->messages != nil)
    return self->messages;
  
  r    = [self fetchBlock];
  uids = [self sortedUIDs];
  if ((len = [uids count]) > r.length)
    /* only need to restrict if we have a lot */
    uids = [uids subarrayWithRange:r];
  
  msgs = [[self clientObject] fetchUIDs:uids parts:[self fetchKeys]];
  self->messages = [[msgs valueForKey:@"fetch"] retain];
  return self->messages;
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

- (NSString *) clickedMsgJS 
{
  /* return 'false' aborts processing */
  return [NSString stringWithFormat:@"clickedUid(this, '%@'); return false", 
		     [self messageUidString]];
}

// the following are unused?
- (NSString *) dblClickedMsgJS 
{
  return [NSString stringWithFormat:@"doubleClickedUid(this, '%@')", 
		     [self messageUidString]];
}

// the following are unused?
- (NSString *) highlightRowJS 
{
  return [NSString stringWithFormat:@"highlightUid(this, '%@')", 
		     [self messageUidString]];
}
- (NSString *) lowlightRowJS 
{
  return [NSString stringWithFormat:@"lowlightUid(this, '%@')", 
		     [self messageUidString]];
}

- (NSString *) markUnreadJS 
{
  return [NSString stringWithFormat:
		     @"mailListMarkMessage(this, 'markMessageUnread', "
		     @"'%@', false)", 
		     [self messageUidString]];
}
- (NSString *) markReadJS 
{
  return [NSString stringWithFormat:
		     @"mailListMarkMessage(this, 'markMessageRead', "
		     @"'%@', true)", 
		     [self messageUidString]];
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
  
  if ((uid = [[[self context] request] formValueForKey:@"uid"]) == nil)
    return nil;

  return [[self clientObject] lookupName:uid inContext:[self context]
			      acquire:NO];
}

/* actions */

- (BOOL) isJavaScriptRequest 
{
  return [[[[self context] request] formValueForKey:@"jsonly"] boolValue];
}

- (id) javaScriptOK 
{
  WOResponse *r;

  r = [[self context] response];
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

- (id) defaultAction 
{
  WORequest *request;
  NSValue *specificMessage;

  request = [[self context] request];
  specificMessage = [request formValueForKey: @"pageforuid"];
  self->firstMessageNumber
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

- (id) expungeAction 
{
  // TODO: we might want to flush the caches?
  NSException *error;
  id client;
  
  if ((client = [self clientObject]) == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"did not find mail folder"];
  }
  
  if ((error = [[self clientObject] expunge]) != nil)
    return error;
  
  if ([client respondsToSelector:@selector(flushMailCaches)])
    [client flushMailCaches];
  return [self redirectToLocation:@"view"];
}

- (id) emptyTrashAction 
{
  // TODO: we might want to flush the caches?
  NSException *error;
  id client;
  
  if ((client = [self clientObject]) == nil) {
    error = [NSException exceptionWithHTTPStatus:404 /* Not Found */
			 reason:@"did not find mail folder"];
    return [self redirectToViewWithError:error];
  }

  if (![client isKindOfClass:NSClassFromString(@"SOGoTrashFolder")]) {
    /* would be better to move the method to an own class, but well .. */
    error = [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			 reason:@"method cannot be invoked on "
                                @"the specified object"];
    return [self redirectToViewWithError:error];
  }
  
  /* mark all as deleted */

  [self logWithFormat:@"TODO: must mark all as deleted for empty-trash"];
  
  error = [[self clientObject] addFlagsToAllMessages:@"deleted"];
  if (error != nil)
    // TODO: improve error
    return [self redirectToViewWithError:error];
  
  /* expunge */
  
  if ((error = [[self clientObject] expunge]) != nil)
    // TODO: improve error
    return [self redirectToViewWithError:error];
  
  if ([client respondsToSelector:@selector(flushMailCaches)])
    [client flushMailCaches];
  return [self redirectToLocation:@"view"];
}

/* folder operations */

- (id) createFolderAction 
{
  NSException *error;
  NSString    *folderName;
  id client;
  
  folderName = [[[self context] request] formValueForKey:@"name"];
  if ([folderName length] == 0) {
    error = [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			 reason:@"missing 'name' query parameter!"];
    return [self redirectToViewWithError:error];
  }
  
  if ((client = [self clientObject]) == nil) {
    error = [NSException exceptionWithHTTPStatus:404 /* Not Found */
			 reason:@"did not find mail folder"];
    return [self redirectToViewWithError:error];
  }
  
  if ((error = [[self clientObject] davCreateCollection:folderName
				    inContext:[self context]]) != nil) {
    return [self redirectToViewWithError:error];
  }
  
  return [self redirectToLocation:[folderName stringByAppendingString:@"/"]];
}

- (id) deleteFolderAction 
{
  NSException *error;
  NSString *url;
  id client;
  
  if ((client = [self clientObject]) == nil) {
    error = [NSException exceptionWithHTTPStatus:404 /* Not Found */
			 reason:@"did not find mail folder"];
    return [self redirectToViewWithError:error];
  }
  
  /* jump to parent folder afterwards */
  url = [[client container] baseURLInContext:[self context]];
  if (![url hasSuffix:@"/"]) url = [url stringByAppendingString:@"/"];
  
  if ((error = [[self clientObject] delete]) != nil)
    return [self redirectToViewWithError:error];
  
  return [self redirectToLocation:url];
}

@end

/* UIxMailListView */
