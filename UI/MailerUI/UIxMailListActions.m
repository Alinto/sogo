/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2011 Inverse inc.

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
  UIxMailListActions
  
  This component represent a list of mails and is attached to an SOGoMailFolder
  object.
*/

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGImap4/NGImap4Envelope.h>

#import <EOControl/EOQualifier.h>

#import <Mailer/NSString+Mail.h>
#import <Mailer/SOGoDraftsFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoSentFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import "WOContext+UIxMailer.h"
#import "UIxMailFormatter.h"

#import "UIxMailListActions.h"

// The maximum number of headers to prefetch when querying the UIDs list
#define headersPrefetchMaxSize 100

@implementation UIxMailListActions

- (id) initWithRequest: (WORequest *) newRequest
{
  SOGoUser *user;

  if ((self = [super initWithRequest: newRequest]))
    {
      user = [[self context] activeUser];
      ASSIGN (dateFormatter, [user dateFormatterInContext: context]);
      ASSIGN (userTimeZone, [[user userDefaults] timeZone]);
      sortByThread = [[user userDefaults] mailSortByThreads];
      folderType = 0;
      specificMessageNumber = 0;
    }

  return self;
}

- (void) dealloc 
{
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

- (NSString *) messageSize
{
  NSString *rc;
  int size;

  size = [[message valueForKey: @"size"] intValue];
  if (size > 1024*1024)
    rc = [NSString stringWithFormat: @"%.1f MB", (float) size/1024/1024];
  else if (size > 1024*100)
    rc = [NSString stringWithFormat: @"%d KB", size/1024];    
  else
    rc = [NSString stringWithFormat: @"%.1f KB", (float) size/1024];
  
  return rc;
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
  subject = [baseSubject decodedHeader];
  if (![subject length])
    subject = @"";

  return [subject stringByEscapingHTMLString];
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

- (BOOL) isMessageFlagged
{
  NSArray *flags;
  
  flags = [[self message] valueForKey:@"flags"];
  return [flags containsObject:@"flagged"];
}

- (NSString *) messageUidString 
{
  return [[[self message] valueForKey:@"uid"] stringValue];
}

- (NSString *) messageRowStyleClass 
{
  NSArray *flags;
  NSString *cellClass = @"";

  flags = [[self message] valueForKey:@"flags"];

  if ([self isMessageDeleted])
    cellClass = [cellClass stringByAppendingString: @"mailer_listcell_deleted "];

  if (![self isMessageRead])
    cellClass = [cellClass stringByAppendingString: @"mailer_unreadmail "];
  
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

  parts = [[message objectForKey: @"bodystructure"] objectForKey: @"parts"];
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

  return [sort uppercaseString];
}

- (NSString *) imap4SortOrdering 
{
  NSString *sort, *ascending;
  NSString *module;
  NSMutableDictionary *moduleSettings;
  BOOL asc;
  SOGoUser *activeUser;
  SOGoUserSettings *us;

  sort = [self imap4SortKey];
  ascending = [[context request] formValueForKey: @"asc"];
  asc = [ascending boolValue];

  activeUser = [context activeUser];
  module = @"Mail";
  us = [activeUser userSettings];
  moduleSettings = [us objectForKey: module];

  if ([sort length])
    {
      if ([sort isEqualToString: [self defaultSortKey]] && !asc)
	{
	  if (moduleSettings)
	    {
	      [moduleSettings removeObjectForKey: @"SortingState"];
	      [us synchronize];
	    }
	}
      else
	{
	  // Save the sorting state in the user settings
	  if (!moduleSettings)
	    {
	      moduleSettings = [NSMutableDictionary dictionary];
	      [us setObject: moduleSettings forKey: module];
	    }
	  [moduleSettings setObject: [NSArray arrayWithObjects: [sort lowercaseString], [NSString stringWithFormat: @"%d", (asc?1:0)], nil]
			     forKey: @"SortingState"];
	  [us synchronize];
	}
    }
  else if (moduleSettings)
    {
      NSArray *sortState = [moduleSettings objectForKey: @"SortingState"];
      if ([sortState count])
	{
	  sort = [[sortState objectAtIndex: 0] uppercaseString];
	  asc = [[sortState objectAtIndex: 1] boolValue];
	}
    }
  if (![sort length])
    sort = [self defaultSortKey];
  
  // Construct and return the final IMAP ordering constraint
  if (!asc)
    sort = [@"REVERSE " stringByAppendingString: sort];

  return sort;
}

- (EOQualifier *) searchQualifier
{
  NSString *criteria, *value;
  EOQualifier *qualifier;
  WORequest *request;  

  request = [context request];
  criteria = [request formValueForKey: @"search"];
  value = [request formValueForKey: @"value"];
  qualifier = nil;
  if ([value length])
    {
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
    }
  
  return qualifier;
}

- (NSArray *) getSortedUIDsInFolder: (SOGoMailFolder *) mailFolder
{
  EOQualifier *qualifier, *fetchQualifier, *notDeleted;

  if (!sortedUIDs)
    {
      notDeleted = [EOQualifier qualifierWithQualifierFormat:
				  @"(not (flags = %@))",
				@"deleted"];
      qualifier = [self searchQualifier];
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
        = [mailFolder fetchUIDsMatchingQualifier: fetchQualifier
				    sortOrdering: [self imap4SortOrdering]
                                        threaded: sortByThread];

      [sortedUIDs retain];
    }

  return sortedUIDs;
}

/**
 * Returns a flatten representation of the messages threads as triples of 
 * metadata, including the message UID, thread level and root position.
 * @param _sortedUIDs the interleaved arrays representation of the messages UIDs
 * @return an flatten array representation of the messages UIDs
 */
- (NSArray *) threadedUIDs: (NSArray *) _sortedUIDs
{
  NSMutableArray *threads;
  NSMutableArray *currentThreads;
  NSEnumerator *rootThreads;
  id thread;
  int count;
  int i;
  BOOL first;
  BOOL expected;
  int previousLevel;

  count = 0;
  i = 0;
  previousLevel = 0;
  expected = YES;
  threads = [NSMutableArray arrayWithObject: [NSArray arrayWithObjects: @"uid", @"level", @"first", nil]];
  rootThreads  = [_sortedUIDs objectEnumerator];
  thread = [rootThreads nextObject];

  // Make sure rootThreads starts with an NSArray
  if (![thread respondsToSelector: @selector(objectEnumerator)])
    return nil;

  first = [thread count] > 1;
  thread = [thread objectEnumerator];

  currentThreads = [NSMutableArray array];

  while (thread)
    {
      unsigned int ecount = 0;
      id t;

      if ([thread isKindOfClass: [NSEnumerator class]])
        {
          t = [thread nextObject];
        }
      else
        t = thread; // never happen?
      while (t && ![t isKindOfClass: [NSArray class]])
        {
          BOOL currentFirst;
          int currentLevel;
          NSArray *currentThread;

          currentFirst = (first && ecount == 0) || (i == 0  && count > 0) || (count > 0 && previousLevel < 0);
          currentLevel = (first && ecount == 0)? 0 : (count > 0? count : -1);
          currentThread = [NSArray arrayWithObjects: t,
                            [NSNumber numberWithInt: currentLevel],
                            [NSNumber numberWithInt: currentFirst], nil];
          [threads addObject: currentThread];
          i++;
          count++;
          ecount++;
          expected = NO;
          previousLevel = currentLevel;
          t = [thread nextObject];
        }
      if (t)
        {
          // If t is defined, it has to be an NSArray
          if (expected)
            {
              count++;
              expected = NO;
            }
          thread = [thread allObjects];
          if ([thread count] > 0)
            [currentThreads addObject: [thread objectEnumerator]];
          thread = [t objectEnumerator];
        }
      else if ([currentThreads count] > 0)
        {
          thread = [currentThreads objectAtIndex: 0];
          [currentThreads removeObjectAtIndex: 0];
          count -= ecount;
        }
      else
        {
          thread = [[rootThreads nextObject] objectEnumerator]; // assume all objects of rootThreads are NSArrays
          count = 0;
          expected = YES;
        }

      // Prepare next iteration
      thread = [thread allObjects];
      first = !first && (thread != nil) && [thread count] > 1;
      thread = [thread objectEnumerator];
    }

  return threads;
}

- (int) indexOfMessageUID: (int) messageNbr
{
  NSArray *messageNbrs;
  int index;

  messageNbrs = [self getSortedUIDsInFolder: [self clientObject]];
  index
    = [messageNbrs indexOfObject: [NSNumber numberWithInt: messageNbr]];
//   if (index < 0)
//     index = 0;

  return index;
}

/* JavaScript */

- (NSString *) msgRowID
{
  return [@"row_" stringByAppendingString:[self messageUidString]];
}

- (NSString *) msgIconReadImgID
{
  return [@"readdiv_" stringByAppendingString:[self messageUidString]];
}

- (NSString *) msgIconUnreadImgID
{
  return [@"unreaddiv_" stringByAppendingString:[self messageUidString]];
}

/* error redirects */

/*
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
*/

- (NSDictionary *) getUIDsInFolder: (SOGoMailFolder *) folder
                       withHeaders: (BOOL) includeHeaders
{
  NSMutableDictionary *data;
  NSArray *uids, *threadedUids, *headers;
  NSRange r;
  SOGoMailAccount *account;
  id quota;
  int count;

  data = [NSMutableDictionary dictionary];
  
  // TODO: we might want to flush the caches?
  //[folder flushMailCaches];
  [folder expungeLastMarkedFolder];

  // Retrieve messages UIDs using form parameters "sort" and "asc"
  uids = [self getSortedUIDsInFolder: folder];

  if (includeHeaders)
    {
      // Also retrieve the first headers, up to 'headersPrefetchMaxSize'
      count = [uids count];
      if (count > headersPrefetchMaxSize) count = headersPrefetchMaxSize;
      r = NSMakeRange(0, count);
      headers = [self getHeadersForUIDs: [[uids flattenedArray] subarrayWithRange: r]
                               inFolder: folder];

      [data setObject: headers forKey: @"headers"];
    }

  if (sortByThread)
    {
      // Add threads information
      threadedUids = [self threadedUIDs: uids];
      if (threadedUids != nil)
        uids = threadedUids;
      else
        sortByThread = NO;
    }
  if (uids != nil)
    [data setObject: uids forKey: @"uids"];
  [data setObject: [NSNumber numberWithBool: sortByThread] forKey: @"threaded"];

  // We also return the inbox quota
  account = [folder mailAccountFolder];
  quota = [account getInboxQuota];
  if (quota != nil)
    [data setObject: quota forKey: @"quotas"];

  return data;
}

/* Module actions */

- (id <WOActionResults>) getUIDsAction
{
  NSDictionary *data;
  NSString *noHeaders;
  SOGoMailFolder *folder;
  WORequest *request;
  WOResponse *response;

  request = [context request];
  response = [context response];
  [response setHeader: @"text/plain; charset=utf-8"
	       forKey: @"content-type"];
  folder = [self clientObject];
  
  noHeaders = [request formValueForKey: @"no_headers"];
  data = [self getUIDsInFolder: folder
                   withHeaders: ([noHeaders length] == 0)];

  [response appendContentString: [data jsonRepresentation]];

  return response;
}

- (NSArray *) getHeadersForUIDs: (NSArray *) uids
		       inFolder: (SOGoMailFolder *) mailFolder
{
  NSArray *to, *from;
  NSDictionary *msgs;
  NSMutableArray *headers, *msg;
  NSEnumerator *msgsList;
  NSString *msgIconStatus, *msgDate;
  UIxEnvelopeAddressFormatter *addressFormatter;
  
  headers = [NSMutableArray arrayWithCapacity: [uids count]];
  addressFormatter = [context mailEnvelopeAddressFormatter];
  
  // Fetch headers
  msgs = (NSDictionary *)[mailFolder fetchUIDs: uids
					 parts: [self fetchKeys]];

  msgsList = [[msgs objectForKey: @"fetch"] objectEnumerator];
  [self setMessage: [msgsList nextObject]];

  msg = [NSMutableArray arrayWithObjects: @"To", @"Attachment", @"Flagged", @"Subject", @"From", @"Unread", @"Priority", @"Date", @"Size", @"rowClasses", @"labels", @"rowID", @"uid", nil];
  [headers addObject: msg];
  while (message)
    {
      // We must check for "umimportant" untagged responses.
      //
      // It's generally caused by IMAP server processes sending untagged IMAP responses to SOGo in differnent IMAP
      // connections (SOGo might use 2-3 per user). Say you ask your messages:
      //
      // 127.000.000.001.40725-127.000.000.001.00143: 59 uid fetch 62 (UID FLAGS ENVELOPE RFC822.SIZE BODYSTRUCTURE BODY.PEEK[HEADER.FIELDS (X-PRIORITY)])
      // 127.000.000.001.00143-127.000.000.001.40725: * 62 FETCH (UID 62 FLAGS (\Seen) RFC822.SIZE 854 ENVELOPE  .... (
      // * 61 FETCH (FLAGS (\Deleted \Seen))
      // * 62 FETCH (FLAGS (\Deleted \Seen))
      // * 63 FETCH (FLAGS (\Deleted \Seen))
      // 59 OK Fetch completed.
      //
      // We must ignore the * 61 .. * 63 untagged responses.
      //
      if (![message objectForKey: @"uid"])
	{
	  [self setMessage: [msgsList nextObject]];
	  continue;
	}

      msg = [NSMutableArray arrayWithCapacity: 12];

      // Columns data

      // To
      to = [[message objectForKey: @"envelope"] to];
      if ([to count] > 0)
	[msg addObject: [addressFormatter stringForArray: to]];
      else
	[msg addObject: @""];

      // Attachment
      if ([self hasMessageAttachment])
	[msg addObject: [NSString stringWithFormat: @"<img src=\"%@\"/>", [self urlForResourceFilename: @"title_attachment_14x14.png"]]];
      else
	[msg addObject: @""];

      // Flagged
      if ([self isMessageFlagged])
	[msg addObject: [NSString stringWithFormat: @"<img src=\"%@\" class=\"messageIsFlagged\">",
				  [self urlForResourceFilename: @"flag.png"]]];
      else
	[msg addObject: [NSString stringWithFormat: @"<img src=\"%@\">",
				  [self urlForResourceFilename: @"dot.png"]]];

      // Subject
      [msg addObject: [NSString stringWithFormat: @"<span>%@</span>",
				[self messageSubject]]];
      
      // From
      from = [[message objectForKey: @"envelope"] from];
      if ([from count] > 0)
	[msg addObject: [addressFormatter stringForArray: from]];
      else
	[msg addObject: @""];
      

      // Unread
      if ([self isMessageRead])
	msgIconStatus = @"dot.png";
      else
	msgIconStatus = @"unread.png";
      
      [msg addObject: [NSString stringWithFormat: @"<img src=\"%@\" class=\"mailerReadIcon\" title=\"%@\" title-markread=\"%@\" title-markunread=\"%@\" id=\"%@\"/>",
				[self urlForResourceFilename: msgIconStatus],
 			       [self labelForKey: @"Mark Unread"],
 			       [self labelForKey: @"Mark Read"],
 			       [self labelForKey: @"Mark Unread"],
 				[self msgIconReadImgID]]];
      
      // Priority
      [msg addObject: [self messagePriority]];

      // Date
      msgDate = [self messageDate];
      if (msgDate == nil)
	msgDate = @"";
      [msg addObject: msgDate];

      // Size
      [msg addObject: [self messageSize]];
      
      // rowClasses
      [msg addObject: [self messageRowStyleClass]];

      // labels
      [msg addObject: [self msgLabels]];

      // rowID
      [msg addObject: [self msgRowID]];

      // uid
      [msg addObject: [message objectForKey: @"uid"]];
      [headers addObject: msg];
      
      [self setMessage: [msgsList nextObject]];
    }

  return headers;
}

- (id <WOActionResults>) getHeadersAction
{
  NSArray *uids, *headers;
  WORequest *request;
  WOResponse *response;

  request = [context request];
  if ([request formValueForKey: @"uids"] == nil)
    {
      return [NSException exceptionWithHTTPStatus: 404
					   reason: @"No UID specified"];
    }

  uids = [[request formValueForKey: @"uids"] componentsSeparatedByString: @","]; // Should we support ranges? ie "x-y"
  headers = [self getHeadersForUIDs: uids
			   inFolder: [self clientObject]];
  response = [context response];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [headers jsonRepresentation]];

  return response;
}

- (NSString *) msgLabels
{
  NSMutableArray *labels;
  NSEnumerator *flags;
  NSString *currentFlag;

  labels = [NSMutableArray array];

  flags = [[message objectForKey: @"flags"] objectEnumerator];
  while ((currentFlag = [flags nextObject]))
    if ([currentFlag hasPrefix: @"$label"])
      [labels addObject: [currentFlag substringFromIndex: 1]];
  
  return [labels componentsJoinedByString: @" "];
}

@end

/* UIxMailListActions */
