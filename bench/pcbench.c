/*=========================================================================
*
*   pcbench - Encoding and decoding speed of Q16, QOI, PNG and JPEG on PC.
*
*   Usage: pcbench <image directory> NAME [NAME ...]
*
*   Loads NAME_F.PNG (the full color original written by make_images.py)
*   for each NAME and times encoding and decoding with:
*
*   Q16   q16_lib.c                    RGB565 (+ alpha)
*   QOI   qoi_encode/qoi_decode below  RGB565 pixels expanded to 8 bits
*   PNG   libpng (zlib level 6)        RGB565 pixels expanded to 8 bits
*   PNG   stb_image_write / stb_image  RGB565 pixels expanded to 8 bits
*   JPEG  libjpeg-turbo q90 and q75    full color original (not if alpha)
*   JPEG  stb_image (decoding only)
*
*   Q16, QOI and PNG thus encode exactly the same pixels. Each operation is
*   repeated for at least 0.5 seconds. Prints CSV lines:
*
*   name,format,codec,bytes,encode_ms,decode_ms
*
*=========================================================================*/

#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <setjmp.h>

#include <png.h>
#include <jpeglib.h>

#define STB_IMAGE_IMPLEMENTATION
#include "../stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "../stb_image_write.h"

#include "../q16_lib.h"

/*____ Shared state ______________________________________________________*/

static int				g_w, g_h, g_ch;			/* Image size and channels (3 or 4) */
static uint8_t *		g_full;					/* Original full color pixels */
static uint8_t *		g_q8;					/* RGB565 pixels expanded to 8 bits (+ alpha) */
static uint16_t *		g_q16pix;				/* RGB565 pixels */
static uint8_t *		g_q16alpha;				/* Alpha, NULL if none */
static uint8_t *		g_buf;					/* Encoded data */
static size_t			g_bufSize, g_len;
static uint8_t *		g_out;					/* Decoded data */
static uint8_t			g_staticTable[65536];

static double now( void )
{
	struct timespec t;
	clock_gettime( CLOCK_MONOTONIC, &t );
	return t.tv_sec + t.tv_nsec * 1e-9;
}

/* Milliseconds per call, repeated for at least 0.5 s. */

static double timeit( void (*fn)(void) )
{
	double start, end;
	long count = 0;
	fn();
	start = now();
	do
	{
		fn();
		count++;
		end = now();
	} while( end - start < 0.5 );
	return (end - start) * 1000.0 / count;
}

/*____ Q16 _______________________________________________________________*/

static void q16_enc( void )
{
	uint16_t inst[65];
	long n = (long) g_w * g_h;
	uint8_t * p = g_buf + sizeof(q16_fileheader);
	uint8_t * pixEnd, * alphaEnd;

	q16_beginPixelCompression( inst );
	pixEnd = q16_compressPixels( p, g_q16pix, g_q16pix + n, inst, g_staticTable );
	alphaEnd = g_q16alpha ? q16_compressAlpha( pixEnd, g_q16alpha, g_q16alpha + n ) : pixEnd;
	q16_writeHeader( (q16_fileheader*) g_buf, g_w, g_h, pixEnd - p, alphaEnd - pixEnd, 0 );
	g_len = alphaEnd - g_buf;
}

static void q16_dec( void )
{
	uint16_t inst[65];
	uint8_t ainst[1];
	uint16_t w, h;
	uint32_t pb, ab;
	uint8_t flags, version;
	const uint8_t * p = g_buf + sizeof(q16_fileheader);

	q16_readHeader( (q16_fileheader*) g_buf, &w, &h, &pb, &ab, &flags, &version );
	q16_beginPixelDecompression( inst );
	q16_decompressPixels( (uint16_t*) g_out, p, p + pb, inst, g_staticTable );
	if( ab )
	{
		q16_beginAlphaDecompression( ainst );
		q16_decompressAlpha( g_out + (long) w * h * 2, p + pb, p + pb + ab, ainst );
	}
}

/*____ QOI (from the specification at qoiformat.org) _____________________*/

#define QOI_OP_INDEX	0x00
#define QOI_OP_DIFF		0x40
#define QOI_OP_LUMA		0x80
#define QOI_OP_RUN		0xc0
#define QOI_OP_RGB		0xfe
#define QOI_OP_RGBA		0xff
#define QOI_HASH(r,g,b,a)	(((r)*3 + (g)*5 + (b)*7 + (a)*11) & 63)

