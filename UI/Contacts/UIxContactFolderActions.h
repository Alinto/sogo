/*
 Copyright (C) 2006-2016 Inverse inc.

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

#ifndef __UIxContactFolderActions_H__
#define __UIxContactFolderActions_H__

#import <SOGoUI/UIxComponent.h>

@class NSDictionary;
@class NSString;

@protocol SOGoContactObject;

@interface UIxContactFolderActions : UIxComponent

- (int) importLdifData: (NSString *) ldifData;
- (int) importVcardData: (NSString *) vcardData;
- (BOOL) importVcard: (NGVCard *) card;

@end

#endif /* __UIxContactFolderActions_H__ */
