; ***************************************
; *** Low Level Library for Zacatecas ***
; ***************************************
; (c) 2026 Carlos J. Santisteban
; last modified 20261125-1407

; *** read current pad value (active-high) ***
raw_pad:
	LDA IORA				; current value
	EOR #$FF				; make active-high
	RTS

; *** initialise LCD ***
; assume VIA is set
LCD_reset:
	LDY #15
	JSR delay_ms			; 15 mS delay
	PHP						; proper way
	SEI						; cannot share PA with buttons!
	DEC DDRA				; all outputs, but risky...
	LDX #%00110000			; FC=3
	STX IORA
	JSR LCD_pulse			; just pulse E, no need for speed
	LDY #5
	JSR delay_ms			; more than 4.1 mS
	JSR LCD_pulse			; another E
	LDX #20					; times 5, at least 100 µs delay
	JSR delay_5x
	JSR LCD_pulse			; pulse E for a third time
	LDX #7					; times 5 is 35 µs, with overhead is well beyond 37
	JSR delay_5x
	LDX #%00100000			; FC=2 for 4-bit mode
	STX IORA
	JSR LCD_pulse			; last command sent in 8-bit mode
	LDA #%00101011			; 4-bit interface, 2 lines, 5x8 font
	JSR LCD_command
	LDA #%00001100			; display ON! eeeek
	JSR LCD_command
	LDA #%00000001			; display clear
	JSR LCD_command
	PLP						; this might reenable interrupts after basic init
	LDY #5
	JSR delay_ms			; wait at least 5 mS, maybe 1.5?
	LDA #%00000110			; entry mode set, increment, no shift
	JMP LCD_command			; send and return

; *** send byte in A to LCD *** affects A
; * send A as command *
LCD_command:
	CLC						; commands will be less frequent, thus slower
	BRA send_LCD
; * send A as data *
LCD_data:
	SEC						; fastest data sending
; *** C=1 for data, C=0 for commands *** note separate entry points
send_LCD:
	PHP						; in case interrupts were masked
	SEI						; we must keep PA as output, but ISR expects it to be input all the time!
	DEC DDRA				; now $FF... if a bit risky
	JSR send_byte			; no way for further optimisation
	STZ DDRA				; PA goes back to input
	PLP						; and return with interrupts on, if previously enabled!
	; *** might need to add some safe delay here *** theoretically needs NONE at 1 MHz (takes more than 37 µs)
	RTS
; actual sending of byte in A to LCD, C goes to RS as before
send_byte:
	PHP						; save C for later
	PHA						; save low nybble
	AND #$F0				; send high nybble first
	JSR send_nyb
	PLA						; retrieve full byte...
	ASL
	ASL
	ASL
	ASL						; ...just for the low nybble EEEEK
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

; TO DO *** TO DO ** TO DO

; ************************
; *** support routines ***
; ************************
; pulse E on LCD (affects A)
LCD_pulse:
	LDA IORB				; get previous status
	ORA #LCD_EN				; set E bit
	STA IORB
	AND #LCD_DIS			; E off
	STA IORB
	RTS

; wait for 5·X µS (destroys X, Y)
delay_5x:
	LDY #1					; trick for single iteration of external loop
	BNE delay_loop			; could use BRA as well

; wait for mS in Y (destroys X, Y)
delay_ms:
		LDX #200			; 200 x 5t ≈ 1 mS
delay_loop:
			DEX
			BNE delay_loop
		DEY					; another millisecond?
		BNE delay_ms
	RTS
