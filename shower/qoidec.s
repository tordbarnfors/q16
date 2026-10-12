;=========================================================================
;
;	qoidec.s - QOI image decoder for 68020/68030, for Shower.
;
;	Decodes QOI images (https://qoiformat.org/) into big endian RGB565
;	pixels, blended against black with the alpha channel the same way as
;	Shower blends Q16 pictures: each RGB565 component is multiplied by
;	(alpha + 1) / 256, alpha 0 gives black.
;
;	Follows the reference decoder qoi.h: the palette index is updated
;	after every op, and if the data ends before all pixels are decoded,
;	the rest of the picture is filled with the last pixel.
;
;	Devpac syntax, same calling convention as ../m68k/q16dec.s: arguments
;	on the stack (cdecl), d0-d1/a0-a1 destroyed, all other registers
;	preserved. Reentrant, no BSS or DATA.
;
;=========================================================================

	opt		p=68030

	section	text

	xdef	qoi_dec,_qoi_dec


;____ qoi_dec() __________________________________________________________
;
;	int qoi_dec( unsigned short * pDest,
;	             const unsigned char * pBegin,
;	             const unsigned char * pEnd,
;	             unsigned long nbPixels );
;
;	Decodes the QOI data between pBegin (after the 14 byte header) and
;	pEnd (the start of the 8 byte end marker) into exactly nbPixels
;	pixels at pDest. Ops may read up to 4 bytes beyond pEnd, which the
;	end marker covers. Returns 0.
;
;	Register usage:
;
;	d0 = op (bits 8-31 always 0)
;	d1 = current pixel, $RRGGBBAA
;	d2 = current pixel as RGB565, blended
;	d3-d5 = temp
;	d6 = pixels to write for the current op
;	d7 = pixels left to write
;	a0 = read pointer
;	a1 = write pointer
;	a2 = end of data
;	a3 = index of 64 pixels, on the stack

QD_INDEXSIZE		equ		256
QD_ARGS				equ		4+8*4+QD_INDEXSIZE	; Return address, saved registers, index.

qoi_dec:
_qoi_dec:
	movem.l	d2-d7/a2-a3,-(sp)
	lea		-QD_INDEXSIZE(sp),sp

	move.l	QD_ARGS(sp),a1						; pDest
	move.l	QD_ARGS+4(sp),a0					; pBegin
	move.l	QD_ARGS+8(sp),a2					; pEnd
	move.l	QD_ARGS+12(sp),d7					; nbPixels

	move.l	sp,a3								; Clear the index.
	moveq	#QD_INDEXSIZE/4-1,d0
.clear:
	clr.l	(a3)+
	dbra	d0,.clear
	move.l	sp,a3

	moveq	#0,d0
	move.l	#$000000ff,d1						; Black, opaque
	moveq	#0,d2

.loop:
	tst.l	d7
	beq		.done
	cmpa.l	a2,a0
	bhs		.fill								; Data ended early.
	move.b	(a0)+,d0
	cmp.b	#$fe,d0
	bhs.s	.rgb
	cmp.b	#$c0,d0
	bhs.s	.run
	cmp.b	#$80,d0
	bhs.s	.luma
	cmp.b	#$40,d0
	bhs.s	.diff

	; 00iiiiii - Pixel from index.

	move.l	(a3,d0.w*4),d1
	bra.s	.newpixel

	; 11111110 r g b - New colour, alpha unchanged.
	; 11111111 r g b a - New colour and alpha.

.rgb:
	bne.s	.rgba
	move.b	d1,d3
	move.l	(a0),d1
	addq.l	#3,a0
	move.b	d3,d1
	bra.s	.newpixel
.rgba:
	move.l	(a0)+,d1
	bra.s	.newpixel

	; 11rrrrrr - Repeat the current pixel 1-62 times.

.run:
	moveq	#$3f,d6
	and.w	d0,d6
	addq.w	#1,d6
	bsr.s	.hash
	bra.s	.write

	; 01rrggbb - Small difference from the current pixel, -2 to +1.

.diff:
	move.b	d0,d3
	lsr.b	#4,d3
	and.b	#3,d3
	subq.b	#2,d3								; d3 = red difference
	move.b	d0,d4
	lsr.b	#2,d4
	and.b	#3,d4
	subq.b	#2,d4								; d4 = green difference
	move.b	d0,d5
	and.b	#3,d5
	subq.b	#2,d5								; d5 = blue difference
	bra.s	.add

	; 10gggggg rrrrbbbb - Green -32 to +31, red and blue -8 to +7
	; relative to green.

.luma:
	move.b	d0,d4
	and.b	#$3f,d4
	sub.b	#32,d4								; d4 = green difference
	move.b	(a0)+,d3
	move.b	d3,d5
	lsr.b	#4,d3
	sub.b	#8,d3
	add.b	d4,d3								; d3 = red difference
	and.b	#$0f,d5
	subq.b	#8,d5
	add.b	d4,d5								; d5 = blue difference

.add:
	rol.l	#8,d1								; $GGBBAARR
	add.b	d3,d1
	rol.l	#8,d1								; $BBAARRGG
	add.b	d4,d1
	rol.l	#8,d1								; $AARRGGBB
	add.b	d5,d1
	rol.l	#8,d1								; $RRGGBBAA

.newpixel:
	moveq	#1,d6
	bsr.s	.hash
	bsr.s	.rgb565

.write:
	cmp.l	d7,d6
	bls.s	.count
	move.l	d7,d6								; Never more than nbPixels.
.count:
	sub.l	d6,d7
	subq.w	#1,d6
.pixel:
	move.w	d2,(a1)+
	dbra	d6,.pixel
	bra		.loop

.fill:
	move.w	d2,(a1)+
	subq.l	#1,d7
	bne.s	.fill

.done:
	moveq	#0,d0
	lea		QD_INDEXSIZE(sp),sp
	movem.l	(sp)+,d2-d7/a2-a3
	rts

;	Stores the current pixel in the index at
;	(r * 3 + g * 5 + b * 7 + a * 11) & 63. Uses d3-d5.

.hash:
	move.l	d1,d4
	move.b	d4,d3								; a
	lsl.b	#2,d3
	add.b	d4,d3
	add.b	d3,d3
	add.b	d4,d3								; a * 11
	lsr.l	#8,d4
	move.b	d4,d5								; b
	lsl.b	#3,d5
	sub.b	d4,d5
	add.b	d5,d3								;   + b * 7
	lsr.l	#8,d4
	move.b	d4,d5								; g
	lsl.b	#2,d5
	add.b	d4,d5
	add.b	d5,d3								;   + g * 5
	lsr.w	#8,d4								; r
	add.b	d4,d3
	add.b	d4,d3
	add.b	d4,d3								;   + r * 3
	and.w	#63,d3
	move.l	d1,(a3,d3.w*4)
	rts

;	Sets d2 to the current pixel as RGB565, blended against black.
;	Uses d3-d5.

.rgb565:
	move.l	d1,d3
	swap	d3									; d3.w = $RRGG
	and.w	#$f8fc,d3
	moveq	#0,d4
	move.b	d3,d4
	lsl.w	#3,d4								; Green
	and.w	#$f800,d3							; Red
	or.w	d4,d3
	move.w	d1,d4								; $BBAA
	lsr.w	#8,d4
	lsr.w	#3,d4								; Blue
	or.w	d4,d3
	cmp.b	#255,d1
	beq.s	.opaque
	tst.b	d1
	beq.s	.clear_pixel
	moveq	#0,d5								; Multiply each component by
	move.b	d1,d5								; (alpha + 1) / 256.
	addq.w	#1,d5
	move.w	d3,d2								; Red
	moveq	#11,d4
	lsr.w	d4,d2
	mulu.w	d5,d2
	lsr.w	#8,d2
	lsl.w	d4,d2
	move.w	d3,d4								; Green
	lsr.w	#5,d4
	and.w	#63,d4
	mulu.w	d5,d4
	lsr.w	#8,d4
	lsl.w	#5,d4
	or.w	d4,d2
	and.w	#31,d3								; Blue
	mulu.w	d5,d3
	lsr.w	#8,d3
	or.w	d3,d2
	rts
.clear_pixel:
	moveq	#0,d2
	rts
.opaque:
	move.w	d3,d2
	rts
