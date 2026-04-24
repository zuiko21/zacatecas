; Test code for Zacatecas SBC
; (c) 2026 Carlos J. Santisteban

#include	"zacatecas.h"

#ifdef	POCKET
	*		= $4000			; upper 16K RAM for testing
#else
	*		= $C000			; standard 16K ROM
#endif
; ***********************
; *** standard header ***
; ***********************
rom_start:
; header ID
	.byt	0				; [0]=NUL, first magic number
#ifndef	POCKET
	.asc	"dX"			; bootable ROM
	.asc	"****"			; reserved
#else
	.asc	"pX"			; downloadable Pocket format
	.word	rom_start		; load address
	.word	reset			; execution address
#endif
	.byt	13				; [7]=NEWLINE, second magic number
; filename
	.asc	"Zacatecas boot firmware 1.0", 0	; C-string with filename @ [8], max 220 chars
;	.asc	"(comment)"		; optional C-string with comment after filename, filename+comment up to 220 chars
	.byt	0				; second terminator for optional comment, just in case

; advance to end of header
	.dsb	rom_start + $E6 - *, $FF

; NEW library commit (user field 2)
	.asc	"$$$$$$$$"
; NEW main commit (user field 1)
	.asc	"$$$$$$$$"
; NEW coded version number
	.word	$1001			; 1.0a1		%vvvvrrrrsshhbbbb, where revision = %hhrrrr, ss = %00 (alpha), %01 (beta), %10 (RC), %11 (final)

; date & time in MS-DOS format at byte 248 ($F8)
	.word	$4A00			; time, 17.16		1000 1-010 000-0 0000
	.word	$5C98			; date, 2026/4/24	0101 110-0 100-1 1000
; filesize in top 32 bits (@ $FC) now including header ** must be EVEN number of pages because of 512-byte sectors
	.word	file_end-rom_start			; filesize (rom_end is actually $10000)
	.word	0							; 64K space does not use upper 16 bits, [255]=NUL may be third magic number

; *******************
; *** actual code ***
; *******************
reset:
	SEI						; usual 6502 stuff, just in case
	CLD
	LDX #$FF
	TXS
; Chihuahua/Zacatecas stuff
	STZ DDRA				; PA is input most of the time
	LDA #%11101111			; make sure LCD ENABLE is low ASAP, keep all LEDs off as well
	STA IORB
	STX DDRB				; PB is always output
	LDY #$7F				; disable all interrupt sources for a while
	STY IER
	INY						; VIA should respond as all sources disabled
	CPY IER					; let's check for VIA presence
	BEQ continue
		JMP panic			; otherwise this is not Chihuahua, or something is very wrong
continue:
	LDA #%11000000			; make CB2 low to disable sound, rest as inputs
	STA PCR
	LDA #%01000000			; T1 free run (PB7 no toggle), no SR, no latch
	STA ACR
	LDX #>t1ct				; T1 interrupt speed
	LDY #<t1ct
	STY T1CL
	STX T1CH				; start counting!
	LDY #<isr				; supplied ISR address
	LDX #>isr
	STY fw_irq				; set vector
	STX fw_irq+1
	LDY #<debug				; same with (placeholder) NMI
	LDX #>debug
	STY fw_nmi
	STX fw_nmi+1
startup:
	LDA #%11000000			; this far, only T1 interrupt is enabled
	STA IER
	CLI						; enable interrupts, and we're up and running!
; ************************************************************************
; just enable LCD backlight...
	LDA IORB
	AND #LCD_BLON			; set LCD_BL low to turn on the light!
	STA IORB
lock:
	BRA lock				; just do nothing...
	
; ***********************
; *** USEFUL ROUTINES ***
; ***********************

; *** send byte in A to LCD ***
; *** C=1 for data, C=0 for commands *** note separate entry points
LCD_command:
	CLC						; commands will be less frequent, thus slower
	BRA send_LCD
LCD_data:
	SEC						; fastest data sending
send_LCD:
	SEI						; we must keep PA as output, but ISR expects it to be input all the time!
	DEC DDRA				; now $FF... if a bit risky
	JSR send_byte			; no way for further optimisation
	STZ DDRA				; PA goes back to input
	CLI						; and return with interrupts on
	; *** might need to add some safe delay here *** theoretically needs NONE at 1 MHz (takes more than 37 µs)
	RTS

