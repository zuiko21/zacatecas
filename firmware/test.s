; Debug code for Zacatecas SBC
; (c) 2026 Carlos J. Santisteban

#include	"zacatecas.h"

* = $8000					; 32K ROM
; no header...
	.dsb	$FFE0-*, $FF	; filler for minimal code!
reset:
	SEI
	CLD						; very basic 6502 init
	LDX #$FF
	TXS						; just for the $FF
	LDA #0
	STA IORB				; all zeroes at PB, incl LCD clock
	STX DDRB				; make PB all output
loop:
				DEX
				BNE loop
			DEY
			BNE loop		; ~0.33s delay
		EOR #LCD_BLOFF		; toggle backlight
		STA IORB
		BRA loop			; forever
end:
	RTI						; placeholder

	.dsb	$FFFA-*, $FF	; really invalid ROM footer
	.word	end
	.word	reset			; hard vector
	.word	end
