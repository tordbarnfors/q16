; pccall.s - lets smurftst.c call modules the way Pure C Smurf does.
;
; The service functions destroy d1/d2/a1, which Pure C allows, to check
; that the modules' thunks protect the registers gcc expects preserved.

	section	text

	xdef	pc_call_import,pc_call_export,pc_SMalloc,pc_SMfree
	xdef	_pc_call_import,_pc_call_export,_pc_SMalloc,_pc_SMfree
	xref	_test_SMalloc,_test_SMfree

;	short pc_call_import( void *entry, GARGAMEL *g );

pc_call_import:
_pc_call_import:
	movem.l	d2-d7/a2-a6,-(sp)
	move.l	48(sp),a1
	move.l	52(sp),a0
	jsr		(a1)
	ext.l	d0
	movem.l	(sp)+,d2-d7/a2-a6
	rts

;	EXPORT_PIC *pc_call_export( void *entry, GARGAMEL *g );

pc_call_export:
_pc_call_export:
	movem.l	d2-d7/a2-a6,-(sp)
	move.l	48(sp),a1
	move.l	52(sp),a0
	jsr		(a1)
	move.l	a0,d0
	movem.l	(sp)+,d2-d7/a2-a6
	rts

;	Service functions with Pure C calling convention.
;	void *SMalloc( long amount /* d0 */ ), result in a0.
;	void SMfree( void *ptr /* a0 */ ).

pc_SMalloc:
_pc_SMalloc:
	move.l	d0,-(sp)
	jsr		_test_SMalloc
	addq.l	#4,sp
	move.l	d0,a0
	moveq	#-1,d1
	moveq	#-1,d2
	move.l	#$badbad,a1
	rts

pc_SMfree:
_pc_SMfree:
	move.l	a0,-(sp)
	jsr		_test_SMfree
	addq.l	#4,sp
	moveq	#-1,d1
	moveq	#-1,d2
	move.l	#$badbad,a1
	rts
