/* SOGoContactSourceFolder.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2016 Inverse inc.
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

#ifndef SOGOCONTACTSOURCEFOLDER_H
#define SOGOCONTACTSOURCEFOLDER_H

#import "SOGoFolder+CardDAV.h"

#import <SOGo/SOGoSource.h>

@class NSMutableDictionary;
@class SOGoContactLDIFEntry;

@interface SOGoContactSourceFolder : SOGoFolder <SOGoContactFolder>
{
  id <SOGoSource> source;
  NSMutableDictionary *childRecords;
  BOOL isPersonalSource;
}

+ (id) folderWithName: (NSString *) aName
       andDisplayName: (NSString *) aDisplayName
	  inContainer: (id) aContainer;
- (id) initWithName: (NSString *) newName
     andDisplayName: (NSString *) newDisplayName
	inContainer: (id) newContainer;
- (void) setSource: (id <SOGoSource>) newSource;

- (NSException *) saveLDIFEntry: (SOGoContactLDIFEntry *) ldifEntry;
- (NSException *) deleteLDIFEntry: (SOGoContactLDIFEntry *) ldifEntry;

- (void) setIsPersonalSource: (BOOL) isPersonal;
- (BOOL) isPersonalSource;

- (BOOL) listRequiresDot;

@end


#endif /* SOGOCONTACTSOURCEFOLDER_H */
