/*=========================================================================
*
*   falcbench - Decoding speed benchmark for Atari Falcon (68030).
*
*   Decodes every .Q16, .PNG and .JPG file in the current directory (files
*   ending with _F.PNG are skipped) with the following decoders, repeating
*   each decode for at least two seconds:
*
*   Q16:  asm      - m68k/q16dec.s
*         C        - q16_lib.c
*   PNG:  libpng   - libpng + zlib, to 8-bit RGB(A)
*         stb      - stb_image, to 8-bit RGB(A)
*   JPEG: turbo    - libjpeg-turbo with default settings, to 8-bit RGB
*         turbo565 - libjpeg-turbo with fast settings (IFAST DCT, no fancy
*                    upsampling), directly to RGB565
*         stb      - stb_image, to 8-bit RGB
*
*   Results are printed and written to BENCH.TXT. Under Hatari the program
*   quits the emulator when done (Native Features), on real hardware it
*   waits for a key.
*
*   It also verifies that the asm and C Q16 decoders, as well as libpng and
*   stb_image, give identical results, and that NAME.Q16 decodes to the same
*   pixels as NAME.PNG.
*
*=========================================================================*/

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dirent.h>
#include <setjmp.h>

#include <png.h>
#include <jpeglib.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_ONLY_JPEG
#define STBI_NO_STDIO
#define STBI_NO_HDR
#define STBI_NO_LINEAR
#include "../stb_image.h"

#include "../m68k/q16dec.h"

/* C version of the Q16 decoder (q16lib_c.c), with prefixed names. */

typedef struct { const unsigned char * readEnd; void * writeEnd; } c_q16_result;

void			c_q16_beginPixelDecompression( unsigned short instanceTable[65] );
c_q16_result	c_q16_decompressPixels( unsigned short * pDest, const unsigned char * pBegin, const unsigned char * pEnd,
										unsigned short instanceTable[65], const unsigned char staticTable[65536] );
void			c_q16_beginAlphaDecompression( unsigned char instanceTable[1] );
c_q16_result	c_q16_decompressAlpha( unsigned char * pDest, const unsigned char * pBegin, const unsigned char * pEnd,
									   unsigned char instanceTable[1] );

int nf_shutdown( void );		/* natfeats.s */

#define MAX_PIXELS		(800*600)
#define MIN_TICKS		(2*CLOCKS_PER_SEC)

static unsigned char *	g_file;			/* File being decoded. */
static long				g_size;
static unsigned char *	g_out;			/* Output buffer, 4 bytes per pixel. */
static unsigned char *	g_alpha;		/* Alpha output for Q16. */
static unsigned char *	g_staticTable;
static int				g_width, g_height, g_channels;

static FILE *			g_log;
static int				g_firstRun;		/* First, untimed, decode. Output is kept for verification. */

static void out( const char * fmt, ... )
{
	char buf[256];
	va_list args;
	va_start( args, fmt );
	vsprintf( buf, fmt, args );
	va_end( args );
	fputs( buf, stdout );
	if( g_log )
		fputs( buf, g_log );
}

/*____ Checksums for verification ________________________________________*/

static unsigned long checksum( const unsigned char * p, unsigned long n )
{
	unsigned long s = 0;
	while( n-- )
		s = ((s << 1) | (s >> 31)) ^ *p++;
	return s;
}

/* Checksum of decoded RGB(A) output as RGB565 pixels + alpha, comparable with Q16. */

static unsigned long checksum565( void )
{
	unsigned long s = 0;
	unsigned char * p = g_out;
	long i, n = (long) g_width * g_height;

	for( i = 0 ; i < n ; i++ )
	{
		unsigned short pixel = ((p[0] & 0xF8) << 8) | ((p[1] & 0xFC) << 3) | (p[2] >> 3);
		s = ((s << 1) | (s >> 31)) ^ (pixel >> 8);
		s = ((s << 1) | (s >> 31)) ^ (pixel & 0xFF);
		p += g_channels;
	}
	if( g_channels == 4 )
		for( i = 0, p = g_out + 3 ; i < n ; i++, p += 4 )
			s = ((s << 1) | (s >> 31)) ^ *p;
	return s;
}

/*____ Q16 decoders ______________________________________________________*/

static unsigned short	g_q16w, g_q16h;
static unsigned long	g_pixelBytes, g_alphaBytes;

