;=========================================================================
;
;	q16save.s - Q16 save module for GEM-View 3 (Q16.GVS).
;
;	Saves pictures as Q16 (RGB565, no alpha, since GEM-View pictures have
;	none): True Color, palette pictures (chunky or bitplanes, the palette
;	is applied) and monochrome pictures. Uses
;	../../m68k/q16enc.s and q16dec.s, so it needs a 68020 or better.
;
;	GEM-View calls the module with the Pure C calling convention: the
;	SAVE_Structure in a0 and verbose in d0, the result is returned in d0.
;	The callbacks in SAVE_Structure take their first two pointer arguments
;	in a0/a1 and their first three integer arguments in d0-d2 (int is 16
;	bits) and may destroy d0-d2/a0-a1. d3-d7/a2-a6 must be preserved.
;
;	Assemble with: vasmm68k_mot -devpac -Ftos -o Q16.GVS q16save.s
;
;	The module keeps its state in BSS, so it isn't reentrant, which
;	GEM-View doesn't need.
;
;=========================================================================

	opt		p=68030

	section	text

;____ Module header ______________________________________________________

	jmp		gvw_failed							; $00 Started as a program
	jmp		q16_save							; $06 Save function
	dc.l	'GVWS'								; $0C Save module
	dc.w	$0100								; $10 Interface version
	dc.w	$0007								; $12 Mono, color and True Color
	dc.w	$0000								; $14 Flags
	dc.w	0,0,0								; $16 Reserved
	dc.l	'.Q16'								; $1C Extension
	dc.b	"Q16 RGB565      "					; $20 Name, 16 characters
	dc.b	"V 1.00 2026             "			; $30 Information, 4 x 24 characters
	dc.b	"Q16: fast lossless      "
	dc.b	"RGB565, saves no alpha  "
	dc.b	"Needs 68020 or better   "

gvw_failed:										; $90
	clr.w	-(sp)								; Pterm0
	trap	#1


;____ SAVE_Structure and Image offsets (Pure C layout) ____________________

SS_IMAGE			equ		6
SS_FILENAME			equ		12
SS_OPEN				equ		16
SS_WRITE			equ		20
SS_CLOSE			equ		24
SS_DELETE			equ		28
SS_PRINTOUT			equ		32
SS_MALLOC			equ		44
SS_FREE				equ		48
SS_ALERT			equ		76

IMG_TYPE			equ		4
IMG_WIDTH			equ		6
IMG_HEIGHT			equ		8
IMG_DEPTH			equ		10
IMG_UNALIGNWIDTH	equ		12
IMG_RGBSIZE			equ		14
IMG_RGBUSED			equ		16
IMG_RED				equ		22
IMG_GREEN			equ		26
IMG_BLUE			equ		30
IMG_DATA			equ		34

IBITMAP				equ		$0011				; Monochrome, 1 = black
IATARI_RGB			equ		$0012				; Palette, bitplanes
ITRUEC				equ		$0013				; RGB triples
IRGB				equ		$0014				; Palette, one byte per pixel

;____ q16_save() _________________________________________________________
;
;	int q16_save( SAVE_Structure *ss /* a0 */, int verbose /* d0 */ );
;
;	Returns 1 if the picture was saved, 0 if not.

q16_save:
	movem.l	d3-d7/a2-a6,-(sp)
	move.l	a0,a5								; a5 = SAVE_Structure
	clr.l	pixels
	clr.l	table
	clr.l	out

	move.l	SS_IMAGE(a5),a4						; a4 = Image
	move.w	IMG_TYPE(a4),d0
	cmp.w	#IBITMAP,d0
	blo		.badtype
	cmp.w	#IRGB,d0
	bhi		.badtype
	moveq	#0,d7
	move.w	IMG_UNALIGNWIDTH(a4),d7				; d7 = width (as shown)
	bne.s	.width
	move.w	IMG_WIDTH(a4),d7
