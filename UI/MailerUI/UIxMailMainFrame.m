/*
  Copyright (C) 2007-2011 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
          Ludovic Marcotte <lmarcotte@inverse.ca>

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

#import <EOControl/EOQualifier.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/SoComponent.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactGCSList.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactLDIFEntry.h>

#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailFolder.h>
#import <SOGo/NSDictionary+URL.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGoUI/UIxComponent.h>

#import "UIxMailMainFrame.h"
#import "UIxMailListActions.h"

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
  NSArray *accounts, *names;

  accounts = [[self clientObject] mailAccounts];
  names = [accounts objectsForKey: @"name" notFoundMarker: nil];

  return [names jsonRepresentation];
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

- (NSString *) inboxData
{
  SOGoMailAccounts *accounts;
  SOGoMailAccount *account;
  SOGoMailFolder *inbox;
  NSDictionary *data;
  UIxMailListActions *actions;

  [self _setupContext];
  
#warning this code is dirty: we should not invoke UIxMailListActions from here!
  actions = [[[UIxMailListActions new] initWithRequest: [context request]] autorelease];
  accounts = [self clientObject];
  
  account = [accounts lookupName: @"0" inContext: context acquire: NO];
  inbox = [account inboxFolderInContext: context];

  data = [actions getUIDsInFolder: inbox withHeaders: YES];

  return [data jsonRepresentation];
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
  WORequest *request;
  int i, count;

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
  NSString *expandedFolders;
  
  [self _setupContext];
  request = [context request];
  expandedFolders = [request formValueForKey: @"expandedFolders"];

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

- (BOOL) showToAddress 
{
  SOGoMailFolder *co;

  if (!folderType)
    {
      co = [self clientObject];
      if ([co isKindOfClass: [SOGoSentFolder class]]
	  || [co isKindOfClass: [SOGoDraftsFolder class]])
	folderType = 1;
      else
	folderType = -1;
    }

  return (folderType == 1);
}

- (NSDictionary *) columnsMetaData
{
  NSMutableDictionary *columnsMetaData;
  NSArray *tmpColumns, *tmpKeys;

  columnsMetaData = [NSMutableDictionary dictionaryWithCapacity: 8];
  
  tmpKeys = [NSArray arrayWithObjects: @"headerClass", @"headerId", @"value",
                     nil];
  tmpColumns
    = [NSArray arrayWithObjects: @"messageThreadColumn tbtv_headercell",
               @"invisibleHeader", @"Thread", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
                                                          forKeys: tmpKeys]
                      forKey: @"Thread"];

  tmpColumns
    = [NSArray arrayWithObjects: @"messageSubjectColumn tbtv_headercell sortableTableHeader resizable",
               @"subjectHeader", @"Subject", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
                                                          forKeys: tmpKeys]
                      forKey: @"Subject"];
  
  tmpColumns
    = [NSArray arrayWithObjects: @"messageFlagColumn tbtv_headercell",
	       @"invisibleHeader", @"Flagged", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
					    forKeys: tmpKeys]
		      forKey: @"Flagged"];

  tmpColumns
    = [NSArray arrayWithObjects: @"messageFlagColumn tbtv_headercell",
	       @"attachmentHeader", @"Attachment", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
							  forKeys: tmpKeys]
		      forKey: @"Attachment"];

  tmpColumns
    = [NSArray arrayWithObjects: @"messageFlagColumn tbtv_headercell", @"messageFlagHeader",
	       @"Unread", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns forKeys: tmpKeys]
		      forKey: @"Unread"];

  tmpColumns
    = [NSArray arrayWithObjects: @"messageAddressHeader tbtv_headercell sortableTableHeader resizable",
	       @"toHeader", @"To", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns forKeys: tmpKeys]
		      forKey: @"To"];
  
  tmpColumns
    = [NSArray arrayWithObjects: @"messageAddressColumn tbtv_headercell sortableTableHeader resizable",
	       @"fromHeader", @"From", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
							  forKeys: tmpKeys]
		      forKey: @"From"];
  
  tmpColumns
    = [NSArray arrayWithObjects: @"messageDateColumn tbtv_headercell sortableTableHeader resizable",
	       @"dateHeader", @"Date", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
							  forKeys: tmpKeys]
		      forKey: @"Date"];
  
  tmpColumns
    = [NSArray arrayWithObjects: @"messagePriorityColumn tbtv_headercell resizable", @"priorityHeader",
	       @"Priority", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
							  forKeys: tmpKeys]
		      forKey: @"Priority"];

  tmpColumns
    = [NSArray arrayWithObjects: @"messageSizeColumn tbtv_headercell sortableTableHeader", @"sizeHeader",
	       @"Size", nil];
  [columnsMetaData setObject: [NSDictionary dictionaryWithObjects: tmpColumns
							  forKeys: tmpKeys]
		      forKey: @"Size"];
  
  return columnsMetaData;
}

- (NSArray *) columnsDisplayOrder
{
  NSMutableArray *finalOrder, *invalid;
  NSArray *available;
  NSDictionary *metaData;
  SOGoUserDefaults *ud;
  unsigned int i;

  if (!columnsOrder)
    {
      ud = [[context activeUser] userDefaults];
      columnsOrder = [ud mailListViewColumnsOrder];

      metaData = [self columnsMetaData];

      invalid = [columnsOrder mutableCopy];
      [invalid autorelease];
      available = [metaData allKeys];
      [invalid removeObjectsInArray: available];
      if ([invalid count] > 0)
        {
          [self errorWithFormat: @"those column names specified in"
                @" SOGoMailListViewColumnsOrder are invalid: '%@'",
                [invalid componentsJoinedByString: @"', '"]];
          [self errorWithFormat: @"  falling back on hardcoded column order"];
          columnsOrder = available;
        }

      finalOrder = [columnsOrder mutableCopy];
      [finalOrder autorelease];

      if (![ud mailSortByThreads])
        [finalOrder removeObject: @"Thread"];
      else
        {
          i = [finalOrder indexOfObject: @"Thread"];
          if (i == NSNotFound)
            [finalOrder insertObject: @"Thread" atIndex: 0];
        }
      if ([self showToAddress])
        {
          i = [finalOrder indexOfObject: @"From"];
          if (i != NSNotFound)
	    {
	      [finalOrder removeObject: @"To"];
	      [finalOrder replaceObjectAtIndex: i withObject: @"To"];
	    }
        }
      else
        {
          i = [finalOrder indexOfObject: @"To"];
          if (i != NSNotFound)
	    {
	      [finalOrder removeObject: @"From"];
	      [finalOrder replaceObjectAtIndex: i withObject: @"From"];
	    }
	}

      columnsOrder = [[self columnsMetaData] objectsForKeys: finalOrder
                                             notFoundMarker: @""];
      [columnsOrder retain];
    }

  return columnsOrder;
}

- (NSString *) columnsDisplayCount
{
  return [NSString stringWithFormat: @"%d", [[self columnsDisplayOrder] count]];
}

- (void) setCurrentColumn: (NSDictionary *) newCurrentColumn
{
  ASSIGN (currentColumn, newCurrentColumn);
}

- (NSDictionary *) currentColumn
{
  return currentColumn;
}

- (NSString *) columnTitle
{
  return [self labelForKey: [currentColumn objectForKey: @"value"]];
}

- (NSString *) unseenCountFolders
{
  NSArray *pathComponents, *filters, *actions;
  NSDictionary *d, *action;
  NSMutableArray *folders;
  NSMutableString *path;
  SOGoUserDefaults *ud;
  NSString *s;
  int i, j, k;

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
		      [path appendFormat: @"folder%@", [[pathComponents objectAtIndex: k] asCSSIdentifier]];
		      if (k < [pathComponents count] - 1)
			[path appendString: @"/"];
		    }
		  
		  [folders addObject: [NSString stringWithFormat: @"/0/%@", path]];
		}
	    }
	}
    }
  
  return [folders jsonRepresentation];
}

@end /* UIxMailMainFrame */
