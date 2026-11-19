; Zacatecas SD bootloader
; based on v2.1.11 with volume-into-FAT32
; (c) 2023-2026 Carlos J. Santisteban
; based on code from http://www.rjhcoding.com/avrc-sd-interface-1.php and https://en.wikipedia.org/wiki/Serial_Peripheral_Interface
; last modified 20261119-1042

#ifndef	ZACATECAS
#include	"zacatecas.h"
#endif

; flags for convenience, note they're fixed b/c of the use of BIT instruction
#define	CACH_EN		%01000000
#define	DISP_EN		%10000000

; offsets for (non-fatal) messages
#define	SDSPLASH	sd_splash-sd_msg
#define	

; *****************
; *** RAM usage ***
; *****************
; *** directory storage ***
en_tab		= $800			; now taking all available RAM, will need indirect-indexed (32-byte entries)
-end_pg		= $300			; originally at buffer+255, no longer the ugly hack... *** CHECK

; **************************
; *** SD-card bootloader ***
; **************************
sd_main:
.(
	LDX #SPLASH
	JSR disp_code			; display splash screen while mounting SD
; check SD type for display *** TBD
; SD device driver is fixed, proceed to check for SD card as usual
sd_selected:
	JSR b_dini				; check SD card (BIOS call)
	BCC is_ok				; continue if succeeded
		JMP err_code		; display error with buzz... and go away
is_ok:
; first sector *in volume* is already read!
	STZ en_ix				; reset index
	STZ cur_ix				; same with cursor
	LDA #CACH_EN			; disable display, enable caching
	STA flags
	STA old_c				; any non-zero value will display first entry when available
	BRA header_see			; because it's already loaded! perhaps checked too, but check it anyway
; *** main loop ***
ls_disp:
		BIT flags			; is caching enabled?
		BVC no_cache
; * load current sector and cache entry, if possible *
; ...unless it's the very first
			LDX #>buffer	; temporary load address
			STX ptr+1
;			STZ ptr			; assume buffer is page-aligned
			JSR b_rblk		; read one 512-byte sector
; might do some error check here...
header_see:
			JSR chk_head	; look for a valid header
		BCC header_ok
			LDA #CACH_EN
			TRB flags		; if not, that's the end of the volume, thus stop caching
			LDA en_ix		; has any entry been recorded?
		BNE no_cache		; already some, just let the user select one
			LDX #NON_EXEC	; otherwise it's an invalid card
			JMP switch_dev	; go away
header_ok:
; header is valid, check whether bootable or not
			LDA bootsig		; check Pocket signature
			CMP #'p'
		BNE next_file
chk_exec:
			LDA bootsig+1
;			ORA #2			; OPTIONAL *** this will allow Durango executables as well (pX/pZ)
			CMP #'Z'
		BNE next_file		; ignore generic files or Durango executables
; * executable detected, register sector and store filename *
			LDA en_ix		; first empty entry
			JSR ix2tab		; create pointer to that
			LDY #3			; max sector offset
en_loop:
				LDA arg, Y				; current sector (big endian)
				STA (ptr), Y			; store locally (keeps endianness)
				DEY
				BPL en_loop				; complete four bytes
; now for the name
			LDY #4			; we must skip the stored sector number
en_name:
				LDA fname-4, Y			; note offset as we already copied the sector number
				STA (ptr), Y			; store entry, even if it's NULL
			BEQ enam_ex					; but exit afterwards
				INY
				CPY #32					; already at the limit?
				BNE en_name				; if not, keep copying
enam_ex:
			LDA en_ix		; was this the very first entry?
			BNE not_first
				LDA #DISP_EN
				TSB flags	; enable display
not_first:
			INC en_ix		; one more entry has been detected
			CMP #255		; max. 255 entries for this implementation
			BNE next_file
				LDA #$C0	; first char of second line
				JSR l_lcmd	; send command (set DDRAM address)
				LDA #'!'
				JSR l_ldat	; direct print on LCD
				LDA #CACH_EN
				TRB flags	; disable caching
next_file:
; compute next header sector
			JSR next_sector
no_cache:
		BIT flags
		BMI ls_disp			; if display is not enabled, keep caching
; * display selection *
; manage keypad
			JSR b_pad		; BIOS call, updated keypad
			BCS no_key		; something new pressed?
				BIT #PAD_DN				; next entry
			BEQ no_down
					LDA cur_ix			; unless we're at the last one
					CMP en_ix
				BCS offlimits			; complain a bit if so
					INC cur_ix			; next entry otherwise
					BRA no_key
no_down:
				BIT #PAD_UP				; previous entry?
			BEQ no_up
					LDA cur_ix			; unless we're at the first one
					BNE do_up
offlimits:
						LDA #7			; complain a bit if so
						JSR b_conio		; BIOS call for BEL
						BRA no_key
do_up:
					DEC cur_ix			; just set cursor to previous entry
					BRA no_key
no_up:
				BIT #PAD_SEL			; discard SD?
			BEQ no_sel
					LDX #ABORT
					JMP switch_dev		; go away if so ****ERR
no_sel:
				BIT #PAD_A|PAD_ST		; finally, should execute?
					BNE do_boot			; if so, let's go!
no_key:
; print selected filename, if changed
			LDA cur_ix		; get current selection index
			CMP old_c		; has it changed?
		BNE no_disp
			STA old_c		; eeek
			JSR ix2tab		; create pointer to index
			LDA #0			; first char top line
			JSR l_lcmd		; send command (set DDRAM address)
			LDY #4			; first char after sector number
name_loop:
				LDA (ptr), Y			; get char
			BEQ name_end				; until terminator
				JSR l_ldat				; direct print
				INY
				CPY #20					; 4+16 chars per line
			BNE name_loop				; no need for BRA
				LDA (ptr), Y			; already at terminator?
			BEQ no_disp					; no need for anything else
				LDA #15		; otherwise, go to last char on top line
				JSR l_lcmd	; send command (set DDRAM address)
				LDA #'>'	; no room for the full name
				JSR l_ldat	; direct print
			BRA no_disp		; print is done
name_end:
				LDA #' '	; usually put trailing spaces
				JSR l_ldat	; direct print
				INY
				CPY #20		; until end of line
				BNE name_end
no_disp:
		JMP ls_disp

; ******************************************
; *** file is selected, now boot from it ***
; ******************************************
do_boot:
	SEI						; no more interaction needed, slight performance improvement.
; reload sector of selected entry into buffer
	LDX #>buffer			; temporary load address
	STX ptr+1
;	STZ ptr					; assume buffer is page-aligned
	JSR b_rblk				; read first 512-byte sector of the file (will be read again)
; check size being pZ format, begin from specified address AND end as required
	LDA ld_addr+1			; * get load address from header
	TAX						; * and save for later
	CLC						; *
	ADC fsize+1				; * add number of pages
	LDY fsize				; * but check LSB (size not necessarily page-aligned)
	BEQ all_pg				; * if zero, already OK
		INC					; * otherwise fill last page
all_pg:						; *
	BIT #1					; * pocket images may have odd number of pages EEEEK
	BEQ ev_pg				; * even page is sector-aligned
		INC					; * make it even otherwise
ev_pg:						; *
	STA end_pg				; * store end page
; no ROM images allowed
set_ptr:
	STX ptr+1
	STZ ptr					; definitive pointer is ready, proceed with load!
	JSR makebar				; X is first page (at ptr+1), A is page after last (at end_pg), draw progress bar accordingly
boot:
		JSR b_rblk			; read one 512-byte sector
; might do some error check here...
		JSR chk_brk			; ** check for BREAK key
			BCS abort		; ** if pressed, go for next interface (built-in ROM or nanoBoot)
		JSR progress
		INC arg+3			; EEEEEEEEK endianness!
		BNE no_wrap
			INC arg+2		; now could have several images, may wrap...
		BNE no_wrap
			INC arg+1		; now could have several images, may wrap...
		BNE no_wrap
			INC arg			; now could have several images, may wrap...
no_wrap:
		LDA ptr+1			; check current page
		CMP end_pg			; this is usually zero... unless it's a screenshot!
		BNE boot			; until completion
	JMP (ex_addr)			; * run from specified address (from preloaded header)
; if load was interrupted, switch device
abort:
	LDX #ABORT				; ****ERR
	BRA switch_dev
; ***************************
; *** standard exit point ***
; ***************************
sd_fail:					; SD card failed
	LDX #FAIL_MSG			; FAIL message****
switch_dev:
	JMP err_code			; display and buzz, try with default ROM, or nanoBoot instead -- but not here!

; ********************************
; *** some high-level routines ***
; ********************************
chk_head:
; * look for a valid header * assume sector loaded at buffer
	LDA magic1				; check magic number one
		BNE not_magic 
	LDA magic2				; check magic number two
	CMP #13					; must be NEWL instead of zero
		BNE not_magic
	LDA magic3				; check magic number three
		BNE not_magic
	CLC						; report no error, header is valid
	RTS
not_magic:
		SEC					; otherwise header is not valid
		RTS

chk_brk:
; * check for SELECT+START buttons (BREAK) *
	JSR l_pad				; check instant pad status
	CMP #(PAD_SEL|PAD_ST)	; check for SELECT + START eeek
	BNE no_break
		SEC
		RTS					; notify BREAK and return
no_break:
	CLC
	RTS						; no break, continue as usual

next_sector:
; * advance to next sector according to filesize *
; first, convert size into number of sectors
	LDX fsize		; any padding used?
	BEQ full_pg
		INC fsize+1			; if so, count as one more page
		BNE full_pg			; ** eeeeeek
			INC fsize+2		; ** now supporting up to 16M headers!
full_pg:
	LSR fsize+2		; **
	ROR fsize+1		; half the number of sectors...
	BCC below64
		INC fsize+1	; ...unless it was odd
	BNE below64		; **
		INC fsize+2	; **
below64:
	CLC				; EEEEEEEEEEEEEEEEEEEEEEEEEEEEK
	LDA fsize+1
	ADC arg+3		; add to current sector, note big-endian!
	STA arg+3
	LDA fsize+2		; **
	ADC arg+2
	STA arg+2
	LDA #0			; no files over 16 MiB! eeeek
	ADC arg+1		; propagate carry, just in case
	STA arg+1
	BCC sec_ok
		INC arg
sec_ok:
	RTS

ix2tab:
; * convert index in A to address for en_tab at ptr *
	STA ptr			; store as LSB (will be shifted)
	LDA #0			; clear MSB, will add base later (assume page-aligned)
	ASL ptr
	ROL
	ASL ptr
	ROL
	ASL ptr
	ROL
	ASL ptr
	ROL
	ASL ptr			; 32-byte entries (4 for LBA, 28 for name)
	ROL
	CLC
	ADC #>en_tab	; add base address
	STA ptr+1		; pointer is complete
	RTS


; ************************
; *** support routines ***
; ************************
; *** display generic message ***
disp_code:
		LDA sd_msg, X		; get char
	BEQ dc_end				; message ended
		JSR b_conio			; display char (BIOS call keeps all registers)
		INX
		BNE disp_code		; next char
dc_end:

; *** buzzing error code display *** no return
err_code:
; display error message
	LDX sdix_tab, Y			; reindex
ec_loop:		
		LDA err_msg, X		; get char
	BEQ ec_end				; message ended
		JSR b_conio			; display char (BIOS call keeps all registers)
		INX
		BNE ec_loop			; next char
ec_end:
	LDX #sd_err-sd_msg		; generic error
	JSR disp_code			; display it...
;	JMP long_buzz			; ...and buzz
long_buzz:
	LDA #%11100000			; this will set CB2 high (enable sound)
	TSB PCR
	LDA ACR					; previous state of ACR
	PHA						; keep it just in case
	ORA #%11000000			; T1 continuous interrupts, PB7 square wave
	STA ACR					; start buzzing
	LDA ticks				; get ticks LSB
	SBC #5					; about 1 second delay (don't care about C)
	PHP
	CLI						; just in case...
lb_wait:
		CMP ticks			; wait for next second
		BNE lb_wait
	PLP						; back to previous interrupt status
	PLA
	STA ACR					; restore ACR
	LDA #%00100000			; was %111xxxxx, TRB will turn into %110xxxxx
	TRB PCR
	BRA end_sd				; EXIT, no return!
.)
; *** progress bar module ***
#ifndef	PROGRESS
#include "modules/progress.s"
#endif