.width:
	moveq	#0,d6
	move.w	IMG_HEIGHT(a4),d6					; d6 = height
	tst.l	d7
	beq		.badtype
	tst.l	d6
	beq		.badtype

	lea		msg_saving(pc),a0
	bsr		qs_print

	move.l	d7,d5
	mulu.l	d6,d5								; d5 = number of pixels
	move.l	d5,d0								; Allocate buffers.
	add.l	d0,d0
	bsr		qs_malloc
	move.l	a0,pixels
	beq		.nomem
	move.l	#65536,d0
	bsr		qs_malloc
	move.l	a0,table
	beq		.nomem
	move.l	d5,d0								; Header + Q16_MAX_PIXEL_BYTES
	add.l	d0,d0
	move.l	d5,d1
	lsr.l	#5,d1
	add.l	d1,d0
	add.l	#20+1,d0
	bsr		qs_malloc
	move.l	a0,out
	beq		.nomem

												; Convert to RGB565. Lines are padded to 16 pixels in all types.

	move.l	IMG_DATA(a4),a2						; a2 = line
	move.l	pixels,a1							; a1 = RGB565 pixels
	move.l	d6,d3
	subq.l	#1,d3								; d3 = lines - 1
	move.l	d7,d4
	add.l	#15,d4
	and.w	#$fff0,d4							; d4 = padded width
	cmp.w	#ITRUEC,IMG_TYPE(a4)
	beq		.truecolor
	bsr		qs_palette
	lea		lut,a6								; a6 = palette as RGB565
	cmp.w	#IRGB,IMG_TYPE(a4)
	beq.s	.chunky

												; Bitplanes, one plane after the other: bit p of a pixel's colour is
												; in plane p.

	lsr.l	#3,d4								; d4 = bytes per line and plane
	move.l	d4,d0
	mulu.l	d6,d0
	move.l	d0,planesize
	moveq	#0,d1
	move.w	IMG_DEPTH(a4),d1
	beq		.badtype
	cmp.w	#8,d1
	bhi		.badtype
	subq.w	#1,d1
	move.w	d1,depth							; depth = planes - 1
	mulu.l	d1,d0
	move.l	d0,lastplane						; Offset of the last plane
.planarline:
	moveq	#0,d2								; d2 = x
.planarpixel:
	move.l	d2,d0
	lsr.l	#3,d0
	lea		(a2,d0.l),a0
	add.l	lastplane,a0						; Byte in the last plane
	move.w	d2,d1
	not.w	d1
	and.w	#7,d1								; Bit, 7 = leftmost pixel
	moveq	#0,d0								; d0 = colour
	move.w	depth,d5
.planarbit:
	add.w	d0,d0
	btst	d1,(a0)
	beq.s	.planarzero
	addq.w	#1,d0
.planarzero:
	sub.l	planesize,a0
	dbra	d5,.planarbit
	move.w	(a6,d0.w*2),(a1)+
	addq.l	#1,d2
	cmp.l	d7,d2
	blo.s	.planarpixel
	add.l	d4,a2
	dbra	d3,.planarline
	bra.s	.converted

.chunky:										; One byte per pixel
	moveq	#0,d0
.chunkyline:
	move.l	a2,a0
	move.l	d7,d2
	subq.l	#1,d2
.chunkypixel:
	move.b	(a0)+,d0
	move.w	(a6,d0.w*2),(a1)+
	dbra	d2,.chunkypixel
	add.l	d4,a2
	dbra	d3,.chunkyline
	bra.s	.converted

.truecolor:										; Red, green, blue
	mulu.l	#3,d4								; d4 = bytes per line
.line:
	move.l	a2,a0
	move.l	d7,d2
	subq.l	#1,d2
.pixel:
	move.b	(a0)+,d0							; Red
	lsl.w	#8,d0
	and.w	#$f800,d0
	moveq	#0,d1								; Green
	move.b	(a0)+,d1
	lsl.w	#3,d1
	and.w	#$07e0,d1
	or.w	d1,d0
	moveq	#0,d1								; Blue
	move.b	(a0)+,d1
	lsr.w	#3,d1
	or.w	d1,d0
	move.w	d0,(a1)+
	dbra	d2,.pixel
	add.l	d4,a2
	dbra	d3,.line

.converted:
	move.l	d7,d5
	mulu.l	d6,d5								; d5 = number of pixels

												; Compress.

	move.l	table,-(sp)
	bsr		q16_setupStaticTable
	addq.l	#4,sp

	move.l	table,-(sp)
	move.l	pixels,a0
	move.l	d5,d0
	add.l	d0,d0
	add.l	a0,d0
	move.l	d0,-(sp)
	move.l	a0,-(sp)
	move.l	out,a0
	pea		20(a0)
	bsr		q_encPix
	lea		16(sp),sp
	sub.l	out,d0
	move.l	d0,d3								; d3 = file length

	clr.l	-(sp)								; Flags
	clr.l	-(sp)								; Alpha bytes
	move.l	d3,d0
	sub.l	#20,d0
	move.l	d0,-(sp)							; Pixel bytes
	move.l	d6,-(sp)
	move.l	d7,-(sp)
	move.l	out,-(sp)
	bsr		q16_writeHeader
	lea		24(sp),sp

												; Write the file.

	move.l	SS_FILENAME(a5),a0
	move.l	SS_OPEN(a5),a2
	jsr		(a2)
	move.w	d0,d4								; d4 = handle
	ble.s	.writeerror
	move.w	d4,d0
	move.l	d3,d1
	move.l	out,a0
	move.l	SS_WRITE(a5),a2
	jsr		(a2)
	cmp.l	d3,d0
	bne.s	.closedelete
	move.w	d4,d0
	move.l	SS_CLOSE(a5),a2
	jsr		(a2)
	tst.w	d0
	bne.s	.delete

	lea		msg_done(pc),a0
	bsr.s	qs_print
	bsr.s	qs_cleanup
	moveq	#1,d0
	bra.s	.return