send_byte:
	PHP						; save C for later
	PHA						; save low nybble
	AND #$F0				; send high nybble first
	JSR send_nyb
	PLA						; retrieve full byte...
	LSR
	LSR
	LSR
	LSR						; ...just for the low nybble
	PLP						; and back to RS in C
send_nyb:
	ADC #0					; set PA0 according to RS
	STA IORA				; send nybble+RS
	LDA IORB				; check current status
	ORA #LCD_EN				; set E bit
	STA IORB				; pulse E output
	AND #LCD_DIS			; clear E bit
	STA IORB
	RTS

; ******************************************
; *** standard Interrupt Service Routine ***
; ******************************************
isr:						; assume PA all input
	BIT IFR					; check interrupt source
	BPL no_via				; not a VIA-sourced interrupt!
	BVC no_t1				; non-periodic? otherwise...
		BIT T1CL			; easiest way to acknowledge T1 interrupt EEEEK
		INC jiffy			; update counter
	BNE end_t1				; check carry and exit promptly
		INC jiffy+1
	BNE end_t1
		INC jiffy+2
	BNE end_t1
		INC jiffy+2
end_t1:
	RTI
no_via:						; VIA is the only interrupt source... this should be either BRK or spurious!
	PHA
	PHX
	TSX						; let's dig into the stack
	LDA $0103, X			; get saved P, below pushed A & X
	AND #$10				; check B bit
	BEQ no_brk				; it was a hardware interrupt, thus spurious
		JMP panic			; otherwise BRK is treated as PANIC!
no_brk:
; might do something to signal spurious interrupts, like powering Emilio's LED
	PLX
	PLA
	RTI						; otherwise restore status and continue
no_t1:
	PHA						; need to get the whole IFR
	LDA IFR
	ASL						; discard IRQ bit (assumed set) as well as T1 bit
	ASL						; is it T2?
;	BPL no_t2
;		BIT T2CL			; ack
; do T2 stuff **placeholder**
;		BRA via_exit		; restore A and exit
no_t2:
	ASL
;	BPL no_cb1
;		BIT IORB			; ack
; ** placeholder**
;		BRA via_exit
	ASL
;	BPL no_cb2
;		BIT IORB			; ack... if not independent!
; ** placeholder**
;		BRA via_exit
	ASL
	BPL no_sr
		BIT VSR				; ack
; ** placeholder** mainly for SS22 port
		BRA via_exit
	ASL
	BPL no_ca1
		BIT IORA			; ack
; ** placeholder** for external interrupt
		BRA via_exit
	ASL
	BPL no_ca2
		BIT IORA			; ack... if not independent!
; ** placeholder** for SS22 /STROBE
;		BRA via_exit		; already there!
via_exit:
	PLA
debug:						; *** NMI placeholder ***
	RTI

; *********************
; *** PANIC routine ***
; *********************
panic:
	SEI						; just in case
	LDA #$FF
	STA DDRB				; retrieve outputs
	LDA #%11100000			; make CB2 hi for clicking, rest as inputs
	STA PCR
	LDA #%00001110			; all LEDs on (including Durango's!) and keep LCD_E low for good measure
panic_repeat:
		STA IORB
		STA $DFAF			; Durango interrupt-enable port!
		STA $DFBF			; make Durango's buzzer click as well
		LDY #$7F			; faster-then-usual blink in Durango, about 3 Hz in Chihuahua/Zacatecas
panic_loop:
				DEX
				BNE panic_loop
			DEY
			BNE panic_loop	; quite some delay, ~0.16s @ 1 MHz
		EOR #%11100001		; toggle all relevant bits (will send SCLK pulses, though)
		JMP panic_repeat	; forever

#ifndef	POCKET
; ****************************
; *** standard ROM trailer ***
; ****************************
	.dsb	$FFD6-*, $FF	; filling
	.asc	"ZmOS"			; usual ROM signature... but this is Zacatecas!

NMI_handler:
	JMP (fw_nmi)			; make best use of space, standard vector at $0202
IRQ_handler:
	JMP (fw_irq)			; standard vector at $0200

	.dsb	$FFE1-*, $FF	; Durango devCart is *not* supported, but anyway
	JMP ($FFFC)

	.dsb	$FFFA-*, $FF	; fill until 6502 hard vectors
	.word	NMI_handler
	.word	reset
	.word	IRQ_handler
#endif
file_end:					; should be $10000 for ROM images, otherwise pocket file length
