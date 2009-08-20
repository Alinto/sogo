/* UIxDatePicker.h - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
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

#ifndef UIXDATEPICKER_H
#define UIXDATEPICKER_H

#import <NGObjWeb/WOComponent.h>

@class NSString;

@interface UIxDatePicker : WOComponent
{
  NSString *dateID;
  id       day;
  id       month;
  id       year;
  NSString *label;
  BOOL isDisabled;
  NSString *format;
  NSString *jsFormat;
}

- (NSString *) dateID;
- (NSString *) dateFormat;
- (NSString *) jsDateFormat;
- (BOOL) useISOFormats;
- (void) setupFormat;
@end

#endif /* UIXDATEPICKER_H */
