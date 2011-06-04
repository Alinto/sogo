/* SOGoMAPIFSFolder.h - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#ifndef SOGOMAPIFSFOLDER_H
#define SOGOMAPIFSFOLDER_H

#import <SOGo/SOGoFolder.h>

@class NSURL;

@class SOGoMAPIFSMessage;

@interface SOGoMAPIFSFolder : SOGoFolder
{
  NSString *directory;
  BOOL directoryIsSane;
}

+ (id) folderWithURL: (NSURL *) url
	andTableType: (uint8_t) tableType;
- (id) initWithURL: (NSURL *) url
      andTableType: (uint8_t) tableType;

- (NSString *) directory;

- (SOGoMAPIFSMessage *) newMessage;
- (void) ensureDirectory;

- (NSCalendarDate *) creationTime;
- (NSCalendarDate *) lastModificationTime;

@end

#endif /* SOGOMAPIFSFOLDER_H */
