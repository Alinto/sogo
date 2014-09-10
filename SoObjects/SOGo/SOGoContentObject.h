/*
  Copyright (C) 2004 SKYRIX Software AG
  Copyright (C) 2005-2014 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __SOGo_SOGoContentObject_H__
#define __SOGo_SOGoContentObject_H__

#import <SOGo/SOGoObject.h>

@class NSArray;
@class NSCalendarDate;
@class NSException;
@class NSString;
@class SOGoGCSFolder;
@class WOContext;

@interface SOGoContentObject : SOGoObject
{
  BOOL isNew;
  NSString *content;
  unsigned int version;
  NSCalendarDate *creationDate;
  NSCalendarDate *lastModified;
}

+ (id) objectWithRecord: (NSDictionary *) objectRecord
	    inContainer: (SOGoGCSFolder *) newContainer;
+ (id) objectWithName: (NSString *) newName
	   andContent: (NSString *) newContent
	  inContainer: (SOGoGCSFolder *) newContainer;
- (id) initWithRecord: (NSDictionary *) objectRecord
	  inContainer: (SOGoGCSFolder *) newContainer;
- (id) initWithName: (NSString *) newName
	 andContent: (NSString *) newContent
	inContainer: (SOGoGCSFolder *) newContainer;
- (Class *) parsingClass;

/* content */

- (BOOL) isNew;
- (void) setIsNew: (BOOL) newIsNew;

- (unsigned int) version;

- (NSCalendarDate *) creationDate;
- (NSCalendarDate *) lastModified;

- (NSString *) contentAsString;
- (NSException *) saveComponent: (id) theComponent
                    baseVersion: (unsigned int) _baseVersion;
- (NSException *) saveComponent: (id) theComponent;

- (id) PUTAction: (WOContext *) _ctx;

/* actions */
- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder;
- (NSException *) moveToFolder: (SOGoGCSFolder *) newFolder;
- (NSException *) delete;

/* DAV support */

- (id) davEntityTag;
- (NSString *) davCreationDate;
- (NSString *) davLastModified;
- (NSString *) davContentLength;

@end

@interface SOGoContentObject (OptionalMethods)

- (NSException *) prepareDelete;

@end

#endif /* __SOGo_SOGoContentObject_H__ */
