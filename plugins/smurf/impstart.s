; Startup code for Smurf import modules (.SIM).
;
; Smurf loads the module with Pexec mode 3 and expects, from the start of
; the TEXT segment: an exit for when it's run directly, a branch to the
; main function at +4, the magic "SIMD" at +8, a pointer to module_info
; at +12 and the interface version at +16.
;
; Assembled with PUREC_SMURF defined for Smurf built with Pure C, which
; passes the GARGAMEL pointer in a0 and has its service functions take
; their arguments in registers.

	section	text

	xref	imp_module_main
	xref	module_info
	xdef	_errno

	clr.w	-(sp)								; Pterm0 if started as a program.
	trap	#1
	ifd		PUREC_SMURF
	bra.w	pc_entry
	else
	bra.w	imp_module_main
	endc
	dc.l	'SIMD'
	dc.l	module_info
	dc.l	$0101

	ifd		PUREC_SMURF

;	short imp_module_main( GARGAMEL *smurf_struct /* a0 */ ), result in d0.

pc_entry:
	move.l	a0,-(sp)
	jsr		imp_module_main
	addq.l	#4,sp
	rts

;	void *pc_call_SMalloc( void *(*fn)(long), long amount );
;	void pc_call_SMfree( void (*fn)(void *), void *ptr );
;
;	Call Pure C functions: amount in d0, ptr in a0, result in a0. Pure C
;	functions may destroy d2/a2, which gcc expects to be preserved.

	xdef	pc_call_SMalloc,_pc_call_SMalloc
	xdef	pc_call_SMfree,_pc_call_SMfree

pc_call_SMalloc:
_pc_call_SMalloc:
	movem.l	d2/a2,-(sp)
	move.l	12(sp),a1
	move.l	16(sp),d0
	jsr		(a1)
	move.l	a0,d0
	movem.l	(sp)+,d2/a2
	rts

pc_call_SMfree:
_pc_call_SMfree:
	movem.l	d2/a2,-(sp)
	move.l	12(sp),a1
	move.l	16(sp),a0
	jsr		(a1)
	movem.l	(sp)+,d2/a2
	rts

	endc

	section	data

_errno:				dc.l	0
