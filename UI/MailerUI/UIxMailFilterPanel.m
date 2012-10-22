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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <EOControl/EOQualifier.h>
#import <NGObjWeb/WOComponent.h>

@interface UIxMailFilterPanel : WOComponent
{
  NSString *searchText;
  NSString *searchCriteria;
}

@end

@implementation UIxMailFilterPanel

static NSArray *filters = nil;
// static NSDictionary *filterToQualifier = nil;

+ (void)initialize {
  // TODO: also available: answered, draft [custom: NotJunk and Junk]
  // Note: we currently cannot use: "flags != 'deleted'"
  static NSString *quals[] = {
    @"all", nil,
    @"read", @"flags = 'seen' AND NOT (flags = 'deleted')",
    @"unread", @"flags = 'unseen' AND NOT (flags = 'deleted')",
    @"deleted", @"flags = 'deleted'",
    @"flagged", @"flags = 'flagged'",
    nil, nil
  };
  NSMutableDictionary *md;
  NSMutableArray *ma;
  unsigned i;
  
#warning why not populate "filters" directly, as an NSMutableArray?
  md = [[NSMutableDictionary alloc] initWithCapacity:8];
  ma = [[NSMutableArray alloc] initWithCapacity:4];

  for (i = 0; quals[i] != nil; i += 2) {
    [ma addObject:quals[i]];
    if (quals[i + 1] != nil) {
      [md setObject:[EOQualifier qualifierWithQualifierFormat:quals[i + 1]]
	  forKey:quals[i]];
    }
  }
  
//   filterToQualifier = [md copy];
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

- (void) dealloc
{
  [searchCriteria release];
  [searchText release];
  [super dealloc];
}

/* accessors */

- (void) setSearchText: (NSString *) _txt
{
  ASSIGN (searchText, _txt);
}

- (void) setSearchCriteria: (NSString *) _txt
{
  ASSIGN (searchText, _txt);
}

- (NSString *) searchText
{
  if (!searchText)
    {
      searchText = [[context request] formValueForKey: @"value"];
      [searchText retain];
    }

  return searchText;
}

- (NSString *) searchCriteria
{
  if (!searchCriteria)
    {
      searchCriteria = [[context request] formValueForKey: @"criteria"];
      [searchCriteria retain];
    }

  return searchCriteria;
}

/* filters */

- (NSArray *) filters
{
  return filters;
}

/* qualifiers */

// - (EOQualifier *) searchTextQualifier
// {
//   EOQualifier *q;
//   NSString *s;
  
//   s = [self searchText];
//   if ([s length] == 0)
//     return nil;
  
//   q = [EOQualifier qualifierWithQualifierFormat:
// 		     @"(subject doesContain: %@) OR "
// 		     @"(from doesContain: %@)",
// 		     s, s];
//   return q;
// }

// - (NSString *) filterLabel
// {
// #if 1
//   return [[context page] labelForKey:[self valueForKey:@"filter"]];
// #else
//   return [self valueForKey:@"filter"];
// #endif
// }

// - (NSString *) selectedFilter
// {
//   return  [[context request] formValueForKey: @"filterpopup"];
// }

// - (EOQualifier *) filterQualifier
// {
//   NSString *selectedFilter;
  
//   selectedFilter = [self selectedFilter];
  
//   return [selectedFilter length] > 0
//     ? [filterToQualifier objectForKey:selectedFilter] : nil;
// }

// - (EOQualifier *) qualifier
// {
//   EOQualifier *sq, *fq;
//   NSArray *qa;
  
//   sq = [self searchTextQualifier];
//   fq = [self filterQualifier];
  
//   if (fq == nil) return sq;
//   if (sq == nil) return fq;
  
//   qa = [NSArray arrayWithObjects:fq, sq, nil];

//   return [[[EOAndQualifier alloc] initWithQualifierArray:qa] autorelease];
// }

@end /* UIxMailFilterPanel */
