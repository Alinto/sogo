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
  
#ifndef UIXMAILLISTACTIONS_H
#define UIXMAILLISTACTIONS_H

#import <NGObjWeb/WODirectAction.h>

@class NSDictionary;
@class EOQualifier;
@class SOGoDateFormatter;
@class UIxMailSizeFormatter;

@interface UIxMailListActions : WODirectAction
{
  NSArray *sortedUIDs; /* we always need to retrieve all anyway! */
  NSArray *messages;
  id message;
  SOGoDateFormatter *dateFormatter;
  NSTimeZone *userTimeZone;
  UIxMailSizeFormatter *sizeFormatter;
  BOOL sortByThread;
  int folderType;
  int specificMessageNumber;
}

- (NSString *) defaultSortKey;
- (NSString *) imap4SortKey;
- (NSString *) imap4SortOrdering;
- (EOQualifier *) searchQualifier;
- (NSString *) msgLabels;

- (NSArray *) getSortedUIDsInFolder: (SOGoMailFolder *) mailFolder;
- (NSArray *) getHeadersForUIDs: (NSArray *) uids
		       inFolder: (SOGoMailFolder *) mailFolder;
- (NSDictionary *) getUIDsInFolder: (SOGoMailFolder *) folder
                       withHeaders: (BOOL) includeHeaders;

- (id <WOActionResults>) getUIDsAction;
- (id <WOActionResults>) getHeadersAction;

@end

#endif /* UIXMAILLISTACTIONS_H */
