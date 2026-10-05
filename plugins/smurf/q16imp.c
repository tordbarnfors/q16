/*=========================================================================
*
*   q16imp.c - Q16 import module for Smurf (https://github.com/th-otto/smurf).
*
*   Decodes Q16 pictures into 16-bit RGB565, Smurf's (and the Falcon's)
*   native True Color format. Smurf has no alpha channel, so pictures with
*   alpha are blended against white.
*
*=========================================================================*/

#include <string.h>
#include "import.h"
#include "smurfine.h"
#include "smurfabi.h"
#include "q16_lib.h"

MOD_INFO module_info =
{
	"Q16",						/* Name of module */
	0x0100,						/* Version */
	"Q16 project",				/* Author */
	{ "Q16", "", "", "", "", "", "", "", "", "" },
	{ NULL, NULL, NULL, NULL },
	{ NULL, NULL, NULL, NULL },
	{ NULL, NULL, NULL, NULL },
	{ { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
	{ { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
	{ 0, 0, 0, 0 },
	{ 0, 0, 0, 0 },
	{ 0, 0, 0, 0 },
	0,
	COMPILER_ID,
	{ NULL, NULL, NULL, NULL, NULL, NULL }
};

/* Blends RGB565 pixels with alpha against white. */

static void blend_white( uint16_t * pixels, const uint8_t * alpha, unsigned long n )
{
	while( n-- )
	{
		unsigned a = *alpha++;
		if( a != 255 )
		{
			unsigned p = *pixels, inv = 255 - a;
			unsigned r = ((p >> 11) * a + 31 * inv + 127) / 255;
			unsigned g = (((p >> 5) & 63) * a + 63 * inv + 127) / 255;
			unsigned b = ((p & 31) * a + 31 * inv + 127) / 255;
			*pixels = (uint16_t) ((r << 11) | (g << 5) | b);
		}
		pixels++;
	}
}

short imp_module_main( GARGAMEL * smurf_struct )
{
	SMURF_PIC * pic = smurf_struct->smurf_pic;
	uint8_t * file = pic->pic_data;
	uint16_t width, height, instance[65];
	uint8_t alphaInstance[1], flags, version;
	uint32_t pixelBytes, alphaBytes;
	unsigned long nbPixels;
	uint16_t * pixels;
	uint8_t * alpha = NULL;
	q16_result res;
	const uint8_t * p;

	if( pic->file_len < (long) sizeof(q16_fileheader)
		|| q16_readHeader( (q16_fileheader *) file, &width, &height, &pixelBytes, &alphaBytes, &flags, &version ) != 0
		|| width == 0 || height == 0
		|| sizeof(q16_fileheader) + (unsigned long) pixelBytes + alphaBytes > (unsigned long) pic->file_len )
		return M_INVALID;

	nbPixels = (unsigned long) width * height;
	pixels = SMALLOC( smurf_struct, nbPixels * 2 );
	if( alphaBytes )
		alpha = SMALLOC( smurf_struct, nbPixels );
	if( !pixels || (alphaBytes && !alpha) )
	{
		if( pixels ) SMFREE( smurf_struct, pixels );
		if( alpha ) SMFREE( smurf_struct, alpha );
		return M_MEMORY;
	}

	p = file + sizeof(q16_fileheader);
	q16_beginPixelDecompression( instance );
	res = q16_decompressPixels( pixels, p, p + pixelBytes, instance );
	if( res.readEnd != p + pixelBytes || res.writeEnd != pixels + nbPixels )
		goto corrupt;

	if( alphaBytes )
	{
		p += pixelBytes;
		q16_beginAlphaDecompression( alphaInstance );
		res = q16_decompressAlpha( alpha, p, p + alphaBytes, alphaInstance );
		if( res.readEnd != p + alphaBytes || res.writeEnd != alpha + nbPixels )
			goto corrupt;
		blend_white( pixels, alpha, nbPixels );
		SMFREE( smurf_struct, alpha );
	}

	SMFREE( smurf_struct, file );
	pic->pic_data = pixels;
	pic->pic_width = width;
	pic->pic_height = height;
	pic->depth = 16;
	pic->bp_pal = 0;
	pic->col_format = RGB;
	strcpy( pic->format_name, alphaBytes ? "Q16 RGB565+Alpha" : "Q16 RGB565" );
	return M_PICDONE;

corrupt:
	SMFREE( smurf_struct, pixels );
	if( alpha ) SMFREE( smurf_struct, alpha );
	return M_PICERR;
}
