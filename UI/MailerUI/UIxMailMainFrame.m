/*
  Copyright (C) 2007-2014 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSValue.h>


#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <Contacts/SOGoContactGCSList.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactLDIFEntry.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailLabel.h>
#import <Mailer/SOGoSentFolder.h>
#import <SOGo/NSDictionary+URL.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserSettings.h>

#import "UIxMailMainFrame.h"

// Avoid compilation warnings
@interface SOGoUserFolder (private)

- (SOGoAppointmentFolders *) privateContacts: (NSString *) key
				   inContext: (WOContext *) localContext;

@end

@implementation UIxMailMainFrame

- (id) init
{
  if ((self = [super init]))
    {
      folderType = 0;
    }

  return self;
}

- (void) dealloc
{
  RELEASE(_currentLabel);
  [super dealloc];
}

- (NSString *) modulePath
{
  return @"Mail";
}

- (void) _setupContext
{
  SOGoUser *activeUser;
  NSString *module;
  SOGoMailAccounts *clientObject;

  activeUser = [context activeUser];
  clientObject = [self clientObject];

  module = [clientObject nameInContainer];

  us = [activeUser userSettings];
  moduleSettings = [us objectForKey: module];
  if (!moduleSettings)
    {
      moduleSettings = [NSMutableDictionary dictionary];
      [us setObject: moduleSettings forKey: module];
    }
}

/* accessors */

- (NSString *) mailAccounts
{
  NSArray *accounts;

  accounts = [[self clientObject] mailAccounts];

  return [accounts jsonRepresentation];
}

- (WOResponse *) mailAccountsAction
{
  WOResponse *response;
  NSString *s;

  s = [self mailAccounts];
  response = [self responseWithStatus: 200
                            andString: s];

  return response;
}

- (NSString *) userNames
{
  NSArray *accounts, *userNames;
  
  accounts = [[self clientObject] mailAccounts];
  userNames = [accounts objectsForKey: @"userName" notFoundMarker: nil];
  
  return [userNames jsonRepresentation];
}

- (NSString *) pageFormURL
{
  NSString *u;
  NSRange  r;
  
  u = [[[self context] request] uri];
  if ((r = [u rangeOfString:@"?"]).length > 0) {
    /* has query parameters */
    // TODO: this is ugly, create reusable link facility in SOPE
    // TODO: remove 'search' and 'filterpopup', preserve sorting
    NSMutableString *ms;
    NSArray    *qp;
    NSUInteger i, count;
    
    qp    = [[u substringFromIndex:(r.location + r.length)] 
	        componentsSeparatedByString:@"&"];
    count = [qp count];
    ms    = [NSMutableString stringWithCapacity:count * 12];
    
    for (i = 0; i < count; i++) {
      NSString *s;
      
      s = [qp objectAtIndex:i];
      
      /* filter out */
      if ([s hasPrefix:@"search="]) continue;
      if ([s hasPrefix:@"filterpopup="]) continue;
      
      if ([ms length] > 0) [ms appendString:@"&"];
      [ms appendString:s];
    }
    
    if ([ms length] == 0) {
      /* no other query params */
      u = [u substringToIndex:r.location];
    }
    else {
      u = [u substringToIndex:r.location + r.length];
      u = [u stringByAppendingString:ms];
    }
    return u;
  }
  return [u hasSuffix:@"/"] ? @"view" : @"#";
}

- (id <WOActionResults>) composeAction
{
  id contact;
  NSArray *contactsId, *cards;
  NSString *newLocation, *parameters, *folderId, *uid, *formattedMail;
  NSEnumerator *uids;
  NSMutableArray *addresses;
  NGVCard *card;
  NGVList *list;
  SOGoMailAccounts *co;
  SOGoContactFolders *folders;
  SOGoParentFolder *folder;
  WORequest  *request;
  NSUInteger i, count;

  parameters = nil;
  co = [self clientObject];
  
  request = [context request];
  
  if ((folderId = [request formValueForKey: @"folder"]) &&
      (contactsId = [request formValuesForKey: @"uid"]))
    {
      // Retrieve the email addresses from the specified address book
      // and contact IDs
      folders = (SOGoContactFolders *)[[[self clientObject] container] privateContacts: @"Contacts"
                                                                             inContext: nil];
      folder = [folders lookupName: folderId
                         inContext: nil
                           acquire: NO];
      if (folder)
        {
          uids = [contactsId objectEnumerator];
          uid = [uids nextObject];

          addresses = [NSMutableArray array];

          while (uid)
            {
              contact = [folder lookupName: uid
                                 inContext: [self context]
                                   acquire: NO];
              if ([contact isKindOfClass: [SOGoContactGCSList class]])
                {
                  list = [(SOGoContactGCSList *)contact vList];
                  cards = [list cardReferences];
                  count = [cards count];
                  for (i = 0; i < count; i++)
		    {
		      formattedMail = [self formattedMailtoString: [cards objectAtIndex: i]];
		      if (formattedMail)
			[addresses addObject: formattedMail];
		    }
                }
              else if ([contact isKindOfClass: [SOGoContactGCSEntry class]]
		       || [contact isKindOfClass: [SOGoContactLDIFEntry class]])
                {
                  // We fetch the preferred email address of the contact or
                  // the first defined email address
                  card = [contact vCard];
		  formattedMail = [self formattedMailtoString: card];
		  if (formattedMail)
		    [addresses addObject: formattedMail];
                }
	      
              uid = [uids nextObject];
            }

          if ([addresses count] > 0)
	    parameters = [NSString stringWithFormat: @"?mailto=%@", 
                                   [addresses jsonRepresentation]];
        }
    }
  else if ([[request formValues] objectForKey: @"mailto"])
    // We use the email addresses defined in the request
    parameters = [[request formValues] asURLParameters];

  if (!parameters)
    // No parameter passed; simply open the compose window
    parameters = @"?mailto=";

  newLocation = [NSString stringWithFormat: @"%@/0/compose%@",
                 [co baseURLInContext: context],
                 parameters];

  return [self redirectToLocation: newLocation];
}

