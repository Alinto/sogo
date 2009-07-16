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
#import <NGObjWeb/WORequest.h>
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

+ (id) objectWithRecord: (NSDictionary *) objectRecord
	    inContainer: (SOGoGCSFolder *) newContainer
{
  SOGoContentObject *newObject;

  newObject = [[self alloc] initWithRecord: objectRecord
			    inContainer: newContainer];
  [newObject autorelease];

  return newObject;
}

+ (id) objectWithName: (NSString *) newName
	   andContent: (NSString *) newContent
	  inContainer: (SOGoGCSFolder *) newContainer
{
  SOGoContentObject *newObject;

  newObject = [[self alloc] initWithName: newName
			    andContent: newContent
			    inContainer: newContainer];
  [newObject autorelease];

  return newObject;
}

// TODO: check superclass version

- (id) init
{
  if ((self = [super init]))
    {
      isNew = NO;
      content = nil;
      version = 0;
      lastModified = nil;
      creationDate = nil;
    }

  return self;
}

- (void) _setRecord: (NSDictionary *) objectRecord
{
  id data;
  int intValue;

  data = [objectRecord objectForKey: @"c_content"];
  if (data)
    ASSIGN (content, data);
  data = [objectRecord objectForKey: @"c_version"];
  if (data)
    version = [data unsignedIntValue];
  data = [objectRecord objectForKey: @"c_creationdate"];
  if (data)
    {
      intValue = [data intValue];
      ASSIGN (creationDate,
	      [NSCalendarDate dateWithTimeIntervalSince1970: intValue]);
    }
  data = [objectRecord objectForKey: @"c_lastmodified"];
  if (data)
    {
      intValue = [[objectRecord objectForKey: @"c_lastmodified"] intValue];
      ASSIGN (lastModified,
	      [NSCalendarDate dateWithTimeIntervalSince1970: intValue]);
    }
}

- (id) initWithRecord: (NSDictionary *) objectRecord
	  inContainer: (SOGoGCSFolder *) newContainer
{
  NSString *newName;

  newName = [objectRecord objectForKey: @"c_name"];
  if ((self = [self initWithName: newName inContainer: newContainer]))
    {
      [self _setRecord: objectRecord];
    }

  return self;
}

- (id) initWithName: (NSString *) newName
	 andContent: (NSString *) newContent
	inContainer: (SOGoGCSFolder *) newContainer
{
  if ((self = [self initWithName: newName inContainer: newContainer]))
    {
      ASSIGN (content, newContent);
    }

  return self;
}

- (void) dealloc
{
  [content release];
  [creationDate release];
  [lastModified release];
  [super dealloc];
}

/* accessors */

- (BOOL) isFolderish
{
  return NO;
}

/* content */

- (BOOL) isNew
{
  return isNew;
}

- (void) setIsNew: (BOOL) newIsNew
{
  isNew = newIsNew;
}

- (NSString *) contentAsString
{
  return content;
}

- (NSException *) saveContentString: (NSString *) newContent
                        baseVersion: (unsigned int) newVersion
{
  /* Note: "iCal multifolder saves" are implemented in the apt subclass! */
  GCSFolder *folder;
  NSException *ex;
  NSCalendarDate *now;

  ex = nil;

  now = [NSCalendarDate calendarDate];
  if (!content)
    ASSIGN (creationDate, now);
  ASSIGN (lastModified, now);
  ASSIGN (content, newContent);
  version = newVersion;

  folder = [container ocsFolder];
  if (folder)
    {
      ex = [folder writeContent: newContent
		   toName: nameInContainer
		   baseVersion: newVersion];
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

/* actions */

- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSException *) moveToFolder: (SOGoGCSFolder *) newFolder
{
  SOGoContentObject *newObject;
  NSException *ex;

  newObject = [[self class] objectWithName: nameInContainer
			    inContainer: newFolder];
  [newObject setIsNew: YES];
  ex = [newObject saveContentString: content];
  if (!ex)
    ex = [self delete];

  return ex;
}

- (NSException *) delete
{
  /* Note: "iCal multifolder saves" are implemented in the apt subclass! */
  GCSFolder   *folder;
  NSException *ex;
  
  // TODO: add precondition check? (or add DELETEAction?)
  
  if ((folder = [container ocsFolder]) == nil) {
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
  WORequest *rq;
  NSException *error;
  unsigned int baseVersion;
  id etag, tmp;
  BOOL needsLocation;
  WOResponse *response;

  error = [self matchesRequestConditionInContext: _ctx];
  if (error)
    response = (WOResponse *) error;
  else
    {
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
      if ([tmp isEqualToString: @"new"])
	{
	  tmp = [self globallyUniqueObjectId];
	  needsLocation = YES;

	  [self debugWithFormat:
		  @"reassigned a new location for special new-location: %@", tmp];

	  /* kinda dangerous */
	  ASSIGNCOPY (nameInContainer, tmp);
	}
  
      /* determine base version from etag in if-match header */
      /*
	Note: The -matchesRequestConditionInContext: already checks whether the
	etag matches and returns an HTTP exception in case it doesn't.
	We retrieve the etag again here to _ensure_ a transactionally save
	commit.
	(between the check and the update a change could have been done)
      */
      tmp = [rq headerForKey: @"if-match"];
      tmp = [self parseETagList: tmp];
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
	
	etag = [tmp objectAtIndex: 0];
      }
      baseVersion = (isNew ? 0 : version);
  
      /* attempt a save */
      
      error = [self saveContentString: [rq contentAsString]
		    baseVersion: baseVersion];
      if (error)
	response = (WOResponse *) error;
      else
	{
	  if (!isNew)
	    version++;
	  response = [_ctx response];
	  /* setup response */
  
	  // TODO: this should be automatic in the SoDispatcher if we return
	  // nil?
	  if (isNew)
	    [response setStatus: 201 /* Created */];
	  else
	    [response setStatus: 204 /* No Content */];
 
	  etag = [self davEntityTag];
	  if (etag)
	    {
	      [response setHeader: etag forKey: @"etag"];
	      if (needsLocation)
		[response setHeader: [self baseURLInContext:_ctx] 
			  forKey: @"location"];
	    }
	}
    }
  
  return response;
}

/* E-Tags */

- (id) davEntityTag
{
  NSString *etag;

  etag = [NSString stringWithFormat: @"<D:getetag>\"gcs%.8d\"</D:getetag>", version];

  return [SOGoWebDAVValue valueForObject: etag attributes: nil];;
}

// - (id) davEntityTag
// {
//   return [NSString stringWithFormat: @"\"gcs%.8d\"", version];
// }

/* WebDAV */
- (NSString *) davCreationDate
{
  return [creationDate rfc822DateString];
}

- (NSString *) davLastModified
{
  return [lastModified rfc822DateString];
}

- (NSString *) davContentLength
{
  return [NSString stringWithFormat: @"%u",
		   [content lengthOfBytesUsingEncoding: NSUTF8StringEncoding]];
}

- (NSString *) davResourceType
{
  return @"";
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
  NSMutableArray *pathArray;

  pathArray = [NSMutableArray arrayWithArray: [container pathArrayToFolder]];
  [pathArray addObject: nameInContainer];

  return [container aclUsersForObjectAtPath: pathArray];
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
      /* The creation of an object is actually a "modification" to an
	 unexisting object. When the object is new, we give the
	 "ObjectCreator" the "ObjectModifier" role temporarily while we
	 disallow the "ObjectModifier" users to modify them, unless they are
	 ObjectCreators too. */
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

@end /* SOGoContentObject */