.closedelete:
	move.w	d4,d0
	move.l	SS_CLOSE(a5),a2
	jsr		(a2)
.delete:
	move.l	SS_FILENAME(a5),a0
	move.l	SS_DELETE(a5),a2
	jsr		(a2)
.writeerror:
	lea		alert_write(pc),a0
	bra.s	.error
.nomem:
	lea		alert_memory(pc),a0
	bra.s	.error
.badtype:
	lea		alert_type(pc),a0
.error:
	moveq	#1,d0
	move.l	SS_ALERT(a5),a2
	jsr		(a2)
	lea		msg_error(pc),a0
	bsr.s	qs_print
	bsr.s	qs_cleanup
	moveq	#0,d0
.return:
	movem.l	(sp)+,d3-d7/a2-a6
	rts

;	Prints the text at a0 in GEM-View's log window. printout() takes a
;	printf() format; the texts have no conversions, and the pointer is
;	passed both in a0 and on the stack, so it doesn't matter how Pure C
;	passes the fixed argument of a function with a variable argument list.

qs_print:
	move.l	a0,-(sp)
	move.l	SS_PRINTOUT(a5),a1
	jsr		(a1)
	addq.l	#4,sp
	rts

;	Frees the buffers.

qs_cleanup:
	lea		pixels,a3
	moveq	#2,d3								; pixels, table, out
.loop:
	move.l	(a3),d0
	beq.s	.next
	clr.l	(a3)
	move.l	d0,a0
	move.l	SS_FREE(a5),a2
	jsr		(a2)
.next:
	addq.l	#4,a3
	dbra	d3,.loop
	rts

;	Converts the picture's palette to RGB565 in lut. Monochrome pictures
;	have no palette: 0 is white and 1 black.

qs_palette:
	movem.l	a1-a3,-(sp)
	lea		lut,a0
	moveq	#127,d0								; Clear all 256 entries.
.clear:
	clr.l	(a0)+
	dbra	d0,.clear
	lea		lut,a0
	cmp.w	#IBITMAP,IMG_TYPE(a4)
	bne.s	.color
	move.w	#$ffff,(a0)
	bra.s	.done
.color:
	moveq	#0,d2
	move.w	IMG_RGBUSED(a4),d2					; Colours used
	bne.s	.used
	move.w	IMG_RGBSIZE(a4),d2
.used:
	cmp.w	#256,d2
	bls.s	.count
	move.w	#256,d2
.count:
	subq.w	#1,d2
	bmi.s	.done
	move.l	IMG_RED(a4),a1
	move.l	IMG_GREEN(a4),a2
	move.l	IMG_BLUE(a4),a3
.entry:
	move.w	(a1)+,d0							; Intensities are 0-65535.
	and.w	#$f800,d0
	move.w	(a2)+,d1
	lsr.w	#5,d1
	and.w	#$07e0,d1
	or.w	d1,d0
	move.w	(a3)+,d1
	lsr.w	#8,d1
	lsr.w	#3,d1
	or.w	d1,d0
	move.w	d0,(a0)+
	dbra	d2,.entry
.done:
	movem.l	(sp)+,a1-a3
	rts

;	a0 = ss->memory.malloc( d0 ), setting the flags for a0.

qs_malloc:
	move.l	SS_MALLOC(a5),a2
	jsr		(a2)
	cmp.w	#0,a0
	rts

msg_saving:			dc.b	"  Saving Q16 picture ... ",0
msg_done:			dc.b	"done.",10,0
msg_error:			dc.b	"error.",10,0
alert_write:		dc.b	"[3][ | Error writing the Q16 file! | Disk full? ][  OK  ]",0
alert_memory:		dc.b	"[3][ | Not enough memory to save | the Q16 picture. ][  OK  ]",0
alert_type:			dc.b	"[3][ | The Q16 module can't save | this kind of picture. ][  OK  ]",0
	even

	include	"../../m68k/q16dec.s"
	include	"../../m68k/q16enc.s"

;____ Variables __________________________________________________________

	section	bss

pixels:				ds.l	1					; pixels, table and out must stay
table:				ds.l	1					; in this order, see qs_cleanup.
out:				ds.l	1
planesize:			ds.l	1					; Bytes per plane
lastplane:			ds.l	1					; Offset of the last plane
depth:				ds.w	1					; Planes - 1
lut:				ds.w	256					; Palette as RGB565
