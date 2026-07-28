; **************************************
; *** Zacatecas hardware definitions ***
; **************************************
#ifndef	SPEED
#define		SPEED	1000000
#endif

; LCD at PB4...PB5, BL is active LOW
#define		LCD_BLON	%11011111
#define		LCD_BLOFF	%00100000
#define		LCD_EN		%00010000
#define		LCD_DIS		%11101111

; LCD data at PA4...PA7, RS at PA0
#define		LCD_RS		%00000001
#define		LCD_DATA	%11110000

; SD interface at PB0...PB3, CS is active LOW
#define		SD_EN		%11110111
#define		SD_DIS		%00001000
#define		SD_MISO		%00000100
#define		SD_MOSI		%00000010
#define		SD_CLK		%00000001

; Emilio's LED at PB6, active LOW
#define		LED_ON		%10111111
#define		LED_OFF		%01000000

; key pad at PA0...PA7, all active LOW
#define		PAD_RT		%00000001
#define		PAD_DN		%00000010
#define		PAD_LT		%00000100
#define		PAD_UP		%00001000
#define		PAD_SEL		%00010000
#define		PAD_B		%00100000
#define		PAD_ST		%01000000
#define		PAD_A		%10000000

; *** VIA constants ***
#define	IORB	VIA+0
#define	IORA	VIA+1
#define	DDRB	VIA+2
#define	DDRA	VIA+3
#define	T1CL	VIA+4
#define	T1CH	VIA+5
#define	T1LL	VIA+6
#define	T1LH	VIA+7
#define	T2CL	VIA+8
#define	T2CH	VIA+9
#define	VSR		VIA+10
#define	ACR		VIA+11
#define	PCR		VIA+12
#define	IFR		VIA+13
#define	IER		VIA+14
#define	NHRA	VIA+15

; ****************************
; *** standard definitions ***
	fw_irq	= $0200
	fw_nmi	= $0202
	ticks	= $0206
	gamepad	= $0226
	VIA		= $BFF0			; EEEEEEEEEEEEEEEEEEEEEEEEEEK
	
	t1ct	= (SPEED/250)-2	; 250 Hz interrupt at 1 MHz (or whatever) clock rate
; ****************************
