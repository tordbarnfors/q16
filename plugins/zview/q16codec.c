/*=========================================================================
*
*   q16codec.c - Q16 codec for zView (https://github.com/th-otto/zview).
*
*   Built as an LDG library (Q16.LDG) that zView loads from its codecs
*   folder. Decodes Q16 pictures to 24-bit RGB lines and encodes 24-bit
*   RGB lines into Q16. Pictures with alpha are blended against the
*   background color requested by zView.
*
*   Uses q16_lib.c for compression and decompression, so it runs on any
*   Atari (68000 and up).
*
*=========================================================================*/

#include <string.h>
#include <osbind.h>
#include <ldg.h>

#include "imginfo.h"
#include "q16_lib.h"

#define VERSION		0x100
#define NAME		"Q16 (RGB565 with alpha)"
#define AUTHOR		"Q16 project"
#define EXTENSIONS	"Q16\0"

/* Private data, kept in img_info->_priv_ptr. */

typedef struct
{
	uint16_t *	pixels;			/* Decoded RGB565 pixels or pixels to encode */
	uint8_t *	alpha;			/* Decoded alpha, NULL if none */
	long		line;			/* Next line to read or write */
	int16_t		handle;			/* File handle when encoding */
} q16_codec;

static void * xmalloc( long size )
{
	long p = Malloc( size );
	return p > 0 ? (void *) p : NULL;
}

static void xfree( void * p )
{
	if( p )
		Mfree( p );
}

static void free_codec( q16_codec * c )
{
	if( c )
	{
		xfree( c->pixels );
		xfree( c->alpha );
		xfree( c );
	}
}

/* Expands 5 or 6 bits to 8 by replicating the high bits. */

static uint8_t expand5( unsigned v ) { return (uint8_t) ((v << 3) | (v >> 2)); }
static uint8_t expand6( unsigned v ) { return (uint8_t) ((v << 2) | (v >> 4)); }

/* (a * b) / 255 rounded, for a, b in 0-255. */

static unsigned mul255( unsigned a, unsigned b )
{
	unsigned long x = (unsigned long) a * b + 128;
	return (unsigned) ((x + (x >> 8)) >> 8);
}


/*____ reader_init() _____________________________________________________*/

boolean __CDECL reader_init( const char * name, IMGINFO info )
{
	long handle, size;
	uint8_t * file = NULL;
	uint8_t * table = NULL;
	q16_codec * c = NULL;
	uint16_t width, height, instance[65];
	uint8_t alphaInstance[1], flags, version;
	uint32_t pixelBytes, alphaBytes;
	unsigned long nbPixels;
	q16_result res;

	handle = Fopen( name, 0 );
	if( handle < 0 )
		return FALSE;
	size = Fseek( 0, (int16_t) handle, 2 );
	Fseek( 0, (int16_t) handle, 0 );

	if( size < (long) sizeof(q16_fileheader) || (file = xmalloc( size )) == NULL
		|| Fread( (int16_t) handle, size, file ) != size )
	{
		Fclose( (int16_t) handle );
		xfree( file );
		return FALSE;
	}
	Fclose( (int16_t) handle );

	if( q16_readHeader( (q16_fileheader *) file, &width, &height, &pixelBytes, &alphaBytes, &flags, &version ) != 0
		|| width == 0 || height == 0
		|| sizeof(q16_fileheader) + (unsigned long) pixelBytes + alphaBytes > (unsigned long) size )
		goto fail;

	nbPixels = (unsigned long) width * height;

	c = xmalloc( sizeof(q16_codec) );
	table = xmalloc( 65536 );
	if( !c || !table )
		goto fail;
	memset( c, 0, sizeof(q16_codec) );
	c->pixels = xmalloc( nbPixels * 2 );
	if( !c->pixels || (alphaBytes && (c->alpha = xmalloc( nbPixels )) == NULL) )
		goto fail;

	q16_setupStaticTable( table );
	q16_beginPixelDecompression( instance );
	res = q16_decompressPixels( c->pixels, file + sizeof(q16_fileheader),
								file + sizeof(q16_fileheader) + pixelBytes, instance, table );
	if( res.readEnd != file + sizeof(q16_fileheader) + pixelBytes || res.writeEnd != c->pixels + nbPixels )
		goto fail;

	if( alphaBytes )
	{
		const uint8_t * p = file + sizeof(q16_fileheader) + pixelBytes;
		q16_beginAlphaDecompression( alphaInstance );
		res = q16_decompressAlpha( c->alpha, p, p + alphaBytes, alphaInstance );
		if( res.readEnd != p + alphaBytes || res.writeEnd != c->alpha + nbPixels )
			goto fail;
	}

	xfree( table );
	xfree( file );

	info->width = width;
	info->height = height;
	info->real_width = width;
	info->real_height = height;
	info->components = 3;
	info->planes = alphaBytes ? 32 : 16;
	info->colors = 65536;
	info->indexed_color = FALSE;
	info->orientation = UP_TO_DOWN;
	info->page = 1;
	info->delay = 0;
	info->num_comments = 0;
	info->max_comments_length = 0;
	info->memory_alloc = TT_RAM;
	strcpy( info->info, alphaBytes ? "Q16 RGB565 + alpha" : "Q16 RGB565" );
	strcpy( info->compression, "Q16" );

	info->_priv_ptr = c;
	return TRUE;

fail:
	free_codec( c );
	xfree( table );
	xfree( file );
	return FALSE;
}


/*____ reader_read() _____________________________________________________*/

