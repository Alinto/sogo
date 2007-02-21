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

#import <NGObjWeb/SoObject.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderType.h>

#import "SOGoFolder.h"
#import "common.h"
#import <unistd.h>
#import <stdlib.h>

#import "SOGoAclsFolder.h"

@implementation SOGoFolder

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

+ (NSString *)globallyUniqueObjectId {
  /*
    4C08AE1A-A808-11D8-AC5A-000393BBAFF6
    SOGo-Web-28273-18283-288182
    printf( "%x", *(int *) &f);
  */
  static int   pid = 0;
  static int   sequence = 0;
  static float rndm = 0;
  float f;

  if (pid == 0) { /* break if we fork ;-) */
    pid = getpid();
    rndm = random();
  }
  sequence++;
  f = [[NSDate date] timeIntervalSince1970];
  return [NSString stringWithFormat:@"%0X-%0X-%0X-%0X",
		   pid, *(int *)&f, sequence++, random];
}

- (void)dealloc {
  [self->ocsFolder release];
  [self->ocsPath   release];
  [super dealloc];
}

/* accessors */

- (BOOL)isFolderish {
  return YES;
}

- (void)setOCSPath:(NSString *)_path {
  if ([self->ocsPath isEqualToString:_path])
    return;
  
  if (self->ocsPath)
    [self warnWithFormat:@"GCS path is already set! '%@'", _path];
  
  ASSIGNCOPY(self->ocsPath, _path);
}

- (NSString *)ocsPath {
  return self->ocsPath;
}

- (GCSFolderManager *)folderManager {
  return [GCSFolderManager defaultFolderManager];
}

- (GCSFolder *)ocsFolderForPath:(NSString *)_path {
  return [[self folderManager] folderAtPath:_path];
}

- (GCSFolder *) ocsFolder {
  GCSFolder *folder;

  if (!ocsFolder)
    ocsFolder = [[self ocsFolderForPath:[self ocsPath]] retain];

  if ([ocsFolder isNotNull])
    folder = ocsFolder;
  else
    folder = nil;

  return folder;
}

- (NSString *) folderType
{
  return @"";
}

- (BOOL) create
{
  NSException *result;

  [GCSFolderType setFolderNamePrefix: @"SOGo_"];

  result = [[self folderManager] createFolderOfType: [self folderType]
                                 atPath: ocsPath];

  return (result == nil);
}

- (NSArray *)fetchContentObjectNames {
  NSArray *fields, *records;
  
  fields = [NSArray arrayWithObject:@"c_name"];
  records = [[self ocsFolder] fetchFields:fields matchingQualifier:nil];
  if (![records isNotNull]) {
    [self errorWithFormat:@"(%s): fetch failed!", __PRETTY_FUNCTION__];
    return nil;
  }
  if ([records isKindOfClass:[NSException class]])
    return records;
  return [records valueForKey:@"c_name"];
}

- (BOOL) nameExistsInFolder: (NSString *) objectName
{
  NSArray *fields, *records;
  EOQualifier *qualifier;

  qualifier
    = [EOQualifier qualifierWithQualifierFormat:
                     [NSString stringWithFormat: @"c_name='%@'", objectName]];

  fields = [NSArray arrayWithObject: @"c_name"];
  records = [[self ocsFolder] fetchFields: fields
                              matchingQualifier: qualifier];
  return (records
          && ![records isKindOfClass:[NSException class]]
          && [records count] > 0);
}

- (NSDictionary *)fetchContentStringsAndNamesOfAllObjects {
  NSDictionary *files;
  
  files = [[self ocsFolder] fetchContentsOfAllFiles];
  if (![files isNotNull]) {
    [self errorWithFormat:@"(%s): fetch failed!", __PRETTY_FUNCTION__];
    return nil;
  }
  if ([files isKindOfClass:[NSException class]])
    return files;
  return files;
}

/* reflection */

- (NSString *)defaultFilenameExtension {
  /* 
     Override to add an extension to a filename
     
     Note: be careful with that, needs to be consistent with object lookup!
  */
  return nil;
}

- (NSArray *) davResourceType
{
  NSArray *rType, *groupDavCollection;

  if ([self respondsToSelector: @selector (groupDavResourceType)])
    {
      groupDavCollection = [NSArray arrayWithObjects: [self groupDavResourceType],
                                    @"http://groupdav.org/", @"G", nil];
      rType = [NSArray arrayWithObjects: @"collection", groupDavCollection, nil];
    }
  else
    rType = [NSArray arrayWithObject: @"collection"];

  return rType;
}

- (NSArray *) toOneRelationshipKeys {
  /* toOneRelationshipKeys are the 'files' contained in a folder */
  NSMutableArray *ma;
  NSArray  *names;
  NSString *name, *ext;
  unsigned i, count;
  NSRange  r;

  names = [self fetchContentObjectNames];
  count = [names count];
  ext = [self defaultFilenameExtension];
  if (count && [ext length] > 0)
    {
      ma = [NSMutableArray arrayWithCapacity: count];
      for (i = 0; i < count; i++)
        {
          name = [names objectAtIndex: i];
          r = [name rangeOfString: @"."];
          if (r.length == 0)
            name = [[name stringByAppendingString:@"."] stringByAppendingString: ext];
          [ma addObject:name];
        }

      names = ma;
    }

  return names;
}

/* WebDAV */

- (BOOL)davIsCollection {
  return [self isFolderish];
}

/* folder type */

- (NSString *)outlookFolderClass {
  return nil;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  [super appendAttributesToDescription:_ms];
  
  [_ms appendFormat:@" ocs=%@", [self ocsPath]];
}

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"<0x%08X[%@]:%@>",
		   self, NSStringFromClass([self class]),
		   [self nameInContainer]];
}

@end /* SOGoFolder */
