
/* SOGoAppointmentFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <GDLAccess/EOAdaptorChannel.h>

#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/WORequest+SOGo.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoWebDAVValue.h>
#import <SOGo/SOGoUser.h>
#import "SOGoAppointmentFolder.h"
#import "SOGoWebAppointmentFolder.h"

#import "SOGoAppointmentFolders.h"

@interface SOGoParentFolder (Private)

- (NSException *) initSubscribedSubFolders;

@end

@implementation SOGoAppointmentFolders

+ (NSString *) gcsFolderType
{
  return @"Appointment";
}

+ (Class) subFolderClass
{
  return [SOGoAppointmentFolder class];
}

- (NSString *) defaultFolderName
{
  return [self labelForKey: @"Personal Calendar"];
}

- (NSArray *) toManyRelationshipKeys
{
  NSEnumerator *sortedSubFolders;
  SOGoGCSFolder *currentFolder;
  NSString *login;
  NSMutableArray *keys;

  login = [[context activeUser] login];
  if ([[context request] isICal])
    {
      keys = [NSMutableArray array];
      if ([owner isEqualToString: login])
        {
          sortedSubFolders = [[self subFolders] objectEnumerator];
          while ((currentFolder = [sortedSubFolders nextObject]))
            {
              if ([[currentFolder ownerInContext: context]
                    isEqualToString: owner])
                [keys addObject: [currentFolder nameInContainer]];
            }
        }
      else
        [keys addObject: @"personal"];
    }
  else
    keys = (NSMutableArray *) [super toManyRelationshipKeys];

  return keys;
}

- (NSString *) _fetchPropertyWithName: (NSString *) propertyName
			      inArray: (NSArray *) section
{
  NSObject <DOMElement> *currentElement;
  NSString *currentName, *property;
  NSEnumerator *elements;
  NSObject <DOMNodeList> *values;

  property = nil;

  elements = [section objectEnumerator];
  while (!property && (currentElement = [elements nextObject]))
    {
      currentName = [NSString stringWithFormat: @"{%@}%@",
			      [currentElement namespaceURI],
			      [currentElement nodeName]];
      if ([currentName isEqualToString: propertyName])
	{
	  values = [currentElement childNodes];
	  if ([values length])
	    property = [[values objectAtIndex: 0] nodeValue];
	}
    }

  return property;
}

#warning this method may be useful at a higher level
#warning not all values are simple strings...
- (NSException *) _applyMkCalendarProperties: (NSArray *) properties
				    toObject: (SOGoObject *) newFolder
{
  NSEnumerator *allProperties;
  NSObject <DOMElement> *currentProperty;
  NSObject <DOMNodeList> *values;
  NSString *value, *currentName;
  SEL methodSel;

  allProperties = [properties objectEnumerator];
  while ((currentProperty = [allProperties nextObject]))
    {
      values = [currentProperty childNodes];
      if ([values length])
	{
	  value = [[values objectAtIndex: 0] nodeValue];
	  currentName = [NSString stringWithFormat: @"{%@}%@",
				  [currentProperty namespaceURI],
				  [currentProperty nodeName]];
	  methodSel = SOGoSelectorForPropertySetter (currentName);
	  if ([newFolder respondsToSelector: methodSel])
	    [newFolder performSelector: methodSel
		       withObject: value];
	}
    }

  return nil;
}

- (NSException *) davCreateCalendarCollection: (NSString *) newName
				    inContext: (id) createContext
{
  NSArray *subfolderNames, *setProperties;
  NSString *content, *newDisplayName;
  NSDictionary *properties;
  NSException *error;
  SOGoAppointmentFolder *newFolder;

  subfolderNames = [self toManyRelationshipKeys];
  if ([subfolderNames containsObject: newName])
    {
      content = [NSString stringWithFormat:
			    @"A collection named '%@' already exists.",
			  newName];
      error = [NSException exceptionWithHTTPStatus: 403
			   reason: content];
    }
  else
    {
      properties = [[createContext request]
		     davPatchedPropertiesWithTopTag: @"mkcalendar"];
      setProperties = [properties objectForKey: @"set"];
      newDisplayName = [self _fetchPropertyWithName: @"{DAV:}displayname"
			     inArray: setProperties];
      if (![newDisplayName length])
	newDisplayName = newName;
      error
	= [self newFolderWithName: newDisplayName andNameInContainer: newName];
      if (!error)
	{
	  newFolder = [self lookupName: newName
			    inContext: createContext
			    acquire: NO];
	  error = [self _applyMkCalendarProperties: setProperties
			toObject: newFolder];
	}
    }

  return error;
}

- (NSArray *) davComplianceClassesInContext: (id)_ctx
{
  NSMutableArray *classes;
  NSArray *primaryClasses;

  classes = [NSMutableArray array];

  primaryClasses = [super davComplianceClassesInContext: _ctx];
  if (primaryClasses)
    [classes addObjectsFromArray: primaryClasses];
  [classes addObject: @"calendar-access"];
  [classes addObject: @"calendar-schedule"];

  return classes;
}

- (SOGoWebDAVValue *) davCalendarComponentSet
{
  static SOGoWebDAVValue *componentSet = nil;
  NSMutableArray *components;

  if (!componentSet)
    {
      components = [NSMutableArray array];
      /* Totally hackish.... we use the "n1" prefix because we know our
         extensions will assign that one to ..:caldav but we really need to
         handle element attributes */
      [components addObject: [SOGoWebDAVValue
                               valueForObject: @"<n1:comp name=\"VEVENT\"/>"
                                   attributes: nil]];
      [components addObject: [SOGoWebDAVValue
                               valueForObject: @"<n1:comp name=\"VTODO\"/>"
                                   attributes: nil]];
      componentSet
        = [davElementWithContent (@"supported-calendar-component-set",
                                  XMLNS_CALDAV,
                                  components)
                                 asWebDAVValue];
      [componentSet retain];
    }

  return componentSet;
}

