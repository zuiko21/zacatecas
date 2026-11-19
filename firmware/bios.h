; definitions for Zacatecas BIOS
; (c) 2026 Carlos J. Santisteban
; last modified 20261119-1333

; ************************************
; *** *** SD STORAGE FUNCTIONS *** ***
; ************************************
; *** *** SD interface constants *** ***
#define	CMD0		0
#define	CMD0_CRC	$94
#define	CMD8		8
#define	CMD8_ARG	$01AA
#define	CMD8_CRC	$86
#define	CMD16		16
#define	CMD16_ARG	$0200
#define	ACMD41		41
#define	ACMD41_ARG	$40
#define	CMD55		55
#define	CMD58		58

#define	CMD17		17
#define	SD_MAX_READ_ATTEMPTS	203

#define	CMD24		24
#define	SD_MAX_WRITE_ATTEMPTS	254

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
; some generic SD error codes
#define	NON_EXEC	14
; ****************************

; *** memory usage *** CHECK
dev_id	= $EA		; $EB 1...4=SPI, 241=devCart, 0=RasPi; will turn into '0...3' and ' ' (and '/') for display
crc		= dev_id+ 1	; $EC
en_ix	= crc	+ 1	; $ED ### directory storage ###
sd_ver	= en_ix	+ 1 ; $EE ### not so temporary ###
arg		= sd_ver+ 1	; $F0-$F3
res		= arg	+ 4	; $F4-$F8
mosi	= res	+ 5	; $F9
miso	= mosi	+ 1	; $FA
token	= miso	+ 1	; $FB
ptr		= token	+ 1	; $FC-$FD
cnt		= ptr	+ 2	; $FE
tmpba	= cnt	- 1	; actually $FE-$FF, as $FD will NOT be used
