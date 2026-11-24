; *****************************
; *** Zacatecas definitions ***
; *****************************
; Last modified 20261124-0824

; *** *** ******************** *** ***
; *** *** hardware definitions *** ***
; *** *** ******************** *** ***

#ifndef	SPEED
#define		SPEED	1000000
#endif

; define VIA T1 values for standard 250 Hz interrupt
#define		t1ct	((SPEED/250)-2)

; *** memory map ***
; VIA registers
#define	IORB	$BFF0
#define	IORA	$BFF1
#define	DDRB	$BFF2
#define	DDRA	$BFF3
#define	T1CL	$BFF4
#define	T1CH	$BFF5
#define	T1LL	$BFF6
#define	T1LH	$BFF7
#define	T2CL	$BFF8
#define	T2CH	$BFF9
#define	VSR		$BFFA
#define	ACR		$BFFB
#define	PCR		$BFFC
#define	IFR		$BFFD
#define	IER		$BFFE
#define	NHRA	$BFFF

; *** Zacatecas pin assignments ***
; key pad at PA0...PA7, all active LOW
#define		PAD_RT		%00000001
#define		PAD_DN		%00000010
#define		PAD_LT		%00000100
#define		PAD_UP		%00001000
#define		PAD_SEL		%00010000
#define		PAD_B		%00100000
#define		PAD_ST		%01000000
#define		PAD_A		%10000000

; LCD data at PA4...PA7, RS at PA0
#define		LCD_RS		%00000001
#define		LCD_DATA	%11110000

; SD interface at PB0...PB3, CS is active LOW (lights activity LED as well)
#define		SD_EN		%11110111
#define		SD_DIS		%00001000
#define		SD_CS		%00001000
#define		SD_MISO		%00000100
#define		SD_MOSI		%00000010
#define		SD_CLK		%00000001

; LCD at PB4...PB5, BackLight is active LOW
#define		LCD_BLON	%11011111
#define		LCD_BLOFF	%00100000
#define		LCD_LIGHT	%00100000
#define		LCD_EN		%00010000
#define		LCD_DIS		%11101111

; Emilio's LED at PB6, active LOW
#define		LED_ON		%10111111
#define		LED_OFF		%01000000
#define		LED_EMI		%01000000

; *** *** ************ *** ***
; *** *** memory usage *** ***
; *** *** ************ *** ***

; *** standard globals *** same as Durango
#define	fw_irq		$0200
#define	fw_nmi		$0202
#define	ticks		$0206
; DLE mode for CONIO
#define	fw_cbin		$0210
; cursor address into DDRAM (1 byte)
#define	fw_ciop		$021D
; flag D7=cursor ON
#define	fw_scur		$0222
#define	gamepad		$0226

; *** storage globals *** CHECK * CHECK * CHECK
#define	sd_ver		$03FB
; mount point (BIG endian like arg) $3FC..$3FF
#define	mnt_point	$3FC

; * sector buffer and offsets *
; could create a second buffer by adding +$0200
#define	buffer		$0400
; magic numbers must be 0, 13 and 0 (assume filesize < 16 MiB)
#define	magic1		$0400
#define	magic2		$0407
#define	magic3		$04FF
; must contain 'dX' for bootable ROM images, 'dA' for generic files, 'dL' for free space, 'pZ' for regular executables
#define	bootsig		$0401
; load address for Pocket format, '**' otherwise
#define	ld_addr		$0403		
; execution address for Pocket format, '**' otherwise
#define	ex_addr		$0405
; NUL-terminated filename, then NUL-terminated comment (before +$E6)
#define	fname		$0408
; date and time in MS-DOS format
#define	ftime		$04F8	
#define	fdate		$04FA
; file size INCLUDING 256-byte header
#define	fsize		$04FC	

; *** *** ****************** *** ***
; *** *** software interface *** ***
; *** *** ****************** *** ***

; *** zeropage usage *** FOR PARAMETERS ONLY, local variables go into their respective .h files

; CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK ***
; CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK *** CHECK ***

; CONIO zeropage usage ($E4-$E7) *** CHECK
cio_src	= $E4
cio_pt	= cio_src+2	; $E6-$E7

; SD loader usage ($E8-$EB)
cur_ix	= $E8		; $E8 ### directory position ### new, 8-bit so far
old_c	= cur_ix+ 1	; $E9
en_ix	= old_c	+ 1	; $EA ### directory storage ### 8-bit so far
flags	= en_ix	+ 1 ; $EB flags to enable caching (D6) and display (D7)

end_pg		= $3F5			; *** *** *** CHECK