- (NSArray *) proxyFoldersWithWriteAccess: (BOOL) hasWriteAccess
{
  NSMutableArray *proxyFolders;
  NSArray *proxySubscribers;
  NSEnumerator *folders;
  SOGoAppointmentFolder *currentFolder;
  NSString *folderOwner, *currentUser;

  proxyFolders = [NSMutableArray array];

  currentUser = [[context activeUser] login];

  [self initSubscribedSubFolders];
  folders = [subscribedSubFolders objectEnumerator];
  while ((currentFolder = [folders nextObject]))
    {
      folderOwner = [currentFolder ownerInContext: context];
      /* we currently only list the users of which we have subscribed to the
         personal folder */
      if ([[currentFolder realNameInContainer] isEqualToString: @"personal"])
        {
          proxySubscribers
            = [currentFolder proxySubscribersWithWriteAccess: hasWriteAccess];
          if ([proxySubscribers containsObject: currentUser])
            [proxyFolders addObject: currentFolder];
        }
    }

  return proxyFolders;
}

- (NSArray *) webCalendarIds
{
  NSUserDefaults *us;
  NSDictionary *tmp, *calendars;
  NSArray *rc;
  
  rc = nil;

  us = [[context activeUser] userSettings];
  tmp = [us objectForKey: @"Calendar"];
  if (tmp)
    {
      calendars = [tmp objectForKey: @"WebCalendars"];
      if (calendars)
        rc = [calendars allKeys];
    }

  if (!rc)
    rc = [NSArray array];

  return rc;
}

- (NSException *) _fetchPersonalFolders: (NSString *) sql
                            withChannel: (EOAdaptorChannel *) fc
{
  int count, max;
  NSArray *webCalendarIds;
  NSString *name;
  SOGoAppointmentFolder *old;
  SOGoWebAppointmentFolder *folder;
  NSException *error;
  BOOL isWebRequest;

  isWebRequest = [[context request] handledByDefaultHandler];
  error = [super _fetchPersonalFolders: sql withChannel: fc];

  webCalendarIds = [self webCalendarIds];
  max = [webCalendarIds count];
  if (!error && max)
    {
      for (count = 0; count < max; count++)
        {
          name = [webCalendarIds objectAtIndex: count];
          if (isWebRequest)
            {
              old = [subFolders objectForKey: name];
              folder = [SOGoWebAppointmentFolder objectWithName: name 
                                                    inContainer: self];
              [folder setOCSPath: [old ocsPath]];
              [subFolders setObject: folder forKey: name];
            }
          else
            [subFolders removeObjectForKey: name];
        }
    }

  return error;
}

@end
