/* MAPIApplication.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2010 Wolfgang Sourdeau
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

#import <Foundation/NSUserDefaults.h>

#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <Appointments/iCalEntityObject+SOGo.h>

#import "MAPIStoreContext.h"

#import "MAPIApplication.h"

MAPIApplication *MAPIApp = nil;

@interface UnixSignalHandler : NSObject

+ sharedHandler;

- (void)removeObserver:(id)observer;

@end

@implementation MAPIApplication

- (id) init
{
        SOGoProductLoader *loader;
        NSUserDefaults *ud;
        SOGoSystemDefaults *sd;

        if (!MAPIApp) {
                /* Here we work around a bug in GNUstep which decodes XML user
                   defaults using the system encoding rather than honouring
                   the encoding specified in the file. */
                putenv ("GNUSTEP_STRING_ENCODING=NSUTF8StringEncoding");

                sd = [SOGoSystemDefaults sharedSystemDefaults];

                // /* We force the plugin to base its configuration on the SOGo tree. */
                ud = [NSUserDefaults standardUserDefaults];
                [ud registerDefaults: [ud persistentDomainForName: @"sogod"]];

                NSLog (@"(config check) imap server: %@", [sd imapServer]);

                // TODO publish
                loader = [SOGoProductLoader productLoader];
                [loader loadProducts: [NSArray arrayWithObjects:
                                                 @"Contacts.SOGo",
                                               @"Appointments.SOGo",
                                               @"Mailer.SOGo",
                                               nil]];

                // TODO publish
                [iCalEntityObject initializeSOGoExtensions];

                MAPIApp = [super init];
                [MAPIApp retain];

                /* This is a hack to revert what is done in [WOCoreApplication
                   init] */
                [[NSClassFromString(@"UnixSignalHandler") sharedHandler]
                  removeObserver: self];
        }

        return MAPIApp;
}

- (void) dealloc
{
        [mapiContext release];
        [super dealloc];
}

- (void) setMAPIStoreContext: (MAPIStoreContext *) newMAPIStoreContext
{
        ASSIGN (mapiContext, newMAPIStoreContext);
}

- (id) authenticatorInContext: (id) context
{
        return [mapiContext authenticator];
}

@end
