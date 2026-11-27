; Modular firmware for Zacatecas SBC
; (c) 2026 Carlos J. Santisteban
; last modified 20261127-0833

; add -DDEFAULT="path-to-default-Pocket-executable"
; add -DALONE for DEVELOPMENT only (requires external nanoBoot in ROM) perhaps with -DLOADADDR=$xxxx as required

; standard definitions
#include	"zacatecas.h"

; not much sense to set macro in CLI, but change as required if a proper debugger is to be installed
#define	STDNMI	panic

; *** linked bootloader ROM ***
#ifdef	ALONE
#ifndef	LOADADDR
#define		LOADADDR	$7000
#endif
	*		= LOADADDR		; 4K should suffice, and allow space in lower RAM
#else
	*		= $C000			; standard 16K ROM
; default ROM goes first
#ifdef	DEFAULT
#include	DEFAULT
	.dsb	$F000-*, $FF	; fill up to 4K loader *** CHECK
#endif
#endif
; ***********************
; *** standard header ***
; ***********************
.(
rom_start:
; header ID
	.byt	0				; [0]=NUL, first magic number
#ifdef	ALONE
	.asc	"pZ"			; Zacatecas Pocket executable
	.word	LOADADDR		; load address in RAM
	.word	reset			; execution address
#else
	.asc	"dX"			; bootable ROM
	.asc	"****"			; reserved
#endif
	.byt	13				; [7]=NEWLINE, second magic number
; filename
	.asc	"Zacatecas boot firmware 0.2a4", 0	; C-string with filename @ [8], max 220 chars
;	.asc	"(comment)"		; optional C-string with comment after filename, filename+comment up to 220 chars
	.byt	0				; second terminator for optional comment, just in case

; advance to end of header
	.dsb	rom_start + $E6 - *, $FF

; NEW library commit (user field 2)
	.asc	"$$$$$$$$"
; NEW main commit (user field 1)
	.asc	"$$$$$$$$"
; NEW coded version number
	.word	$0204			; 0.2a4		%vvvvrrrrsshhbbbb, where revision = %hhbbbb, ss = %00 (alpha), %01 (beta), %10 (RC), %11 (final)

; date & time in MS-DOS format at byte 248 ($F8)
	.word	$4400			; time, 08.32		0100 0-100 000-0 0000
	.word	$5D7B			; date, 2026/11/27	0101 110-1 011-1 1011
; filesize in top 32 bits (@ $FC) now including header ** must be EVEN number of pages because of 512-byte sectors
	.word	file_end-rom_start			; filesize (rom_end is actually $10000, otherwise use Pocket size)
	.word	0							; 64K space does not use upper 16 bits, [255]=NUL may be third magic number

; ************************
; *** actual boot code ***
; ************************
reset:
	SEI						; usual 6502 stuff, just in case
	CLD
	LDX #$FF
	TXS
; Chihuahua/Zacatecas stuff
	LDA #LCD_DIS			; make sure LCD ENABLE is low ASAP, keep all LEDs off as well
	STA IORB
	LDA #(SD_MISO^$FF)		; EEEEEEEEEEEEEEK
	STA DDRB				; PB is always output EXCEPT MISO
	STZ DDRA				; PA is input most of the time
	LDY #$7F				; disable all interrupt sources for a while
	STY IER
	STY IFR					; and clear any previous interrupt, just in case
	INY						; VIA should respond as all sources disabled ($80)
	CPY IER					; let's check for VIA presence
	BEQ continue
		JMP panic			; otherwise this is not Zacatecas, or something is very wrong
continue:
	LDA #%11000000			; make CB2 low to disable sound, rest as inputs
	STA PCR
	LDA #%01000000			; T1 free run (PB7 no toggle), no SR, no latch
	STA ACR
	LDX #>t1ct				; T1 interrupt speed for 250 Hz (as defined in zacatecas.h)
	LDY #<t1ct
	STY T1CL
	STX T1CH				; start counting!
	LDY #<isr				; supplied ISR address
	LDX #>isr
	STY fw_irq				; set vector
	STX fw_irq+1
	LDY #<STDNMI			; same with (placeholder) NMI
	LDX #>STDNMI
	STY fw_nmi
	STX fw_nmi+1
; *** startup ***
	LDA #%11000000			; this far, only T1 interrupt is enabled
	STA IER
	CLI						; enable interrupts, and we're up and running!
	STZ fw_cbin				; BIOS init, standard (non-DLE) CONIO mode
; Startup message
	JSR l_lrst				; init screen (LLL call)
	LDY #<splash
	LDX #>splash			; pointer to splash screen
	STY ptr
	STX ptr+1				; standard parameter
	JSR print
	JSR bong				; make startup sound

; ***********************
; *** boot key combos ***
; ***********************
; enable LCD backlight... if desired
	LDA gamepad				; check keys -- assume interrupts running
	BIT #PAD_LT				; press LEFT to turn Backlight OFF
	BNE bl_off
		TAY					; preserve gamepad status, saving 1 byte
		LDA #LCD_LIGHT		; clear LCD_BL to turn *on* the light!
		TRB IORB
		TYA					; retrieve A
bl_off:
; straight to nanoBoot, if desired
	BIT #PAD_SEL			; is select pressed?
	BEQ go_sd
		JMP go_nanoboot		; if so, skip SD & ROM and wait for nanoBoot
.)

