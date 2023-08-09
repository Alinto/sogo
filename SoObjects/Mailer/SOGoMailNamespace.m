/* SOGoMailNamespace.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2022 Inverse inc.
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

#import <SOGo/NSString+Utilities.h>

#import "SOGoMailAccount.h"

#import "SOGoMailNamespace.h"

@implementation SOGoMailNamespace

- (id) lookupName: (NSString *) _key
	inContext: (id)_ctx
	  acquire: (BOOL) _acquire
{
  NSString *folderName, *fullFolderName, *className;
  SOGoMailAccount *mailAccount;
  id obj;

  if ([_key hasPrefix: @"folder"])
    {
      mailAccount = [self mailAccountFolder];
      folderName = [[_key substringFromIndex: 6] fromCSSIdentifier];
      fullFolderName = [NSString stringWithFormat: @"%@/%@",
                                 [self traversalFromMailAccount], folderName];
      if ([fullFolderName isEqualToString: [mailAccount sentFolderNameInContext: _ctx]])
        className = @"SOGoSentFolder";
      else if ([fullFolderName isEqualToString: [mailAccount draftsFolderNameInContext: _ctx]])
        className = @"SOGoDraftsFolder";
      else if ([fullFolderName isEqualToString: [mailAccount trashFolderNameInContext: _ctx]])
        className = @"SOGoTrashFolder";
      else if ([fullFolderName isEqualToString: [mailAccount junkFolderNameInContext: _ctx]])
        className = @"SOGoJunkFolder";
      else if ([fullFolderName isEqualToString: [mailAccount templatesFolderNameInContext: _ctx]])
        className = @"SOGoTemplatesFolder";
      /*       else if ([folderName isEqualToString:
               [mailAccount sieveFolderNameInContext: _ctx]])
               obj = [self lookupFiltersFolder: _key inContext: _ctx]; */
      else
        className = @"SOGoMailFolder";

      obj = [NSClassFromString (className) objectWithName: _key
                                              inContainer: self];
    }
  else
    obj = [super lookupName: _key inContext: _ctx acquire: NO];

  return obj;
}

@end
