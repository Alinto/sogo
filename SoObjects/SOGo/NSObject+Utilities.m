/* NSObject+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2018 Inverse inc.
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

#import <Foundation/NSBundle.h>
#import <Foundation/NSDebug.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>

#import "NSDictionary+Utilities.h"
#import "SOGoUser.h"
#import "SOGoUserDefaults.h"

#import "NSObject+Utilities.h"

static NSMutableDictionary *translationCache = nil;


@implementation NSObject (SOGoObjectUtilities)

- (NSString *) jsonRepresentation
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSArray *) domNode: (id <DOMNode>) node
  getChildNodesByType: (DOMNodeType ) type
{
  NSMutableArray *nodes;
  id <DOMNode> currentChild;

  nodes = [NSMutableArray array];

  currentChild = [node firstChild];
  while (currentChild)
    {
      if ([currentChild nodeType] == type)
	[nodes addObject: currentChild];
      currentChild = [currentChild nextSibling];
    }

  return nodes;
}

- (NSArray *) _languagesForLabelsInContext: (WOContext *) context
{
  NSMutableArray *languages;
  NSArray *browserLanguages;
  NSString *language;
  SOGoUser *user;

#warning the purpose of this method needs to be reviewed
  languages = [NSMutableArray array];

  user = [context activeUser];
  if ([user isKindOfClass: [SOGoUser class]])
    {
      language = [[user userDefaults] language];
      [languages addObject: language];
    }
  else
    {
      browserLanguages = [[context request] browserLanguages];
      [languages addObjectsFromArray: browserLanguages];
    }

  return languages;
}

- (NSString *) labelForKey: (NSString *) key
                 inContext: (WOContext *) context
{
  NSString *language, *label;
  NSArray *paths;
  NSEnumerator *languages;
  NSBundle *bundle;
  NSDictionary *strings;

  label = nil;

  bundle = [NSBundle bundleForClass: [self class]];
  if (!bundle)
    bundle = [NSBundle mainBundle];
  languages = [[self _languagesForLabelsInContext: context] objectEnumerator];
  
  if(!translationCache)
    translationCache = [NSMutableDictionary new];

  while (!label && (language = [languages nextObject]))
    {
      if (![translationCache objectForKey: language]) {
        paths = [bundle pathsForResourcesOfType: @"strings"
          inDirectory: [NSString stringWithFormat: @"%@.lproj",
                        language]
		      forLocalization: language];
        if ([paths count] > 0)
	      {
	        strings = [NSDictionary
		                 dictionaryFromStringsFile: [paths objectAtIndex: 0]];
	        [translationCache setObject: strings forKey: language];
	        label = [strings objectForKey: key];
	      }
	    } else {
	      strings = [translationCache objectForKey: language]; 
	      label = [strings objectForKey: key];
	    }
    }
  if (!label)
    label = key;
  
  return label;
}

//
//  Set SOGoDebugLeaks = YES in your defaults to enable.
//
+ (void) memoryStatistics
{
  Class *classList = GSDebugAllocationClassList ();
  Class *pointer;
  int i, count, total, peak;
  NSString *className;

  pointer = classList;
  i = 0;
 
  printf("Class  count  total  peak\n");
  while (pointer[i] != NULL)
    {
      className = NSStringFromClass (pointer[i]);
      count = GSDebugAllocationCount (pointer[i]);
      total = GSDebugAllocationTotal (pointer[i]);
      peak = GSDebugAllocationPeak (pointer[i]);
     
      printf("%s  %d  %d  %d\n", [className UTF8String], count, total, peak);
      i++;
    }
  NSZoneFree(NSDefaultMallocZone(), classList);

  printf("Done!\n");
}

//
// Small hack to avoid SOPE's stupid behavior to wrap a multipart
// object in a NGMimeBodyPart.
//
- (NSArray *) parts
{
  if ([self isKindOfClass: [NGMimeMultipartBody class]])
    return [self parts];

  if ([self isKindOfClass: [NGMimeBodyPart class]] &&
      [[(id)self body] isKindOfClass: [NGMimeMultipartBody class]])
    return [[(id)self body] parts];

  return [NSArray array];
}

@end
