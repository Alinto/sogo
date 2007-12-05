/** NSException - Object encapsulation of a general exception handler
   Copyright (C) 1993, 1994, 1996, 1997, 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   $Date: 2007-09-14 07:36:11 -0400 (Fri, 14 Sep 2007) $ $Revision: 25482 $

   NOTE: This code was taken from GNUstep Base Library and sligthly modified
         by Ludovic Marcotte <ludovic@inverse.ca>
*/

#include <bfd.h>
#include <dlfcn.h>
#include <signal.h>

typedef void* dl_handle_t;
typedef void* dl_symbol_t;

#import "NSException+Stacktrace.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSData.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSThread.h>

// #if GNUSTEP_BASE_MAJOR_VERSION >= 1
// #if GNUSTEP_BASE_MINOR_VERSION > 13

//
//
//
static void _terminate()
{
  abort();
}

static void
_NSFoundationUncaughtExceptionHandler (NSException *exception)
{
  NSString	*stack;
  
  fprintf(stderr, "Uncaught exception %s, reason: %s\n",
    [[exception name] lossyCString], [[exception reason] lossyCString]);
  fflush(stderr);	/* NEEDED UNDER MINGW */
  stack = [[[exception userInfo] objectForKey: @"GSStackTraceKey"] description];
  if (stack != nil)
    {
      fprintf(stderr, "Stack\n%s\n", [stack lossyCString]);
    }
  fflush(stderr);	/* NEEDED UNDER MINGW */

  _terminate();
}

//
//
//

#define	STACKSYMBOLS	1

@interface GSStackTrace : NSObject
{
  NSMutableArray *frames;
}

+ (GSStackTrace*) currentStack;

- (NSString*) description;
- (NSEnumerator*) enumerator;
- (id) frameAt: (unsigned)index;
- (unsigned) frameCount;
- (NSEnumerator*) reverseEnumerator;

@end

#ifdef STACKSYMBOLS

// GSStackTrace inspired by  FYStackTrace.m
// created by Wim Oudshoorn on Mon 11-Apr-2006
// reworked by Lloyd Dupont @ NovaMind.com  on 4-May-2006

@class GSBinaryFileInfo;

@interface GSFunctionInfo : NSObject
{
  void			*_address;
  NSString		*_fileName;
  NSString		*_functionName;
  int			_lineNo;
  GSBinaryFileInfo	*_module;
}
- (void*) address;
- (NSString *) fileName;
- (NSString *) function;
- (id) initWithModule: (GSBinaryFileInfo*)module
	      address: (void*)address 
		 file: (NSString*)file 
	     function: (NSString*)function 
		 line: (int)lineNo;
- (int) lineNumber;
- (GSBinaryFileInfo*) module;

@end


@interface GSBinaryFileInfo : NSObject
{
  NSString	*_fileName;
  bfd		*_abfd;
  asymbol	**_symbols;
  long		_symbolCount;
}
- (NSString *) fileName;
- (GSFunctionInfo *) functionForAddress: (void*) address;
- (id) initWithBinaryFile: (NSString *)fileName;
- (id) init; // return info for the current executing process

@end

@implementation GSFunctionInfo

- (void*) address
{
  return _address;
}

- (oneway void) dealloc
{
  [_module release];
  _module = nil;
  [_fileName release];
  _fileName = nil;
  [_functionName release];
  _functionName = nil;
  [super dealloc];
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"(%@: %p) %@  %@: %d",
    [_module fileName], _address, _functionName, _fileName, _lineNo];
}

- (NSString *) fileName
{
  return _fileName;
}

- (NSString *) function
{
  return _functionName;
}

- (id) init
{
  [self release];
  return nil;
}

- (id) initWithModule: (GSBinaryFileInfo*)module
	      address: (void*)address 
		 file: (NSString*)file 
	     function: (NSString*)function 
		 line: (int)lineNo
{
  _module = [module retain];
  _address = address;
  _fileName = [file retain];
  _functionName = [function retain];
  _lineNo = lineNo;

  return self;
}

- (int) lineNumber
{
  return _lineNo;
}

- (GSBinaryFileInfo *) module
{
  return _module;
}

@end

@implementation GSBinaryFileInfo

+ (GSBinaryFileInfo*) infoWithBinaryFile: (NSString *)fileName
{
  return [[[self alloc] initWithBinaryFile: fileName] autorelease];
}

+ (void) initialize
{
  static BOOL first = YES;

  if (first == NO)
    {
      return;
    }
  first = NO;
  bfd_init ();
}

