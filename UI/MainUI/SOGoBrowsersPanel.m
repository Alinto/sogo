/* SOGoBrowsersPanel.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <NGObjWeb/WEClientCapabilities.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>

#import "SOGoBrowsersPanel.h"

@implementation SOGoBrowsersPanel

- (BOOL) isIE7Compatible
{
  WEClientCapabilities *cc;

  cc = [[context request] clientCapabilities];
  
  return ([cc isWindowsBrowser] &&
	  ([[cc userAgent] rangeOfString: @"NT 5.1"].location != NSNotFound ||
	   [[cc userAgent] rangeOfString: @"NT 6"].location != NSNotFound));
}

- (BOOL) isMac
{
  WEClientCapabilities *cc;

  cc = [[context request] clientCapabilities];

  return [cc isMacBrowser];
}

@end
