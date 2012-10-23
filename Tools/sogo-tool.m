/* sogo-tool.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <SOGo/SOGoSystemDefaults.h>

#import "SOGoTool.h"

/* TODO:
   - help for modules
   - have a help syntax/mechanism similar to the one in monotone */

@interface SOGoToolDispatcher : NSObject
{
  NSMutableDictionary *tools;
  BOOL verboseMode;
  BOOL helpMode;
  NSString *tool;
  NSArray *toolArguments;
}

- (BOOL) run;

@end

@implementation SOGoToolDispatcher

- (id) init
{
  if ((self = [super init]))
    {
      tools = [NSMutableDictionary new];
      helpMode = NO;
      verboseMode = NO;
      tool = nil;
      toolArguments = nil;
    }

  return self;
}

- (void) dealloc
{
  [tools release];
  [tool release];
  [toolArguments release];
  [super dealloc];
}

- (void) registerTool: (NSString *) command
            withClass: (NSString *) className
       andDescription: (NSString *) description
{
  NSArray *toolData;

  toolData = [NSArray arrayWithObjects: className, description, nil];
  [tools setObject: toolData forKey: command];
}

- (void) parseArguments: (NSArray *) arguments
{
  BOOL error;
  int count, max;
  NSString *argument;

  error = NO;

  max = [arguments count];
  count = 1;
  while (!error && !tool && count < max)
    {
      argument = [arguments objectAtIndex: count];
      if ([argument isEqualToString: @"-v"]
          || [argument isEqualToString: @"--verbose"])
        verboseMode = YES;
      else if ([argument isEqualToString: @"-h"]
               || [argument isEqualToString: @"--help"])
        helpMode = YES;
      else if ([argument hasPrefix: @"-"])
        {
          error = YES;
          helpMode = YES;
          NSLog (@"Invalid command line parameter: '%@'", argument);
        }
      else
        {
          ASSIGN (tool,
                  [[tools objectForKey: argument] objectAtIndex: 0]);
          count++;
          if (count < max)
            {
              max -= count;
              toolArguments = [arguments
                                subarrayWithRange: NSMakeRange (count, max)];
              [toolArguments retain];
            }
        }

      count++;
    }
}

- (void) help
{
  NSMutableString *helpString;
  NSEnumerator *toolsEnum;
  NSString *command;
  NSArray *currentTool;

  helpString = [NSMutableString stringWithString: @"sogo-tool [-v|--verbose]"
                                @" [-h|--help]"
                                @" command [argument1] ...\n"];
  [helpString appendString: @"  -v, --verbose\tenable verbose mode\n"];
  [helpString appendString: @"  -h, --help\tdisplay this help information\n\n"];
  [helpString appendString: @"  argument1, ...\targuments passed to the"
              @" specified command\n\n"];
  [helpString appendString: @"  Available commands:\n"];
  toolsEnum = [[[tools allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];
  while ((command = [toolsEnum nextObject]))
    {
      currentTool = [tools objectForKey: command];
      [helpString appendFormat: @"\t%-20@-- %@\n",
                  command, [currentTool objectAtIndex: 1]];
    }

  NSLog (helpString);
}

- (void) registerTools
{
  NSEnumerator *toolsEnum;
  Class currentTool;
  NSString *command, *description;

  toolsEnum = [GSObjCAllSubclassesOfClass ([SOGoTool class]) objectEnumerator];
  while ((currentTool = [toolsEnum nextObject]))
    {
      command = [currentTool command];
      if (command)
        {
          description = [currentTool description];
          [self registerTool: command
                   withClass: NSStringFromClass (currentTool)
              andDescription: description];
        }
    }
}

- (BOOL) run
{
  NSProcessInfo *processInfo;
  NSArray *arguments;
  Class toolClass;
  NSString *toolsList;
  BOOL rc;

  [self registerTools];

  processInfo = [NSProcessInfo processInfo];
  arguments = [processInfo arguments];
  [self parseArguments: arguments];
  if (helpMode || !tool)
    {
      rc = YES;
      [self help];
    }
  else
    {
      if (tool)
        {
          toolClass = NSClassFromString (tool);
          if (toolClass)
            rc = [toolClass runToolWithArguments: toolArguments
                                         verbose: verboseMode];
          else
            {
              rc = NO;
              toolsList = [[tools allKeys] componentsJoinedByString: @", "];
              NSLog (@"No tool named '%@'. Available tools are:\n\t%@",
                     tool, toolsList);
            }
        }
      else
        rc = NO;
    }

  return rc;
}

@end

static void
setupUserDefaults ()
{
  NSMutableDictionary *defaultsOverrides;
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];

  defaultsOverrides = [NSMutableDictionary new];
  [defaultsOverrides setObject: [NSNumber numberWithInt: 0]
                        forKey: @"SOGoLDAPQueryLimit"];
  [defaultsOverrides setObject: [NSNumber numberWithInt: 0]
                        forKey: @"SOGoLDAPQueryTimeout"];
  [ud setVolatileDomain: defaultsOverrides
                forName: @"sogo-tool-overrides"];
  [ud addSuiteNamed: @"sogo-tool-overrides"];
  [defaultsOverrides release];
}

int
main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool;
  SOGoToolDispatcher *dispatcher;
  int rc;

  rc = 0;

  pool = [NSAutoreleasePool new];

  [SOGoSystemDefaults sharedSystemDefaults];
  setupUserDefaults ();

  dispatcher = [SOGoToolDispatcher new];
  if ([dispatcher run])
    rc = 0;
  else
    rc = -1;
  [dispatcher release];
  [pool release];

  return rc;
}