- (oneway void) dealloc
{
  [_fileName release];
  _fileName = nil;
  if (_abfd)
    {
      bfd_close (_abfd);
      _abfd = NULL;
    }
  if (_symbols)
    {
      objc_free (_symbols);
      _symbols = NULL;
    }
  [super dealloc];
}

- (NSString *) fileName
{
  return _fileName;
}

- (id) init
{
  NSString *processName;

  processName = [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
  return [self initWithBinaryFile: processName];
}

- (id) initWithBinaryFile: (NSString *)fileName
{
  int neededSpace;

  // 1st initialize the bfd
  if ([fileName length] == 0)
    {
      //NSLog (@"GSBinaryFileInfo: No File");
      [self release];
      return nil;
    }
  _fileName = [fileName copy];
  _abfd = bfd_openr ([fileName cString], NULL);
  if (!_abfd)
    {
      //NSLog (@"GSBinaryFileInfo: No Binary Info");
      [self release];
      return nil;
    }
  if (!bfd_check_format_matches (_abfd, bfd_object, NULL))
    {
      //NSLog (@"GSBinaryFileInfo: BFD format object error");
      [self release];
      return nil;
    }

  // second read the symbols from it
  if (!(bfd_get_file_flags (_abfd) & HAS_SYMS))
    {
      //NSLog (@"GSBinaryFileInfo: BFD does not contain any symbols");
      [self release];
      return nil;
    }

  neededSpace = bfd_get_symtab_upper_bound (_abfd);
  if (neededSpace < 0)
    {
      //NSLog (@"GSBinaryFileInfo: BFD error while deducing needed space");
      [self release];
      return nil;
    }
  if (neededSpace == 0)
    {
      //NSLog (@"GSBinaryFileInfo: BFD no space for symbols needed");
      [self release];
      return nil;
    }
  _symbols = objc_malloc (neededSpace);
  if (!_symbols)
    {
      //NSLog (@"GSBinaryFileInfo: Can't allocate buffer");
      [self release];
      return nil;
    }
  _symbolCount = bfd_canonicalize_symtab (_abfd, _symbols);
  if (_symbolCount < 0)
    {
      //NSLog (@"GSBinaryFileInfo: BFD error while reading symbols");
      [self release];
      return nil;
    }

  return self;
}

struct SearchAddressStruct
{
  void			*theAddress;
  GSBinaryFileInfo	*module;
  asymbol		**symbols;
  GSFunctionInfo	*theInfo;
};

static void find_address (bfd *abfd, asection *section,
  struct SearchAddressStruct *info)
{
  bfd_vma	address;
  bfd_vma	vma;
  unsigned	size;
  const char	*fileName;
  const char	*functionName;
  unsigned	line = 0;

  if (info->theInfo)
    {
      return;
    }
  if (!(bfd_get_section_flags (abfd, section) & SEC_ALLOC))
    {
      return;
    }

  address = (bfd_vma) (intptr_t)info->theAddress;

  vma = bfd_get_section_vma (abfd, section);

#if     defined(bfd_get_section_size)
  size = bfd_get_section_size (section);        // recent
#else                                
  size = bfd_section_size (abfd, section);      // older version
#endif                               
     
  if (address < vma || address >= vma + size)
    {
      return;
    }

  if (bfd_find_nearest_line (abfd, section, info->symbols,
    address - vma, &fileName, &functionName, &line))
    {
      GSFunctionInfo	*fi;
      NSString		*file = nil;
      NSString		*func = nil;

      if (fileName != 0)
        {
	  file = [NSString stringWithCString: fileName 
	    encoding: [NSString defaultCStringEncoding]];
	}
      if (functionName != 0)
        {
	  func = [NSString stringWithCString: functionName 
	    encoding: [NSString defaultCStringEncoding]];
	}
      fi = [GSFunctionInfo alloc];
      fi = [fi initWithModule: info->module
		      address: info->theAddress
			 file: file
		     function: func
			 line: line];
      [fi autorelease];
      info->theInfo = fi;
    }
}

- (GSFunctionInfo *) functionForAddress: (void*) address
{
  struct SearchAddressStruct searchInfo = { address, self, _symbols, nil };

  bfd_map_over_sections (_abfd,
    (void (*) (bfd *, asection *, void *)) find_address, &searchInfo);
  return searchInfo.theInfo;
}

@end

static NSRecursiveLock		*modLock = nil;
static NSMutableDictionary	*stackModules = nil;

// initialize stack trace info
static id
GSLoadModule(NSString *fileName)
{
  GSBinaryFileInfo	*module = nil;

  [modLock lock];

  if (stackModules == nil)
    {
      NSEnumerator	*enumerator;
      NSBundle		*bundle;

      stackModules = [NSMutableDictionary new];

      /*
       * Try to ensure we have the main, base and gui library bundles.
       */
      [NSBundle mainBundle];
      [NSBundle bundleForClass: [NSObject class]];
      [NSBundle bundleForClass: NSClassFromString(@"NSView")];

      /*
       * Add file info for all bundles with code.
       */
      enumerator = [[NSBundle allBundles] objectEnumerator];
      while ((bundle = [enumerator nextObject]) != nil)
	{
	  if ([bundle load] == YES)
	    {
	      GSLoadModule([bundle executablePath]);
	    }
	}
    }

  if ([fileName length] > 0)
    {
      module = [stackModules objectForKey: fileName];
      if (module == nil);
	{
	  module = [GSBinaryFileInfo infoWithBinaryFile: fileName];
	  if (module == nil)
	    {
	      module = (id)[NSNull null];
	    }
	  if ([stackModules objectForKey: fileName] == nil)
	    {
	      [stackModules setObject: module forKey: fileName];
	    }
	  else
	    {
	      module = [stackModules objectForKey: fileName];
	    }
	}
    }
  [modLock unlock];

  if (module == (id)[NSNull null])
    {
      module = nil;
    }
  return module;
}

#endif	/* STACKSYMBOLS */


//
//
//
@implementation NSException (SOGoExtensions)

- (void) raise
{
#ifndef _NATIVE_OBJC_EXCEPTIONS
  NSThread	*thread;
  NSHandler	*handler;
#endif

  if ([_e_info objectForKey: @"GSStackTraceKey"] == nil)
    {
      NSMutableDictionary	*m;

      if (_e_info == nil)
	{
	  _e_info = m = [NSMutableDictionary new];
	}
      else if ([_e_info isKindOfClass: [NSMutableDictionary class]] == YES)
        {
	  m = (NSMutableDictionary*)_e_info;
        }
      else
	{
	  m = [_e_info mutableCopy];
	  RELEASE(_e_info);
	  _e_info = m;
	}
      [m setObject: [GSStackTrace currentStack] forKey: @"GSStackTraceKey"];
    }

#ifdef _NATIVE_OBJC_EXCEPTIONS
  @throw self;
#else
  thread = GSCurrentThread();
  handler = thread->_exception_handler;
  if (handler == NULL)
    {
      static	int	recursion = 0;

      /*
       * Set/check a counter to prevent recursive uncaught exceptions.
       * Allow a little recursion in case we have different handlers
       * being tried.
       */
      if (recursion++ > 3)
	{
	  fprintf(stderr,
	    "recursion encountered handling uncaught exception\n");
	  fflush(stderr);	/* NEEDED UNDER MINGW */
	  _terminate();
	}

      /*
       * Call the uncaught exception handler (if there is one).
       */
      if (_NSUncaughtExceptionHandler != NULL)
	{
	  (*_NSUncaughtExceptionHandler)(self);
	}

      /*
       * The uncaught exception handler which is set has not
       * exited, so we call the builtin handler, (undocumented
       * behavior of MacOS-X).
       * The standard handler is guaranteed to exit/abort.
       */
      _NSFoundationUncaughtExceptionHandler(self);
    }

  thread->_exception_handler = handler->next;
  handler->exception = self;
  longjmp(handler->jumpState, 1);
#endif
}

@end

static jmp_buf *
jbuf()
{
  NSMutableData	*d;

  d = [[[NSThread currentThread] threadDictionary] objectForKey: @"GSjbuf"];
  if (d == nil)
    {
      d = [[NSMutableData alloc] initWithLength:
	sizeof(jmp_buf) + sizeof(void(*)(int))];
      [[[NSThread currentThread] threadDictionary] setObject: d
						      forKey: @"GSjbuf"];
      RELEASE(d);
    }
  return (jmp_buf*)[d mutableBytes];
}

static void
recover(int sig)
{
  jmp_buf	*env = jbuf();

  longjmp(*env, 1);
}

#define _NS_FRAME_HACK(a) case a: val = __builtin_frame_address(a + 1); break;
#define _NS_RETURN_HACK(a) case a: val = __builtin_return_address(a + 1); break;

static void *
NSFrameAddress(int offset)
{
  jmp_buf	*env;
  void		(*old)(int);
  void		*val;

  env = jbuf();
  if (setjmp(*env) == 0)
    {
      old = signal(SIGSEGV, recover);
      memcpy(env + 1, &old, sizeof(old));
      switch (offset)
	{
	  _NS_FRAME_HACK(0); _NS_FRAME_HACK(1); _NS_FRAME_HACK(2);
	  _NS_FRAME_HACK(3); _NS_FRAME_HACK(4); _NS_FRAME_HACK(5);
	  _NS_FRAME_HACK(6); _NS_FRAME_HACK(7); _NS_FRAME_HACK(8);
	  _NS_FRAME_HACK(9); _NS_FRAME_HACK(10); _NS_FRAME_HACK(11);
	  _NS_FRAME_HACK(12); _NS_FRAME_HACK(13); _NS_FRAME_HACK(14);
	  _NS_FRAME_HACK(15); _NS_FRAME_HACK(16); _NS_FRAME_HACK(17);
	  _NS_FRAME_HACK(18); _NS_FRAME_HACK(19); _NS_FRAME_HACK(20);
	  _NS_FRAME_HACK(21); _NS_FRAME_HACK(22); _NS_FRAME_HACK(23);
	  _NS_FRAME_HACK(24); _NS_FRAME_HACK(25); _NS_FRAME_HACK(26);
	  _NS_FRAME_HACK(27); _NS_FRAME_HACK(28); _NS_FRAME_HACK(29);
	  _NS_FRAME_HACK(30); _NS_FRAME_HACK(31); _NS_FRAME_HACK(32);
	  _NS_FRAME_HACK(33); _NS_FRAME_HACK(34); _NS_FRAME_HACK(35);
	  _NS_FRAME_HACK(36); _NS_FRAME_HACK(37); _NS_FRAME_HACK(38);
	  _NS_FRAME_HACK(39); _NS_FRAME_HACK(40); _NS_FRAME_HACK(41);
	  _NS_FRAME_HACK(42); _NS_FRAME_HACK(43); _NS_FRAME_HACK(44);
	  _NS_FRAME_HACK(45); _NS_FRAME_HACK(46); _NS_FRAME_HACK(47);
	  _NS_FRAME_HACK(48); _NS_FRAME_HACK(49); _NS_FRAME_HACK(50);
	  _NS_FRAME_HACK(51); _NS_FRAME_HACK(52); _NS_FRAME_HACK(53);
	  _NS_FRAME_HACK(54); _NS_FRAME_HACK(55); _NS_FRAME_HACK(56);
	  _NS_FRAME_HACK(57); _NS_FRAME_HACK(58); _NS_FRAME_HACK(59);
	  _NS_FRAME_HACK(60); _NS_FRAME_HACK(61); _NS_FRAME_HACK(62);
	  _NS_FRAME_HACK(63); _NS_FRAME_HACK(64); _NS_FRAME_HACK(65);
	  _NS_FRAME_HACK(66); _NS_FRAME_HACK(67); _NS_FRAME_HACK(68);
	  _NS_FRAME_HACK(69); _NS_FRAME_HACK(70); _NS_FRAME_HACK(71);
	  _NS_FRAME_HACK(72); _NS_FRAME_HACK(73); _NS_FRAME_HACK(74);
	  _NS_FRAME_HACK(75); _NS_FRAME_HACK(76); _NS_FRAME_HACK(77);
	  _NS_FRAME_HACK(78); _NS_FRAME_HACK(79); _NS_FRAME_HACK(80);
	  _NS_FRAME_HACK(81); _NS_FRAME_HACK(82); _NS_FRAME_HACK(83);
	  _NS_FRAME_HACK(84); _NS_FRAME_HACK(85); _NS_FRAME_HACK(86);
	  _NS_FRAME_HACK(87); _NS_FRAME_HACK(88); _NS_FRAME_HACK(89);
	  _NS_FRAME_HACK(90); _NS_FRAME_HACK(91); _NS_FRAME_HACK(92);
	  _NS_FRAME_HACK(93); _NS_FRAME_HACK(94); _NS_FRAME_HACK(95);
	  _NS_FRAME_HACK(96); _NS_FRAME_HACK(97); _NS_FRAME_HACK(98);
	  _NS_FRAME_HACK(99);
	  default: val = NULL; break;
	}
      signal(SIGSEGV, old);
    }
  else
    {
      env = jbuf();
      memcpy(&old, env + 1, sizeof(old));
      signal(SIGSEGV, old);
      val = NULL;
    }
  return val;
}

static void *
NSReturnAddress(int offset)
{
  jmp_buf	*env;
  void		(*old)(int);
  void		*val;

  env = jbuf();
  if (setjmp(*env) == 0)
    {
      old = signal(SIGSEGV, recover);
      memcpy(env + 1, &old, sizeof(old));
      switch (offset)
	{
	  _NS_RETURN_HACK(0); _NS_RETURN_HACK(1); _NS_RETURN_HACK(2);
	  _NS_RETURN_HACK(3); _NS_RETURN_HACK(4); _NS_RETURN_HACK(5);
	  _NS_RETURN_HACK(6); _NS_RETURN_HACK(7); _NS_RETURN_HACK(8);
	  _NS_RETURN_HACK(9); _NS_RETURN_HACK(10); _NS_RETURN_HACK(11);
	  _NS_RETURN_HACK(12); _NS_RETURN_HACK(13); _NS_RETURN_HACK(14);
	  _NS_RETURN_HACK(15); _NS_RETURN_HACK(16); _NS_RETURN_HACK(17);
	  _NS_RETURN_HACK(18); _NS_RETURN_HACK(19); _NS_RETURN_HACK(20);
	  _NS_RETURN_HACK(21); _NS_RETURN_HACK(22); _NS_RETURN_HACK(23);
	  _NS_RETURN_HACK(24); _NS_RETURN_HACK(25); _NS_RETURN_HACK(26);
	  _NS_RETURN_HACK(27); _NS_RETURN_HACK(28); _NS_RETURN_HACK(29);
	  _NS_RETURN_HACK(30); _NS_RETURN_HACK(31); _NS_RETURN_HACK(32);
	  _NS_RETURN_HACK(33); _NS_RETURN_HACK(34); _NS_RETURN_HACK(35);
	  _NS_RETURN_HACK(36); _NS_RETURN_HACK(37); _NS_RETURN_HACK(38);
	  _NS_RETURN_HACK(39); _NS_RETURN_HACK(40); _NS_RETURN_HACK(41);
	  _NS_RETURN_HACK(42); _NS_RETURN_HACK(43); _NS_RETURN_HACK(44);
	  _NS_RETURN_HACK(45); _NS_RETURN_HACK(46); _NS_RETURN_HACK(47);
	  _NS_RETURN_HACK(48); _NS_RETURN_HACK(49); _NS_RETURN_HACK(50);
	  _NS_RETURN_HACK(51); _NS_RETURN_HACK(52); _NS_RETURN_HACK(53);
	  _NS_RETURN_HACK(54); _NS_RETURN_HACK(55); _NS_RETURN_HACK(56);
	  _NS_RETURN_HACK(57); _NS_RETURN_HACK(58); _NS_RETURN_HACK(59);
	  _NS_RETURN_HACK(60); _NS_RETURN_HACK(61); _NS_RETURN_HACK(62);
	  _NS_RETURN_HACK(63); _NS_RETURN_HACK(64); _NS_RETURN_HACK(65);
	  _NS_RETURN_HACK(66); _NS_RETURN_HACK(67); _NS_RETURN_HACK(68);
	  _NS_RETURN_HACK(69); _NS_RETURN_HACK(70); _NS_RETURN_HACK(71);
	  _NS_RETURN_HACK(72); _NS_RETURN_HACK(73); _NS_RETURN_HACK(74);
	  _NS_RETURN_HACK(75); _NS_RETURN_HACK(76); _NS_RETURN_HACK(77);
	  _NS_RETURN_HACK(78); _NS_RETURN_HACK(79); _NS_RETURN_HACK(80);
	  _NS_RETURN_HACK(81); _NS_RETURN_HACK(82); _NS_RETURN_HACK(83);
	  _NS_RETURN_HACK(84); _NS_RETURN_HACK(85); _NS_RETURN_HACK(86);
	  _NS_RETURN_HACK(87); _NS_RETURN_HACK(88); _NS_RETURN_HACK(89);
	  _NS_RETURN_HACK(90); _NS_RETURN_HACK(91); _NS_RETURN_HACK(92);
	  _NS_RETURN_HACK(93); _NS_RETURN_HACK(94); _NS_RETURN_HACK(95);
	  _NS_RETURN_HACK(96); _NS_RETURN_HACK(97); _NS_RETURN_HACK(98);
	  _NS_RETURN_HACK(99);
	  default: val = NULL; break;
	}
      signal(SIGSEGV, old);
    }
  else
    {
      env = jbuf();
      memcpy(&old, env + 1, sizeof(old));
      signal(SIGSEGV, old);
      val = NULL;
    }

  return val;
}

static unsigned NSCountFrames(void)
{
   unsigned    x = 0;

   while (NSFrameAddress(x + 1)) x++;

   return x;
}


static void *
__objc_dynamic_get_symbol_path(dl_handle_t handle, dl_symbol_t symbol)
{
  dl_symbol_t sym;
  Dl_info     info;

  if (handle == 0)
    handle = RTLD_DEFAULT;

  sym = dlsym(handle, symbol);

  if (!sym)
    return NULL;

  if (!dladdr(sym, &info))
    return NULL;

  return (void *) info.dli_fname;
}

static NSArray*
GSListModules()
{
  NSArray	*result;

  GSLoadModule(nil);	// initialise
  [modLock lock];
  result = [stackModules allValues];
  [modLock unlock];
  return result;
}

@implementation GSStackTrace : NSObject

+ (GSStackTrace*) currentStack
{
  return [[[GSStackTrace alloc] init] autorelease];
}

- (oneway void) dealloc
{
  [frames release];
  frames = nil;

  [super dealloc];
}

- (NSString*) description
{
  NSMutableString *result = [NSMutableString string];
  int i;
  int n;

  n = [frames count];
  for (i = 0; i < n; i++)
    {
      id	line = [frames objectAtIndex: i];

      [result appendFormat: @"%3d: %@\n", i, line];
    }
  return result;
}

- (NSEnumerator*) enumerator
{
  return [frames objectEnumerator];
}

- (id) frameAt: (unsigned)index
{
  return [frames objectAtIndex: index];
}

- (unsigned) frameCount
{
  return [frames count];
}

// grab the current stack 
- (id) init
{
#if	defined(STACKSYMBOLS)
  int i;
  int n;

  frames = [[NSMutableArray alloc] init];
  n = NSCountFrames();

  for (i = 0; i < n; i++)
    {
      GSFunctionInfo	*aFrame = nil;
      void		*address = NSReturnAddress(i);
      void		*base;
      NSString		*modulePath = __objc_dynamic_get_symbol_path(address, &base);
      GSBinaryFileInfo	*bfi;

      if (modulePath != nil && (bfi = GSLoadModule(modulePath)) != nil)
        {
	  aFrame = [bfi functionForAddress: (void*)(address - base)];
	  if (aFrame == nil)
	    {
	      /* We know we have the right module be function lookup
	       * failed ... perhaps we need to use the absolute
	       * address rather than offest by 'base' in this case.
	       */
	      aFrame = [bfi functionForAddress: address];
	    }
//if (aFrame == nil) NSLog(@"BFI base for %@ (%p) is %p", modulePath, address, base);
	}
      else
        {
	  NSArray	*modules;
	  int		j;
	  int		m;

//if (modulePath != nil) NSLog(@"BFI not found for %@ (%p)", modulePath, address);

	  modules = GSListModules();
	  m = [modules count];
	  for (j = 0; j < m; j++)
	    {
	      bfi = [modules objectAtIndex: j];

	      if ((id)bfi != (id)[NSNull null])
		{
		  aFrame = [bfi functionForAddress: address];
		  if (aFrame != nil)
		    {
		      break;
		    }
		}
	    }
	}

      // not found (?!), add an 'unknown' function
      if (aFrame == nil)
	{
	  aFrame = [GSFunctionInfo alloc];
	  [aFrame initWithModule: nil
			 address: address 
			    file: nil
			function: nil
			    line: 0];
	  [aFrame autorelease];
	}
      [frames addObject: aFrame];
    }
#else
  int i;
  int n;

  frames = [[NSMutableArray alloc] init];
  n = NSCountFrames();

  for (i = 0; i < n; i++)
    {
      void		*address = NSReturnAddress(i);

      [frames addObject: [NSString stringWithFormat: @"%p", address]];
    }
#endif

  return self;
}

- (NSEnumerator*) reverseEnumerator
{
  return [frames reverseObjectEnumerator];
}

@end

// #endif /* GNUSTEP_BASE_MINOR_VERSION */
// #endif /* GNUSTEP_BASE_MAJOR_VERSION */
