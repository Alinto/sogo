/*
  Copyright (C) 2005 SKYRIX Software AG

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

#include "SOGoMailFolderDataSource.h"
#include "SOGoMailManager.h"
#include <NGObjWeb/EOFetchSpecification+SoDAV.h>
#include <NGImap4/NGImap4Envelope.h>
#include "common.h"

@implementation SOGoMailFolderDataSource

static BOOL debugOn = NO;

- (id)initWithImap4URL:(NSURL *)_imap4URL imap4Password:(NSString *)_pwd {
  if (_imap4URL == nil) {
    [self release];
    return nil;
  }

  if ((self = [super init])) {
    self->imap4URL      = [_imap4URL copy];
    self->imap4Password = [_pwd copy];
  }
  return self;
}
- (id)init {
  return [self initWithImap4URL:nil imap4Password:nil];
}

- (void)dealloc {
  [self->imap4Password      release];
  [self->imap4URL           release];
  [self->fetchSpecification release];
  [super dealloc];
}

/* accessors */

- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec {
  if ([_fetchSpec isEqual:self->fetchSpecification]) return;
  
  ASSIGN(self->fetchSpecification, _fetchSpec);
  [self postDataSourceChangedNotification];
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fetchSpecification;
}

- (NSURL *)imap4URL {
  return self->imap4URL;
}

- (NGImap4ConnectionManager *)mailManager {
  static NGImap4ConnectionManager *mm = nil;
  if (mm == nil) 
    mm = [[NGImap4ConnectionManager defaultConnectionManager] retain];
  return mm;
}

/* fetches */

- (NSArray *)partsForWebDAVPropertyNames:(NSArray *)_names {
  // TODO: implement
  static NSArray *parts = nil;

  // [self logWithFormat:@"props: %@", _names];
  
  if (parts == nil) {
    parts = [[NSArray alloc] initWithObjects:
			       @"FLAGS", @"ENVELOPE", @"RFC822.SIZE", nil];
  }
  return parts;
}

- (void)addRecordsForFolderNames:(NSArray *)_n toArray:(NSMutableArray *)_r {
  unsigned i, count;
  
  for (i = 0, count = [_n count]; i < count; i++) {
    NSDictionary *rec;
    NSString *keys[2], *values[2];
    
    keys[0] = @"{DAV:}href";      values[0] = [_n objectAtIndex:i];
    keys[1] = @"davResourceType"; values[1] = @"collection";
    rec = [[NSDictionary alloc] initWithObjects:values forKeys:keys count:2];
    [_r addObject:rec];
    [rec release];
  }
}

- (void)addRecordsForUIDs:(NSArray *)_uids toArray:(NSMutableArray *)_r {
  NSAutoreleasePool *pool;
  NSArray  *partNames, *results;
  unsigned i, count;
  
  if ([_uids count] == 0)
    return;

  pool = [[NSAutoreleasePool alloc] init];
  
  partNames = [self partsForWebDAVPropertyNames:
		      [[self fetchSpecification] selectedWebDAVPropertyNames]];
  
  results = [[self mailManager] fetchUIDs:_uids inURL:self->imap4URL
				parts:partNames password:self->imap4Password];
  results = [results valueForKey:@"fetch"];

  for (i = 0, count = [results count]; i < count; i++) {
    NGImap4Envelope *envelope;
    NSDictionary *result;
    NSDictionary *rec;
    NSString *keys[6];
    id       values[6];
    
    result   = [results objectAtIndex:i];
    envelope = [result valueForKey:@"envelope"];
    // NSLog(@"RES: %@", result);
    
    keys[0]   = @"{DAV:}href";      
    values[0] = [[[result objectForKey:@"uid"] stringValue]
		  stringByAppendingString:@".mail"];
    keys[1]   = @"davResourceType";
    values[1] = @"";
    keys[2]   = @"davContentLength";
    values[2] = [result objectForKey:@"size"];
    keys[3]   = @"davDisplayName";
    values[3] = [envelope subject];
    keys[4]   = @"davLastModified";
    values[4] = [envelope date];
    
    rec = [[NSDictionary alloc] initWithObjects:values forKeys:keys count:5];
    [_r addObject:rec];
    [rec release];
  }

  [pool release];
}

/* operations */

- (NSArray *)fetchObjects {
  NSMutableArray *results;
  EOQualifier    *qualifier;
  NSArray        *sortOrderings;
  NSArray  *uids, *folderNames;
  unsigned total;
  
  // TODO: support [fs davBulkTargetKeys]
  if ([[self fetchSpecification] davBulkTargetKeys] != nil) {
    [self logWithFormat:@"unsupported fetch specification"];
    return nil;
  }
  
  /* fetch message uids */
  
  // TODO: translate WebDAV qualifier and sort-ordering into IMAP4 one
  uids = [[self mailManager] fetchUIDsInURL:self->imap4URL
			     qualifier:nil sortOrdering:@"DATE"
			     password:self->imap4Password];
  
  /* fetch folders */
  
  folderNames = [[self mailManager] subfoldersForURL:self->imap4URL
				    password:self->imap4Password];
  
  /* builds results */
  
  if ((total = ([uids count] + [folderNames count])) == 0)
    return [NSArray array];
  
  results = [NSMutableArray arrayWithCapacity:total];
  
  [self addRecordsForFolderNames:folderNames toArray:results];
  [self addRecordsForUIDs:uids               toArray:results];
  
  /* filter and sort results */
  
  if ((qualifier = [[self fetchSpecification] qualifier]) != nil)
    results = (id)[results filteredArrayUsingQualifier:qualifier];
  
  if ((sortOrderings = [[self fetchSpecification] sortOrderings]) != nil) {
    if (qualifier != nil)
      results = (id)[results sortedArrayUsingKeyOrderArray:sortOrderings];
    else
      [results sortUsingKeyOrderArray:sortOrderings];
  }
  
  return results;
}

/* logging */

- (NSString *)loggingPrefix {
  return @"[mailfolder-ds]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SOGoMailFolderDataSource */
