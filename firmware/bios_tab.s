; miniBIOS jump table

	.dsb	$FF00-*, $FF	; standard jump table address
bios_tab:
; *** *** JUMP TABLE *** ***
b_conio:	JMP conio
; TO DO *** TO DO ** TO DO