static int q16_header( void )
{
	unsigned char flags, version;
	if( q16_readHeader( (q16_fileheader*) g_file, &g_q16w, &g_q16h, &g_pixelBytes, &g_alphaBytes, &flags, &version ) != 0 )
		return -1;
	if( sizeof(q16_fileheader) + g_pixelBytes + g_alphaBytes > (unsigned long) g_size || (long) g_q16w * g_q16h > MAX_PIXELS )
		return -1;
	g_width = g_q16w;
	g_height = g_q16h;
	return 0;
}

static int dec_q16_asm( void )
{
	unsigned long n = (unsigned long) g_q16w * g_q16h;
	const unsigned char * p = g_file + sizeof(q16_fileheader);

	if( q_decPix( (unsigned short*) g_out, p, p + g_pixelBytes, n, g_staticTable ) != 0 )
		return -1;
	if( g_alphaBytes && q_decAlp( g_alpha, p + g_pixelBytes, p + g_pixelBytes + g_alphaBytes, n ) != 0 )
		return -1;
	return 0;
}

static int dec_q16_c( void )
{
	static unsigned short instance[65];
	static unsigned char alphaInstance[1];
	unsigned long n = (unsigned long) g_q16w * g_q16h;
	const unsigned char * p = g_file + sizeof(q16_fileheader);
	c_q16_result res;

	c_q16_beginPixelDecompression( instance );
	res = c_q16_decompressPixels( (unsigned short*) g_out, p, p + g_pixelBytes, instance, g_staticTable );
	if( res.readEnd != p + g_pixelBytes || res.writeEnd != ((unsigned short*) g_out) + n )
		return -1;

	if( g_alphaBytes )
	{
		c_q16_beginAlphaDecompression( alphaInstance );
		res = c_q16_decompressAlpha( g_alpha, p + g_pixelBytes, p + g_pixelBytes + g_alphaBytes, alphaInstance );
		if( res.readEnd != p + g_pixelBytes + g_alphaBytes || res.writeEnd != g_alpha + n )
			return -1;
	}
	return 0;
}

static unsigned long checksum_q16( void )
{
	unsigned long n = (unsigned long) g_q16w * g_q16h;
	unsigned long s = checksum( g_out, n * 2 );		/* Big endian pixels, same byte order as checksum565(). */
	if( g_alphaBytes )
	{
		unsigned long i;
		for( i = 0 ; i < n ; i++ )
			s = ((s << 1) | (s >> 31)) ^ g_alpha[i];
	}
	return s;
}

/*____ PNG decoders ______________________________________________________*/

typedef struct { const unsigned char * p; unsigned long left; } memsrc;

static void png_memread( png_structp png, png_bytep dest, png_size_t n )
{
	memsrc * m = (memsrc*) png_get_io_ptr( png );
	if( n > m->left )
		png_error( png, "Unexpected end of data" );
	memcpy( dest, m->p, n );
	m->p += n;
	m->left -= n;
}

static int dec_libpng( void )
{
	static png_bytep rows[MAX_PIXELS / 64];
	png_structp png;
	png_infop info;
	memsrc m;
	int y;

	png = png_create_read_struct( PNG_LIBPNG_VER_STRING, NULL, NULL, NULL );
	info = png_create_info_struct( png );
	if( setjmp( png_jmpbuf(png) ) )
	{
		png_destroy_read_struct( &png, &info, NULL );
		return -1;
	}

	m.p = g_file;
	m.left = g_size;
	png_set_read_fn( png, &m, png_memread );
	png_read_info( png, info );
	png_set_expand( png );
	png_set_strip_16( png );
	png_set_gray_to_rgb( png );
	png_read_update_info( png, info );

	g_width = png_get_image_width( png, info );
	g_height = png_get_image_height( png, info );
	g_channels = png_get_channels( png, info );
	if( (long) g_width * g_height > MAX_PIXELS )
		png_error( png, "Too large" );

	for( y = 0 ; y < g_height ; y++ )
		rows[y] = g_out + (long) y * g_width * g_channels;

	png_read_image( png, rows );
	png_read_end( png, NULL );
	png_destroy_read_struct( &png, &info, NULL );
	return 0;
}

static int dec_stb( void )
{
	int w, h, c;
	unsigned char * p = stbi_load_from_memory( g_file, g_size, &w, &h, &c, 0 );
	if( !p )
		return -1;
	g_width = w;
	g_height = h;
	g_channels = c;
	if( g_firstRun && (long) w * h * c <= MAX_PIXELS * 4 )
		memcpy( g_out, p, (long) w * h * c );		/* Kept for verification, not part of timed runs. */
	stbi_image_free( p );
	return 0;
}

