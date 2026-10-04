/*
 * smurfabi.h - calls to Smurf's service functions.
 *
 * When built with PUREC_SMURF defined, the modules are for Smurf built with
 * Pure C (the original Smurf 1.06 binaries): the structures have the same
 * layout, but Pure C passes arguments in registers. The service functions
 * are then called through thunks in pcstart.s and the module identifies
 * itself as built with Pure C.
 */

#ifdef PUREC_SMURF

#undef COMPILER_ID
#define COMPILER_ID 0

void * pc_call_SMalloc( void *(*fn)(long), long amount );
void pc_call_SMfree( void (*fn)(void *), void * ptr );

#define SMALLOC( g, n )		pc_call_SMalloc( (g)->services->SMalloc, (n) )
#define SMFREE( g, p )		pc_call_SMfree( (g)->services->SMfree, (p) )

#else

#define SMALLOC( g, n )		(g)->services->SMalloc( n )
#define SMFREE( g, p )		(g)->services->SMfree( p )

#endif
