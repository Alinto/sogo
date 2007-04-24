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

#import <GDLContentStore/GCSFolder.h>

#import <SOGo/SOGoUser.h>

#import "common.h"
#import "SOGoFolder.h"
#import "SOGoContentObject.h"

@interface SOGoContentObject(ETag)
- (NSArray *)parseETagList:(NSString *)_c;
@end

@implementation SOGoContentObject

// TODO: check superclass version

- (void)dealloc {
  [content release];
  [ocsPath release];
  [super dealloc];
}

/* notifications */

- (void)sleep {
  [content release]; content = nil;
  [super sleep];
}

/* accessors */

- (BOOL)isFolderish {
  return NO;
}

- (void)setOCSPath:(NSString *)_path {
  if ([ocsPath isEqualToString:_path])
    return;
  
  if (ocsPath)
    [self warnWithFormat:@"GCS path is already set! '%@'", _path];
  
  ASSIGNCOPY(ocsPath, _path);
}

- (NSString *)ocsPath {
  if (ocsPath == nil) {
    NSString *p;
    
    if ((p = [self ocsPathOfContainer]) != nil) {
      if (![p hasSuffix:@"/"]) p = [p stringByAppendingString:@"/"];
      p = [p stringByAppendingString:[self nameInContainer]];
      ocsPath = [p copy];
    }
  }
  return ocsPath;
}

- (NSString *)ocsPathOfContainer {
  if (![[self container] respondsToSelector:@selector(ocsPath)])
    return nil;

  return [[self container] ocsPath];
}

- (GCSFolder *) ocsFolder
{
  return [container ocsFolder];
}

/* content */

- (NSString *) contentAsString
{
  if (!content)
    {
      content = [[self ocsFolder] fetchContentWithName: nameInContainer];
      [content retain];
    }

  return content;
}

- (NSException *) saveContentString: (NSString *) _str
                        baseVersion: (unsigned int) _baseVersion
{
  /* Note: "iCal multifolder saves" are implemented in the apt subclass! */
  GCSFolder   *folder;
  NSException *ex;
  
  if ((folder = [self ocsFolder]) == nil) {
    [self errorWithFormat:@"Did not find folder of content object."];
    return nil;
  }
  
  ex = [folder writeContent:_str toName:[self nameInContainer]
	       baseVersion:_baseVersion];
  if (ex != nil) {
    [self errorWithFormat:@"write failed: %@", ex];
    return ex;
  }
  return nil;
}
- (NSException *)saveContentString:(NSString *)_str {
  return [self saveContentString:_str baseVersion:0 /* don't check */];
}

- (NSException *)delete {
  /* Note: "iCal multifolder saves" are implemented in the apt subclass! */
  GCSFolder   *folder;
  NSException *ex;
  
  // TODO: add precondition check? (or add DELETEAction?)
  
  if ((folder = [self ocsFolder]) == nil) {
    [self errorWithFormat:@"Did not find folder of content object."];
    return nil;
  }
  
  if ((ex = [folder deleteContentWithName:[self nameInContainer]])) {
    [self errorWithFormat:@"delete failed: %@", ex];
    return ex;
  }
  return nil;
}

/* actions */

