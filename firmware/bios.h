; definitions for Zacatecas BIOS
; (c) 2026 Carlos J. Santisteban
; last modified 20261126-0944

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
#define	ECHO_ERR	3
#define	INIT_ERR	4
#define	READY_ERR	5
; OLD_SD/HC_XC not actually errors, should write these values anywhere
#define	OLD_SD		6
#define	HC_XC		7
; FAT32 specific errors (non-fatal, thus seldom used if any)
#define MBR_PTYP	8
#define	MBR_BSIG	9
; FAT32 fatal errors
#define	VBR_JUMP	10
#define	BPB_MEDIA	11
#define	BPB_EXTBS	12
#define	BPB_BPS		13
#define	FAT_ABORT	14
#define	FAT_NOVOL	15
; some generic SD error codes
#define	NON_EXEC	16
; ****************************

; *** memory usage *** CHECK
cnt			= $E7			; directory sector counter
tmpba		= cnt			; $E7-$E8, generic use
sec_clus	= cnt		+ 1	; number of sectors per cluster $E8
dir_clus	= sec_clus	+ 1	; first cluster of directory (needed for subtract) $E9-$EC
token		= dir_clus	+ 4	; $ED
mosi		= token		+ 1	; $EE convenient
miso		= mosi		+ 1	; $EF convenient
res			= miso		+ 1	; $F0-$F4
crc			= res		+ 5	; $F5
;arg		= crc		+ 1	; $F6-$F9
;ptr		= arg		+ 4	; $FA-$FB needed
