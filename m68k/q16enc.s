;=========================================================================
;
;	q16enc.s - Q16 image encoder for 68020/68030 (Atari Falcon, TT etc.)
;
;	Encodes complete images into Q16 (RGB565 pixels with optional 8-bit
;	alpha). The output is byte-identical to q16_lib.c when the image is
;	compressed in one call. See q16enc.h for the C interface and
;	../q16_lib.h for a description of the file format.
;
;	Devpac syntax. Uses 68020+ addressing modes and unaligned word writes,
;	so a 68000 is not supported.
;
;	Calling convention as in q16dec.s: arguments on the stack (cdecl),
;	d0-d1/a0-a1 destroyed, all other registers preserved. Pointers are
;	returned in both d0 and a0, since compilers differ in which register
;	they expect. Reentrant, no BSS or DATA.
;
;	The file can be assembled on its own or INCLUDEd into a program.
;
;=========================================================================

	opt		p=68030

	section	text

	xdef	q16_writeHeader,_q16_writeHeader
	xdef	q_encPix,_q_encPix
	xdef	q_encAlp,_q_encAlp


;____ q16_writeHeader() __________________________________________________
;
;	void q16_writeHeader( q16_fileheader * header,
;	                      unsigned long width, unsigned long height,
;	                      unsigned long pixelBytes, unsigned long alphaBytes,
;	                      unsigned long flags );

WH_HEADER			equ		4
WH_WIDTH			equ		8
WH_HEIGHT			equ		12
WH_PIXELBYTES		equ		16
WH_ALPHABYTES		equ		20
WH_FLAGS			equ		24

q16_writeHeader:
_q16_writeHeader:
	move.l	WH_HEADER(sp),a0
	move.l	#$51353635,(a0)						; "Q565"
	move.b	#1,4(a0)							; Version
	move.b	WH_FLAGS+3(sp),5(a0)
	move.w	WH_WIDTH+2(sp),d0
	ror.w	#8,d0
	move.w	d0,6(a0)
	move.w	WH_HEIGHT+2(sp),d0
	ror.w	#8,d0
	move.w	d0,8(a0)
	clr.w	10(a0)
	move.l	WH_PIXELBYTES(sp),d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	move.l	d0,12(a0)
	move.l	WH_ALPHABYTES(sp),d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	move.l	d0,16(a0)
	rts


;____ q_encPix() _________________________________________________________
;
;	unsigned char * q_encPix( unsigned char * pDest,
;	                          const unsigned short * pBegin,
;	                          const unsigned short * pEnd,
;	                          const unsigned char staticTable[65536] );
;
;	Compresses the big endian RGB565 pixels between pBegin and pEnd into
;	pDest, which must have room for Q16_MAX_PIXEL_BYTES(pixels) bytes.
;	Returns the end of the compressed data.
;
;	Register usage:
;
;	d0 = palette index (bits 8-31 always 0)
;	d1 = pixel (bits 16-31 always 0)
;	d2-d4 = temp
;	d5 = 11, shift count for red
;	d6 = temp / literal count - 1
;	d7 = previous pixel
;	a0 = read pointer
;	a1 = write pointer
;	a2 = static table (pixel to palette index)
;	a3 = palette (64 words on the stack)
;	a4 = end of input
;	a5 = count byte of current literal run

EP_PALSIZE			equ		128
EP_ARGS				equ		4+11*4+EP_PALSIZE	; Return address, saved registers, palette.

;	DELTA pixel,previous,result,temp1,temp2,toolarge
;
;	Builds the delta opcode for pixel compared to previous in result, or
;	branches to toolarge if the difference doesn't fit. Same test as
;	q16_lib.c: red and blue -2 to +1, green -4 to +3.

