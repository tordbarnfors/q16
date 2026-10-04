;=========================================================================
;
;	q16decf.s - Q16 pixel decoder for 68020/68030 without the static table.
;
;	q_decPixF() is q_decPix() from q16dec.s with one difference: the palette
;	index of each new pixel is calculated with the hash formula
;
;	    (p + (p >> 3) + (p >> 4) + (p >> 10)) & 63
;
;	instead of being looked up in the 64 KB static table. It saves the 64 KB
;	and the time q16_setupStaticTable() takes, but is slower per pixel. See
;	../bench/README.md for when each is faster. q16_readHeader() and
;	q_decAlp() are in q16dec.s.
;
;	Devpac syntax, same calling convention as q16dec.s: arguments on the
;	stack (cdecl), d0-d1/a0-a1 destroyed, all other registers preserved.
;	Reentrant, no BSS or DATA. Can be assembled on its own or INCLUDEd.
;
;=========================================================================

	opt		p=68030

	section	text

	xdef	q_decPixF,_q_decPixF


;	hash pixel
;
;	Sets d2 to the palette index of pixel (a data register). Uses d4.

hash				macro
	move.w	\1,d2
	move.w	\1,d4
	lsr.w	#3,d4
	add.w	d4,d2								; p + (p >> 3)
	lsr.w	#1,d4
	add.w	d4,d2								;   + (p >> 4)
	lsr.w	#6,d4
	add.w	d4,d2								;   + (p >> 10)
	and.w	#63,d2								; Bits 8-31 of d2 stay 0.
	endm


;____ q_decPixF() _______________________________________________________
;
;	int q_decPixF( unsigned short * pDest,
;	               const unsigned char * pBegin,
;	               const unsigned char * pEnd,
;	               unsigned long nbPixels );
;
;	Decodes the complete pixel stream between pBegin and pEnd into exactly
;	nbPixels big endian RGB565 pixels at pDest.
;
;	Same as q_decPix(), but calculates the palette index of each new pixel
;	with the hash formula instead of looking it up in the 64 KB static
;	table, so it needs neither the table nor q16_setupStaticTable().
;
;	Returns 0 if ok, -1 if the stream is corrupt or doesn't decode into
;	exactly nbPixels pixels. Never reads beyond pEnd nor writes beyond
;	pDest + nbPixels, even for corrupt data.
;
;	Register usage:
;
;	d0 = opcode (bits 8-31 always 0)
;	d1 = literal pixel (bits 16-31 always 0)
;	d2 = palette index (bits 8-31 always 0)
;	d3 = temp
;	d4 = temp, also used by hash
;	d5 = end of output
;	d6 = opcodes left to decode in fast loop before next safety check
;	d7 = last pixel (bits 16-31 always 0)
;	a0 = read pointer
;	a1 = write pointer
;	a2 = not used
;	a3 = palette (64 words on the stack)
;	a4 = delta table - $80*2, so it can be indexed by delta opcodes
;	a5 = palette - $40*2, so it can be indexed by index opcodes
;	a6 = end of input

DF_PALSIZE			equ		128
DF_ARGS				equ		4+10*4+DF_PALSIZE	; Return address, saved registers, palette.

q_decPixF:
_q_decPixF:
	movem.l	d2-d7/a3-a6,-(sp)
	lea		-DF_PALSIZE(sp),sp

	move.l	DF_ARGS(sp),a1						; pDest
	move.l	DF_ARGS+4(sp),a0					; pBegin
	move.l	DF_ARGS+8(sp),a6					; pEnd
	move.l	DF_ARGS+12(sp),d5					; nbPixels

	cmpa.l	a0,a6
	blo		.error								; pEnd before pBegin.

	add.l	d5,d5
	add.l	a1,d5								; d5 = end of output

	move.l	sp,a3								; Clear the palette.
	moveq	#DF_PALSIZE/4-1,d0
.clear:
	clr.l	(a3)+
	dbra	d0,.clear

	move.l	sp,a3
	lea		-$40*2(a3),a5
	lea		.deltatable-$80*2(pc),a4

	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d7

	; Calculate how many opcodes we can decode before we need to check
	; for end of input or output. An opcode reads at most 65 bytes and
	; writes at most 32 pixels (64 bytes).

.refill:
	move.l	a6,d3
	sub.l	a0,d3
	lsr.l	#7,d3								; d3 = input bytes left / 128
	move.l	d5,d4
	sub.l	a1,d4
	lsr.l	#6,d4								; d4 = output bytes left / 64
	cmp.l	d4,d3
	bls.s	.refill2
	move.l	d4,d3
.refill2:
	tst.l	d3
	beq		.slow								; Close to the end, continue carefully.
	cmp.l	#$10000,d3
	bls.s	.refill3
	move.l	#$10000,d3
.refill3:
	subq.l	#1,d3
	move.w	d3,d6

	; Fast loop. No checks for end of input or output.

.loop:
	move.b	(a0)+,d0
	bmi.s	.delta
	btst	#6,d0
	bne.s	.index
	btst	#5,d0
	bne.s	.repeat

	; 000xxxxx - New pixels (1-32), little endian.

	move.w	d0,d3
