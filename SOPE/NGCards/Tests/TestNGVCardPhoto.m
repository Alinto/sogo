/* TestNGVCardPhoto.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
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

#include <Foundation/Foundation.h>
#include <stdio.h>

#include "NGVCard.h"

static int
Check (int condition, const char *message)
{
  if (!condition)
    {
      printf ("FAIL: %s\n", message);
      return 1;
    }

  return 0;
}

int
main (void)
{
  NSAutoreleasePool *pool;
  NGVCard *card;
  NSString *versit;
  int failures = 0;

  pool = [[NSAutoreleasePool alloc] init];

  card = [NGVCard cardWithUid: @"photo-test"];
  [card setPhoto: @"QUJDRA=="];

  versit = [card versitString];
  failures += Check ([versit rangeOfString: @"ENCODING=b"].location
                     != NSNotFound,
                     "photo must use the vCard 3.0 ENCODING=b value");
  failures += Check ([versit rangeOfString: @"TYPE=JPEG"].location
                     != NSNotFound,
                     "photo must declare its TYPE");
  failures += Check ([versit rangeOfString: @"ENCODING=BASE64"].location
                     == NSNotFound,
                     "the 2.1 ENCODING=BASE64 spelling must not be emitted");
  failures += Check ([versit rangeOfString: @"QUJDRA=="].location
                     != NSNotFound,
                     "photo value must be preserved");

  [pool release];

  if (failures)
    printf ("%d failure(s)\n", failures);
  else
    printf ("all tests passed\n");

  return failures ? 1 : 0;
}