/*____ JPEG decoders _____________________________________________________*/

struct jpeg_err { struct jpeg_error_mgr pub; jmp_buf jb; };

static void jpeg_err_exit( j_common_ptr cinfo )
{
	longjmp( ((struct jpeg_err*) cinfo->err)->jb, 1 );
}

static int dec_turbo_common( int fast )
{
	struct jpeg_decompress_struct cinfo;
	struct jpeg_err jerr;
	long stride;

	cinfo.err = jpeg_std_error( &jerr.pub );
	jerr.pub.error_exit = jpeg_err_exit;
	if( setjmp( jerr.jb ) )
	{
		jpeg_destroy_decompress( &cinfo );
		return -1;
	}

	jpeg_create_decompress( &cinfo );
	jpeg_mem_src( &cinfo, g_file, g_size );
	jpeg_read_header( &cinfo, TRUE );

	if( fast )
	{
		cinfo.out_color_space = JCS_RGB565;
		cinfo.dct_method = JDCT_IFAST;
		cinfo.do_fancy_upsampling = FALSE;
		cinfo.dither_mode = JDITHER_NONE;
	}
	else
		cinfo.out_color_space = JCS_RGB;

	jpeg_start_decompress( &cinfo );
	g_width = cinfo.output_width;
	g_height = cinfo.output_height;
	g_channels = fast ? 2 : 3;
	stride = (long) g_width * g_channels;
	if( (long) g_width * g_height > MAX_PIXELS )
		longjmp( jerr.jb, 1 );

	while( cinfo.output_scanline < cinfo.output_height )
	{
		JSAMPROW rows[4];
		int i;
		for( i = 0 ; i < 4 ; i++ )
			rows[i] = g_out + (cinfo.output_scanline + i) * stride;
		jpeg_read_scanlines( &cinfo, rows, cinfo.output_height - cinfo.output_scanline < 4 ? cinfo.output_height - cinfo.output_scanline : 4 );
	}

	jpeg_finish_decompress( &cinfo );
	jpeg_destroy_decompress( &cinfo );
	return 0;
}

static int dec_turbo( void )	{ return dec_turbo_common( 0 ); }
static int dec_turbo565( void )	{ return dec_turbo_common( 1 ); }

/*____ Timing ____________________________________________________________*/

/* Returns milliseconds * 100 per decode, or -1 on error. */

static long time_decoder( int (*decode)(void) )
{
	clock_t start, now;
	long count = 0;

	g_firstRun = 1;
	if( decode() != 0 )
		return -1;
	g_firstRun = 0;

	start = clock();
	while( (now = clock()) == start ) {}		/* Sync to tick. */
	start = now;
	do
	{
		decode();
		count++;
	} while( (now = clock()) - start < MIN_TICKS );

	return (long) (now - start) * 100000L / CLOCKS_PER_SEC / count;
}

/*____ Main ______________________________________________________________*/

typedef struct { char base[16]; unsigned long q16sum, pngsum; int hasQ16, hasPng; } verify_entry;

static verify_entry		g_verify[64];
static int				g_nbVerify;
static int				g_errors;

static verify_entry * verify_get( const char * name )
{
	char base[16];
	int i;
	for( i = 0 ; name[i] && name[i] != '.' && i < 15 ; i++ )
		base[i] = name[i];
	base[i] = 0;
	for( i = 0 ; i < g_nbVerify ; i++ )
		if( strcmp( g_verify[i].base, base ) == 0 )
			return &g_verify[i];
	strcpy( g_verify[g_nbVerify].base, base );
	return &g_verify[g_nbVerify++];
}

static int compare_names( const void * a, const void * b )
{
	return strcmp( (const char*) a, (const char*) b );
}

static void report( const char * name, const char * decoder, long t )
{
	if( t < 0 )
	{
		out( "%-12s %8ld  %-9s   ERROR\n", name, g_size, decoder );
		g_errors++;
	}
	else
		out( "%-12s %8ld  %-9s %6ld.%02ld ms  %4ld kpixels/s\n", name, g_size, decoder, t / 100, t % 100,
			 (long) g_width * g_height * 100 / (t ? t : 1) );
}