delta				macro
	move.w	\1,\3								; Red
	lsr.w	d5,\3
	move.w	\2,\4
	lsr.w	d5,\4
	sub.w	\4,\3
	addq.w	#2,\3
	cmp.w	#4,\3
	bhs		\6
	move.w	\1,\4								; Green
	lsr.w	#5,\4
	and.w	#63,\4
	move.w	\2,\5
	lsr.w	#5,\5
	and.w	#63,\5
	sub.w	\5,\4
	addq.w	#4,\4
	cmp.w	#8,\4
	bhs		\6
	lsl.w	#5,\3
	lsl.w	#2,\4
	or.w	\4,\3
	move.w	\1,\4								; Blue
	moveq	#31,\5
	and.w	\5,\4
	and.w	\2,\5
	sub.w	\5,\4
	addq.w	#2,\4
	cmp.w	#4,\4
	bhs		\6
	or.w	\4,\3
	or.b	#$80,\3
	endm

q_encPix:
_q_encPix:
	movem.l	d2-d7/a2-a6,-(sp)
	lea		-EP_PALSIZE(sp),sp

	move.l	EP_ARGS(sp),a1						; pDest
	move.l	EP_ARGS+4(sp),a0					; pBegin
	move.l	EP_ARGS+8(sp),a4					; pEnd
	move.l	EP_ARGS+12(sp),a2					; staticTable

	move.l	sp,a3								; Clear the palette.
	moveq	#EP_PALSIZE/4-1,d0
.clear:
	clr.l	(a3)+
	dbra	d0,.clear
	move.l	sp,a3

	moveq	#0,d0
	moveq	#0,d1
	moveq	#11,d5
	moveq	#0,d7

.loop:
	cmpa.l	a4,a0
	bhs		.done
	move.w	(a0)+,d1
	cmp.w	d7,d1
	bne.s	.notrepeat

	; 001xxxxx - Repeat previous pixel (1-32).

	moveq	#0,d2								; d2 = count - 1
.repeat:
	cmpa.l	a4,a0
	bhs.s	.repeatend
	cmp.w	(a0),d1
	bne.s	.repeatend
	addq.l	#2,a0
	addq.w	#1,d2
	cmp.w	#31,d2
	blo.s	.repeat
.repeatend:
	or.b	#$20,d2
	move.b	d2,(a1)+
	bra.s	.loop

	; 01xxxxxx - Pixel from palette.

.notrepeat:
	move.b	(a2,d1.l),d0
	cmp.w	(a3,d0.w*2),d1
	bne.s	.notindex
	move.b	d0,d2
	or.b	#$40,d2
	move.b	d2,(a1)+
	move.w	d1,d7
	bra.s	.loop

	; 1rrgggbb - Delta from previous pixel.

.notindex:
	delta	d1,d7,d2,d3,d4,.literal
	move.b	d2,(a1)+
	move.w	d1,(a3,d0.w*2)
	move.w	d1,d7
	bra		.loop

	; 000xxxxx - New pixels (1-32), little endian. Continues for as long
	; as the next pixel can't be stored in a better way.

.literal:
	move.l	a1,a5								; Count byte, filled in when done.
	addq.l	#1,a1
	move.w	d1,d2
	ror.w	#8,d2
	move.w	d2,(a1)+
	move.w	d1,(a3,d0.w*2)
	moveq	#0,d6								; d6 = count - 1
.literalnext:
	cmp.w	#31,d6
	bhs.s	.literalend
	cmpa.l	a4,a0
	bhs.s	.literalend
	moveq	#0,d3
	move.w	(a0),d3								; d3 = next pixel
	cmp.w	d1,d3
	beq.s	.literalend							; Start of repeat.
	move.b	(a2,d3.l),d0
	cmp.w	(a3,d0.w*2),d3
	beq.s	.literalend							; Can be taken from palette.
	delta	d3,d1,d2,d4,d7,.literalpixel
	bra.s	.literalend							; Can be stored as delta.
