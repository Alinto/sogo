/*
  Copyright (C) 2007-2009 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSUserDefaults.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NGVList.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/SoComponent.h>
#import <NGExtensions/NSString+misc.h>

#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactGCSList.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactFolders.h>

#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailAccounts.h>
#import <SoObjects/SOGo/NSDictionary+URL.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserFolder.h>
#import <SOGoUI/UIxComponent.h>

#import "UIxMailMainFrame.h"

// Avoid compilation warnings
@interface SOGoUserFolder (private)

- (SOGoAppointmentFolders *) privateContacts: (NSString *) key
				   inContext: (WOContext *) localContext;

@end


@implementation UIxMailMainFrame

- (void) _setupContext
{
  SOGoUser *activeUser;
  NSString *login, *module;
  SOGoMailAccounts *clientObject;

  activeUser = [context activeUser];
  login = [activeUser login];
  clientObject = [self clientObject];

  module = [clientObject nameInContainer];

  ud = [activeUser userSettings];
  moduleSettings = [ud objectForKey: module];
  if (!moduleSettings)
    {
      moduleSettings = [NSMutableDictionary new];
      [moduleSettings autorelease];
    }
  [ud setObject: moduleSettings forKey: module];
}

/* accessors */

#warning this method is a duplication of SOGoMailAccounts:toManyRelationShipKeys
- (NSString *) mailAccounts
{
  NSArray *accounts, *accountNames;

  accounts = [[context activeUser] mailAccounts];
  accountNames = [accounts objectsForKey: @"name" notFoundMarker: nil];

  return [accountNames jsonRepresentation];
}

- (NSString *) defaultColumnsOrder
{
  NSArray *defaultColumnsOrder;
  NSUserDefaults *sud;
  
  sud = [NSUserDefaults standardUserDefaults];
  defaultColumnsOrder = [NSArray arrayWithArray: [sud arrayForKey: @"SOGoMailListViewColumnsOrder"]];
  if ( [defaultColumnsOrder count] == 0 )
  {
    defaultColumnsOrder = [NSArray arrayWithObjects: @"Flagged", @"Attachment", @"Subject", 
      @"From", @"Unread", @"Date", @"Priority", nil];
  }
    
  return [defaultColumnsOrder jsonRepresentation];
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
    NSArray  *qp;
    unsigned i, count;
    
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
  NSArray *accounts, *contactsId, *cards;
  NSString *firstAccount, *newLocation, *parameters, *folderId, *uid;
  NSEnumerator *uids;
  NSMutableArray *addresses;
  NGVCard *card;
  NGVList *list;
  SOGoMailAccounts *co;
  SOGoContactFolders *folders;
  SOGoParentFolder *folder;
  WORequest *request;
  int i, count;

  parameters = nil;
  co = [self clientObject];
  
  // We use the first mail account
  accounts = [[context activeUser] mailAccounts];
  firstAccount = [[accounts objectsForKey: @"name" notFoundMarker: nil]
		   objectAtIndex: 0];
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

          addresses = [NSMutableArray new];

          while (uid)
            {
              contact = [folder lookupName: uid
                                 inContext: [self context]
                                   acquire: NO];
              if ([contact isKindOfClass: [SOGoContactGCSList class]])
                {
                  list = [contact vList];
                  cards = [list cardReferences];
                  count = [cards count];
                  for (i = 0; i < count; i++)
                    [addresses addObject: 
                     [self formattedMailtoString: [cards objectAtIndex: i]]];
                }
              else if ([contact isKindOfClass: [SOGoContactGCSEntry class]])
                {
                  // We fetch the preferred email address of the contact or
                  // the first defined email address
                  card = [contact vCard];
                  [addresses addObject: [self formattedMailtoString: card]];
                }
              uid = [uids nextObject];
            }

          if ([addresses count] > 0)
            parameters = [NSString stringWithFormat: @"?mailto=%@", [addresses componentsJoinedByString: @","]];
        }
    }
  else if ([[request formValues] objectForKey: @"mailto"])
    // We use the email addresses defined in the request
    parameters = [[request formValues] asURLParameters];

  if (!parameters)
    // No parameter passed; simply open the compose window
    parameters = @"?mailto=";

  newLocation = [NSString stringWithFormat: @"%@/%@/compose%@",
                 [co baseURLInContext: context],
                 firstAccount,
                 parameters];

  return [self redirectToLocation: newLocation];
}

- (NSString *) formattedMailtoString: (NGVCard *) card
{
  NSString *email;
  NSMutableString *fn, *rc = nil;
  NSArray *n;
  unsigned int max;

  if ([card respondsToSelector: @selector (preferredEMail)])
    email = [card preferredEMail];
  else
    email = [card email];

  if (email == nil)
    email = (NSString*)[card firstChildWithTag: @"EMAIL"];

  if (email)
    {
      email = [NSString stringWithFormat: @"<%@>", email];

      // We append the contact's name
      fn = [NSMutableString stringWithString: [card fn]];
      if ([fn length] == 0)
        {
          n = [card n];
          if (n)
            {
              max = [n count];
              if (max > 0)
                {
                  if (max > 1)
                    fn = [NSMutableString stringWithFormat: @"%@ %@", [n objectAtIndex: 1], [n objectAtIndex: 0]];
                  else
                    fn = [NSMutableString stringWithString: [n objectAtIndex: 0]];
                }
            }
        }
      if (fn)
        {
          [fn appendFormat: @" %@", email];
          rc = fn;
        }
      else
        rc = email;
    }

  return rc;
}

- (WOResponse *) getFoldersStateAction
{
  NSString *expandedFolders;

  [self _setupContext];
  expandedFolders = [moduleSettings objectForKey: @"ExpandedFolders"];

  return [self responseWithStatus: 200 andString: expandedFolders];
}

- (NSString *) verticalDragHandleStyle
{
   NSString *vertical;

   [self _setupContext];
   vertical = [moduleSettings objectForKey: @"DragHandleVertical"];
   
   return ((vertical && [vertical intValue] > 0) ? (id)[vertical stringByAppendingFormat: @"px"] : nil);
}

- (NSString *) horizontalDragHandleStyle
{
   NSString *horizontal;

   [self _setupContext];
   horizontal = [moduleSettings objectForKey: @"DragHandleHorizontal"];

   return ((horizontal && [horizontal intValue] > 0) ? (id)[horizontal stringByAppendingFormat: @"px"] : nil);
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
  
  [ud synchronize];
  
  return [self responseWithStatus: 204];
}

- (WOResponse *) saveFoldersStateAction
{
  WORequest *request;
  NSString *expandedFolders;
  
  [self _setupContext];
  request = [context request];
  expandedFolders = [request formValueForKey: @"expandedFolders"];

  [moduleSettings setObject: expandedFolders
		  forKey: @"ExpandedFolders"];

  [ud synchronize];

  return [self responseWithStatus: 204];
}

@end /* UIxMailMainFrame */
