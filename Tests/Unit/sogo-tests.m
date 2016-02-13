/* sogo-tests.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/Foundation.h>

#import "SOGoTestRunner.h"

static void Usage ()
{
  /* Print usage and exit */
  NSLog (@"sogo-tests [-h|--help] [-f|--format=text|junit]\n"
         @"  -h, --help\t\t\tdisplay this help information\n"
         @"  -f, --format=text|junit\treport format. Default: text\n\n");
  exit(0);
}

static SOGoTestOutputFormat ParseArguments (NSArray *args)
{
  /* Parse arguments from command line */
  BOOL help = NO;
  NSString *arg, *format = nil;
  NSUInteger i, max;
  SOGoTestOutputFormat outFormat;

  max = [args count];
  /* Skip program name */
  i = 1;
  while (!help && i < max)
    {
      arg = [args objectAtIndex: i];
      if ([arg isEqualToString: @"-f"] || [arg isEqualToString: @"--format"])
        {
          NSArray *validFormats = [NSArray arrayWithObjects: @"text", @"junit", nil];
          i++;
          if (i < max)
            {
              arg = [args objectAtIndex: i];
              if ([validFormats containsObject: arg])
                format = arg;
              else
                {
                  help = YES;
                  NSLog (@"Invalid format: '%@'. Use 'text' or 'junit'", arg);
                }
            }
          else
            {
              NSLog (@"Missing format argument");
              help = YES;
            }
        }
      else if ([arg isEqualToString: @"-h"]
               || [arg isEqualToString: @"--help"])
        help = YES;
      else
        {
          NSLog (@"Invalid command line argument: '%@'", arg);
          help = YES;
        }
      i++;
    }


  if (help)
    {
      Usage ();
    }

  if (format)
    {
      if ([format isEqualToString: @"text"])
        outFormat = SOGoTestTextOutputFormat;
      else if ([format isEqualToString: @"junit"])
        outFormat = SOGoTestJUnitOutputFormat;
    }
  else
    outFormat = SOGoTestTextOutputFormat;

  return outFormat;
}

int main(int argc, char *argv[], char *env[])
{
  NSAutoreleasePool *pool;
  int rc;
  NSDictionary *defaults;
  NSUserDefaults *ud;
  SOGoTestOutputFormat reportFormat;

  pool = [NSAutoreleasePool new];

  defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool: YES],
                           @"NGUseUTF8AsURLEncoding",
                           nil];
  ud = [NSUserDefaults standardUserDefaults];
  [ud setVolatileDomain: defaults
                forName: @"sogo-tests-volatile"];
  [ud addSuiteNamed: @"sogo-tests-volatile"];

  /* Process arguments */
  [NSProcessInfo initializeWithArguments: argv
                                   count: argc
                             environment: env];

  reportFormat = ParseArguments ([[NSProcessInfo processInfo] arguments]);

  rc = [[SOGoTestRunner testRunnerWithFormat: reportFormat] run];
  [pool release];

  return rc;
}