static void put32( uint8_t * p, uint32_t v ) { p[0] = v >> 24; p[1] = v >> 16; p[2] = v >> 8; p[3] = v; }
static uint32_t get32( const uint8_t * p ) { return ((uint32_t) p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]; }

static void qoi_enc( void )
{
	uint8_t index[64][4] = {{0}};
	uint8_t pr = 0, pg = 0, pb = 0, pa = 255;
	uint8_t * o = g_buf;
	const uint8_t * s = g_q8;
	long n = (long) g_w * g_h, i;
	int run = 0;

	memcpy( o, "qoif", 4 );
	put32( o + 4, g_w );
	put32( o + 8, g_h );
	o[12] = g_ch;
	o[13] = 0;
	o += 14;

	for( i = 0 ; i < n ; i++, s += g_ch )
	{
		uint8_t r = s[0], g = s[1], b = s[2], a = g_ch == 4 ? s[3] : 255;
		if( r == pr && g == pg && b == pb && a == pa )
		{
			if( ++run == 62 || i == n - 1 )
			{
				*o++ = QOI_OP_RUN | (run - 1);
				run = 0;
			}
			continue;
		}
		if( run )
		{
			*o++ = QOI_OP_RUN | (run - 1);
			run = 0;
		}
		int h = QOI_HASH( r, g, b, a );
		if( index[h][0] == r && index[h][1] == g && index[h][2] == b && index[h][3] == a )
			*o++ = QOI_OP_INDEX | h;
		else
		{
			index[h][0] = r; index[h][1] = g; index[h][2] = b; index[h][3] = a;
			if( a == pa )
			{
				int8_t dr = r - pr, dg = g - pg, db = b - pb;
				int8_t dgr = dr - dg, dgb = db - dg;
				if( dr > -3 && dr < 2 && dg > -3 && dg < 2 && db > -3 && db < 2 )
					*o++ = QOI_OP_DIFF | ((dr + 2) << 4) | ((dg + 2) << 2) | (db + 2);
				else if( dgr > -9 && dgr < 8 && dg > -33 && dg < 32 && dgb > -9 && dgb < 8 )
				{
					*o++ = QOI_OP_LUMA | (dg + 32);
					*o++ = ((dgr + 8) << 4) | (dgb + 8);
				}
				else
				{
					*o++ = QOI_OP_RGB; *o++ = r; *o++ = g; *o++ = b;
				}
			}
			else
			{
				*o++ = QOI_OP_RGBA; *o++ = r; *o++ = g; *o++ = b; *o++ = a;
			}
		}
		pr = r; pg = g; pb = b; pa = a;
	}
	memcpy( o, "\0\0\0\0\0\0\0\1", 8 );
	g_len = o + 8 - g_buf;
}

static void qoi_dec( void )
{
	uint8_t index[64][4] = {{0}};
	uint8_t r = 0, g = 0, b = 0, a = 255;
	const uint8_t * p = g_buf + 14;
	int ch = g_buf[12];
	long n = (long) get32( g_buf + 4 ) * get32( g_buf + 8 ), i;
	uint8_t * o = g_out;
	int run = 0;

	for( i = 0 ; i < n ; i++ )
	{
		if( run )
			run--;
		else
		{
			int v = *p++;
			if( v == QOI_OP_RGB ) { r = *p++; g = *p++; b = *p++; }
			else if( v == QOI_OP_RGBA ) { r = *p++; g = *p++; b = *p++; a = *p++; }
			else if( (v & 0xc0) == QOI_OP_INDEX ) { r = index[v][0]; g = index[v][1]; b = index[v][2]; a = index[v][3]; }
			else if( (v & 0xc0) == QOI_OP_DIFF ) { r += ((v >> 4) & 3) - 2; g += ((v >> 2) & 3) - 2; b += (v & 3) - 2; }
			else if( (v & 0xc0) == QOI_OP_LUMA ) { int v2 = *p++, dg = (v & 0x3f) - 32; r += dg - 8 + ((v2 >> 4) & 15); g += dg; b += dg - 8 + (v2 & 15); }
			else run = v & 0x3f;
			int h = QOI_HASH( r, g, b, a );
			index[h][0] = r; index[h][1] = g; index[h][2] = b; index[h][3] = a;
		}
		o[0] = r; o[1] = g; o[2] = b;
		if( ch == 4 ) o[3] = a;
		o += ch;
	}
}

