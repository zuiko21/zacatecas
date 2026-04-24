; **************************************
; *** Zacatecas hardware definitions ***
; **************************************
#ifndef	SPEED
#define		SPEED	1000000
#endif

#define		LCD_BLON	%11011111
#define		LCD_EN		%00010000
#define		LCD_DIS		%11101111

; *** VIA constants ***
#define	IORB	0
#define	IORA	1
#define	DDRB	2
#define	DDRA	3
#define	T1CL	4
#define	T1CH	5
#define	T1LL	6
#define	T1LH	7
#define	T2CL	8
#define	T2CH	9
#define	VSR		10
#define	ACR		11
#define	PCR		12
#define	IFR		13
#define	IER		14
#define	NHRA	15

; ****************************
; *** standard definitions ***
	fw_irq	= $0200
	fw_nmi	= $0202
	jiffy	= $0206
	
	t1ct	= (SPEED/250)-2	; 250 Hz interrupt at 1 MHz (or whatever) clock rate
; ****************************
