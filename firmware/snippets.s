; Test code for Zacatecas SBC
; (c) 2026 Carlos J. Santisteban

; *** send byte in A to LCD ***
; *** C=1 for data, C=0 for commands ***

	PHP					; save C for later
	PHA					; save low nybble
	AND #$F0			; send high nybble first
	JSR send_nyb
	PLA					; retrieve full byte...
	LSR
	LSR
	LSR
	LSR					; ...just for the low nybble
	PLP					; and back to RS in C
send_nyb:
	ADC #0				; set PA0 according to RS
	STA IORA			; send nybble+RS
	LDA IORB			; check current status
	ORA #LCD_EN			; set E bit
	STA IORB			; pulse E output
	AND #LCD_DIS		; clear E bit
	STA IORB
	RTS
