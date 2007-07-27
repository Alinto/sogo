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

#import <Foundation/NSCalendarDate.h>
#import <NGObjWeb/SoObject.h>
#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SOGoUI/UIxComponent.h>

/*
  UIxFilterList

  This component shows a list of filter scripts and is (usually) attached to
  a SOGoSieveScriptsFolder object.
*/

@interface UIxFilterList : UIxComponent
{
  NSArray *filters;
  id filter;
}

@end

@implementation UIxFilterList

- (void)dealloc {
  [self->filter  release];
  [self->filters release];
  [super dealloc];
}

/* notifications */

- (void)sleep {
  [self->filter  release]; self->filter  = nil;
  [self->filters release]; self->filters = nil;
  [super sleep];
}

/* accessors */

- (void)setFilter:(id)_msg {
  ASSIGN(self->filter, _msg);
}
- (id)filter {
  return self->filter;
}

- (NSArray *)filters {
  return self->filters;
}

- (NSString *)panelTitle {
  return [self labelForKey:@"Mail Filters"];
}

/* JavaScript code */

- (NSString *)clickedFilterJS {
  /* return 'false' aborts processing */
  return [NSString stringWithFormat:
		     @"clickedFilter(this, '%@'); return false", 
		     [self filter]];
}

/* creating scripts */

- (NSString *)newScriptName {
  NSCalendarDate *now;
  
  now = [NSCalendarDate date];
  return [NSString stringWithFormat:@"MyFilter-%04d%02d%02d-%02d%02d%02d",
		   [now yearOfCommonEra], [now monthOfYear], 
		   [now dayOfMonth],
		   [now hourOfDay], [now minuteOfHour], [now secondOfMinute]];
}

/* actions */

- (id)defaultAction {
  [self debugWithFormat:@"fetch scripts in: %@", [self clientObject]];
  self->filters = [[[self clientObject] toOneRelationshipKeys] copy];
  return self;
}

- (id)createAction {
  NSString *newURL;
  
  newURL = [[self clientObject] baseURLInContext:[self context]];
  if (![newURL hasSuffix:@"/"]) newURL = [newURL stringByAppendingString:@"/"];
  newURL = [newURL stringByAppendingString:[self newScriptName]];
  newURL = [newURL stringByAppendingString:@"/edit"];
  
  return [self redirectToLocation:newURL];
}

@end /* UIxFilterList */