- (NSString *) formattedMailtoString: (NGVCard *) card
{
  NSString *firstName, *lastName, *email;
  NSMutableString *fn, *rc = nil;
  CardElement *n;

  if ([card isKindOfClass: [NGVCard class]])
    email = [card preferredEMail];
  else
    email = [(NGVCardReference *)card email];

  if (email == nil)
    email = (NSString*)[card firstChildWithTag: @"EMAIL"];

  if (email)
    {
      email = [NSString stringWithFormat: @"<%@>", email];

      // We append the contact's name
      fn = [NSMutableString stringWithString: [card fn]];
      if ([fn length] == 0
	  && [card isKindOfClass: [NGVCard class]])
        {
          n = [card n];
          lastName = [n flattenedValueAtIndex: 0 forKey: @""];
          firstName = [n flattenedValueAtIndex: 1 forKey: @""];
          if ([firstName length] > 0)
            {
              if ([lastName length] > 0)
                fn = [NSMutableString stringWithFormat: @"%@ %@", firstName, lastName];
              else
                fn = [NSMutableString stringWithString: firstName];
            }
          else if ([lastName length] > 0)
            fn = [NSMutableString stringWithString: lastName];
        }
      if ([fn length] > 0)
        {
          [fn appendFormat: @" %@", email];
          rc = fn;
        }
      else
        rc = [NSMutableString stringWithString: email];
    }

  return rc;
}

- (WOResponse *) getFoldersStateAction
{
  id o;
  NSArray *expandedFolders;

  [self _setupContext];
  o = [moduleSettings objectForKey: @"ExpandedFolders"];
  if ([o isKindOfClass: [NSString class]])
    expandedFolders = [o componentsSeparatedByString: @","];
  else
    expandedFolders = o;

  return [self responseWithStatus: 200 andJSONRepresentation: expandedFolders];
}

- (NSString *) verticalDragHandleStyle
{
   NSString *vertical;

   [self _setupContext];
   vertical = [moduleSettings objectForKey: @"DragHandleVertical"];
   
   return ((vertical && [vertical intValue] > 0) ? (id)[vertical stringByAppendingString: @"px"] : nil);
}

- (NSString *) horizontalDragHandleStyle
{
   NSString *horizontal;

   [self _setupContext];
   horizontal = [moduleSettings objectForKey: @"DragHandleHorizontal"];

   return ((horizontal && [horizontal intValue] > 0) ? (id)[horizontal stringByAppendingString: @"px"] : nil);
}

- (NSString *) mailboxContentStyle
{
   NSString *height;

   [self _setupContext];
   height = [moduleSettings objectForKey: @"DragHandleVertical"];

   return ((height && [height intValue] > 0) ? (id)[NSString stringWithFormat: @"%ipx", ([height intValue] - 27)] : nil);
}

- (WOResponse *) saveDragHandleStateAction
{
  WORequest *request;
  NSString *dragHandle;
  
  [self _setupContext];
  request = [context request];

  if ((dragHandle = [request formValueForKey: @"vertical"]) != nil)
    [moduleSettings setObject: dragHandle
		    forKey: @"DragHandleVertical"];
  else if ((dragHandle = [request formValueForKey: @"horizontal"]) != nil)
    [moduleSettings setObject: dragHandle
		    forKey: @"DragHandleHorizontal"];
  else
    return [self responseWithStatus: 400];
  
  [us synchronize];
  
  return [self responseWithStatus: 204];
}

- (WOResponse *) saveFoldersStateAction
{
  WORequest *request;
  NSArray *expandedFolders;
  
  [self _setupContext];
  request = [context request];
  expandedFolders = [[request contentAsString] objectFromJSONString];

  [moduleSettings setObject: expandedFolders
                     forKey: @"ExpandedFolders"];

  [us synchronize];

  return [self responseWithStatus: 204];
}

- (NSString *) columnsState
{
   NSDictionary *columns;

   [self _setupContext];
   columns = [moduleSettings objectForKey: @"ColumnsState"];
   
   return [columns jsonRepresentation];
}

