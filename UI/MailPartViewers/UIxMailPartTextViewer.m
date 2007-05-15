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

/*
  UIxMailPartTextViewer

  Show plaintext mail parts correctly formatted.

  TODO: add server side wrapping.
  TODO: add contained link detection.
*/

#import <SoObjects/SOGo/NSString+Utilities.h>

#import "common.h"

#import "UIxMailPartTextViewer.h"

@implementation UIxMailPartTextViewer

- (NSString *) flatContentAsString
{
  NSMutableString *content;
  NSString *superContent, *urlText, *newUrlText;
  NSRange httpRange, rest, currentURL;
  unsigned int length;

  content = [NSMutableString string];
  superContent = [[super flatContentAsString] stringByEscapingHTMLString];
  [content appendString: [superContent stringByDetectingURLs]];
  [content replaceString: @"\r\n" withString: @"<br />"];
  [content replaceString: @"\n" withString: @"<br />"];

  return content;
}

@end /* UIxMailPartTextViewer */
