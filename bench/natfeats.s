;	int nf_shutdown( void );
;
;	Quits Hatari through Native Features. Returns 0 if Native Features are
;	not available, e.g. on real hardware.

	SECTION	TEXT

	XDEF	nf_shutdown,_nf_shutdown

nf_shutdown:
_nf_shutdown:
	movem.l	d2/a2,-(sp)
	pea	nf_do_shutdown(pc)
	move.w	#38,-(sp)		; Supexec
	trap	#14
	addq.l	#6,sp
	movem.l	(sp)+,d2/a2
	rts

nf_do_shutdown:
	move.l	$10.w,a1		; Catch illegal instruction on real hardware.
	lea	nf_illegal(pc),a0
	move.l	a0,$10.w
	moveq	#0,d0
	pea	nf_name(pc)
	bsr.s	nf_id
	addq.l	#4,sp
	move.l	a1,$10.w
	tst.l	d0
	beq.s	nf_none
	move.l	d0,-(sp)
	bsr.s	nf_call
	addq.l	#4,sp
	moveq	#1,d0
nf_none:
	rts

nf_illegal:
	moveq	#0,d0
	addq.l	#2,2(sp)		; Skip the 2 byte Native Features opcode.
	rte

nf_id:
	dc.w	$7300
	rts

nf_call:
	dc.w	$7301
	rts

nf_name:
	dc.b	"NF_SHUTDOWN",0
	EVEN

	END
