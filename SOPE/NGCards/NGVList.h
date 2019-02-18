/* NGVList.h - this file is part of NGCards
 *
 * Copyright (C) 2008-2019 Inverse inc.
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

#ifndef NGVLIST_H
#define NGVLIST_H


#import "NGVCard.h"

@class NSArray;
@class NSDictionary;
@class NSString;

@class NGVCardReference;

@interface NGVList : CardGroup

+ (id) listWithUid: (NSString *) newUid;
- (id) initWithUid: (NSString *) newUid;

/* accessors */

- (void) setProdID: (NSString *) newProdID;
- (NSString *) prodID;
- (void) setVersion: (NSString *) newVersion;
- (NSString *) version;

- (void) setUid: (NSString *) newUid;
- (NSString *) uid;

- (void) setAccessClass: (NSString *) newAccessClass;
- (NSString *) accessClass;
- (NGCardsAccessClass) symbolicAccessClass;
- (BOOL) isPublic;

- (void) setFn: (NSString *) newFn;
- (NSString *) fn;
- (void) setNickname: (NSString *) newNickname;
- (NSString *) nickname;
- (void) setDescription: (NSString *) newDescription;
- (NSString *) description;

- (void) addCardReference: (NGVCardReference *) newCardRef;
- (void) deleteCardReference: (NGVCardReference *) cardRef;
- (NSArray *) cardReferences;

@end

#endif /* NGVLIST_H */
