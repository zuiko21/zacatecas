; Zacatecas default ROM bootloader
; (c) 2026 Carlos J. Santisteban
; last modified 20261114-2233

#ifndef	ZACATECAS
#include	"zacatecas.h"
#endif

#define ROMSTART	$C000

; ******************************
; *** default ROM bootloader ***
; ******************************
drom_main:
.(
; *** zeropage usage ***
	mx_pg	= $F9			; last computed page
	-ptr		= $FA			; destination pointer
	src		= $F8			; source pointer

; *** display banner ***
	LDX #splash-msg_rom		; initial index (actually 0)
	JSR disp_code
; *** check whether there's a Pocket executable at the beginning of ROM ***
; just for convenience, copy header into RAM buffer
;	LDX #>buffer			; expected 4 (for $0400)
;	LDY #<buffer			; expected 0
;	STX ptr+1
;	STY ptr
;hdcpy:
;		LDA ROMSTART, Y		; fixed ROM address
;		STA (ptr), Y		; RAM buffer
;		INY
;		BNE hdcpy			; copy full page
; * look for a valid header *
	LDA ROMSTART			; check magic number one (magic1)
		BNE not_magic 
	LDA ROMSTART+7			; check magic number two (magic2)
	CMP #13					; must be NEWL instead of zero
		BNE not_magic
	LDA ROMSTART+255		; check magic number three (magic3)
	BEQ is_magic
not_magic:
		JMP no_rom			; otherwise header is not valid *** pretty strange, as the bootloader ROM image header is expected
is_magic:
; * header is valid, check whether executable or not *
	LDA ROMSTART+1			; check Pocket signature (bootsig)
	CMP #'p'
		BNE not_magic
	LDA ROMSTART+2
	CMP #'Z'
		BNE not_magic		; ignore generic files or Durango executables
; *** there is a Pocket executable in ROM, check whether executable-in-place
	LDX ROMSTART+4			; check load page (ld_addr+1)
	BMI xip					; it is ROMmable, thus execute directly
; otherwise display name for a moment (maybe for XIPs as well?)
		LDY #0				; reset index
r_name:
			LDA ROMSTART+8, Y			; indexed name (respect X)
		BEQ name_ok						; until terminator
			JSR b_conio					; BIOS call
			INY							; next char
;			CPY #16
			BNE r_name
name_ok:
; and then copy ROM file into RAM as expected
		LDA #<ROMSTART		; ROM address as source
		LDY #>ROMSTART
		STA src
		STY src+1			; source pointer set
		LDA ROMSTART+3		; get expected load address (ld_addr), MSB already in X
		STA ptr
; compute last address (trying to keep X for later) *** assume ld_addr LSB is ZERO!
		TXA					; start page
		CLC
		ADC ROMSTART+253	; add fsize+1
		LDY ROMSTART+252	; is it round page size?
		BEQ mpg_ok			; if not, add one more page
			INC
mpg_ok:
		STA mx_pg			; store first free page
; proceed with copy (don't think progress bar is needed)
		LDY #0
xpage:
			STX ptr+1					; destination pointer set... and keep X as writing page
xcpy:
				LDA (src), Y			; (5) get source
				STA (ptr), Y			; (6) store at destination
				INY						; (2+3) next byte
				BNE xcpy
			INC src+1		; next page
			INX				; destination as well
			CPX mx_pg		; are we there yet?
			BNE xpage
; *** proceed with execution ***
xip:
	JMP (ROMSTART+5)		; *** lauch *** somewhat safer than JMP (ex_addr)

; *** failed to detect default ROM ***
no_rom:
	LDX #nexec-msg_rom		; complain
	JSR err_code
	JMP end_drom			; as a last resort, return to bootloader for nanoBoot

; ************************
; *** support routines ***
; ************************
; *** display indexed message ***
disp_code:
		LDA msg_rom, X		; get char
	BEQ dc_end				; message ended
		JSR b_conio			; display char (BIOS call keeps all registers)
		INX
		BNE disp_code		; next char
dc_end:
	RTS

; *** buzzing error code display ***
err_code:
	JSR disp_code			; display message...
;	JMP long_buzz			; ...and buzz
long_buzz:
	LDA #%11100000			; this will set CB2 high (enable sound)
	TSB PCR
	LDA ACR					; previous state of ACR
	PHA						; keep it just in case
	ORA #%11000000			; T1 continuous interrupts, PB7 square wave
	STA ACR					; start buzzing
	LDA ticks				; get ticks LSB
	SBC #5					; about 1 second delay (don't care about C)
	PHP
	CLI						; just in case...
lb_wait:
		CMP ticks			; wait for next second
		BNE lb_wait
	PLP						; back to previous interrupt status
	PLA
	STA ACR					; restore ACR
	LDA #%00100000			; was %111xxxxx, TRB will turn into %110xxxxx
	TRB PCR
	RTS

; ********************
; *** diverse data ***
; ********************
; messages for ROMboot
msg_rom:
splash:
	.asc	"  Default ROM:", 13, 0
nexec:
	.asc	"*** No EXEC ***", 0
.)
end_drom:
