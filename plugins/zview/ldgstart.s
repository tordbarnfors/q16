; ldgstart.s - startup code for Q16.LDG without a C library.
;
; The LDG manager loads the library with Pexec(3), starts it with Pexec(4)
; and keeps the memory after the library has terminated. This shrinks the
; memory block to the program and a small stack, calls main() and
; terminates with its return value.
;
; Assemble with: vasmm68k_mot -devpac -Faout -o ldgstart.o ldgstart.s

STACKSIZE			equ		4096

	section	text

	xdef	_start,_basepage
	xref	_main

_start:
	move.l	4(sp),a0							; Basepage
	move.l	a0,_basepage
	move.l	12(a0),d0							; Text, data and BSS length
	add.l	20(a0),d0
	add.l	28(a0),d0
	add.l	#256+STACKSIZE,d0					; Basepage and stack
	and.b	#$fc,d0
	lea		(a0,d0.l),sp						; Stack at the end of the block
	move.l	d0,-(sp)
	move.l	a0,-(sp)
	clr.w	-(sp)
	move.w	#$4a,-(sp)							; Mshrink
	trap	#1
	lea		12(sp),sp
	jsr		_main
	move.w	d0,-(sp)
	move.w	#$4c,-(sp)							; Pterm
	trap	#1

	section	bss

_basepage:
	ds.l	1
