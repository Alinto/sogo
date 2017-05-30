/* SOGoToolDumpDefaults.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
 *
 * Author: Jean Raby <jraby@inverse.ca>
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
#import <Foundation/NSData.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSPropertyList.h>

#import "SOGoTool.h"

@interface SOGoToolDumpDefaults : SOGoTool
@end

@implementation SOGoToolDumpDefaults

+ (void) initialize
{
}

+ (NSString *) command
{
  return @"dump-defaults";
}
+ (NSString *) description
{
  return @"Prints the sogod GNUstep domain configuration as a property list";
}

- (void) usage
{
  fprintf (stderr, "dump-defaults [-f <filename>|[all]]\n\n"
     "  Prints the sogod GNUstep domain configuration as a property list.\n"
     "  The output should be suitable for inclusion as /etc/sogo/sogo.conf\n"
     "\n"
     "  If 'all' is specified, prints all defaults and their current values.\n"
     "  This might be useful to see the list of all known configuration parameters.\n"
     "\n"
     "  If '-f filename' is specified, reads a property list in xml format\n"
     "  and outputs it in OpenStep format. To some, this is more readable than XML.\n"
     "  Note that the output might need further editing to be used as sogo.conf.\n"
     );
}

- (NSString *) processDefaults: (BOOL)allDefaults
{
  NSDictionary *defaultsDict;
  NSUserDefaults *ud;
  NSData *plistData;

  ud = [NSUserDefaults standardUserDefaults];
  if (allDefaults)
    {
      /* grab the running defaults - contains EVERYTHING */
      defaultsDict = [ud dictionaryRepresentation];
    }
  else
    {
      /* grab only the sogod domain */
      defaultsDict = [ud persistentDomainForName: @"sogod"];
    }

  if (!defaultsDict)
    return @"No defaults found. Try to use -f.";

  plistData = [NSPropertyListSerialization dataFromPropertyList: (id) defaultsDict
                                         format: NSPropertyListOpenStepFormat
                               errorDescription: 0 ];
  return [[[NSString alloc] initWithData:plistData encoding:NSUTF8StringEncoding] autorelease];
}


- (NSString *) defaultsFromFilename: (NSString *)filename
{
  NSData *rawData, *plistRawData, *plistDataOpenStep;
  NSString *errstr;

  rawData = [NSData dataWithContentsOfFile: filename];
  if (rawData == nil)
    {
      NSLog(@"Cannot read configuration from file '%s'",
                                [filename UTF8String]);
      return @"";
    }

  plistRawData = [NSPropertyListSerialization propertyListFromData: rawData
                                                  mutabilityOption: 0
                                                            format: 0
                                                  errorDescription: &errstr];
  if (plistRawData == nil)
    {
      NSLog(@"Error converting '%s' to plist: %@", [filename UTF8String], errstr);
      return @"";
    }
  
  plistDataOpenStep = [NSPropertyListSerialization dataFromPropertyList: (id) plistRawData
                                         format: NSPropertyListOpenStepFormat
                               errorDescription: &errstr ];
  if (!plistDataOpenStep)
    {
      NSLog(@"Error converting plist to OpenStep format: %@", errstr);
      return @"";
    }

  return [[[NSString alloc] initWithData:plistDataOpenStep encoding:NSUTF8StringEncoding] autorelease];
}

- (BOOL) run
{
  BOOL rc;
  NSString *filename, *output;
  
  rc = YES;

  /* FIXME: this should really be replaced by getopt(3) or some equivalent */
  if ([arguments count])
    {
      if ([arguments count] == 2 &&
          [[arguments objectAtIndex: 0] isEqualToString: @"-f"])
       {
         filename = [arguments objectAtIndex: 1];
         output = [self defaultsFromFilename: filename];
       }
      else if ([[arguments objectAtIndex: 0] isEqualToString: @"all"])
         output = [self processDefaults: YES];
      else
       {
         [self usage];
         return NO;
       }
    }
  else
    output = [self processDefaults: NO];

  printf("%s\n", [output UTF8String]);
  
  return rc;
}

@end