; ***************************************************************
; *** system is up and running, execute different bootloaders ***
; ***************************************************************
go_sd:
#include "modules/sdboot.s"

go_rom:
#include "modules/romboot.s"

go_nanoboot:
#include "modules/nanoboot.s"

; *** *** should not arrive here EVER *** ***
	BRK					; PANIC instead

; ***********************
; *** USEFUL ROUTINES ***
; ***********************

; *** print string ***
; standard ptr parameter points to C-string
print:
.(
	LDY #0
pr_loop:
		LDA (ptr), Y
	BEQ pr_exit
		JSR b_conio			; must call proper vectored CONIO
		INY
		BNE pr_loop			; could use BRA as well, but this limits to 256 chars
pr_exit:
	RTS
.)

; *** bong sound ***
bong:
.(
	LDY #<(t1ct/8)
	LDA #>(t1ct/8)			; *** placeholder 1 kHz
	STY T1CL
	STA T1CH				; set T1 speed
	STZ T2CL
	STZ T2CH				; now pointing to T2CH, free run at max speed
	LDA #%11100000			; this will set CB2 high (enable sound)
	TSB PCR
	LDA ACR					; previous state of ACR
	PHA						; keep it just in case
	LDA #%11010000			; T1 free run (PB7 on), SR free, no latch
	STA ACR					; start beeping
	LDA #$FF				; max volume PWM
bvol:
		STA VSR				; set PWM
		LDX #$40			; in case a shorter envelope is desired
bloop:
				INY			; some delay, first iteration a bit shorter
				BNE bloop
			DEX
			BNE bloop
		ASL					; one bit less
		BCS bvol
	PLA
	STA ACR					; restore ACR (and stop shifting)
	LDA #%00100000			; was %111xxxxx, TRB will turn into %110xxxxx
	TRB PCR					; CB2 low stops sound, no matter PB7 status
	LDX #>t1ct				; restore standard T1 interrupt speed
	LDY #<t1ct
	STY T1CL
	STX T1CH				; (re)start counting!
	RTS
.)

; ******************************************
; *** standard Interrupt Service Routine ***
; ******************************************
isr:						; assume PA all input
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
		PLA					; restore this (usual fast interrupt)
		RTI
no_via:						; VIA is the only interrupt source... this should be either BRK or spurious!
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
	PLX						; extra saved register to check B flag
	PLA
	RTI						; otherwise restore status and continue
no_t1:
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
; **placeholder**
;		BRA via_exit
no_cb1:
	ASL
;	BPL no_cb2
;		BIT IORB			; ack... if not independent!
; **placeholder**
;		BRA via_exit
no_cb2:
	ASL
	BPL no_sr
		BIT VSR				; ack
; **placeholder** mainly for SS22 port
		BRA via_exit
no_sr:
	ASL
	BPL no_ca1
		BIT IORA			; ack
; **placeholder** for external interrupt
		BRA via_exit
no_ca1:
	ASL
	BPL no_ca2
		BIT IORA			; ack... if not independent!
; **placeholder** for SS22 /STROBE
;		BRA via_exit		; already there!
no_ca2:
via_exit:
	PLA
	RTI
.)

; *********************
; *** PANIC routine *** universal
; *********************
panic:
.(
	SEI						; just in case
	LDA #(SD_MISO^$FF)		; EEEEEEEEEEEEEEK
	STA DDRB				; retrieve outputs
	LDA #%11100000			; make CB2 hi for clicking, rest as inputs
	STA PCR
	LDA #%00000110			; all LEDs on (including Durango's!) and keep LCD_E low for good measure
panic_repeat:
		STA IORB			; set Zacatecas bits
		ROL:ROL				; this will set D7 at D1
		STA $DFAF			; Durango interrupt-enable port!
		STA $DFBF			; make Durango's buzzer click as well
		ROR:ROR				; back to standard value
		LDY #$7F			; faster-then-usual blink in Durango, about 3 Hz in Chihuahua/Zacatecas
panic_loop:
				DEX
				BNE panic_loop
			DEY
			BNE panic_loop	; quite some delay, ~0.16s @ 1 MHz
		EOR #%11101000		; toggle all relevant bits
		JMP panic_repeat	; forever
.)

; ********************
; *** DATA section ***
; ********************
splash:
	.asc	"Zacatecas 0.2a4", 13, 0

; **********************
; *** BIOS functions ***
; **********************
#include	"bios.s"
#include	"lll.s"

; *** BIOS / LLL interface ***
; BIOS table always starts at $FF00, includes padding
#include	"bios_tab.s"

; assume LLL jump table will provide adequate padding before it
#include	"lll_tab.s"
; LLL always ends at $FFBF, grows backwards

; ****************************
; *** standard ROM trailer ***
; ****************************
.(
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
.)
file_end:					; should be $10000 for ROM images, otherwise pocket file length

