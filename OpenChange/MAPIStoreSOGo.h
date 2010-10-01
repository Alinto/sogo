#ifndef __MAPISTORE_SOGO_H
#define	__MAPISTORE_SOGO_H

#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <dlinklist.h>

/* These are essentially local versions of part of the 
   C99 __STDC_FORMAT_MACROS */
#ifndef PRIx64
#if __WORDSIZE == 64
  #define PRIx64        "lx"
#else
  #define PRIx64        "llx"
#endif
#endif

#ifndef PRIX64
#if __WORDSIZE == 64
  #define PRIX64        "lX"
#else
  #define PRIX64        "llX"
#endif
#endif

@class MAPIStoreContext;

typedef struct {
    MAPIStoreContext *objcContext;
} sogo_context;

__BEGIN_DECLS

int	mapistore_init_backend(void);

__END_DECLS

#endif /* !__MAPISTORE_SOGO_H */
