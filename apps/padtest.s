; Modular firmware for Zacatecas SBC
; (c) 2026 Carlos J. Santisteban
; last modified 20261108-1348

; standard definitions
#ifndef	ZACATECAS
#include	"zacatecas.h"
#endif

	*		= $0800

; ***********************
; *** standard header ***
; ***********************
.(
rom_start:
; header ID
	.byt	0				; [0]=NUL, first magic number
	.asc	"pZ"			; downloadable Pocket format (for Zacatecas/Chihuahua)
	.word	rom_start		; load address
	.word	reset			; execution address
	.byt	13				; [7]=NEWLINE, second magic number
; filename
	.asc	"Pad test", 0	; C-string with filename @ [8], max 220 chars
;	.asc	"(comment)"		; optional C-string with comment after filename, filename+comment up to 220 chars
	.byt	0				; second terminator for optional comment, just in case

; advance to end of header
	.dsb	rom_start + $E6 - *, $FF

; NEW library commit (user field 2)
	.asc	"$$$$$$$$"
; NEW main commit (user field 1)
	.asc	"$$$$$$$$"
; NEW coded version number
	.word	$1081			; 1.0RC1		%vvvvrrrrsshhbbbb, where revision = %hhbbbb, ss = %00 (alpha), %01 (beta), %10 (RC), %11 (final)

; date & time in MS-DOS format at byte 248 ($F8)
	.word	$6E00			; time, 13.48		0110 1-110 000-0 0000
	.word	$5D68			; date, 2026/11/8	0101 110-1 011-0 1000
; filesize in top 32 bits (@ $FC) now including header ** must be EVEN number of pages because of 512-byte sectors
	.word	file_end-rom_start			; filesize (rom_end is actually $10000)
	.word	0							; 64K space does not use upper 16 bits, [255]=NUL may be third magic number

; ****************
; *** ZP usage ***
; ****************
	old		= 3				; ZP usage
	mask	= old+1

; *******************
; *** actual code ***
; *******************
reset:
; display all keys sequentially on LCD bottom row
	LDA #$80				; first iteration displays RIGHTmost char
	STA old					; (p)reset counter
seq_loop:
		LDA old				; use counter as mask
		JSR en_str			; display 
		LDY #250			; quarter-of-a-second delay eeeeek EEEEEEEEEEEEEEEEEEEK
		JSR delay_ms
		LSR old				; update counter eeeek
		BCC seq_loop		; until 8-bits done
	LDA #0					; eeeek
	JSR en_str				; clear bottom row for good measure
; *** check pad input and display pressed keys on LCD bottom row ***
	LDA gamepad				; standard address as set by ISR
	STA old					; initial value
k_wait:
		LDA gamepad			; check current value
		CMP old				; did change?
		BEQ k_wait			; no, keep waiting
	STA old					; yes, update recorded value
	JSR en_str				; simply display current status...
	BRA k_wait				; ...forever

; *** *** END OF TEST CODE *** ***
lock:
	BRA lock				; just do nothing...

; ***********************
; *** USEFUL ROUTINES ***
; ***********************

; *** print string ***
; ($FA) points to C-string, second half of zpar
print:
	LDY #0
pr_loop:
		LDA ($FA), Y
	BEQ pr_exit
		JSR b_conio			; JSR LCD_data		; must call proper vectored CONIO
		INY
		BNE pr_loop			; could use BRA as well, but this limits to 256 chars
pr_exit:
	RTS

; *** display 8 chars from memory, replaced by spaces where the A bits are zero ***
; input > A = enable mask
en_str:
	STA mask				; temporary storage of enabling bits (A will be lost)
	LDA #$C0				; set DDRAM address to $40 (second row)
	JSR LCD_command			; direct call, no LLL interface yet -- sorry, Emilio!
	LDX #0
but_loop:
		LSR mask			; take LSB first
		BCS k_on			; if disabled...
			LDA #' '		; ...print a space
			BRA k_set		; else...
k_on:
		LDA keys, X			; ... get char to be displayed
k_set:
		JSR LCD_data		; direct print
		INX
		CPX #8				; all 8 bits done? not the most efficient way
		BNE but_loop
	RTS

; ********************
; *** DATA section ***
; ********************
keys:
	.asc	"RDLUeBtA"		; pad buttons, D0...D7

file_end:					; should be $10000 for ROM images, otherwise pocket file length
.)
