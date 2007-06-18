/*
  Copyright (C) 2004 SKYRIX Software AG

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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NGLogger.h>
#import <NGExtensions/NGLoggerManager.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>

#import "SOGoGroupFolder.h"

@implementation SOGoGroupFolder

static NGLogger *logger = nil;

+ (void) initialize
{
  NGLoggerManager *lm;

  if (!logger)
    {
      lm = [NGLoggerManager defaultLoggerManager];
      logger = [lm loggerForDefaultKey:@"SOGoGroupFolderDebugEnabled"];
    }
}

- (void) dealloc
{
  [uidToFolder release];
  [folders     release];
  [super dealloc];
}

/* logging */

- (id)debugLogger {
  return logger;
}

/* accessors */

- (NSArray *)uids {
  [self errorWithFormat:@"instantiated abstract Group folder class!"];
  return nil;
}

/* folder management */

- (id)_primaryLookupFolderForUID:(NSString *)_uid inContext:(id)_ctx {
  NSException *error = nil;
  NSArray     *path;
  id          ctx, result;

  /* create subcontext, so that we don't destroy our environment */
  
  if ((ctx = [_ctx createSubContext]) == nil) {
    [self errorWithFormat:@"could not create SOPE subcontext!"];
    return nil;
  }
  
  /* build path */
  
  path = _uid != nil ? [NSArray arrayWithObjects:&_uid count:1] : nil;
  
  /* traverse path */
  
  result = [[ctx application] traversePathArray:path inContext:ctx
			      error:&error acquire:NO];
  if (error != nil) {
    [self errorWithFormat:@"folder lookup failed (uid=%@): %@",
	    _uid, error];
    return nil;
  }
  
  if (logger)
    [self debugWithFormat:@"Note: got folder for uid %@ path %@: %@",
	                        _uid, [path componentsJoinedByString:@"=>"], result];
  return result;
}

- (void)_setupFolders {
  NSMutableDictionary *md;
  NSMutableArray      *ma;
  NSArray  *luids;
  unsigned i, count;
  
  if (uidToFolder != nil)
    return;
  if ((luids = [self uids]) == nil)
    return;
  
  count = [luids count];
  ma = [NSMutableArray arrayWithCapacity:count + 1];
  md = [NSMutableDictionary dictionaryWithCapacity:count];
  
  for (i = 0; i < count; i++) {
    NSString *uid;
    id folder;
    
    uid    = [luids objectAtIndex:i];
    folder = [self _primaryLookupFolderForUID:uid inContext: context];
    
    if ([folder isNotNull]) {
      [md setObject:folder forKey:uid];
      [ma addObject:folder];
    }
    else
      [ma addObject:[NSNull null]];
  }
  
  /* fix results */
  uidToFolder = [md copy];
  folders     = [[NSArray alloc] initWithArray:ma];
}

- (NSArray *)memberFolders {
  [self _setupFolders];
  return folders;
}

- (id)folderForUID:(NSString *)_uid {
  [self _setupFolders];
  
  if ([_uid length] == 0)
    return nil;
  
  return [uidToFolder objectForKey:_uid];
}

- (void) resetFolderCaches
{
  [uidToFolder release];
  uidToFolder = nil;
  [folders release];
  folders     = nil;
}

- (void) sleep
{
  [self resetFolderCaches];
  [super sleep];
}

/* SOPE */

- (BOOL) isFolderish
{
  return YES;
}

/* looking up shared objects */

- (SOGoGroupsFolder *) lookupGroupsFolder
{
  return [[self container] lookupGroupsFolder];
}

/* pathes */

/* name lookup */

- (id) groupCalendar: (NSString *) _key
	   inContext: (id) _ctx
{
  static Class calClass = Nil;
  id calendar;
  
  if (calClass == Nil)
    calClass = NSClassFromString(@"SOGoGroupAppointmentFolder");
  if (calClass == Nil) {
    [self errorWithFormat:@"missing SOGoGroupAppointmentFolder class!"];
    return nil;
  }
  
  calendar = [[calClass alloc] initWithName:_key inContainer:self];
  
  // TODO: should we pass over the uids in questions or should the
  //       appointment folder query its container for that info?
  
  return [calendar autorelease];
}

- (id) lookupName: (NSString *) _key
	inContext: (id) _ctx
	  acquire: (BOOL) _flag
{
  id obj;
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  if ([_key isEqualToString:@"Calendar"])
    return [self groupCalendar:_key inContext:_ctx];
  
  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

@end /* SOGoGroupFolder */
