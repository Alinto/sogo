/* SOGoContactFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* exchange folder types:                   */
/* MailItems                IPF.Note
   ContactItems             IPF.Contact
   AppointmentItems         IPF.Appointment
   NoteItems                IPF.StickyNote
   TaskItems                IPF.Task
   JournalItems             IPF.Journal     */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/SoUser.h>

#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SoObjects/SOGo/SOGoPermissions.h>

#import "common.h"

#import "SOGoContactGCSFolder.h"
#import "SOGoContactLDAPFolder.h"
#import "SOGoContactFolders.h"

@implementation SOGoContactFolders

- (id) init
{
  if ((self = [super init]))
    {
      contactFolders = nil;
      OCSPath = nil;
    }

  return self;
}

- (void) dealloc
{
  if (contactFolders)
    [contactFolders release];
  if (OCSPath)
    [OCSPath release];
  [super dealloc];
}

- (void) appendPersonalSourcesInContext: (WOContext *) context;
{
  SOGoContactGCSFolder *ab;
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql;
  NSArray *attrs;
  NSDictionary *row;

  cm = [GCSChannelManager defaultChannelManager];
  folderLocation
    = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if (fc)
    {
      sql
        = [NSString stringWithFormat: @"SELECT c_path4, c_foldername FROM %@"
                    @" WHERE c_path2 = '%@' AND c_folder_type = 'Contact'",
                    [folderLocation gcsTableName],
                    [self ownerInContext: nil]];
      [fc evaluateExpressionX: sql];
      attrs = [fc describeResults: NO];
      row = [fc fetchAttributes: attrs withZone: NULL];
      while (row)
        {
          ab = [SOGoContactGCSFolder contactFolderWithName: [row objectForKey: @"c_path4"]
                                     andDisplayName: [row objectForKey: @"c_foldername"]
                                     inContainer: self];
          [ab setOCSPath: [NSString stringWithFormat: @"%@/%@",
                                    OCSPath, [row objectForKey: @"c_path4"]]];
          [contactFolders setObject: ab forKey: [row objectForKey: @"c_path4"]];
          row = [fc fetchAttributes: attrs withZone: NULL];
        }

      [cm releaseChannel: fc];
//       sql = [sql stringByAppendingFormat:@" WHERE %@ = '%@'", 
//                  uidColumnName, [self uid]];
    }
}

- (WOResponse *) newFolderWithName: (NSString *) name
{
  SOGoContactGCSFolder *newFolder;
  WOResponse *response;

  newFolder = [SOGoContactGCSFolder contactFolderWithName: name
                                    andDisplayName: name
                                    inContainer: [self clientObject]];
  if ([newFolder isKindOfClass: [NSException class]])
    response = (WOResponse *) newFolder;
  else
    {
      [newFolder setOCSPath: [NSString stringWithFormat: @"%@/%@",
                                       OCSPath, name]];
      if ([newFolder create])
        {
          response = [WOResponse new];
          [response setStatus: 201];
          [response autorelease];
        }
      else
        response = [NSException exceptionWithHTTPStatus: 400
                                reason: @"The new folder could not be created"];
    }

  return response;
}

- (void) appendSystemSourcesInContext: (WOContext *) context;
{
  NSUserDefaults *ud;
  NSEnumerator *ldapABs;
  NSDictionary *udAB;
  SOGoContactLDAPFolder *ab;

  ud = [NSUserDefaults standardUserDefaults];
  ldapABs = [[ud objectForKey: @"SOGoLDAPAddressBooks"] objectEnumerator];
  udAB = [ldapABs nextObject];
  while (udAB)
    {
      ab = [SOGoContactLDAPFolder contactFolderWithName:
                                    [udAB objectForKey: @"id"]
                                  andDisplayName:
                                    [udAB objectForKey: @"displayName"]
                                  inContainer: self];
      [ab LDAPSetHostname: [udAB objectForKey: @"hostname"]
          setPort: [[udAB objectForKey: @"port"] intValue]
          setBindDN: [udAB objectForKey: @"bindDN"]
          setBindPW: [udAB objectForKey: @"bindPW"]
          setContactIdentifier: [udAB objectForKey: @"idField"]
          setUserIdentifier: [udAB objectForKey: @"userIdField"]
          setRootDN: [udAB objectForKey: @"rootDN"]];
      [contactFolders setObject: ab forKey: [udAB objectForKey: @"id"]];
      udAB = [ldapABs nextObject];
    }
}

- (void) initContactSourcesInContext: (WOContext *) context;
{
  if (!contactFolders)
    {
      contactFolders = [NSMutableDictionary new];
      [self appendPersonalSourcesInContext: context];
      [self appendSystemSourcesInContext: context];
    }
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) context
          acquire: (BOOL) acquire
{
  id obj;
  id folder;

  /* first check attributes directly bound to the application */
  obj = [super lookupName: name inContext: context acquire: NO];
  if (!obj)
    {
      if (!contactFolders)
        [self initContactSourcesInContext: context];

      folder = [contactFolders objectForKey: name];
      obj = ((folder)
             ? folder
             : [NSException exceptionWithHTTPStatus: 404]);
    }

  return obj;
}

- (NSArray *) toManyRelationshipKeys
{
  WOContext *context;

  if (!contactFolders)
    {
      context = [[WOApplication application] context];
      [self initContactSourcesInContext: context];
    }

  return [contactFolders allKeys];
}

- (NSArray *) contactFolders
{
  WOContext *context;

  if (!contactFolders)
    {
      context = [[WOApplication application] context];
      [self initContactSourcesInContext: context];
    }

  return [contactFolders allValues];
}

- (NSString *) roleOfUser: (NSString *) uid
                inContext: (WOContext *) context
{
  NSArray *roles, *traversalPath;
  NSString *objectName, *role;

  role = nil;
  traversalPath = [context objectForKey: @"SoRequestTraversalPath"];
  if ([traversalPath count] > 2)
    {
      objectName = [traversalPath objectAtIndex: 2];
      if ([objectName isEqualToString: @"personal"])
        {
          roles = [[context activeUser]
                    rolesForObject: [self lookupName: objectName
                                          inContext: context
                                          acquire: NO]
                    inContext: context];
          if ([roles containsObject: SOGoRole_Assistant]
              || [roles containsObject: SOGoRole_Delegate])
            role = SOGoRole_Assistant;
        }
    }

  return role;
}

- (BOOL) davIsCollection
{
  return YES;
}

- (void) setBaseOCSPath: (NSString *) newOCSPath
{
  if (OCSPath)
    [OCSPath release];
  OCSPath = newOCSPath;
  if (OCSPath)
    [OCSPath retain];
}

/* web interface */
- (NSString *) defaultSourceName
{
  return @"personal";
}

@end