; ********************
; *** diverse data *** CHECK
; ********************
; interface messages *** CHECK
sd_msg:
sd_splash:
	.asc	"SD ", 0
sd_old:
	.asc	"1.x"			; any chance?
sd_next:
	.asc	12, "      ...       ", 13, " U/D (Se) [St/A]", 0	; *** CHECK
sd_err:
	.asc	" FAIL!", 0

; error messages for SD init (reindexed)
err_msg:
sd_ok:
	.asc	"OK", 7, 0		; just for completeness, with short beep, may be indexed from sd_msg
sd_idle:
	.asc	"IDLE", 0
sd_sdif:
	.asc	"SD I/F", 0
sd_inierr:
	.asc	"INIT", 0
sd_rdy:
	.asc	"READY", 0
sd_hc:
	.asc	"HC/XC"		; ### special prefix if CCS=1 ### will be indexed from sd_msg instead
mbr_ptype:
	.asc	"MBRpt", 0
mbr_bsig:
	.asc	"MBRbs", 0
vbr_jump:
	.asc	"VBRji", 0
bpb_media:
	.asc	"BPB2mt", 0
bpb_extbs:
	.asc	"BPB7ebs", 0
bpb_bps:
	.asc	"BPB2bps", 0
sd_abort:
	.asc	" ### Aborted ###", 0
sd_vol:
	.asc	"STORAGE.AV", 0
; some generic fatal errors as well
sd_noex:
	.asc	"NO EXEC", 0

; *** offsets for error codes ***
sdix_tab:
	.byt	sd_ok-err_msg		; SD_OK
	.byt	sd_idle-err_msg		; IDLE_ERR
	.byt	sd_sdif-err_msg		; SDIF_ERR
	.byt	sd_inierr-err_msg	; INIT_ERR
	.byt	sd_rdy-err_msg		; READY_ERR
	.byt	sd_hc-err_msg		; HC_XC
	.byt	mbr_ptype-err_msg	; MBR_PTYP
	.byt	mbr_bsig-err_msg	; MBR_BSIG
	.byt	vbr_jump-err_msg	; VBR_JUMP
	.byt	bpb_media-err_msg	; BPB_MEDIA
	.byt	bpb_extbs-err_msg	; BPB_EXTBS
	.byt	bpb_bps-err_msg		; BPB_BPS
	.byt	sd_abort-err_msg	; FAT_ABORT
	.byt	sd_vol-err_msg		; FAT_NOVOL
	.byt	sd_noex-err_msg		; NON_EXEC, actually from SD bootloader interface
end_sd:
