; definitions for Zacatecas BIOS
; (c) 2026 Carlos J. Santisteban
; last modified 20261119-1223

; ************************************
; *** *** SD STORAGE FUNCTIONS *** ***
; ************************************
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
