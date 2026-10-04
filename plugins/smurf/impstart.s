; Startup code for Smurf import modules (.SIM).
;
; Smurf loads the module with Pexec mode 3 and expects, from the start of
; the TEXT segment: an exit for when it's run directly, a branch to the
; main function at +4, the magic "SIMD" at +8, a pointer to module_info
; at +12 and the interface version at +16.
;
; Assembled with PUREC_SMURF defined for Smurf built with Pure C, which
; passes the GARGAMEL pointer in A0 and has its service functions take
; their arguments in registers.

	SECTION	TEXT

	XREF	imp_module_main
	XREF	module_info
	XDEF	_errno

	clr.w	-(sp)			; Pterm0 if started as a program.
	trap	#1
	IFD	PUREC_SMURF
	bra.w	pc_entry
	ELSE
	bra.w	imp_module_main
	ENDC
	dc.l	'SIMD'
	dc.l	module_info
	dc.l	$0101

	IFD	PUREC_SMURF

;	short imp_module_main( GARGAMEL *smurf_struct /* A0 */ ), result in D0.

pc_entry:
	move.l	a0,-(sp)
	jsr	imp_module_main
	addq.l	#4,sp
	rts

;	void *pc_call_SMalloc( void *(*fn)(long), long amount );
;	void pc_call_SMfree( void (*fn)(void *), void *ptr );
;
;	Call Pure C functions: amount in D0, ptr in A0, result in A0. Pure C
;	functions may destroy D2/A2, which gcc expects to be preserved.

	XDEF	pc_call_SMalloc,_pc_call_SMalloc
	XDEF	pc_call_SMfree,_pc_call_SMfree

pc_call_SMalloc:
_pc_call_SMalloc:
	movem.l	d2/a2,-(sp)
	move.l	12(sp),a1
	move.l	16(sp),d0
	jsr	(a1)
	move.l	a0,d0
	movem.l	(sp)+,d2/a2
	rts

pc_call_SMfree:
_pc_call_SMfree:
	movem.l	d2/a2,-(sp)
	move.l	12(sp),a1
	move.l	16(sp),a0
	jsr	(a1)
	movem.l	(sp)+,d2/a2
	rts

	ENDC

	SECTION	DATA

_errno:	dc.l	0
