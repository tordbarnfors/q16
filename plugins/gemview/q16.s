;=========================================================================
;
;	q16.s - Q16 load module for GEM-View 3 (Q16.GVL).
;
;	Loads Q16 pictures as True Color images. Pictures with alpha are
;	blended against white. Uses ../../m68k/q16dec.s, so it needs a
;	68020 or better (Falcon, TT).
;
;	GEM-View calls the module with the Pure C calling convention: the
;	LOAD_Structure in a0 and verbose in d0, the result is returned in a0.
;	The callbacks in LOAD_Structure take their first two pointer arguments
;	in a0/a1 and their first three integer arguments in d0-d2 (int is 16
;	bits) and may destroy d0-d2/a0-a1. d3-d7/a2-a6 must be preserved.
;
;	Assemble with: vasmm68k_mot -devpac -Ftos -o Q16.GVL q16.s
;
;	The module keeps its state in BSS, so it isn't reentrant, which
;	GEM-View doesn't need.
;
;=========================================================================

	opt		p=68030

	section	text

;____ Module header ______________________________________________________

	jmp		gvw_failed							; $00 Started as a program
	jmp		q16_load							; $06 Load function
	dc.l	'GVWL'								; $0C Load module
	dc.w	$0100								; $10 Interface version
	dc.w	$0007								; $12 Supports mono, color and True Color screens
	dc.w	$0006								; $14 Auto (identify) and file selector
	dc.w	0,0,0								; $16 Reserved
	dc.l	'.Q16'								; $1C Extension
	dc.b	"Q16 RGB565      "					; $20 Name, 16 characters
	dc.b	"V 1.00 2026             "			; $30 Information, 4 x 24 characters
	dc.b	"Q16: fast lossless      "
	dc.b	"RGB565 + 8-bit alpha    "
	dc.b	"Needs 68020 or better   "

gvw_failed:										; $90
	clr.w	-(sp)								; Pterm0
	trap	#1


;____ LOAD_Structure and Image offsets (Pure C layout) ____________________

LS_FILENAME			equ		6
LS_IDENTIFY			equ		12
LS_OPEN				equ		16
LS_READ				equ		20
LS_CLOSE			equ		48
LS_MALLOC			equ		64
LS_FREE				equ		68
LS_NEWTC			equ		80

IMG_TITLE			equ		0
IMG_DATA			equ		34

;____ q16_load() _________________________________________________________
;
;	Image *q16_load( LOAD_Structure *ls /* a0 */, int verbose /* d0 */ );
;
;	Returns the image, NULL if the file isn't a Q16 picture, -1 if it is
;	one but couldn't be loaded, or 1 when only identifying.

q16_load:
	movem.l	d3-d7/a2-a6,-(sp)
	move.l	a0,a5								; a5 = LOAD_Structure
	clr.l	file
	clr.l	pixels
	clr.l	alpha
	clr.l	table
	clr.l	title

	move.l	LS_FILENAME(a5),a0					; Open file.
	moveq	#0,d0
	move.l	LS_OPEN(a5),a2
	jsr		(a2)
	move.l	a0,zfile
	beq		.notmine

	move.l	zfile,a0							; Read header.
	lea		header,a1
	moveq	#20,d0
	move.l	LS_READ(a5),a2
	jsr		(a2)
	cmp.l	#20,d0
	bne		.closenotmine

	pea		version								; Check and convert header.
	pea		flags
	pea		alphabytes
	pea		pixelbytes
	pea		height
	pea		width
	pea		header
	bsr		q16_readHeader
	lea		28(sp),sp
	tst.l	d0
	bne		.closenotmine
	tst.w	width
	beq		.closenotmine
	tst.w	height
	beq		.closenotmine

	tst.w	LS_IDENTIFY(a5)						; Only identify?
	beq.s	.load
	bsr		ql_close
	move.l	#1,a0
	bra		.return

.load:
	moveq	#0,d6
	move.w	width,d6
	moveq	#0,d0
	move.w	height,d0
	mulu.l	d0,d6								; d6 = number of pixels

	move.l	pixelbytes,d0						; Read compressed data.
	add.l	alphabytes,d0
	bcs		.fail
	move.l	d0,d3
	bsr		ql_malloc
	move.l	a0,file
	beq		.fail
	move.l	zfile,a0
	move.l	file,a1
	move.l	d3,d0
	move.l	LS_READ(a5),a2
	jsr		(a2)
	cmp.l	d3,d0
	bne		.fail

	move.l	#65536,d0							; Allocate buffers.
	bsr		ql_malloc
	move.l	a0,table
	beq		.fail
	move.l	d6,d0
	add.l	d0,d0
	bsr		ql_malloc
	move.l	a0,pixels
	beq		.fail
	tst.l	alphabytes
	beq.s	.decode
	move.l	d6,d0
	bsr		ql_malloc
	move.l	a0,alpha
	beq		.fail

