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

#include "SOGoDraftsFolder.h"
#include "SOGoDraftObject.h"
#include <SOGo/SOGoUserFolder.h>
#include <NGExtensions/NSFileManager+Extensions.h>
#include "common.h"
#include <unistd.h>

@implementation SOGoDraftsFolder

static NSString *spoolFolder = nil;

+ (int)version {
  return [super version] + 0 /* v1 */;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  spoolFolder = [[ud stringForKey:@"SOGoMailSpoolPath"] copy];
  if ([spoolFolder length] < 3)
    spoolFolder = @"/tmp/";
  
  NSLog(@"Note: using SOGo mail spool folder: %@", spoolFolder);
}

/* new objects */

- (NSString *)makeNewObjectNameInContext:(id)_ctx {
  static int counter = 1; // THREAD
  return [NSString stringWithFormat:@"draft_%08d_%08x", getpid(), counter++];
}

- (NSString *)newObjectBaseURLInContext:(id)_ctx {
  NSString *s, *n;
  
  n = [self makeNewObjectNameInContext:_ctx];
  if (![n isNotNull]) return nil;
  
  s = [self baseURLInContext:_ctx];
  if (![s isNotNull]) return nil;
  if (![s hasSuffix:@"/"]) s = [s stringByAppendingString:@"/"];
  return [s stringByAppendingString:n];
}

- (id)newObjectInContext:(id)_ctx {
  return [self lookupName:[self makeNewObjectNameInContext:_ctx]
	       inContext:_ctx acquire:NO];
}

/* draft folder functionality */

- (NSFileManager *)spoolFileManager {
  return [NSFileManager defaultManager];
}

- (NSString *)spoolFolderPath {
  return spoolFolder;
}
- (NSString *)userSpoolFolderPath {
  NSString *p, *n;
  
  p = [self spoolFolderPath];
  n = [[self lookupUserFolder] nameInContainer];
  return [p stringByAppendingPathComponent:n];
}

- (BOOL)_ensureUserSpoolFolderPath {
  NSFileManager *fm;
  
  if ((fm = [self spoolFileManager]) == nil) {
    [self errorWithFormat:@"missing spool file manager!"];
    return NO;
  }
  return [fm createDirectoriesAtPath:[self userSpoolFolderPath]
	     attributes:nil];
}

- (NSArray *)fetchMailNames {
  NSString *p;
  
  if ((p = [self userSpoolFolderPath]) == nil)
    return nil;
  
  return [[self spoolFileManager] directoryContentsAtPath:p];
}

/* folder methods (used by template) */

- (NSArray *)fetchUIDsMatchingQualifier:(id)_q sortOrdering:(id)_so {
  // TODO: retrieve contained objects
  NSArray *allUids;
  
  allUids = [self fetchMailNames];
  if (![allUids isNotNull]) {
    [self logWithFormat:@"Note: no uids in drafts folder: %@",
	    [self userSpoolFolderPath]];
    return [NSArray array];
  }
  
  // TODO: should sort uids (q=%@,so=%@): %@", _q, _so, allUids];
  return allUids;
}
- (NSArray *)fetchUIDs:(NSArray *)_uids parts:(NSArray *)_parts {
  /* FLAGS, ENVELOPE, RFC822.SIZE */
  NSMutableArray  *drafts;
  unsigned i, count;
  
  if (_uids == nil)
    return nil;
  if ((count = [_uids count]) == 0)
    return [NSArray array];
  
  drafts = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    SOGoDraftObject *draft;
    id parts;
    
    draft = [self lookupName:[_uids objectAtIndex:i] inContext:nil acquire:NO];
    if (![draft isNotNull] || [draft isKindOfClass:[NSException class]])
      continue;
    
    parts = [draft fetchParts:_parts];
    if ([parts isNotNull])
      [drafts addObject:parts];
  }
  
  return drafts;
}

/* name lookup */

- (id)lookupDraftMessage:(NSString *)_key inContext:(id)_ctx {
  // TODO: we might want to check for existence prior controller creation
  return [[[SOGoDraftObject alloc] initWithName:_key 
				   inContainer:self] autorelease];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]) != nil)
    return obj;
  
  if ((obj = [self lookupDraftMessage:_key inContext:_ctx]) != nil)
    return obj;
  
  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

/* WebDAV */

- (BOOL)davIsCollection {
  return YES;
}

- (NSArray *)toOneRelationshipKeys {
  return [self fetchMailNames];
}

/* folder type */

- (NSString *)outlookFolderClass {
  return @"IPF.Drafts";
}

@end /* SOGoDraftsFolder */
