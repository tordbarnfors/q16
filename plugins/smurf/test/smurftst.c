/*
 * smurftst.c - tests Smurf import and export modules without Smurf.
 *
 * Loads the modules the same way as Smurf (Pexec mode 3, header found at
 * the start of the TEXT segment) and calls them with a minimal GARGAMEL.
 * Reads SMURFTST.CFG with five lines: import module, picture, file to write
 * the imported 16 bit pixels to, export module, file to export them to.
 * Writes a log to SMURFTST.TXT.
 *
 * Built with PUREC_CALLER defined, it calls the modules like Smurf built
 * with Pure C (arguments in registers, see pccall.s).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <osbind.h>
#include <mint/basepage.h>
#include "import.h"
#include "smurfine.h"

/* Start of a module's TEXT segment, as MODULE_START in Smurf's plugin.h. */

typedef struct
{
	unsigned short trap[2];					/* Pterm0 */
	unsigned short entry[2];				/* bra.w to the main function */
	unsigned long magic;
	const MOD_INFO * info;
	const MOD_ABILITY * ability;			/* Export modules only */
	unsigned long interface_version;
} MODULE_START;

static FILE * logf;

void * test_SMalloc( long amount );
void test_SMfree( void * ptr );

#ifdef PUREC_CALLER
short pc_call_import( const void * entry, GARGAMEL * g );
EXPORT_PIC * pc_call_export( const void * entry, GARGAMEL * g );
void * pc_SMalloc( long amount );
void pc_SMfree( void * ptr );
#define CALL_IMPORT( m, g )		pc_call_import( (m)->entry, (g) )
#define CALL_EXPORT( m, g )		pc_call_export( (m)->entry, (g) )
#define EXPECTED_COMPILER		0
#else
#define CALL_IMPORT( m, g )		((short (*)(GARGAMEL *)) (m)->entry)( (g) )
#define CALL_EXPORT( m, g )		((EXPORT_PIC * (*)(GARGAMEL *)) (m)->entry)( (g) )
#define EXPECTED_COMPILER		1
#endif

void * test_SMalloc( long amount )
{
	long p = Malloc( amount );
	return p > 0 ? (void *) p : NULL;
}

void test_SMfree( void * ptr )
{
	Mfree( ptr );
}

static const MODULE_START * load_module( const char * path )
{
	long r = Pexec( 3, path, "", NULL );
	BASEPAGE * bp;
	unsigned long * text;

	if( r <= 0 )
	{
		fprintf( logf, "Pexec(3, %s) failed: %ld\n", path, r );
		return NULL;
	}
	bp = (BASEPAGE *) r;

	/* As Smurf's start_module(): shrink the module's memory to what it
	   needs, since Pexec mode 3 gives it all free memory, and start it. */
	{
		long len = sizeof(BASEPAGE) + bp->p_tlen + bp->p_dlen + bp->p_blen + 1024L;
		bp->p_hitpa = (char *) bp + len;
		Mshrink( bp, len );
		Pexec( 4, NULL, (char *) bp, NULL );
	}

	text = (unsigned long *) bp->p_tbase;
	if( (text[0] == 0x283a001aL && text[1] == 0x4efb48faL) || (text[0] == 0x203a001aL && text[1] == 0x4efb08faL) )
		text += 228 / sizeof(*text);
	return (const MODULE_START *) text;
}

static void chomp( char * s ) { s[strcspn( s, "\r\n" )] = 0; }

