/*
  Copyright (C) 2005-2015 Inverse inc.

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
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef UIXCONTACTVIEW_H
#define UIXCONTACTVIEW_H

#import <SOGoUI/UIxComponent.h>

@class NGVCard;

@interface UIxContactView : UIxComponent
{
  NGVCard *card;
}

- (NSString *) photoURL;

@end

#endif /* UIXCONTACTVIEW_H */
