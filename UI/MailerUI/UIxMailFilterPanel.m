/*
 Copyright (C) 2000-2005 SKYRIX Software AG
 
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

#include <NGObjWeb/WOComponent.h>

@interface UIxMailFilterPanel : WOComponent
{
  NSString *searchText;
  NSString *searchCriteria;
}

@end

#include <SOGoUI/UIxComponent.h>
#include "common.h"

@implementation UIxMailFilterPanel

static NSArray      *filters           = nil;
static NSDictionary *filterToQualifier = nil;

+ (void)initialize {
  // TODO: also available: answered, draft [custom: NotJunk and Junk]
  // Note: we currently cannot use: "flags != 'deleted'"
  static NSString *quals[] = {
    @"all",     nil,
    @"read",    @"flags = 'seen'   AND NOT (flags = 'deleted')",
    @"unread",  @"flags = 'unseen' AND NOT (flags = 'deleted')",
    @"deleted", @"flags = 'deleted'",
    @"flagged", @"flags = 'flagged'",
    nil, nil
  };
  NSMutableDictionary *md;
  NSMutableArray *ma;
  unsigned i;
  
  md = [[NSMutableDictionary alloc] initWithCapacity:8];
  ma = [[NSMutableArray alloc] initWithCapacity:4];

  for (i = 0; quals[i] != nil; i += 2) {
    [ma addObject:quals[i]];
    if (quals[i + 1] != nil) {
      [md setObject:[EOQualifier qualifierWithQualifierFormat:quals[i + 1]]
	  forKey:quals[i]];
    }
  }
  
  filterToQualifier = [md copy];
  filters           = [ma copy];
  [md release]; md = nil;
  [ma release]; ma = nil;
}

- (id) init
{
  if ((self = [super init]))
    {
      searchText = nil;
      searchCriteria = nil;
    }

  return self;
}

- (void)dealloc {
  [self->searchCriteria release];
  [self->searchText release];
  [super dealloc];
}

/* accessors */

- (void)setSearchText: (NSString *)_txt
{
  ASSIGNCOPY(self->searchText, _txt);
}

- (void)setSearchCriteria: (NSString *)_txt
{
  ASSIGNCOPY(self->searchText, _txt);
}

- (NSString *)searchText
{
  if (self->searchText == nil)
    {
      self->searchText = 
	[[[[self context] request] formValueForKey:@"search"] copy];
    }
  return self->searchText;
}

- (NSString *)searchCriteria
{
  if (self->searchCriteria == nil)
    {
      self->searchCriteria = 
	[[[[self context] request] formValueForKey:@"criteria"] copy];
    }
  return self->searchCriteria;
}

/* filters */

- (NSArray *)filters
{
  return filters;
}

/* qualifiers */

- (EOQualifier *) searchTextQualifier
{
  EOQualifier *q;
  NSString *s;
  
  s = [self searchText];
  if ([s length] == 0)
    return nil;
  
  q = [EOQualifier qualifierWithQualifierFormat:
		     @"(subject doesContain: %@) OR "
		     @"(from doesContain: %@)",
		     s, s];
  return q;
}

- (NSString *)filterLabel
{
#if 1
  return [[[self context] page] labelForKey:[self valueForKey:@"filter"]];
#else
  return [self valueForKey:@"filter"];
#endif
}

- (NSString *)selectedFilter
{
  return  [[[self context] request] formValueForKey:@"filterpopup"];
}

- (EOQualifier *)filterQualifier
{
  NSString *selectedFilter;
  
  selectedFilter = [self selectedFilter];
  
  return [selectedFilter length] > 0
    ? [filterToQualifier objectForKey:selectedFilter] : nil;
}

- (EOQualifier *) qualifier
{
  EOQualifier *sq, *fq;
  NSArray *qa;
  
  sq = [self searchTextQualifier];
  fq = [self filterQualifier];
  
  if (fq == nil) return sq;
  if (sq == nil) return fq;
  
  qa = [NSArray arrayWithObjects:fq, sq, nil];
  return [[[EOAndQualifier alloc] initWithQualifierArray:qa] autorelease];
}

@end /* UIxMailFilterPanel */
