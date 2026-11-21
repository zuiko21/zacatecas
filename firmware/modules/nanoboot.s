; nanoBoot v2 (Zacatecas version, also Chihuahua suitable with an LCD hat)
; (c) 2024-2026 Carlos J. Santisteban
; last modified 20261121-1754

; assemble from root dir... xa modules/nanoboot.s
; add -DALONE for standalone version (otherwise module into boot.s, after sdboot.s/romboot.s)

#ifndef	ZACATECAS
#include	"zacatecas.h"
#endif

#ifndef	STDNMI
#define		STDNMI	panic
#endif

#ifdef ALONE
	*		= $F000			; skip I/O, just in case

rom_start:
; header ID
	.byt	0				; [0]=NUL, first magic number
	.asc	"dX"			; bootable ROM
	.asc	"****"			; reserved
	.byt	13				; [7]=NEWLINE, second magic number
; filename
	.asc	"nanoBoot v2.2b4", 0		; C-string with filename @ [8], max 220 chars
; optional C-string with comment after filename, filename+comment up to 220 chars
	.asc	"Zacatecas version", 0

; advance to end of header *** NEW format
	.dsb	rom_start + $E6 - *, $FF

; NEW library commit (user field 2)
	.asc	"$$$$$$$$"
; NEW main commit (user field 1)
	.asc	"$$$$$$$$"
; NEW coded version number
	.word	$2244			; 2.2b4		%vvvvrrrrsshhbbbb, where revision = %hhrrrr, ss = %00 (alpha), %01 (beta), %10 (RC), %11 (final)
; date & time in MS-DOS format at byte 248 ($F8)
	.word	$4EC0			; time, 17.54		%1000 1-110 110-0 0000
	.word	$5D75			; date, 2026/11/21	%0101 110-1 011-1 0101
; filesize in top 32 bits (@ $FC) now including header ** must be EVEN number of pages because of 512-byte sectors
	.word	$10000-rom_start			; filesize (rom_end is actually $10000)
	.word	0							; 64K space does not use upper 16 bits, [255]=NUL may be third magic number
