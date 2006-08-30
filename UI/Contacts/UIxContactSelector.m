/*
 Copyright (C) 2000-2004 SKYRIX Software AG
 
 This file is part of OGo
 
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
// $Id: UIxContactSelector.m 394 2004-10-14 08:47:35Z znek $

#import <NGExtensions/NGExtensions.h>

#import <SOGoUI/UIxComponent.h>
#import <SOGo/AgenorUserManager.h>
#import <Scheduler/iCalPerson+UIx.h>

#import "common.h"

#import "UIxContactSelector.h"

@implementation UIxContactSelector

- (id)init {
  if ((self = [super init])) {
    [self setTitle:@"UIxContacts"];
    [self setWindowId:@"UIxContacts"];
    [self setCallback:@"undefined"];
  }
  return self;
}

- (void)dealloc {
  [self->title    release];
  [self->windowId release];
  [self->callback release];
  [super dealloc];
}

/* accessors */

- (void)setTitle:(NSString *)_title {
  ASSIGNCOPY(self->title, _title);
}
- (NSString *)title {
  return self->title;
}

- (void)setWindowId:(NSString *)_winId {
  ASSIGNCOPY(self->windowId, _winId);
}
- (NSString *)windowId {
  return self->windowId;
}

- (void)setSelectorId:(NSString *)_selId {
  ASSIGNCOPY(selectorId, _selId);
}

- (NSString *)selectorId {
  return selectorId;
}

- (NSString *)selectorIdList {
  return [NSString stringWithFormat: @"uixselector-%@-uidList", selectorId];
}

- (NSString *)selectorIdDisplay {
  return [NSString stringWithFormat: @"uixselector-%@-display", selectorId];
}

- (void)setCallback:(NSString *)_callback {
  ASSIGNCOPY(self->callback, _callback);
}
- (NSString *)callback {
  return self->callback;
}

/* Helper */

- (NSString *)relativeContactsPath {
  return [self relativePathToUserFolderSubPath:@"Contacts/select"];
}

/* JavaScript */

- (NSString *)jsFunctionName {
  return [NSString stringWithFormat:@"openUIxContactsListViewWindowWithId%@",
    [self windowId]];
}

- (NSString *)jsFunctionHref {
  return [NSString stringWithFormat:@"javascript:%@()",
    [self jsFunctionName]];
}

- (NSString *)jsCode {
  static NSString *codeFmt = \
  @"function %@() {\n"
  @"  var url = '%@?callback=%@';\n"
  @"  var contactsWindow = window.open(url, '%@', 'width=600, height=400, left=10, top=10, toolbar=no, dependent=yes, menubar=no, location=no, resizable=yes, scrollbars=yes, directories=no, status=no');\n"
  @"  contactsWindow.focus();\n"
  @"}";
  return [NSString stringWithFormat:codeFmt,
    [self jsFunctionName],
    [self relativeContactsPath],
    [self callback],
    [self windowId]];
}

- (void) setContacts: (NSArray *) _contacts
{
  contacts = _contacts;
}

- (NSArray *) contacts
{
  return contacts;
}

- (NSArray *) getICalPersonsFromValue: (NSString *) selectorValue
{
  NSMutableArray *persons;
  NSEnumerator *uids;
  NSString *uid;

  persons = [NSMutableArray new];
  [persons autorelease];

  if ([selectorValue length] > 0)
    {
      uids = [[selectorValue componentsSeparatedByString: @","]
               objectEnumerator];
      uid = [uids nextObject];
      while (uid)
        {
          [persons addObject: [iCalPerson personWithUid: uid]];
          uid = [uids nextObject];
        }
    }

  return persons;
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  contacts = [self getICalPersonsFromValue: [_rq formValueForKey: selectorId]];
  if ([contacts count] > 0)
    NSLog (@"  got %i attendees: %@", [contacts count], contacts);
  else
    NSLog (@"go no attendees!");
}

- (void) setCurrentContact: (iCalPerson *) aContact
{
  currentContact = aContact;
}

- (NSString *) initialContactsAsString
{
  NSEnumerator *persons;
  iCalPerson *person;
  NSMutableArray *participants;

  participants = [NSMutableArray arrayWithCapacity: [contacts count]];
  persons = [contacts objectEnumerator];
  person = [persons nextObject];
  while (person)
    {
      [participants addObject: [person cn]];
      person = [persons nextObject];
    }

  return [participants componentsJoinedByString: @","];
}

- (NSString *) currentContactId
{
  return [currentContact cn];
}

- (NSString *) currentContactName
{
  return [currentContact cn];
}

@end /* UIxContactSelector */