- (WOResponse *) saveColumnsStateAction
{
  WORequest *request;
  NSDictionary *columns;
  NSArray *columnsIds, *widths;
  
  [self _setupContext];
  request = [context request];

  columnsIds = [[request formValueForKey: @"columns"] componentsSeparatedByString: @","];
  widths = [[request formValueForKey: @"widths"] componentsSeparatedByString: @","];
  if (columnsIds != nil && widths != nil && [columnsIds count] == [widths count])
    {
      columns = [NSDictionary dictionaryWithObjects: widths
					    forKeys: columnsIds];
      [moduleSettings setObject: columns
			 forKey: @"ColumnsState"];
    }
  else
    return [self responseWithStatus: 400];
  
  [us synchronize];
  
  return [self responseWithStatus: 204];
}

- (id) defaultAction
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];
  if ([ud rememberLastModule])
    {
      [ud setLoginModule: @"Mail"];
      [ud synchronize];
    }

  return [super defaultAction];
}

- (unsigned int) _unseenCountForFolder: (NSString *) theFolder
{
  NSArray *pathComponents;
  SOGoMailAccount *account;
  SOGoMailFolder *folder;

  pathComponents = [theFolder pathComponents];
  account = [[self clientObject] lookupName: [pathComponents objectAtIndex: 0]
                                  inContext: context
                                    acquire: YES];
  folder = [account lookupNameByPaths: [pathComponents subarrayWithRange: NSMakeRange(1, [pathComponents count]-1)]
                            inContext: context
                              acquire: YES];

  return [folder unseenCount];
}

- (WOResponse *) unseenCountAction
{
  NSMutableDictionary *data;
  WOResponse *response;
  NSArray *folders;
  NSString *folder;
  int i;

  folders = [[[[context request] contentAsString] objectFromJSONString] objectForKey: @"mailboxes"];
  data = [NSMutableDictionary dictionary];

  for (i = 0; i < [folders count]; i++)
    {
      folder = [folders objectAtIndex: i];
      [data setObject: [NSNumber numberWithUnsignedInt: [self _unseenCountForFolder: folder]]
               forKey: folder];
    }

  response = [self responseWithStatus: 200];

  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [data jsonRepresentation]];

  return response;
}

- (NSString *) unseenCountFolders
{
  NSArray *pathComponents, *filters, *actions;
  NSDictionary *d, *action;
  NSMutableArray *folders;
  NSMutableString *path;
  NSString *component;
  SOGoUserDefaults *ud;
  NSString   *s;
  NSUInteger i, j, k;

  // If Sieve scripts aren't enabled, there's no need in considering
  // what's potentially in the database regarding "fileinto" scripts.
  if (![[[context activeUser] domainDefaults] sieveScriptsEnabled])
    return [[NSArray array] jsonRepresentation];

  ud = [[context activeUser] userDefaults];
  folders = [NSMutableArray array];

  filters = [ud sieveFilters];

  for (i = 0; i < [filters count]; i++)
    {
      d = [filters objectAtIndex: i];      
      actions = [d objectForKey: @"actions"];

      for (j = 0; j < [actions count]; j++)
	{
	  action = [actions objectAtIndex: j];
	  
	  if ([[action objectForKey: @"method"] caseInsensitiveCompare: @"fileinto"] == NSOrderedSame)
	    {
	      s = [action objectForKey: @"argument"];
	      
	      // We format the result string so that MailerUI.js can simply consume that information
	      // without doing anything special on its side
	      if (s)
		{
		  pathComponents = [s componentsSeparatedByString: @"/"];
		  path = [NSMutableString string];

		  for (k = 0; k < [pathComponents count]; k++)
		    {
                      component = [[pathComponents objectAtIndex: k] asCSSIdentifier];
                      [path appendString: [NSString stringWithFormat: @"folder%@", component]];
		      if (k < [pathComponents count] - 1)
			[path appendString: @"/"];
		    }
		  
		  [folders addObject: [NSString stringWithFormat: @"0/%@", path]];
		}
	    }
	}
    }
  
  return [folders jsonRepresentation];
}

//
// Standard mapping done by Thunderbird:
//
// label1 => Important
// label2 => Work
// label3 => Personal
// label4 => To Do
// label5 => Later
//
- (NSArray *) availableLabels
{
  NSDictionary *v;

  v = [[[context activeUser] userDefaults] mailLabelsColors];

  return [SOGoMailLabel labelsFromDefaults: v  component: self];
}

- (void) setCurrentLabel: (SOGoMailLabel *) theCurrentLabel
{
  ASSIGN(_currentLabel, theCurrentLabel);
}

- (SOGoMailLabel *) currentLabel
{
  return _currentLabel;
}

@end /* UIxMailMainFrame */

@interface UIxMailFolderTemplate : UIxComponent
@end

@implementation UIxMailFolderTemplate
@end

@interface UIxMailViewTemplate : UIxComponent
@end

@implementation UIxMailViewTemplate
@end
