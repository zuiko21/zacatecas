; miniBIOS jump table

	.dsb	$FF00-*, $FF	; standard jump table address
bios_tab:
; *** *** JUMP TABLE *** ***
b_conio:	JMP conio		; entry at $FF00
b_pad:		JMP rpad		; entry at $FF03
b_sdev:		JMP sel_dev		; entry at $FF06
b_rblk:		JMP ssec_rd		; entry at $FF09
b_wblk:		JMP flush_sd	; entry at $FF0C
b_dini:		JMP sd_init		; entry at $FF0F

; *** TO DO *** TO DO *** TO DO