boolean __CDECL reader_read( IMGINFO info, uint8_t * buffer )
{
	q16_codec * c = (q16_codec *) info->_priv_ptr;
	const uint16_t * p;
	const uint8_t * a;
	int x;

	if( !c || c->line >= info->height )
		return FALSE;

	p = c->pixels + c->line * info->width;

	if( !c->alpha )
	{
		for( x = info->width ; x > 0 ; x-- )
		{
			uint16_t pixel = *p++;
			*buffer++ = expand5( pixel >> 11 );
			*buffer++ = expand6( (pixel >> 5) & 63 );
			*buffer++ = expand5( pixel & 31 );
		}
	}
	else
	{
		unsigned bgR = (info->background_color >> 16) & 255;
		unsigned bgG = (info->background_color >> 8) & 255;
		unsigned bgB = info->background_color & 255;

		a = c->alpha + c->line * info->width;
		for( x = info->width ; x > 0 ; x-- )
		{
			uint16_t pixel = *p++;
			unsigned alpha = *a++, inv = 255 - alpha;
			*buffer++ = mul255( expand5( pixel >> 11 ), alpha ) + mul255( bgR, inv );
			*buffer++ = mul255( expand6( (pixel >> 5) & 63 ), alpha ) + mul255( bgG, inv );
			*buffer++ = mul255( expand5( pixel & 31 ), alpha ) + mul255( bgB, inv );
		}
	}

	c->line++;
	return TRUE;
}


/*____ reader_get_txt() / reader_quit() __________________________________*/

void __CDECL reader_get_txt( IMGINFO info, txt_data * txtdata )
{
	(void) info;
	(void) txtdata;
}

void __CDECL reader_quit( IMGINFO info )
{
	free_codec( (q16_codec *) info->_priv_ptr );
	info->_priv_ptr = NULL;
}


/*____ encoder_init() ____________________________________________________*/

boolean __CDECL encoder_init( const char * name, IMGINFO info )
{
	q16_codec * c;
	long handle;

	c = xmalloc( sizeof(q16_codec) );
	if( !c )
		return FALSE;
	memset( c, 0, sizeof(q16_codec) );
	c->pixels = xmalloc( (long) info->width * info->height * 2 );
	if( !c->pixels )
	{
		free_codec( c );
		return FALSE;
	}

	handle = Fcreate( name, 0 );
	if( handle < 0 )
	{
		free_codec( c );
		return FALSE;
	}
	c->handle = (int16_t) handle;

	info->planes = 24;
	info->components = 3;
	info->colors = 1L << 24;
	info->orientation = UP_TO_DOWN;
	info->indexed_color = FALSE;
	info->memory_alloc = TT_RAM;
	info->page = 1;

	info->_priv_ptr = c;
	return TRUE;
}


/*____ encoder_write() ___________________________________________________*/

boolean __CDECL encoder_write( IMGINFO info, uint8_t * buffer )
{
	q16_codec * c = (q16_codec *) info->_priv_ptr;
	uint16_t * p;
	int x;

	if( !c || c->line >= info->height )
		return FALSE;

	p = c->pixels + c->line * info->width;
	for( x = info->width ; x > 0 ; x-- )
	{
		*p++ = ((buffer[0] & 0xF8) << 8) | ((buffer[1] & 0xFC) << 3) | (buffer[2] >> 3);
		buffer += 3;
	}

	/* Compress and write the file after the last line, since
	   encoder_quit() can't return errors. */

	if( ++c->line == info->height )
	{
		unsigned long nbPixels = (unsigned long) info->width * info->height;
		long size = sizeof(q16_fileheader) + q16_minPixelCompressionBuffer( nbPixels, 1 );
		uint8_t * out = xmalloc( size );
		uint8_t * table = xmalloc( 65536 );
		uint16_t instance[65];
		uint8_t * end;
		long len;

		if( !out || !table )
		{
			xfree( out );
			xfree( table );
			return FALSE;
		}

		q16_setupStaticTable( table );
		q16_beginPixelCompression( instance );
		end = q16_compressPixels( out + sizeof(q16_fileheader), c->pixels, c->pixels + nbPixels, instance, table );
		q16_writeHeader( (q16_fileheader *) out, info->width, info->height,
						 end - (out + sizeof(q16_fileheader)), 0, 0 );
		len = end - out;
		x = Fwrite( c->handle, len, out ) == len;
		xfree( table );
		xfree( out );
		return x ? TRUE : FALSE;
	}
	return TRUE;
}


/*____ encoder_quit() ____________________________________________________*/

void __CDECL encoder_quit( IMGINFO info )
{
	q16_codec * c = (q16_codec *) info->_priv_ptr;

	if( c && c->handle > 0 )
		Fclose( c->handle );
	free_codec( c );
	info->_priv_ptr = NULL;
}


/*____ LDG library _______________________________________________________*/

static void __CDECL plugin_init( void )
{
}

static PROC functions[] =
{
	{ "plugin_init",    "Codec: " NAME,     (void *) plugin_init },
	{ "reader_init",    "Author: " AUTHOR,  (void *) reader_init },
	{ "reader_read",    "Date: " __DATE__,  (void *) reader_read },
	{ "reader_quit",    "",                 (void *) reader_quit },
	{ "reader_get_txt", "",                 (void *) reader_get_txt },
	{ "encoder_init",   "",                 (void *) encoder_init },
	{ "encoder_write",  "",                 (void *) encoder_write },
	{ "encoder_quit",   "",                 (void *) encoder_quit }
};

static LDGLIB library =
{
	VERSION,								/* Library version */
	sizeof(functions) / sizeof(functions[0]),
	functions,
	EXTENSIONS,								/* File types handled, double zero terminated */
	LDG_NOT_SHARED,							/* Each client gets its own copy */
	0,										/* No function called on unload */
	0										/* 0 = extension list is double zero terminated */
};

int main( void )
{
	ldg_init( &library );
	return 0;
}
