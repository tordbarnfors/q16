/*=========================================================================
*
*   q16exp.c - Q16 export module for Smurf (https://github.com/th-otto/smurf).
*
*   Saves 16-bit RGB565 pictures as Q16. Smurf converts pictures of other
*   depths to 16 bit before calling the module.
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

MOD_ABILITY module_ability =
{
	16, 0, 0, 0, 0, 0, 0, 0,	/* Only 16 bit, Smurf converts other depths */
	FORM_PIXELPAK,
	FORM_PIXELPAK,
	FORM_PIXELPAK,
	FORM_PIXELPAK,
	FORM_PIXELPAK,
	FORM_PIXELPAK,
	FORM_PIXELPAK,
	FORM_PIXELPAK,
	0
};

EXPORT_PIC * exp_module_main( GARGAMEL * smurf_struct )
{
	EXPORT_PIC * exp_pic;
	uint16_t * pixels;
	uint8_t * out, * end;
	uint16_t instance[65];
	unsigned long nbPixels;
	short width, height;

	switch( smurf_struct->module_mode )
	{
	case MEXTEND:
		smurf_struct->event_par[0] = 1;			/* Extension 1, "Q16" */
		smurf_struct->module_mode = M_EXTEND;
		return NULL;

	case MCOLSYS:
		smurf_struct->event_par[0] = RGB;
		smurf_struct->module_mode = M_COLSYS;
		return NULL;

	case MSTART:
		smurf_struct->module_mode = M_WAITING;
		return NULL;

	case MEXEC:
		pixels = smurf_struct->smurf_pic->pic_data;
		width = smurf_struct->smurf_pic->pic_width;
		height = smurf_struct->smurf_pic->pic_height;
		nbPixels = (unsigned long) width * height;

		exp_pic = (EXPORT_PIC *) Malloc( sizeof(EXPORT_PIC) );
		out = (uint8_t *) Malloc( sizeof(q16_fileheader) + q16_minPixelCompressionBuffer( nbPixels, 1 ) );
		if( !exp_pic || !out )
		{
			if( exp_pic ) Mfree( exp_pic );
			if( out ) Mfree( out );
			smurf_struct->module_mode = M_MEMORY;
			return NULL;
		}

		q16_beginPixelCompression( instance );
		end = q16_compressPixels( out + sizeof(q16_fileheader), pixels, pixels + nbPixels, instance );
		q16_writeHeader( (q16_fileheader *) out, width, height, end - (out + sizeof(q16_fileheader)), 0, 0 );

		exp_pic->pic_data = out;
		exp_pic->f_len = end - out;
		Mfree( pixels );						/* The 16 bit copy made for us by Smurf. */
		smurf_struct->module_mode = M_DONEEXIT;
		return exp_pic;

	case MTERM:
		smurf_struct->module_mode = M_EXIT;		/* exp_pic is freed by Smurf. */
		break;

	default:
		smurf_struct->module_mode = M_WAITING;
		break;
	}
	return NULL;
}
