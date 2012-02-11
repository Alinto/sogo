/* SQLSource.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2011 Inverse inc.
 *
 * Authors: Ludovic Marcotte <lmarcotte@inverse.ca>
 *          Francis Lachapelle <flachapelle@invers.ca>
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

#ifndef SQLSOURCE_H
#define SQLSOURCE_H

#import <Foundation/NSObject.h>

#import "SOGoSource.h"

@class NSArray;
@class NSDictionary;
@class NSString;
@class NSURL;

@interface SQLSource : NSObject <SOGoSource>
{
  NSString *_sourceID;
  NSString *_domain;
  NSString *_domainField;
  NSString *_authenticationFilter;
  NSArray *_loginFields;
  NSArray *_mailFields;
  NSString *_imapLoginField;
  NSString *_imapHostField;
  NSString *_userPasswordAlgorithm;
  NSURL *_viewURL;

  /* resources handling */
  NSString *_kindField;
  NSString *_multipleBookingsField;
}

@end

#endif /* SQLSOURCE_H */
