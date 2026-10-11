; LAUNCH.TOS - reads LAUNCH.CMD ("PROGRAM ARGUMENTS"), runs PROGRAM with
; ARGUMENTS as command line, then quits Hatari through Native Features.

	opt		p=68030
	section	text

start:
	move.l	4(sp),a5
	lea		stack_top,sp
	move.l	#$100+$4000,-(sp)					; Keep basepage + small text/data/bss.
	move.l	a5,-(sp)
	clr.w	-(sp)
	move.w	#$4a,-(sp)							; Mshrink
	trap	#1
	lea		12(sp),sp

	clr.w	-(sp)
	pea		cmdname(pc)
	move.w	#$3d,-(sp)							; Fopen
	trap	#1
	addq.l	#8,sp
	tst.w	d0
	bmi		quit
	move.w	d0,d7
	pea		cmdbuf
	move.l	#250,-(sp)
	move.w	d7,-(sp)
	move.w	#$3f,-(sp)							; Fread
	trap	#1
	lea		12(sp),sp
	move.l	d0,d6
	move.w	d7,-(sp)
	move.w	#$3e,-(sp)							; Fclose
	trap	#1
	addq.l	#4,sp

	lea		cmdbuf,a0							; Split at first space, strip line end.
	lea		(a0,d6.l),a1
	clr.b	(a1)
	lea		cmdline+1,a2
	moveq	#0,d1
split:
	move.b	(a0)+,d0
	beq.s	run
	cmp.b	#32,d0
	bne.s	split
	clr.b	-1(a0)
copyargs:
	move.b	(a0)+,d0
	beq.s	run
	cmp.b	#13,d0
	beq.s	run
	cmp.b	#10,d0
	beq.s	run
	move.b	d0,(a2)+
	addq.w	#1,d1
	bra.s	copyargs
run:
	clr.b	(a2)
	move.b	d1,cmdline

	clr.l	-(sp)								; env
	pea		cmdline
	pea		cmdbuf
	clr.w	-(sp)								; Load and go
	move.w	#$4b,-(sp)							; Pexec
	trap	#1
	lea		16(sp),sp

quit:
	pea		shutdown(pc)
	move.w	#38,-(sp)							; Supexec
	trap	#14
	addq.l	#6,sp
	clr.w	-(sp)
	trap	#1

shutdown:
	pea		nfname(pc)
	bsr.s	nf_id
	addq.l	#4,sp
	tst.l	d0
	beq.s	.none
	move.l	d0,-(sp)
	bsr.s	nf_call
	addq.l	#4,sp
.none:				rts
nf_id:				dc.w	$7300
	rts
nf_call:
	dc.w	$7301
	rts

cmdname:			dc.b	"LAUNCH.CMD",0
nfname:				dc.b	"NF_SHUTDOWN",0
	even

	section	bss
cmdbuf:				ds.b	256
cmdline:			ds.b	130
	even
	ds.b	4096
stack_top:
