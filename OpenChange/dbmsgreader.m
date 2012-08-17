/* dbmsgreader.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

/* A format-agnostic property list readerer.
   Usage: dbmsgreader [username] [filename] */

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSUserDefaults.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGObjWeb/SoProductRegistry.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoSystemDefaults.h>

#import "MAPIStoreUserContext.h"
#import "SOGoMAPIDBObject.h"

#import "NSObject+PropertyList.m"

Class MAPIStoreUserContextK, SOGoMAPIDBObjectK;

static void
DbDumpObject (NSString *username, NSString *path)
{
  id ctx;
  NSData *content;
  id dbobject;
  NSDictionary *record;

  ctx = [MAPIStoreUserContextK userContextWithUsername: username
                                        andTDBIndexing: NULL];
  dbobject = [SOGoMAPIDBObjectK new];
  [dbobject setTableUrl: [ctx folderTableURL]];
  record = [dbobject lookupRecord: path newerThanVersion: -1];
  if (record)
    {
      content = [[record objectForKey: @"c_content"] dataByDecodingBase64];
      OCDumpPListData (content);
    }
  else
    NSLog (@"record not found");

  [dbobject release];
}

int main (int argc, char *argv[], char *envp[])
{
  NSAutoreleasePool *pool;
  SOGoProductLoader *loader;
  NSUserDefaults *ud;
  SoProductRegistry *registry;
  NSArray *arguments;

  /* Here we work around a bug in GNUstep which decodes XML user
     defaults using the system encoding rather than honouring
     the encoding specified in the file. */
  putenv ("GNUSTEP_STRING_ENCODING=NSUTF8StringEncoding");

  pool = [NSAutoreleasePool new];

  [SOGoSystemDefaults sharedSystemDefaults];

  /* We force the plugin to base its configuration on the SOGo tree. */
  ud = [NSUserDefaults standardUserDefaults];
  [ud registerDefaults: [ud persistentDomainForName: @"sogod"]];

  [NSProcessInfo initializeWithArguments: argv
                                   count: argc
                             environment: envp];

  registry = [SoProductRegistry sharedProductRegistry];
  [registry scanForProductsInDirectory: SOGO_BUNDLES_DIR];

  loader = [SOGoProductLoader productLoader];
  [loader loadProducts: [NSArray arrayWithObject: BACKEND_BUNDLE_NAME]];

  MAPIStoreUserContextK = NSClassFromString (@"MAPIStoreUserContext");
  SOGoMAPIDBObjectK = NSClassFromString (@"SOGoMAPIDBObject");

  arguments = [[NSProcessInfo processInfo] arguments];
  if ([arguments count] > 2)
    DbDumpObject ([arguments objectAtIndex: 1],
                  [arguments objectAtIndex: 2]);

  [pool release];

  return 0;
}
