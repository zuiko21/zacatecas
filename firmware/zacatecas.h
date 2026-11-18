; **************************************
; *** Zacatecas hardware definitions ***
; **************************************
; Last modified 20261118-1302

#ifndef	SPEED
#define		SPEED	1000000
#endif

	VIA		= $BFF0			; EEEEEEEEEEEEEEEEEEEEEEEEEEK
	t1ct	= (SPEED/250)-2	; 250 Hz interrupt at 1 MHz (or whatever) clock rate

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
	fw_cbin	= $0210			; DLE mode
	fw_ciop	= $021D			; cursor address into DDRAM (1 byte)
	fw_scur	= $0222			; flag D7=cursor ON
	gamepad	= $0226

; ****************************
; *** *** SD card BIOS *** *** CHECK
; *** mount point  *** NEW for FAT32 support($2E8-$2F1)
ds_cnt		= $2E8			; directory sector counter, unfortunately no longer in ZP ($2E8)
cnt			= ds_cnt		; *** *** DEBUG USE *** ***
sec_clus	= ds_cnt+1		; number of sectors per cluster $2E9
dir_clus	= sec_clus+1	; first cluster of directory (needed for subtract) $2EA
mnt_point	= dir_clus+4	; mount point (BIG endian like arg) $2EE..$2F1

; *** sector buffer and header pointers ***
tmp_siz		= $2FA			; $2FA-$2FB top 16 bits of temporary size for remaining free block (max. 16M)
hd_cache	= tmp_siz+2		; $2FC-$2FF current header sector position (big-endian)
buffer		= $300
magic1		= buffer+0		; must contain zero
magic2		= buffer+7		; must contain CR (13)
magic3		= buffer+255	; must contain zero (assume filesize < 16 MiB)
bootsig		= buffer+1		; must contain 'dX' for bootable ROM images, 'dA' for generic files, 'dL' for free space, 'pZ' for regular executables
fname		= buffer+8
ftime		= buffer+248	; time in MS-DOS format
fdate		= buffer+250	; date in MS-DOS format
fsize		= buffer+252	; file size INCLUDING 256-byte header

; *** *** SD ERROR CODES  *** ***
#define	SD_OK		0
#define	IDLE_ERR	1
#define	SDIF_ERR	2
#define	INIT_ERR	3
#define	READY_ERR	4
; HC_XC not actually an error, should write this value anywhere
#define	HC_XC		5
; FAT32 specific errors (non-fatal, thus seldom used if any)
#define MBR_PTYP	6
#define	MBR_BSIG	7
; FAT32 fatal errors
#define	VBR_JUMP	8
#define	BPB_MEDIA	9
#define	BPB_EXTBS	10
#define	BPB_BPS		11
#define	FAT_ABORT	12
#define	FAT_NOVOL	13
; ****************************

