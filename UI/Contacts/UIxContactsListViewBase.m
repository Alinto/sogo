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

#include "UIxContactsListViewBase.h"
#include <Contacts/SOGoContactFolder.h>
#include "common.h"

@implementation UIxContactsListViewBase

- (void)dealloc {
  [self->allRecords      release];
  [self->filteredRecords release];
  [self->searchText release];
  [self->contact    release];
  [super dealloc];
}

/* accessors */

- (void)setContact:(id)_contact {
  ASSIGN(self->contact, _contact);
}
- (id)contact {
  return self->contact;
}

- (void)setSearchText:(NSString *)_txt {
  ASSIGNCOPY(self->searchText, _txt);
}
- (id)searchText {
  if (self->searchText == nil)
    [self setSearchText:[[[self context] request] formValueForKey:@"search"]];
  return self->searchText;
}

- (EOQualifier *)qualifier {
  NSString *qs, *s;
  
  s = [self searchText];
  if ([s length] == 0)
    return nil;
  
  // TODO: just use qualifier vars
  qs = [NSString stringWithFormat:
		   @"(sn isCaseInsensitiveLike: '%@*') OR "
		   @"(givenname isCaseInsensitiveLike: '%@*') OR "
		   @"(mail isCaseInsensitiveLike: '*%@*') OR "
		   @"(telephonenumber isCaseInsensitiveLike: '*%@*')",
		   s, s, s, s];
  return [EOQualifier qualifierWithQualifierFormat:qs];
}

- (NSString *)defaultSortKey {
  return @"sn";
}
- (NSString *)sortKey {
  NSString *s;
  
  s = [[[self context] request] formValueForKey:@"sort"];
  return [s length] > 0 ? s : [self defaultSortKey];
}
- (EOSortOrdering *)sortOrdering {
  SEL sel;

  sel = [[[[self context] request] formValueForKey:@"desc"] boolValue]
    ? EOCompareCaseInsensitiveDescending
    : EOCompareCaseInsensitiveAscending;
  
  return [EOSortOrdering sortOrderingWithKey:[self sortKey] selector:sel];
}
- (NSArray *)sortOrderings {
  return [NSArray arrayWithObjects:[self sortOrdering], nil];
}

- (NSArray *)contactInfos {
  // TODO: should be done in the backend, but for Agenor AB its OK here
  NSArray     *records;
  EOQualifier *q;
  
  if (self->filteredRecords != nil)
    return self->filteredRecords;
  
  records = [[self clientObject] fetchCoreInfos];
  self->allRecords = 
    [[records sortedArrayUsingKeyOrderArray:[self sortOrderings]] retain];
  
  if ((q = [self qualifier]) != nil) {
  [self debugWithFormat:@"qs: %@", q];
    self->filteredRecords = 
      [[self->allRecords filteredArrayUsingQualifier:q] retain];
  }
  else
    self->filteredRecords = [self->allRecords retain];
  
  return self->filteredRecords;
}

/* notifications */

- (void)sleep {
  [self->contact         release]; self->contact         = nil;
  [self->allRecords      release]; self->allRecords      = nil;
  [self->filteredRecords release]; self->filteredRecords = nil;
  [super sleep];
}

/* actions */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c{
  return YES;
}

@end /* UIxContactsListViewBase */