/*____ PNG with libpng ___________________________________________________*/

typedef struct { uint8_t * p; size_t len, pos; } membuf;

static void png_write_mem( png_structp png, png_bytep data, png_size_t n )
{
	membuf * m = png_get_io_ptr( png );
	memcpy( m->p + m->len, data, n );
	m->len += n;
}
static void png_flush_mem( png_structp png ) { (void) png; }

static void png_read_mem( png_structp png, png_bytep data, png_size_t n )
{
	membuf * m = png_get_io_ptr( png );
	memcpy( data, m->p + m->pos, n );
	m->pos += n;
}

static void libpng_enc( void )
{
	png_structp png = png_create_write_struct( PNG_LIBPNG_VER_STRING, NULL, NULL, NULL );
	png_infop info = png_create_info_struct( png );
	membuf m = { g_buf, 0, 0 };
	png_bytep rows[4096];
	int y;

	png_set_write_fn( png, &m, png_write_mem, png_flush_mem );
	png_set_IHDR( png, info, g_w, g_h, 8, g_ch == 4 ? PNG_COLOR_TYPE_RGBA : PNG_COLOR_TYPE_RGB,
				  PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT );
	for( y = 0 ; y < g_h ; y++ )
		rows[y] = g_q8 + (long) y * g_w * g_ch;
	png_set_rows( png, info, rows );
	png_write_png( png, info, PNG_TRANSFORM_IDENTITY, NULL );
	png_destroy_write_struct( &png, &info );
	g_len = m.len;
}

static void libpng_dec( void )
{
	png_structp png = png_create_read_struct( PNG_LIBPNG_VER_STRING, NULL, NULL, NULL );
	png_infop info = png_create_info_struct( png );
	membuf m = { g_buf, g_len, 0 };
	png_bytep rows[4096];
	int y;

	png_set_read_fn( png, &m, png_read_mem );
	png_read_info( png, info );
	for( y = 0 ; y < g_h ; y++ )
		rows[y] = g_out + (long) y * g_w * g_ch;
	png_read_image( png, rows );
	png_read_end( png, NULL );
	png_destroy_read_struct( &png, &info, NULL );
}

/*____ PNG with stb ______________________________________________________*/

static void stb_write_mem( void * ctx, void * data, int n )
{
	(void) ctx;
	memcpy( g_buf + g_len, data, n );
	g_len += n;
}

static void stbpng_enc( void )
{
	g_len = 0;
	stbi_write_png_to_func( stb_write_mem, NULL, g_w, g_h, g_ch, g_q8, g_w * g_ch );
}

static void stb_dec( void )
{
	int w, h, c;
	stbi_image_free( stbi_load_from_memory( g_buf, g_len, &w, &h, &c, 0 ) );
}

/*____ JPEG with libjpeg-turbo ___________________________________________*/

static int g_quality;

static void turbo_enc( void )
{
	struct jpeg_compress_struct cinfo;
	struct jpeg_error_mgr jerr;
	unsigned char * out = g_buf;
	unsigned long outSize = g_bufSize;
	JSAMPROW row;

	cinfo.err = jpeg_std_error( &jerr );
	jpeg_create_compress( &cinfo );
	jpeg_mem_dest( &cinfo, &out, &outSize );
	cinfo.image_width = g_w;
	cinfo.image_height = g_h;
	cinfo.input_components = 3;
	cinfo.in_color_space = JCS_RGB;
	jpeg_set_defaults( &cinfo );
	jpeg_set_quality( &cinfo, g_quality, TRUE );
	jpeg_start_compress( &cinfo, TRUE );
	while( cinfo.next_scanline < cinfo.image_height )
	{
		row = g_full + (long) cinfo.next_scanline * g_w * 3;
		jpeg_write_scanlines( &cinfo, &row, 1 );
	}
	jpeg_finish_compress( &cinfo );
	jpeg_destroy_compress( &cinfo );
	g_len = outSize;
}