- (id)PUTAction:(WOContext *)_ctx {
  WORequest    *rq;
  NSException  *error;
  unsigned int baseVersion;
  id           etag, tmp;
  BOOL         needsLocation;
  
  if ((error = [self matchesRequestConditionInContext:_ctx]) != nil)
    return error;
  
  rq = [_ctx request];
  
  /* check whether its a request to the 'special' 'new' location */
  /*
    Note: this is kinda hack. The OGo ZideStore detects writes to 'new' as
          object creations and will assign a server side identifier. Most
	  current GroupDAV clients rely on this behaviour, so we reproduce it
	  here.
	  A correct client would loop until it has a name which doesn't not
	  yet exist (by using if-none-match).
  */
  needsLocation = NO;
  tmp = [[self nameInContainer] stringByDeletingPathExtension];
  if ([tmp isEqualToString:@"new"]) {
    tmp = [[[self container] class] globallyUniqueObjectId];
    needsLocation = YES;
    
    [self debugWithFormat:
	    @"reassigned a new location for special new-location: %@", tmp];
    
    /* kinda dangerous */
    ASSIGNCOPY(nameInContainer, tmp);
    ASSIGN(ocsPath, nil);
  }
  
  /* determine base version from etag in if-match header */
  /*
    Note: The -matchesRequestConditionInContext: already checks whether the
          etag matches and returns an HTTP exception in case it doesn't.
	  We retrieve the etag again here to _ensure_ a transactionally save
	  commit.
          (between the check and the update a change could have been done)
  */
  tmp  = [rq headerForKey:@"if-match"];
  tmp  = [self parseETagList:tmp];
  etag = nil;
  if ([tmp count] > 0) {
    if ([tmp count] > 1) {
      /*
	Note: we would have to attempt a save for _each_ of the etags being
	      passed in! In practice most WebDAV clients submit exactly one
	      etag.
      */
      [self warnWithFormat:
	      @"Got multiple if-match etags from client, only attempting to "
	      @"save with the first: %@", tmp];
    }
    
    etag = [tmp objectAtIndex:0];
  }
  baseVersion = ([etag length] > 0)
    ? [etag unsignedIntValue]
    : 0 /* 0 means 'do not check' */;
  
  /* attempt a save */
  
  if ((error = [self saveContentString:[rq contentAsString]
		     baseVersion:baseVersion]) != nil)
    return error;
  
  /* setup response */
  
  // TODO: this should be automatic in the SoDispatcher if we return nil?
  [[_ctx response] setStatus:201 /* Created */];
  
  if ((etag = [self davEntityTag]) != nil)
    [[_ctx response] setHeader:etag forKey:@"etag"];
  
  if (needsLocation) {
    [[_ctx response] setHeader:[self baseURLInContext:_ctx] 
		     forKey:@"location"];
  }
  
  return [_ctx response];
}

/* security */
- (NSArray *) rolesOfUser: (NSString *) login
{
  NSMutableArray *sogoRoles;
  SOGoUser *user;

  sogoRoles = [NSMutableArray new];
  [sogoRoles autorelease];

  if (![container nameExistsInFolder: nameInContainer])
    {
      user = [[SOGoUser alloc] initWithLogin: login roles: nil];
      [sogoRoles addObjectsFromArray: [user rolesForObject: container
                                            inContext: context]];
      [user release];
    }

  return sogoRoles;
}

/* E-Tags */

- (id)davEntityTag {
  // TODO: cache tag in ivar? => if you do, remember to flush after PUT
  GCSFolder *folder;
  char buf[64];
  
  if ((folder = [self ocsFolder]) == nil) {
    [self errorWithFormat:@"Did not find folder of content object."];
    return nil;
  }
  
  sprintf(buf, "\"gcs%08d\"",
	  [[folder versionOfContentWithName:[self nameInContainer]]
	    unsignedIntValue]);
  return [NSString stringWithCString:buf];
}

/* WebDAV */

- (NSException *)davMoveToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  /*
    Note: even for new objects we won't get a new name but a preinstantiated
          object representing the new one.
  */
  [self logWithFormat:
	  @"TODO: move not implemented:\n  target:  %@\n  new name: %@",
	  _target, _name];
  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                      reason:@"this object cannot be copied via WebDAV"];
}

- (NSException *)davCopyToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  /*
    Note: even for new objects we won't get a new name but a preinstantiated
          object representing the new one.
  */
  [self logWithFormat:
	  @"TODO: copy not implemented:\n  target:  %@\n  new name: %@",
	  _target, _name];
  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                      reason:@"this object cannot be copied via WebDAV"];
}

- (BOOL)davIsCollection {
  return [self isFolderish];
}

/* acls */

- (NSArray *) acls
{
  return [container aclsForObjectAtPath: [self pathArrayToSoObject]];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return [container aclsForUser: uid
                    forObjectAtPath: [self pathArrayToSoObject]];
}

- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid
{
  return [container setRoles: roles
                    forUser: uid
                    forObjectAtPath: [self pathArrayToSoObject]];
}

- (void) removeAclsForUsers: (NSArray *) users
{
  return [container removeAclsForUsers: users
                    forObjectAtPath: [self pathArrayToSoObject]];
}

/* message type */

- (NSString *)outlookMessageClass {
  return nil;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  [super appendAttributesToDescription:_ms];
  
  [_ms appendFormat:@" ocs=%@", [self ocsPath]];
}

@end /* SOGoContentObject */
