/* MAPIStoreMailFolderTable.m - this file is part of SOGo
 *
 * Copyright (C) 2015 Enrique J. Hernández
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

#import <Foundation/NSString.h>

#import "MAPIStoreMailFolderTable.h"
#import "MAPIStoreTypes.h"

@implementation MAPIStoreMailFolderTable

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  switch(property)
    {
    case PR_DISPLAY_NAME:
    case PR_DISPLAY_NAME_UNICODE:
      return @"name";
    default:
      return nil;
    }
}


@end