static void turbo_dec( void )
{
	struct jpeg_decompress_struct cinfo;
	struct jpeg_error_mgr jerr;
	JSAMPROW row;

	cinfo.err = jpeg_std_error( &jerr );
	jpeg_create_decompress( &cinfo );
	jpeg_mem_src( &cinfo, g_buf, g_len );
	jpeg_read_header( &cinfo, TRUE );
	cinfo.out_color_space = JCS_RGB;
	jpeg_start_decompress( &cinfo );
	while( cinfo.output_scanline < cinfo.output_height )
	{
		row = g_out + (long) cinfo.output_scanline * cinfo.output_width * 3;
		jpeg_read_scanlines( &cinfo, &row, 1 );
	}
	jpeg_finish_decompress( &cinfo );
	jpeg_destroy_decompress( &cinfo );
}

/*____ Main ______________________________________________________________*/

static void run( const char * name, const char * format, const char * codec,
				 void (*enc)(void), void (*dec)(void), void (*dec2)(void), const char * codec2 )
{
	double te = timeit( enc );			/* Leaves encoded data in g_buf. */
	double td = timeit( dec );
	printf( "%s,%s,%s,%zu,%.3f,%.3f\n", name, format, codec, g_len, te, td );
	if( dec2 )
		printf( "%s,%s,%s,%zu,,%.3f\n", name, format, codec2, g_len, timeit( dec2 ) );
	fflush( stdout );
}

int main( int argc, char * argv[] )
{
	int i;
	if( argc < 3 )
	{
		fprintf( stderr, "usage: pcbench <image directory> NAME [NAME ...]\n" );
		return 1;
	}

	q16_setupStaticTable( g_staticTable );
	printf( "name,format,codec,bytes,encode_ms,decode_ms\n" );

	for( i = 2 ; i < argc ; i++ )
	{
		char path[1024];
		long n, k;

		snprintf( path, sizeof(path), "%s/%s_F.PNG", argv[1], argv[i] );
		g_full = stbi_load( path, &g_w, &g_h, &g_ch, 0 );
		if( !g_full || (g_ch != 3 && g_ch != 4) )
		{
			fprintf( stderr, "Can't load %s as RGB(A)\n", path );
			return 1;
		}

		n = (long) g_w * g_h;
		g_q8 = malloc( n * g_ch );
		g_q16pix = malloc( n * 2 );
		g_q16alpha = g_ch == 4 ? malloc( n ) : NULL;
		g_bufSize = n * 5 + 65536;
		g_buf = malloc( g_bufSize );
		g_out = malloc( n * 4 + 16 );

		for( k = 0 ; k < n ; k++ )
		{
			const uint8_t * s = g_full + k * g_ch;
			uint8_t * d = g_q8 + k * g_ch;
			d[0] = s[0] & 0xF8;
			d[1] = s[1] & 0xFC;
			d[2] = s[2] & 0xF8;
			g_q16pix[k] = ((s[0] >> 3) << 11) | ((s[1] >> 2) << 5) | (s[2] >> 3);
			if( g_ch == 4 )
				d[3] = g_q16alpha[k] = s[3];
		}

		run( argv[i], "Q16", "q16_lib", q16_enc, q16_dec, NULL, NULL );
		q16_dec();
		if( memcmp( g_out, g_q16pix, n * 2 ) || (g_q16alpha && memcmp( g_out + n * 2, g_q16alpha, n )) )
			fprintf( stderr, "%s: Q16 round trip FAILED\n", argv[i] );
		run( argv[i], "QOI", "qoi", qoi_enc, qoi_dec, NULL, NULL );
		qoi_dec();
		if( memcmp( g_out, g_q8, n * g_ch ) )
			fprintf( stderr, "%s: QOI round trip FAILED\n", argv[i] );
		run( argv[i], "PNG", "libpng", libpng_enc, libpng_dec, stb_dec, "stb_image" );
		libpng_enc();
		libpng_dec();
		if( memcmp( g_out, g_q8, n * g_ch ) )
			fprintf( stderr, "%s: PNG round trip FAILED\n", argv[i] );
		run( argv[i], "PNG", "stb", stbpng_enc, stb_dec, NULL, NULL );
		if( g_ch == 3 )
		{
			g_quality = 90;
			run( argv[i], "JPEG q90", "libjpeg-turbo", turbo_enc, turbo_dec, stb_dec, "stb_image" );
			g_quality = 75;
			run( argv[i], "JPEG q75", "libjpeg-turbo", turbo_enc, turbo_dec, stb_dec, "stb_image" );
		}

		stbi_image_free( g_full );
		free( g_q8 ); free( g_q16pix ); free( g_q16alpha ); free( g_buf ); free( g_out );
	}
	return 0;
}
