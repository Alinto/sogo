/* SOGoTool.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2015 Inverse inc.
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
  int i;

  NSArray *keys;
  NSDictionary   *cliArguments;
  NSMutableArray *mutArguments;
  NSString *kArg, *k, *v;
  NSUInteger kArgPos;

  mutArguments = [NSMutableArray arrayWithArray: newArguments];

  /* Remove NSArgumentDomain '-key value' from the arguments */
  cliArguments = [[NSUserDefaults standardUserDefaults]
                                 volatileDomainForName:NSArgumentDomain];
  keys = [cliArguments allKeys];
  for (i=0; i < [keys count]; i++)
    {
      k = [keys objectAtIndex: i];
      v = [cliArguments objectForKey:k];

      /* -p will be 'p' in NSArgumentDomain */
      kArg = [NSString stringWithFormat:@"-%@", k];
      kArgPos = [mutArguments indexOfObject: kArg];

      if (kArgPos != NSNotFound)
        {
          /* Remove arguments at kArgPos+1 and kArgPos
           * if their sequence matches that of the ArgumentDomain data: -k v
           */
          if (kArgPos < ([mutArguments count] - 1) &&
                [[mutArguments objectAtIndex: kArgPos+1] isEqualToString: v])
            {
              [mutArguments removeObjectAtIndex: kArgPos+1];
              [mutArguments removeObjectAtIndex: kArgPos];
            }
          else
            {
              /* this should not happen unless the argument is the last one */
              [mutArguments removeObjectAtIndex: kArgPos];
            }
        }
    }

  if ([mutArguments count])
    {
      ASSIGN (sanitizedArguments, mutArguments);
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
