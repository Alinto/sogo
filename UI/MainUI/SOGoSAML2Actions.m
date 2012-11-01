/* SOGoSAML2Actions.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/SOGoSAML2Session.h>

@interface SOGoSAML2Actions : WODirectAction
@end

@implementation SOGoSAML2Actions

- (WOResponse *) saml2MetadataAction
{
  WOResponse *response;
  NSString *metadata;

  response = [context response];
  [response setHeader: @"application/xml; charset=utf-8"
               forKey: @"content-type"];

  metadata = [SOGoSAML2Session metadataInContext: context];
  [response setContentEncoding: NSUTF8StringEncoding];
  [response appendContentString: metadata];

  return response;
}

@end
