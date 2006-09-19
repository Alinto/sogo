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

#include "UIxMailPartViewer.h"

/*
  UIxMailPartTextViewer

  Show plain/text mail parts in a <pre> section.
  
  TODO: add server side wrapping.
  TODO: add contained link detection.
*/

@interface UIxMailPartTextViewer : UIxMailPartViewer
{
}

@end

#include "common.h"

@implementation UIxMailPartTextViewer

- (NSString *)flatContentAsString
{
  NSString *content;

  content = [[super flatContentAsString] stringByEscapingHTMLString];
  content = [content stringByReplacingString: @"\r\n"
                     withString: @"<br />"];

  return [content stringByReplacingString: @"\n"
                  withString: @"<br />"];
}

@end /* UIxMailPartTextViewer */
