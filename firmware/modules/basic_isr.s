; Basic ISR for Chihuahua/Zacatecas plus PANIC handler
; (c) 2024-2026 Carlos J. Santisteban
; last modified 20261114-1841

; ************************
; *** standard IRQ ISR ***
; ************************
isr:
.(
	PHA						; will need it, sooner or later
	BIT IFR					; check interrupt source
	BPL no_via				; not a VIA-sourced interrupt!
	BVC no_t1				; non-periodic? otherwise...
			BIT T1CL		; easiest way to acknowledge T1 interrupt EEEEK
			INC ticks		; update counter
		BNE end_t1			; check carry and exit promptly
			INC ticks+1
		BNE end_t1
			INC ticks+2
		BNE end_t1
			INC ticks+2
end_t1:
; should read keypad now
		LDA IORA			; assumed to stay in read mode!
		EOR #$FF			; EEEK
		STA gamepad			; standard gamepad address
		PLA					; restore this
		RTI
no_via:						; VIA is the only interrupt source... this should be either BRK or spurious!
no_t1:						; *** ignore all other sources of VIA interrupts ***
	PHX
	TSX						; let's dig into the stack
	LDA $0103, X			; get saved P, below pushed A & X
	AND #$10				; check B bit
	BEQ no_brk				; it was a hardware interrupt, thus spurious
		JMP panic			; otherwise BRK is treated as PANIC!
no_brk:
; might do something to signal spurious interrupts, like toggling Emilio's LED
	LDA IORB
	EOR #LED_EMI			; toggle Emilio's LED
	STA IORB
; restore and exit
	PLX
	PLA
	RTI						; otherwise restore status and continue
.)

; *** PANIC handler ***
panic:
.(
	LDA IORB				; LEDs control
	ORA #LCD_BLOFF|SD_DIS|LED_OFF		; clear previous status
panic_loop:
		EOR #LCD_LIGHT|SD_CS|LED_EMI	; make EVERYTHING blink!
		STA IORB						; update LEDs
panic_wait:
				INX
				BNE panic_wait
			INY
			BNE panic_wait	; some delay
		BEQ panic_loop		; forever
.)
