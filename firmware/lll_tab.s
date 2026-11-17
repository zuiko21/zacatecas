; Zacatecas Low Level Library jump table

	.dsb	$FFB4-*, $FF	; start address after padding MUST be updated with every new function!!!!

lll_tab:
; *** *** JUMP TABLE *** ***
l_pad:		JMP raw_pad		; entry at $FFB4
l_lrst:		JMP LCD_reset	; entry at $FFB7
l_lcmd:		JMP LCD_command	; entry at $FFBA
l_ldat:		JMP LCD_data	; entry at $FFBD

; *** TO DO *** TO DO *** TO DO ***
