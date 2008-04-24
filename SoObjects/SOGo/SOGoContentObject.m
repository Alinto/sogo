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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <GDLContentStore/GCSFolder.h>

#import "NSCalendarDate+SOGo.h"
#import "SOGoGCSFolder.h"
#import "SOGoUser.h"
#import "SOGoPermissions.h"
#import "SOGoContentObject.h"

@interface SOGoContentObject(ETag)
- (NSArray *)parseETagList:(NSString *)_c;
@end

@implementation SOGoContentObject

// TODO: check superclass version

- (id) initWithName: (NSString *) newName
	inContainer: (id) newContainer
{
  if ((self = [super initWithName: newName inContainer: newContainer]))
    {
      ocsPath = nil;
      record = [[self ocsFolder] recordOfEntryWithName: newName];
      [record retain];
      isNew = (!record);
    }

  return self;
}

- (void) dealloc
{
  [record release];
  [ocsPath release];
  [super dealloc];
}

/* accessors */

- (BOOL) isFolderish
{
  return NO;
}

- (void) setOCSPath: (NSString *) newOCSPath
{
  if (![ocsPath isEqualToString: newOCSPath])
    {
      if (ocsPath)
	[self warnWithFormat:@"GCS path is already set! '%@'", newOCSPath];
  
      ASSIGNCOPY (ocsPath, newOCSPath);
    }
}

- (NSString *) ocsPath
{
  NSMutableString *newOCSPath;

  if (!ocsPath)
    {
      newOCSPath = [NSMutableString new];
      [newOCSPath appendString: [self ocsPathOfContainer]];
      if ([newOCSPath length] > 0)
	{
	  if (![newOCSPath hasSuffix:@"/"])
	    [newOCSPath appendString: @"/"];
	  [newOCSPath appendString: nameInContainer];
	  ocsPath = newOCSPath;
	}
    }

  return ocsPath;
}

- (NSString *) ocsPathOfContainer
{
  NSString *ocsPathOfContainer;

  if ([container respondsToSelector: @selector (ocsPath)])
    ocsPathOfContainer = [container ocsPath];
  else
    ocsPathOfContainer = nil;

  return ocsPathOfContainer;
}

- (GCSFolder *) ocsFolder
{
  return [container ocsFolder];
}

/* content */

- (BOOL) isNew
{
  return isNew;
}

- (NSString *) contentAsString
{
  return [record objectForKey: @"c_content"];
}

- (NSException *) saveContentString: (NSString *) newContent
                        baseVersion: (unsigned int) newBaseVersion
{
  /* Note: "iCal multifolder saves" are implemented in the apt subclass! */
  GCSFolder *folder;
  NSException *ex;
  NSMutableDictionary *newRecord;

  ex = nil;

  if (record)
    newRecord = [NSMutableDictionary dictionaryWithDictionary: record];
  else
    newRecord = [NSMutableDictionary dictionary];
  [newRecord setObject: newContent forKey: @"c_content"];
  ASSIGN (record, newRecord);

  folder = [container ocsFolder];
  if (folder)
    {
      ex = [folder writeContent: newContent toName: nameInContainer
		   baseVersion: newBaseVersion];
      if (ex)
	[self errorWithFormat:@"write failed: %@", ex];
    }
  else
    [self errorWithFormat:@"Did not find folder of content object."];
  
  return ex;
}

- (NSException *) saveContentString: (NSString *) newContent
{
  return [self saveContentString: newContent baseVersion: 0];
}

- (NSException *) delete
{
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

// - (id) lookupName:
// {
//   SoSelectorInvocation *invocation;
//   NSString *name;

//   name = [NSString stringWithFormat: @"%@:", [_key davMethodToObjC]];

//   invocation = [[SoSelectorInvocation alloc]
//                  initWithSelectorNamed: name
//                  addContextParameter: YES];
//   [invocation autorelease];

//   return invocation;

// }

- (id) PUTAction: (WOContext *) _ctx
{
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
    tmp = [self globallyUniqueObjectId];
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

  if ((error = [self saveContentString: [rq contentAsString]
		     baseVersion: baseVersion]) != nil)
    return error;
  
  /* setup response */
  
  // TODO: this should be automatic in the SoDispatcher if we return nil?
  [[_ctx response] setStatus: 201 /* Created */];
  
  if ((etag = [self davEntityTag]) != nil)
    [[_ctx response] setHeader:etag forKey:@"etag"];
  
  if (needsLocation) {
    [[_ctx response] setHeader:[self baseURLInContext:_ctx] 
		     forKey:@"location"];
  }
  
  return [_ctx response];
}

/* E-Tags */

- (id) davEntityTag
{
  // TODO: cache tag in ivar? => if you do, remember to flush after PUT
  GCSFolder *folder;
  char buf[64];
  NSString *entityTag;
  NSNumber *versionValue;
  
  folder = [self ocsFolder];
  if (folder)
    {
      versionValue = [record objectForKey: @"c_version"];
      sprintf (buf, "\"gcs%08d\"", [versionValue unsignedIntValue]);
      entityTag = [NSString stringWithCString: buf];
    }
  else
    {
      [self errorWithFormat:@"Did not find folder of content object."];
      entityTag = nil;
    }

  return entityTag;
}

/* WebDAV */
- (NSString *) davCreationDate
{
  NSCalendarDate *date;

  date = [record objectForKey: @"c_creationdate"];

  return [date rfc822DateString];
}

- (NSString *) davLastModified
{
  NSCalendarDate *date;

  date = [record objectForKey: @"c_lastmodified"];

  return [date rfc822DateString];
}

- (NSString *) davContentLength
{
  NSString *content;

  content = [record objectForKey: @"c_content"];

  return [NSString stringWithFormat: @"%u",
		   [content lengthOfBytesUsingEncoding: NSUTF8StringEncoding]];
}

- (NSException *) davMoveToTargetObject: (id) _target
				newName: (NSString *) _name
			      inContext: (id) _ctx
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

- (NSException *) davCopyToTargetObject: (id)_target
				newName: (NSString *) _name
			      inContext: (id) _ctx
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

/* acls */

- (NSArray *) aclUsers
{
  return [container aclUsersForObjectAtPath: [self pathArrayToSOGoObject]];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSMutableArray *acls;
  NSArray *containerAcls;

  acls = [NSMutableArray array];
  /* this is unused... */
//   ownAcls = [container aclsForUser: uid
// 		       forObjectAtPath: [self pathArrayToSOGoObject]];
//   [acls addObjectsFromArray: ownAcls];
  containerAcls = [container aclsForUser: uid];
  if ([containerAcls count] > 0)
    {
      [acls addObjectsFromArray: containerAcls];
      if (isNew)
	{
	  if ([containerAcls containsObject: SOGoRole_ObjectCreator])
	    [acls addObject: SOGoRole_ObjectEditor];
	  else
	    [acls removeObject: SOGoRole_ObjectEditor];
	}
    }

  return acls;
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

- (NSString *) defaultUserID
{
  return @"<default>";
}

/* message type */

- (NSString *) outlookMessageClass
{
  return nil;
}

/* description */

- (void) appendAttributesToDescription: (NSMutableString *) _ms
{
  [super appendAttributesToDescription:_ms];
  
  [_ms appendFormat:@" ocs=%@", [self ocsPath]];
}

@end /* SOGoContentObject */
