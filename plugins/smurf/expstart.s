; Startup code for Smurf export modules (.SXM).
;
; As for import modules, with the magic "SXMD" at +8, module_info at +12,
; module_ability at +16 and the interface version at +20.
;
; Assembled with PUREC_SMURF defined for Smurf built with Pure C, which
; passes the GARGAMEL pointer in a0 and expects the result in a0.

	section	text

	xref	exp_module_main
	xref	module_info
	xref	module_ability
	xdef	_errno

	clr.w	-(sp)								; Pterm0 if started as a program.
	trap	#1
	ifd		PUREC_SMURF
	bra.w	pc_entry
	else
	bra.w	exp_module_main
	endc
	dc.l	'SXMD'
	dc.l	module_info
	dc.l	module_ability
	dc.l	$0101

	ifd		PUREC_SMURF

;	EXPORT_PIC *exp_module_main( GARGAMEL *smurf_struct /* a0 */ ), result in a0.

pc_entry:
	move.l	a0,-(sp)
	jsr		exp_module_main
	addq.l	#4,sp
	move.l	d0,a0
	rts

	endc

	section	data

_errno:				dc.l	0
