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

#import "SOGoUserFolder.h"
#import "WOContext+Agenor.h"
#import "common.h"
#import "SOGoUser.h"

#import "Appointments/SOGoAppointmentFolder.h"
#import "Contacts/SOGoContactFolders.h"

@implementation SOGoUserFolder

/* accessors */

- (NSString *)login {
  return [self nameInContainer];
}

/* hierarchy */

- (NSArray *)toManyRelationshipKeys {
  static NSArray *children = nil;
  
  if (children == nil) {
    children = [[NSArray alloc] initWithObjects:
				  @"Calendar", @"Contacts", @"Mail", nil];
  }
  return children;
}

/* ownership */

- (NSString *)ownerInContext:(id)_ctx {
  return [self login];
}

/* looking up shared objects */

- (SOGoUserFolder *)lookupUserFolder {
  return self;
}

- (SOGoGroupsFolder *)lookupGroupsFolder {
  return [self lookupName:@"Groups" inContext:nil acquire:NO];
}

/* pathes */

- (void)setOCSPath:(NSString *)_path {
  [self warnWithFormat:
          @"rejected attempt to reset user-folder path: '%@'", _path];
}
- (NSString *)ocsPath {
  return [@"/Users/" stringByAppendingString:[self login]];
}

- (NSString *)ocsUserPath {
  return [self ocsPath];
}
- (NSString *)ocsPrivateCalendarPath {
  return [[self ocsUserPath] stringByAppendingString:@"/Calendar"];
}
- (NSString *)ocsPrivateContactsPath {
  return [[self ocsUserPath] stringByAppendingString:@"/Contacts"];
}

/* name lookup */

- (id)privateCalendar:(NSString *)_key inContext:(id)_ctx {
  static Class calClass = Nil;
  id calendar;
  NSUserDefaults *userPrefs;
  NSTimeZone *timeZone;
  
  if (calClass == Nil)
    calClass = NSClassFromString(@"SOGoAppointmentFolder");
  if (calClass == Nil) {
    [self errorWithFormat:@"missing SOGoAppointmentFolder class!"];
    return nil;
  }

  calendar = [[calClass alloc] initWithName:_key inContainer:self];
  [calendar setOCSPath:[self ocsPrivateCalendarPath]];

  userPrefs = [[_ctx activeUser] userDefaults];
  timeZone = [NSTimeZone
               timeZoneWithName: [userPrefs stringForKey: @"timezonename"]];
  [calendar setTimeZone: timeZone];
  return [calendar autorelease];
}

- (SOGoContactFolders *) privateContacts: (NSString *)_key inContext:(id)_ctx
{
  static Class contactsClass = Nil;
  SOGoContactFolders *contacts;

  if (!contactsClass)
    contactsClass = NSClassFromString (@"SOGoContactFolders");
  if (!contactsClass)
    {
      [self errorWithFormat:@"missing SOGoContactFolders class!"];
      contacts = nil;
    }
  else
    {
      contacts = [[contactsClass alloc] initWithName:_key inContainer: self];
      [contacts autorelease];
      [contacts setBaseOCSPath: [self ocsPrivateContactsPath]];
    }

  return contacts;
}

- (id)groupsFolder:(NSString *)_key inContext:(id)_ctx {
  static Class fldClass = Nil;
  id folder;
  
  if (fldClass == Nil)
    fldClass = NSClassFromString(@"SOGoGroupsFolder");
  if (fldClass == Nil) {
    [self errorWithFormat:@"missing SOGoGroupsFolder class!"];
    return nil;
  }
  
  folder = [[fldClass alloc] initWithName:_key inContainer:self];
  return [folder autorelease];
}

- (id)mailAccountsFolder:(NSString *)_key inContext:(id)_ctx {
  static Class fldClass = Nil;
  id folder;
  
  if (fldClass == Nil)
    fldClass = NSClassFromString(@"SOGoMailAccounts");
  if (fldClass == Nil) {
    [self errorWithFormat:@"missing SOGoMailAccounts class!"];
    return nil;
  }
  
  folder = [[fldClass alloc] initWithName:_key inContainer:self];
  return [folder autorelease];
}

- (id)freeBusyObject:(NSString *)_key inContext:(id)_ctx {
  static Class fbClass = Nil;
  id fb;

  if (fbClass == Nil)
    fbClass = NSClassFromString(@"SOGoFreeBusyObject");
  if (fbClass == Nil) {
    [self errorWithFormat:@"missing SOGoFreeBusyObject class!"];
    return nil;
  }
  
  fb = [[fbClass alloc] initWithName:_key inContainer:self];
  return [fb autorelease];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  if ([_key hasPrefix:@"Calendar"]) {
    id calendar;
    
    calendar = [self privateCalendar:@"Calendar" inContext:_ctx];
    if ([_key isEqualToString:@"Calendar"])
      return calendar;
    
    return [calendar lookupName:[_key pathExtension] 
		     inContext:_ctx acquire:NO];
  }

  if ([_key isEqualToString:@"Contacts"])
    return [self privateContacts:_key inContext:_ctx];
  
  if ([_key isEqualToString:@"Groups"]) {
    /* Agenor requirement, return 403 to stop acquisition */
    if (![_ctx isAccessFromIntranet]) {
      return [NSException exceptionWithHTTPStatus:403 /* Forbidden */];
    }
    return [self groupsFolder:_key inContext:_ctx];
  }

  if ([_key isEqualToString:@"Mail"])
    return [self mailAccountsFolder:_key inContext:_ctx];

  if ([_key isEqualToString:@"freebusy.ifb"])
    return [self freeBusyObject:_key inContext:_ctx];

  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

/* WebDAV */

- (NSArray *)fetchContentObjectNames {
  static NSArray *cos = nil;
  
  if (!cos) {
    cos = [[NSArray alloc] initWithObjects:@"freebusy.ifb", nil];
  }
  return cos;
}

- (BOOL) davIsCollection {
  return YES;
}

@end /* SOGoUserFolder */