.decode:
	move.l	table,-(sp)
	bsr		q16_setupStaticTable
	addq.l	#4,sp

	move.l	table,-(sp)							; Pixels
	move.l	d6,-(sp)
	move.l	file,a0
	move.l	a0,d0
	add.l	pixelbytes,d0
	move.l	d0,-(sp)
	move.l	a0,-(sp)
	move.l	pixels,-(sp)
	bsr		q_decPix
	lea		20(sp),sp
	tst.l	d0
	bne		.fail

	tst.l	alphabytes							; Alpha
	beq.s	.image
	move.l	d6,-(sp)
	move.l	file,a0
	add.l	pixelbytes,a0
	move.l	a0,d0
	add.l	alphabytes,d0
	move.l	d0,-(sp)
	move.l	a0,-(sp)
	move.l	alpha,-(sp)
	bsr		q_decAlp
	lea		16(sp),sp
	tst.l	d0
	bne		.fail

.image:
	move.l	LS_FILENAME(a5),a0					; Copy file name for the title.
	move.l	a0,a1
.strlen:
	tst.b	(a1)+
	bne.s	.strlen
	move.l	a1,d0
	sub.l	a0,d0
	bsr		ql_malloc
	move.l	a0,title
	beq		.fail
	move.l	LS_FILENAME(a5),a1
.strcpy:
	move.b	(a1)+,(a0)+
	bne.s	.strcpy

	sub.l	a0,a0								; Create image, title set below.
	move.w	width,d0
	move.w	height,d1
	move.l	LS_NEWTC(a5),a2
	jsr		(a2)
	move.l	a0,d7								; d7 = image
	beq		.fail
	move.l	title,IMG_TITLE(a0)
	clr.l	title

	; Convert RGB565 (+ alpha) to RGB triples.

	move.l	IMG_DATA(a0),a1
	move.l	pixels,a0
	move.l	alpha,a2
	move.l	d6,d5
.convert:
	move.w	(a0)+,d0
	move.w	d0,d1								; Red: 5 bits to 8
	lsr.w	#8,d1
	and.w	#$f8,d1
	move.w	d1,d2
	lsr.w	#5,d2
	or.w	d2,d1
	move.w	d0,d2								; Green: 6 bits to 8
	lsr.w	#3,d2
	and.w	#$fc,d2
	move.w	d2,d3
	lsr.w	#6,d3
	or.w	d3,d2
	move.w	d0,d3								; Blue: 5 bits to 8
	lsl.w	#3,d3
	and.w	#$f8,d3
	move.w	d3,d4
	lsr.w	#5,d4
	or.w	d4,d3
	cmp.w	#0,a2
	beq.s	.store
	moveq	#0,d4								; Blend against white:
	move.b	(a2)+,d4							; c = (c * a + 255 * (255 - a) + 127) / 255
	cmp.b	#255,d4
	beq.s	.store
	move.w	#255,d0
	sub.w	d4,d0
	mulu.w	#255,d0
	add.w	#127,d0
	mulu.w	d4,d1
	add.w	d0,d1
	divu.w	#255,d1
	mulu.w	d4,d2
	add.w	d0,d2
	divu.w	#255,d2
	mulu.w	d4,d3
	add.w	d0,d3
	divu.w	#255,d3
.store:
	move.b	d1,(a1)+
	move.b	d2,(a1)+
	move.b	d3,(a1)+
	subq.l	#1,d5
	bne.s	.convert

	bsr.s	ql_cleanup
	move.l	d7,a0
	bra.s	.return

.fail:
	bsr.s	ql_cleanup
	move.l	#-1,a0								; Q16 picture, but couldn't be loaded.
	bra.s	.return

.closenotmine:
	bsr.s	ql_close
.notmine:
	sub.l	a0,a0
.return:
	movem.l	(sp)+,d3-d7/a2-a6
	rts

;	Frees all temporary buffers and closes the file.

ql_cleanup:
	lea		file,a3
	moveq	#4,d3								; file, pixels, alpha, table, title
.loop:
	move.l	(a3),d0
	beq.s	.next
	clr.l	(a3)
	move.l	d0,a0
	move.l	LS_FREE(a5),a2
	jsr		(a2)
.next:
	addq.l	#4,a3
	dbra	d3,.loop
ql_close:
	move.l	zfile,d0
	beq.s	.done
	clr.l	zfile
	move.l	d0,a0
	move.l	LS_CLOSE(a5),a2
	jsr		(a2)
.done:
	rts

;	a0 = ls->memory.malloc( d0 ), preserving a1.

ql_malloc:
	move.l	a1,-(sp)
	move.l	LS_MALLOC(a5),a2
	jsr		(a2)
	move.l	(sp)+,a1
	cmp.w	#0,a0
	rts

	include	"../../m68k/q16dec.s"

;____ Variables __________________________________________________________

	section	bss

zfile:				ds.l	1
file:				ds.l	1					; file, pixels, alpha, table and title
pixels:				ds.l	1					; must stay in this order, see ql_cleanup.
alpha:				ds.l	1
table:				ds.l	1
title:				ds.l	1
pixelbytes:			ds.l	1
alphabytes:			ds.l	1
width:				ds.w	1
height:				ds.w	1
flags:				ds.b	1
version:			ds.b	1
header:				ds.b	20
