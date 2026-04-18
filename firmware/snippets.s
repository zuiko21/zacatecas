; Test code for Zacatecas SBC
; (c) 2026 Carlos J. Santisteban

	t1ct	= (SPEED/250)-2	; 250 Hz interrupt at 1 MHz (or whatever) clock rate

* = $C000					; standard 16K ROM

; some header would be nice here, for the sake of it...

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
	SEI						; we must keep PA as output, but ISR expects it to be input all the time!
send_LCD:
	DEC DDRA				; now $FF... if a bit risky
	JSR send_byte			; no way for further optimisation
	STZ DDRA				; PA goes back to input
	CLI						; and return with interrupts on
	; *** might need to add some safe delay here ***
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