int main( void )
{
	char impname[128], picname[128], rawname[128], expname[128], outname[128];
	FILE * cfg, * f;
	const MODULE_START * imp, * exp;
	SERVICE_FUNCTIONS services;
	SMURF_PIC pic;
	GARGAMEL g;
	long size;
	short ret;

	logf = fopen( "SMURFTST.TXT", "w" );
	if( logf )
		setvbuf( logf, NULL, _IONBF, 0 );
	cfg = fopen( "SMURFTST.CFG", "r" );
	if( !logf || !cfg || !fgets( impname, 128, cfg ) || !fgets( picname, 128, cfg ) || !fgets( rawname, 128, cfg )
		|| !fgets( expname, 128, cfg ) || !fgets( outname, 128, cfg ) )
		return 1;
	chomp( impname ); chomp( picname ); chomp( rawname ); chomp( expname ); chomp( outname );

	memset( &services, 0, sizeof(services) );
#ifdef PUREC_CALLER
	services.SMalloc = pc_SMalloc;
	services.SMfree = pc_SMfree;
#else
	services.SMalloc = test_SMalloc;
	services.SMfree = test_SMfree;
#endif

	/* Import */

	imp = load_module( impname );
	if( !imp || imp->magic != MOD_MAGIC_IMPORT )
	{
		fprintf( logf, "%s: no import module\n", impname );
		goto done;
	}
	fprintf( logf, "import module: %s %x by %s, extension %s, compiler %d\n", imp->info->mod_name,
			 imp->info->version, imp->info->autor, imp->info->ext[0], imp->info->compiler_id );

	f = fopen( picname, "rb" );
	fseek( f, 0, SEEK_END );
	size = ftell( f );
	fseek( f, 0, SEEK_SET );
	memset( &pic, 0, sizeof(pic) );
	pic.pic_data = test_SMalloc( size );
	fread( pic.pic_data, 1, size, f );
	fclose( f );
	pic.file_len = size;
	strcpy( pic.filename, picname );

	memset( &g, 0, sizeof(g) );
	g.smurf_pic = &pic;
	g.services = &services;
	g.module_mode = MEXEC;
	if( imp->info->compiler_id != EXPECTED_COMPILER )
		fprintf( logf, "WARNING: compiler id %d, expected %d\n", imp->info->compiler_id, EXPECTED_COMPILER );
	ret = CALL_IMPORT( imp, &g );
	fprintf( logf, "import returned %d: %dx%d depth %d col_format %d format '%s'\n", ret, pic.pic_width,
			 pic.pic_height, pic.depth, pic.col_format, pic.format_name );
	if( ret != M_PICDONE )
		goto done;

	f = fopen( rawname, "wb" );
	fwrite( pic.pic_data, 2, (long) pic.pic_width * pic.pic_height, f );
	fclose( f );

	/* Export, with the message sequence Smurf uses. */

	exp = load_module( expname );
	if( !exp || exp->magic != MOD_MAGIC_EXPORT )
	{
		fprintf( logf, "%s: no export module\n", expname );
		goto done;
	}
	fprintf( logf, "export module: %s %x, depths %d, compiler %d\n", exp->info->mod_name, exp->info->version,
			 exp->ability->depth1, exp->info->compiler_id );
	{
		EXPORT_PIC * result;

		g.module_mode = MEXTEND;
		CALL_EXPORT( exp, &g );
		fprintf( logf, "MEXTEND -> mode %d, extension %d\n", g.module_mode, g.event_par[0] );
		g.module_mode = MCOLSYS;
		CALL_EXPORT( exp, &g );
		fprintf( logf, "MCOLSYS -> mode %d, color system %d\n", g.module_mode, g.event_par[0] );
		g.module_mode = MSTART;
		CALL_EXPORT( exp, &g );
		fprintf( logf, "MSTART -> mode %d\n", g.module_mode );
		g.module_mode = MEXEC;
		result = CALL_EXPORT( exp, &g );			/* Frees pic.pic_data, as Smurf expects. */
		fprintf( logf, "MEXEC -> mode %d, result %p, length %ld\n", g.module_mode, (void *) result,
				 result ? (long) result->f_len : 0L );
		if( result )
		{
			f = fopen( outname, "wb" );
			fwrite( result->pic_data, 1, result->f_len, f );
			fclose( f );
		}
		g.module_mode = MTERM;
		CALL_EXPORT( exp, &g );
	}

done:
	fprintf( logf, "done\n" );
	fclose( logf );
	return 0;
}
