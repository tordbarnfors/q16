/*=========================================================================
*
*   ldgmini.c - what Q16.LDG needs instead of a C library: ldg_init() for
*   the library side of the LDG protocol, and memcpy(), memset(), strcpy().
*   Used with ldgstart.s.
*
*=========================================================================*/

#include <stddef.h>
#include <ldg.h>

#define LDG_PROTOCOL	0x0235			/* Version of the LDG protocol */

extern char * basepage;					/* Set by ldgstart.s */

static LDG lib;

void * memcpy( void * dest, const void * src, size_t n );
void * memset( void * dest, int c, size_t n );
char * strcpy( char * dest, const char * src );
void __main( void );

void * memcpy( void * dest, const void * src, size_t n )
{
	char * d = dest;
	const char * s = src;
	while( n-- )
		*d++ = *s++;
	return dest;
}

void * memset( void * dest, int c, size_t n )
{
	char * d = dest;
	while( n-- )
		*d++ = (char) c;
	return dest;
}

char * strcpy( char * dest, const char * src )
{
	char * d = dest;
	while( (*d++ = *src++) != 0 )
		;
	return dest;
}

/* Called by main() for constructors, which aren't used. */

void __main( void )
{
}

/* The LDG manager passes the address to store the library descriptor at
*  in the environment variable OFFSETLDG, as a decimal number.
*/

int ldg_init( LDGLIB * ldglib )
{
	const char * env = *(char **) (basepage + 44);	/* p_env */
	unsigned long offset = 0;

	lib.magic = LDG_COOKIE;
	lib.vers = ldglib->vers;
	lib.num = ldglib->num;
	lib.list = ldglib->list;
	lib.infos = ldglib->infos;
	lib.flags = ldglib->flags & ~LDG_STDCALL;
	lib.close = ldglib->close;
	lib.vers_ldg = LDG_PROTOCOL;
	lib.user_ext = ldglib->user_ext;
	lib.addr_ext = 0;

	for( ; env && *env ; env++ )
	{
		const char * p = "OFFSETLDG=";
		while( *p && *env == *p )
			p++, env++;
		if( *p == 0 )
		{
			while( *env >= '0' && *env <= '9' )
				offset = offset * 10 + (*env++ - '0');
			*(LDG **) offset = &lib;
			return 0;
		}
		while( *env )
			env++;
	}
	return -1;		/* Not started by the LDG manager */
}