.literalpixel:
	move.w	d3,(a3,d0.w*2)
	move.w	d3,d1
	ror.w	#8,d3
	move.w	d3,(a1)+
	addq.l	#2,a0
	addq.w	#1,d6
	bra.s	.literalnext
.literalend:
	move.b	d6,(a5)
	move.w	d1,d7
	bra		.loop

.done:
	move.l	a1,d0
	move.l	a1,a0
	lea		EP_PALSIZE(sp),sp
	movem.l	(sp)+,d2-d7/a2-a6
	rts


;____ q_encAlp() _________________________________________________________
;
;	unsigned char * q_encAlp( unsigned char * pDest,
;	                          const unsigned char * pBegin,
;	                          const unsigned char * pEnd );
;
;	Compresses the alpha values between pBegin and pEnd into pDest, which
;	must have room for Q16_MAX_ALPHA_BYTES(pixels) bytes. Returns the end
;	of the compressed data. Same algorithm as WonderGUI's RLE compressor.
;
;	Register usage:
;
;	d0 = temp
;	d2 = run length
;	d3 = temp
;	d6 = length of current verbatim span
;	d7 = last value
;	a0 = read pointer
;	a1 = write pointer
;	a2 = end of input
;	a3 = temp
;	a5 = count byte of current verbatim span

EA_ARGS				equ		4+7*4				; Return address, saved registers.

q_encAlp:
_q_encAlp:
	movem.l	d2-d3/d6-d7/a2-a3/a5,-(sp)

	move.l	EA_ARGS(sp),a1						; pDest
	move.l	EA_ARGS+4(sp),a0					; pBegin
	move.l	EA_ARGS+8(sp),a2					; pEnd

	cmpa.l	a2,a0
	bhs		.return								; Nothing to compress.

	move.l	a1,a5
	addq.l	#1,a1
	move.b	(a0)+,d7
	move.b	d7,(a1)+
	moveq	#1,d6

.loop:
	cmpa.l	a2,a0
	bhs.s	.end
	lea		1(a0),a3
	cmpa.l	a2,a3
	bhs.s	.verbatim
	cmp.b	(a0),d7
	bne.s	.verbatim
	cmp.b	(a3),d7
	bne.s	.verbatim

	; At least two more of the last value, store as repeats.

	move.b	d6,d0
	subq.b	#1,d0
	move.b	d0,(a5)								; Close current span.
	addq.l	#1,a3
.scan:
	cmpa.l	a2,a3
	bhs.s	.scanned
	cmp.b	(a3),d7
	bne.s	.scanned
	addq.l	#1,a3
	bra.s	.scan
.scanned:
	move.l	a3,d2
	sub.l	a0,d2								; d2 = repeats
.repeat:
	cmp.l	#2,d2
	blo.s	.repeatdone
	move.l	d2,d3
	cmp.l	#128,d3
	bls.s	.repeat2
	move.l	#128,d3
.repeat2:
	move.b	d3,d0
	neg.b	d0
	move.b	d0,(a1)+
	sub.l	d3,d2
	adda.l	d3,a0
	bra.s	.repeat
.repeatdone:
	cmpa.l	a2,a0
	beq.s	.return								; Input ended with repeats.
	move.l	a1,a5								; New span.
	addq.l	#1,a1
	moveq	#0,d6
	bra.s	.copy

.verbatim:
	cmp.w	#128,d6
	bne.s	.copy
	move.b	#127,(a5)							; Span full, start a new one.
	move.l	a1,a5
	addq.l	#1,a1
	moveq	#0,d6
.copy:
	move.b	(a0)+,d7
	move.b	d7,(a1)+
	addq.w	#1,d6
	bra.s	.loop

.end:
	move.b	d6,d0
	subq.b	#1,d0
	move.b	d0,(a5)
.return:
	move.l	a1,d0
	move.l	a1,a0
	movem.l	(sp)+,d2-d3/d6-d7/a2-a3/a5
	rts
