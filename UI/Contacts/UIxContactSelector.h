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

#ifndef UIXCONTACTSELECTOR_H
#define UIXCONTACTSELECTOR_H

@interface UIxContactSelector : UIxComponent
{
  NSString *title;
  NSString *windowId;
  NSString *selectorId;
  NSString *callback;

  NSArray *contacts;
  iCalPerson *currentContact;
}

- (void)setTitle:(NSString *)_title;
- (NSString *)title;
- (void)setWindowId:(NSString *)_winId;
- (NSString *)windowId;
- (void)setSelectorId:(NSString *)_selId;
- (NSString *)selectorId;
- (void)setCallback:(NSString *)_callback;
- (NSString *)callback;

- (void) setContacts: (NSArray *) _contacts;
- (NSArray *) contacts;

- (void) setCurrentContact: (iCalPerson *) aContact;
- (NSString *) currentContactId;
- (NSString *) currentContactName;
- (NSString *) initialContactsAsString;

- (NSString *)relativeContactsPath;

- (NSString *)jsFunctionName;
- (NSString *)jsFunctionHref;
- (NSString *)jsCode;
@end

#endif /* UIXCONTACTSELECTOR_H */
