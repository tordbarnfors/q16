/*
 * zvtest.c - tests a zView codec without zView.
 *
 * Reads ZVTEST.CFG with four lines: codec (.LDG), picture to decode, file to
 * write the decoded 24-bit RGB lines to, and file to encode them into again.
 * Writes a log to ZVTEST.TXT. Uses background color 0xFFFFFF like zView.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gem.h>
#include <ldg.h>
#include "imginfo.h"

typedef boolean __CDECL (*init_f)( const char *, IMGINFO );
typedef boolean __CDECL (*line_f)( IMGINFO, uint8_t * );
typedef void __CDECL (*quit_f)( IMGINFO );
typedef void __CDECL (*plugin_init_f)( void );

static void chomp( char * s ) { s[strcspn( s, "\r\n" )] = 0; }

int main( void )
{
	char codec[256], picture[256], rgbname[256], encname[256];
	FILE * cfg, * log, * rgb;
	LDG * ldg;
	img_info info, out;
	uint8_t * lines;
	int y;

	appl_init();
	log = fopen( "ZVTEST.TXT", "w" );
	cfg = fopen( "ZVTEST.CFG", "r" );
	if( !log || !cfg || !fgets( codec, 256, cfg ) || !fgets( picture, 256, cfg )
		|| !fgets( rgbname, 256, cfg ) || !fgets( encname, 256, cfg ) )
	{
		if( log ) fprintf( log, "config error\n" );
		goto done;
	}
	chomp( codec ); chomp( picture ); chomp( rgbname ); chomp( encname );

	ldg = ldg_open( codec, ldg_global );
	if( !ldg )
	{
		fprintf( log, "ldg_open failed: %d\n", ldg_error() );
		goto done;
	}
	fprintf( log, "extensions: %s\n", ldg->infos );

	{
		plugin_init_f pinit = (plugin_init_f) ldg_find( "plugin_init", ldg );
		init_f rinit = (init_f) ldg_find( "reader_init", ldg );
		line_f rread = (line_f) ldg_find( "reader_read", ldg );
		quit_f rquit = (quit_f) ldg_find( "reader_quit", ldg );
		init_f einit = (init_f) ldg_find( "encoder_init", ldg );
		line_f ewrite = (line_f) ldg_find( "encoder_write", ldg );
		quit_f equit = (quit_f) ldg_find( "encoder_quit", ldg );

		if( !pinit || !rinit || !rread || !rquit || !einit || !ewrite || !equit )
		{
			fprintf( log, "missing functions\n" );
			goto close;
		}
		pinit();

		memset( &info, 0, sizeof(info) );
		info.background_color = 0xFFFFFF;
		if( !rinit( picture, &info ) )
		{
			fprintf( log, "reader_init failed\n" );
			goto close;
		}
		fprintf( log, "width %u height %u components %u planes %u colors %lu info '%s' compression '%s'\n",
				 info.width, info.height, info.components, info.planes, (unsigned long) info.colors,
				 info.info, info.compression );

		lines = malloc( (size_t) info.width * 3 * info.height );
		for( y = 0 ; y < info.height ; y++ )
			if( !rread( &info, lines + (size_t) y * info.width * 3 ) )
			{
				fprintf( log, "reader_read failed on line %d\n", y );
				break;
			}
		rquit( &info );
		fprintf( log, "decoded %d lines\n", y );

		rgb = fopen( rgbname, "wb" );
		fwrite( lines, (size_t) info.width * 3, info.height, rgb );
		fclose( rgb );

		memset( &out, 0, sizeof(out) );
		out.width = info.width;
		out.height = info.height;
		out.components = 3;
		out.planes = 24;
		if( !einit( encname, &out ) )
			fprintf( log, "encoder_init failed\n" );
		else
		{
			for( y = 0 ; y < info.height ; y++ )
				if( !ewrite( &out, lines + (size_t) y * info.width * 3 ) )
				{
					fprintf( log, "encoder_write failed on line %d\n", y );
					break;
				}
			equit( &out );
			fprintf( log, "encoded %d lines\n", y );
		}
		free( lines );
	}

close:
	ldg_close( ldg, ldg_global );
done:
	if( log )
	{
		fprintf( log, "done\n" );
		fclose( log );
	}
	appl_exit();
	return 0;
}