static int ends_with( const char * s, const char * end )
{
	int ls = strlen( s ), le = strlen( end );
	return ls >= le && strcmp( s + ls - le, end ) == 0;
}

int main( void )
{
	static char names[64][16];
	int nbNames = 0, i;
	DIR * dir;
	struct dirent * entry;
	clock_t t0;

	g_log = fopen( "BENCH.TXT", "w" );
	g_out = malloc( MAX_PIXELS * 4 );
	g_alpha = malloc( MAX_PIXELS );
	g_staticTable = malloc( 65536 );

	t0 = clock();
	q16_setupStaticTable( g_staticTable );
	out( "q16_setupStaticTable: %ld ms\n\n", (long) (clock() - t0) * 1000 / CLOCKS_PER_SEC );

	out( "%-12s %8s  %-9s %9s\n", "File", "Bytes", "Decoder", "Time" );

	dir = opendir( "." );
	while( dir && (entry = readdir( dir )) != NULL && nbNames < 64 )
	{
		char * n = entry->d_name;
		int k;
		char upper[16];
		for( k = 0 ; n[k] && k < 15 ; k++ )
			upper[k] = (n[k] >= 'a' && n[k] <= 'z') ? n[k] - 32 : n[k];
		upper[k] = 0;
		if( (ends_with( upper, ".Q16" ) || ends_with( upper, ".PNG" ) || ends_with( upper, ".JPG" )) && !ends_with( upper, "_F.PNG" ) )
			strcpy( names[nbNames++], upper );
	}
	if( dir )
		closedir( dir );
	qsort( names, nbNames, sizeof(names[0]), compare_names );

	for( i = 0 ; i < nbNames ; i++ )
	{
		const char * name = names[i];
		FILE * fp = fopen( name, "rb" );
		if( !fp )
			continue;
		fseek( fp, 0, SEEK_END );
		g_size = ftell( fp );
		fseek( fp, 0, SEEK_SET );
		g_file = malloc( g_size );
		fread( g_file, 1, g_size, fp );
		fclose( fp );

		if( ends_with( name, ".Q16" ) )
		{
			unsigned long sumAsm, sumC;
			verify_entry * v = verify_get( name );

			if( q16_header() != 0 )
			{
				out( "%-12s not a valid Q16 file\n", name );
				g_errors++;
			}
			else
			{
				report( name, "asm", time_decoder( dec_q16_asm ) );
				sumAsm = checksum_q16();
				report( name, "C", time_decoder( dec_q16_c ) );
				sumC = checksum_q16();
				if( sumAsm != sumC )
				{
					out( "  ERROR: asm and C decoders differ\n" );
					g_errors++;
				}
				v->q16sum = sumAsm;
				v->hasQ16 = 1;
			}
		}
		else if( ends_with( name, ".PNG" ) )
		{
			unsigned long sumLib, sumStb;
			verify_entry * v = verify_get( name );

			report( name, "libpng", time_decoder( dec_libpng ) );
			sumLib = checksum( g_out, (long) g_width * g_height * g_channels );
			v->pngsum = checksum565();
			v->hasPng = 1;
			report( name, "stb", time_decoder( dec_stb ) );
			sumStb = checksum( g_out, (long) g_width * g_height * g_channels );
			if( sumLib != sumStb )
			{
				out( "  ERROR: libpng and stb_image differ\n" );
				g_errors++;
			}
		}
		else
		{
			report( name, "turbo", time_decoder( dec_turbo ) );
			report( name, "turbo565", time_decoder( dec_turbo565 ) );
			report( name, "stb", time_decoder( dec_stb ) );
		}

		free( g_file );
	}

	out( "\n" );
	for( i = 0 ; i < g_nbVerify ; i++ )
		if( g_verify[i].hasQ16 && g_verify[i].hasPng )
		{
			int same = g_verify[i].q16sum == g_verify[i].pngsum;
			out( "%s.Q16 and %s.PNG decode to %s pixels\n", g_verify[i].base, g_verify[i].base, same ? "identical" : "DIFFERENT" );
			if( !same )
				g_errors++;
		}

	out( "\n%s (%d errors)\n", g_errors ? "DONE WITH ERRORS" : "DONE", g_errors );

	if( g_log )
		fclose( g_log );

	if( !nf_shutdown() )
	{
		printf( "Results written to BENCH.TXT. Press any key.\n" );
		getchar();
	}
	return 0;
}
