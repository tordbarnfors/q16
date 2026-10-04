; Startup code for Smurf export modules (.SXM), gcc version.
;
; As for import modules, with the magic "SXMD" at +8, module_info at +12,
; module_ability at +16 and the interface version at +20.

	SECTION	TEXT

	XREF	exp_module_main
	XREF	module_info
	XREF	module_ability
	XDEF	_errno

	clr.w	-(sp)			; Pterm0 if started as a program.
	trap	#1
	bra.w	exp_module_main
	dc.l	'SXMD'
	dc.l	module_info
	dc.l	module_ability
	dc.l	$0101

	SECTION	DATA

_errno:	dc.l	0