.literal:
	move.w	(a0)+,d1
	ror.w	#8,d1
	move.w	d1,(a1)+
	hash	d1
	move.w	d1,(a3,d2.w*2)
	dbra	d3,.literal
	move.w	d1,d7
	dbra	d6,.loop
	bra.s	.refill

	; 1rrgggbb - Delta from previous pixel.

.delta:
	add.w	(a4,d0.w*2),d7
	move.w	d7,(a1)+
	hash	d7
	move.w	d7,(a3,d2.w*2)
	dbra	d6,.loop
	bra.w	.refill

	; 01xxxxxx - Pixel from palette.

.index:
	move.w	(a5,d0.w*2),d7
	move.w	d7,(a1)+
	dbra	d6,.loop
	bra.w	.refill

	; 001xxxxx - Repeat previous pixel (1-32).

.repeat:
	moveq	#$1f,d3
	and.w	d0,d3
	add.w	d3,d3
	neg.w	d3
	jmp		.replast(pc,d3.w)
	rept	31
	move.w	d7,(a1)+
	endr
.replast:
	move.w	d7,(a1)+
	dbra	d6,.loop
	bra		.refill

	; Slow loop for the last opcodes. Checks every opcode against end of
	; input and output.

.slow:
	cmpa.l	a6,a0
	bhs.w	.inputend
	move.b	(a0)+,d0
	bmi.s	.slowdelta
	btst	#6,d0
	bne.s	.slowindex

	moveq	#$1f,d3
	and.w	d0,d3								; d3 = pixels - 1
	moveq	#0,d4
	move.w	d3,d4
	addq.w	#1,d4
	add.w	d4,d4								; d4 = bytes of output (and input if literal)
	move.l	d5,d1
	sub.l	a1,d1
	cmp.l	d4,d1
	blo.s	.error								; Writes beyond end of output.
	moveq	#0,d1

	btst	#5,d0
	bne.s	.slowrepeat

	move.l	a6,d1
	sub.l	a0,d1
	cmp.l	d4,d1
	blo.s	.error								; Reads beyond end of input.
	moveq	#0,d1
.slowliteral:
	move.w	(a0)+,d1
	ror.w	#8,d1
	move.w	d1,(a1)+
	hash	d1
	move.w	d1,(a3,d2.w*2)
	dbra	d3,.slowliteral
	move.w	d1,d7
	bra.s	.slow

.slowrepeat:
	move.w	d7,(a1)+
	dbra	d3,.slowrepeat
	bra.s	.slow

.slowdelta:
	cmp.l	a1,d5
	bls.s	.error
	add.w	(a4,d0.w*2),d7
	move.w	d7,(a1)+
	hash	d7
	move.w	d7,(a3,d2.w*2)
	bra.w	.slow

.slowindex:
	cmp.l	a1,d5
	bls.s	.error
	move.w	(a5,d0.w*2),d7
	move.w	d7,(a1)+
	bra.w	.slow

.inputend:
	cmp.l	a1,d5
	bne.s	.error								; Input ended before all pixels were decoded.
	moveq	#0,d0
	bra.s	.done
.error:
	moveq	#-1,d0
.done:
	lea		DF_PALSIZE(sp),sp
	movem.l	(sp)+,d2-d7/a3-a6
	rts

	; Value to add to previous pixel for each delta opcode ($80-$FF).
	; Opcode $d2 (zero delta) is reserved and never written by the encoder.

.deltatable:
	dc.w	$ef7e,$ef7f,$ef80,$ef81,$ef9e,$ef9f,$efa0,$efa1
	dc.w	$efbe,$efbf,$efc0,$efc1,$efde,$efdf,$efe0,$efe1
	dc.w	$effe,$efff,$f000,$f001,$f01e,$f01f,$f020,$f021
	dc.w	$f03e,$f03f,$f040,$f041,$f05e,$f05f,$f060,$f061
	dc.w	$f77e,$f77f,$f780,$f781,$f79e,$f79f,$f7a0,$f7a1
	dc.w	$f7be,$f7bf,$f7c0,$f7c1,$f7de,$f7df,$f7e0,$f7e1
	dc.w	$f7fe,$f7ff,$f800,$f801,$f81e,$f81f,$f820,$f821
	dc.w	$f83e,$f83f,$f840,$f841,$f85e,$f85f,$f860,$f861
	dc.w	$ff7e,$ff7f,$ff80,$ff81,$ff9e,$ff9f,$ffa0,$ffa1
	dc.w	$ffbe,$ffbf,$ffc0,$ffc1,$ffde,$ffdf,$ffe0,$ffe1
	dc.w	$fffe,$ffff,$0000,$0001,$001e,$001f,$0020,$0021
	dc.w	$003e,$003f,$0040,$0041,$005e,$005f,$0060,$0061
	dc.w	$077e,$077f,$0780,$0781,$079e,$079f,$07a0,$07a1
	dc.w	$07be,$07bf,$07c0,$07c1,$07de,$07df,$07e0,$07e1
	dc.w	$07fe,$07ff,$0800,$0801,$081e,$081f,$0820,$0821
	dc.w	$083e,$083f,$0840,$0841,$085e,$085f,$0860,$0861
