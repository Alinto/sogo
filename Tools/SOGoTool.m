/* SOGoTool.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2011 Inverse inc.
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
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import "SOGoTool.h"

/* TODO:
   - log facility, handling verbose mode */

@implementation SOGoTool

+ (NSString *) command
{
  return nil;
}

+ (NSString *) description
{
  return nil;
}

+ (BOOL) runToolWithArguments: (NSArray *) toolArguments
                      verbose: (BOOL) isVerbose
{
  SOGoTool *instance;

  instance = [self new];
  [instance autorelease];

  [instance setArguments: toolArguments];
  [instance setSanitizedArguments: toolArguments];
  [instance setVerbose: isVerbose];

  return [instance run];
}

- (id) init
{
  if ((self = [super init]))
    {
      arguments = nil;
      sanitizedArguments = nil;
      verbose = NO;
    }

  return self;
}

- (void) setArguments: (NSArray *) newArguments
{
  ASSIGN (arguments, newArguments);
}

- (void) setSanitizedArguments: (NSArray *) newArguments
{
  NSString *argPair, *argsString, *k, *v;
  NSDictionary   *cliArguments;
  NSArray *keys, *wordsWP;

  int i;

  argsString = [newArguments componentsJoinedByString:@" "];

  /* Remove NSArgumentDomain -key value from the arguments */
  cliArguments = [[NSUserDefaults standardUserDefaults]
                                 volatileDomainForName:NSArgumentDomain];
  keys = [cliArguments allKeys];
  for (i=0; i < [keys count]; i++)
    {
      k = [keys objectAtIndex: i];
      v = [cliArguments objectForKey:k];
      argPair = [NSString stringWithFormat:@"-%@ %@", k, v];
      argsString = [argsString stringByReplacingOccurrencesOfString: argPair
                                                         withString: @""];
    }
  if ([argsString length])
    {
      /* dance to compact whitespace */
      NSMutableArray *words = [NSMutableArray array];
      wordsWP = [argsString componentsSeparatedByCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
      for (i=0; i < [wordsWP count]; i++)
        {
          v = [wordsWP objectAtIndex: i];

          if([v length] > 1) 
            {
              [words addObject:v];
            }
        }
      argsString = [words componentsJoinedByString:@" "];
      ASSIGN (sanitizedArguments, [argsString componentsSeparatedByString:@" "]);
    }
  else
    {
      DESTROY(sanitizedArguments);
    }

}

- (void) setVerbose: (BOOL) newVerbose
{
  verbose = newVerbose;
}

- (void) dealloc
{
  [arguments release];
  [sanitizedArguments release];
  [super dealloc];
}

- (BOOL) run
{
  return NO;
}

@end