#endif
; *** zeropage usage *** CHECK
	nb_ex	= $DC			; copy of initial address, or execution address (no longer $F8)
	nb_ptr	= nb_ex+2		; maybe F8? needs 5 bytes from there; initial address, will be used as pointer (will reuse for screen drawing)
	nb_end	= nb_ptr+2		; final address (consecutive) after downloaded chunk
	nb_type	= nb_end+2		; magic number at $E2 (note it might be defined elsewhere

; *******************
; *** actual code ***
; *******************
nb_start:
.(
	SEI						; just in case!
#ifdef	ALONE
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
	STY IFR					; and clear any previous interrupt (?)
	INY						; VIA should respond as all sources disabled ($80)
	CPY IER					; let's check for VIA presence
	BEQ continue
		JMP panic			; otherwise this is not Chihuahua, or something is very wrong
continue:
	LDA #%11000000			; make CB2 low to disable sound, rest as inputs (CA2 no longer high)
	STA PCR
	LDA #%01000000			; T1 free run (PB7 no toggle), no SR, no latch *** will be needed afterwards
	STA ACR
	LDX #>t1ct				; T1 interrupt speed
	LDY #<t1ct
	STY T1CL
	STX T1CH				; start counting!
;	LDY #<isr				; supplied ISR address *** not needed as nanoBoot handlers will be set
;	LDX #>isr
;	STY fw_irq				; set vector
;	STX fw_irq+1
;	LDY #<STDNMI			; same with (placeholder) NMI
;	LDX #>STDNMI
;	STY fw_nmi
;	STX fw_nmi+1
;	LDA #%11000000			; this far, only T1 interrupt is enabled
;	STA IER
	STZ fw_cbin				; standard (non-DLE) CONIO mode
	JSR l_lrst				; init screen (LLL call)
; as usual, holding LEFT during startup disables LCD backlight
	LDA IORA				; check keys (DIRECT input)
	EOR #$FF
	BIT #PAD_LT				; press LEFT to turn Backlight OFF
	BNE bl_off
		TAY					; preserve gamepad status, saving 1 byte
		LDA #LCD_LIGHT		; clear LCD_BL to turn *on* the light!
		TRB IORB
		TYA					; retrieve A
#endif
bl_off:
	LDA #%01111111			; disable ALL interrupt sources EEEEEEEEEEK
	STA IER
	STA IFR					; and clear any pending one, of course

; let's display some feedback
	LDA #LED_EMI			; keep Emilio's LED turned on
	TRB IORB
; * display nanoBoot banner *
	LDX #nb_banner-nb_msg	; reset offset
	JSR sb_loop				; and print selected message

; *** all inited, get ready for reception ***
nb_rdy:
	LDY #<nb_irq
	LDA #>nb_irq			; get receiver ISR address
	STY fw_irq
	STA fw_irq+1			; standard vector
	LDY #<nb_nmi
	LDA #>nb_nmi			; get receiver NMI address
	STY fw_nmi
	STA fw_nmi+1			; standard vector
; *** receive full preamble and set things accordingly ***
	LDY #4					; (2) max preamble offset
nh_rcv:
		LDX #8				; (2) prepare for next byte
nh_rby:
; inner loop is the best place for aborting
			PHY							; (3) eeek
			LDY IORA					; (4) get direct pad status
			CPY #(PAD_ST|PAD_SEL)^$FF	; (2) just both SELECT & START?
			BNE no_ab					; (3/2) nope, just continue EEEEK
				LDX #nb_abort-nb_msg
				BRA nb_disp			; tell the cause
no_ab:
			PLY				; (4) eeek
			CPX #0			; (2) how many bits remaining?
			BNE nh_rby		; (3/2) wait for complete byte
		STA nb_ptr, Y		; (5) store received byte
		DEY					; (2) next preamble byte (note reversed order)
		BPL nh_rcv			; (3/2) until all 40 bits done

; check preamble
	LDX nb_type				; (3) first of all, check for a valid magic number
	CPX #$4B				; (2) below $4B?
		BCC nb_error		; (2/3) if so, not valid
	CPX #$4F				; (2) above $4E?
		BCS nb_error		; (2/3) if so, not valid EEEEK
	CPX #$4C				; (2) ROM images not allowed
	BNE pre_ok
		JMP is_cart			; (2/3) report accordingly
pre_ok:
	LDY nb_ptr
	LDA nb_ptr+1			; (3+3) copy start address...
	STY nb_ex
	STA nb_ex+1				; (3+3) ...for future use
; *** fix for Zacatecas progress bar ***
	LDA nb_end+1			; (3) get last page EEEEEEEK
	STA end_pg				; (4) needed for progress bar EEEEK
	LDY nb_end				; (3) check LSB as well
	BEQ no_extra			; (3/2) in case of extra page
		INC end_pg
no_extra:
; display detected type
;	LDX nb_type
	TXA
	SEC
	SBC #9					; (2+2+2) turn $4B...$4E into 'B'...'E'
	JSR b_conio				; display type (BIOS call)
	JSR makebar				; prepare progress indicator
	LDY nb_ptr				; (3) retrieve base offset in Y
	STZ nb_ptr				; (3) clear offset, and we are ready!

; *** receive payload ***
nb_rcv:
		LDX #8				; (2) prepare for next byte
nb_rby:
			CPX #0			; (2) byte done?
			BNE nb_rby		; (3/2) wait for complete byte
		STA (nb_ptr), Y		; (6) store received byte
; ** toggle SD LED for feedback **
		LDA IORB			; (4) get LEDs' status
		EOR #SD_CS			; (2) toggle activity
		STA IORB			; (4) update LEDs
; continue load
		INY					; (2) next address
		BNE nb_nw			; (3/2) no wrap
			INC nb_ptr+1	; (5) or next page
;			LDX nb_ptr+1	; (3) but skip I/O!
;			CPX #$DF		; (2) is it IO page?
;			BNE no_io		; (3/2)
;				INC nb_ptr+1			; (5) skip it EEEEEEK
;no_io:
; may check for break key (inlined)
			LDA IORA					; (4) get direct pad status
			CMP #(PAD_ST|PAD_SEL)^$FF	; (2) both SELECT & START?
			BNE nb_cont					; (3/2) nope, just continue
;				BRA nb_error
; **********************************************************************
; *** if no valid magic number, make it PANIC by blinking like crazy ***
nb_error:
; draw some feedback
	LDX #err_msg-nb_msg		; preset offset (generic error message)
	BRA ne_cont				; stay on top line
nb_disp:					; *** expect message offset in X
	LDA #$C0				; start of bottom line eeek
	JSR l_lcmd				; set cursor
ne_cont:
	SEI
	LDY #<nb_rti			; (2+2) get null clock handler
	LDA #>nb_rti
	STY fw_nmi				; (3+3) redirect handler (might become simply STZ fw_nmi if aligned!)
	STA fw_nmi+1
	JSR sb_loop				; ...and print selected message
nb_panic:
	JMP panic				; blink like CRAZY!
; **********************************************************************
nb_cont:
; add some page feedback
			JSR progress	; generic call, should not affect Y
; check limits
nb_nw:
		CPY nb_end			; (3) already finished?
			BNE nb_rcv		; (3/2) no, get next byte
		LDA nb_ptr+1		; (3+3) check MSB too
		CMP nb_end+1
			BNE nb_rcv		; (3/2)
; *** transfer ended ***
	LDY #<nb_rti
	LDA #>nb_rti			; (2+2) set null NMI vector, just in case
	STY fw_nmi
	STA fw_nmi+1			; (4+4)
	LDY #<isr
	LDA #>isr				; (2+2) standard ISR, just in case
	STY fw_irq
	STA fw_irq+1			; (4+4) all clear for interrupts
	LDA #%11000000			; (2+4) enable T1
	STA IER					; *** should I reenable interrupts (CLI) as well? *** *** ***
	LDA #LED_EMI|SD_CS		; (2+6) all done, turn Emilio's LED _off_ (and activity, just in case)
	TSB IORB
; *** execute if possible ***
nb_exec:
	LDA nb_type				; (3) get magic byte
	CMP #$4B				; (2) legacy nanoBoot binary?
	BNE not_bin				; (3/2)
		JMP (nb_ex)			; (6) go for it!
not_bin:
	CMP #$4C				; (2) Durango ROM image? *** NOPE
	BNE not_cart			; (2/3)
; ROM images are NOT accepted
is_cart:
		LDX #nb_cart-nb_msg	; message index
		BRA nb_disp			; display and PANIC (no longer besides nb_error)
not_cart:
	CMP #$4D				; (2) generic data?
	BNE not_data			; (3/2)
		JMP bl_off			; (3) data already received, back to receiving mode
not_data:
	CMP #$4E				; (2) Pocket executable?
	BNE nb_bad				; (3/2) if not, bad byte *** should NEVER happen ***
; else, point to execution address in loaded file header EEEEEEK
		LDY #5				; (2) execution address offset
		LDA (nb_ex), Y		; (5) extract LSB from header
		STA nb_ptr			; (3) reuse this pointer for final indirect jump
		INY					; (2) go for MSB (offset 6)
		LDA (nb_ex), Y		; (5) extract MSB from header
		STA nb_ptr+1		; (3) indirect pointer is complete
		JMP (nb_ptr)		; (6) actual execution pointer is *pointed* here
nb_bad:
	BRA nb_error			; PANIC

; ************************
; *** feedback support ***
; ************************
; print message from selected offset
sb_loop:
		LDA nb_msg, X		; get char EEEEEK
	BEQ sb_exit				; until end
		JSR b_conio			; print it (BIOS call keeps all registers)
		INX					; next char
		BNE sb_loop			; no need for BRA
sb_exit:
	RTS
.)

; ***********************************
; *** nanoBoot interrupt handlers ***
; ***********************************
; *** SERCLK handler ***
nb_nmi:
; received bits should be LSB first!
	CLC						; bits are *OFF* by default (2)
	PHA						; preserve A, as ISR will change it! (3)
	CLI						; enable interrupts for a moment (2... plus 22)
; if /IRQ was low, ISR will *set* C, thus injecting a one
	SEI						; what happened? (2)
	PLA						; retrieve A, but C won't be affected (4)
	ROR						; inject C into byte, LSB first (2)
	DEX						; this will turn 0 when done, if preloaded with 8 (2)
nb_rti:
	RTI						; (6) total 23, plus 22 for ISR, plus 7 for ACK (worst 52)

; *** SERDAT handler ***
nb_irq:
; *** this modifies A (and stored P), thus PHA is needed on NMI for proper operation ***
; since this has to set I flag anyway, clear stored C as received bit value
	PLA						; saved status... (4)
	ORA #%00000101			; ...now with I set *AND* C set (2)
	PHA						; restore all (A changed) (3)
	RTI						; (6) whole routine takes only 15 clocks, plus acknowledge (total 22)

; ********************
; *** data section ***
; ********************
; * feedback messages thru CONIO *
nb_msg:						; base address
nb_banner:
	.asc	"nanoBoot? ", 0				; standard banner
nb_cart:
	.asc	" * CARTRIDGE! *", 0		; ROM images NOT accepted
nb_abort:
	.asc	" ### Aborted ###", 0		; BREAK combo

err_msg:
	.asc	"FAIL!", 0					; generic error message

nb_code_end:
; *******************************************************
; *** end of module, start of required firmware ahead ***
; *******************************************************
#ifdef	ALONE
#include "modules/basic_isr.s"

; **************************
; *** BIOS/LLL functions ***
; **************************
#include	"bios.s"
#include	"lll.s"
; *** progress bar module ***
#ifndef	PROGRESS
#include "modules/progress.s"
#endif

fw_end:

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
	.word	nb_start
	.word	IRQ_handler
.)
#endif

