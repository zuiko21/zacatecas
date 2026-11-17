; ******************************
; *** miniBIOS for Zacatecas *** v0.1a2
; ******************************
; (c) 2026 Carlos J. Santisteban
; last modified 20261117-1050

; *** CONIO ***
; display char in A, unless 0 > return key in A and C=0 if pressed, otherwise C=1 
conio:
	PHA
	PHX
	PHY						; save all registers, just in case *** check
; should check if in DLE mode *** TO DO
	TAY						; check parameter
	BEQ c_in				; input if zero
		CPY #12				; is it FF?
		BNE no_ff
			LDA #1			; CLEAR DISPLAY
			JSR l_lcmd
			STZ fw_ciop		; reset cursor position
			LDY #2
			JSR delay_ms	; wait for a couple mS (at least 1.52) *** actually inside LLL
			BRA cio_exit
no_ff:
		CPY #13				; is it CR?
		BNE no_cr
			LDA fw_ciop		; get previous position
			AND #%01000000	; just keep D6 (row) as CR
			EOR #%01000000	; TOGGLE row as implicit LF
			ORA #%10000000	; set D7 for command (Set DDRAM address)
			STA fw_ciop		; save for later
			TAY
			JSR l_lcmd		; send command
			LDA #' '		; will clear next line
			LDX #16			; chars per line
cl2end:
				JSR l_ldat	; direct space print
				DEX			; until line is full
				BNE cl2end
			TYA				; retrieve position
			JSR l_lcmd		; send command (back to line start)
			BRA cio_exit
no_cr:
		CPY #1				; is it CR-without-LF?
		BNE no_cwl
			LDA fw_ciop		; get previous cursor
			AND #%01000000	; just keep D6 (row) as CR... without toggling it
			ORA #%10000000	; set D7 for command (Set DDRAM address)
set_cur:
			STA fw_ciop		; save for later
			TAY
			JSR l_lcmd		; send command
			BRA cio_exit
no_cwl:
		CPY #21				; is it home?
		BNE no_home
			LDA #%10000000	; command and null position (Set DDRAM address)
			BRA set_cur		; and issue new position
no_home:
		CPY #7				; is it bell?
		BNE no_bell
; short beep, set IRQ frequency to 2 kHz and wait 255 ticks (almost 1/8 second)
			PHP				; just in case...
			CLI				; interrupts MUST be on!
			LDY #<(t1ct/8)
			LDA #>(t1ct/8)	; will sound at 1 kHz
			STY T1CL
			STA T1CH		; set T1 speed
			LDA #%11100000	; this will set CB2 high (enable sound)
			TSB PCR
			LDA ACR			; previous state of ACR
			PHA				; keep it just in case
			ORA #%11000000	; T1 continuous interrupts, PB7 square wave
			STA ACR			; start buzzing
			LDA ticks		; get jiffy count (LSB)
			DEC				; wait for (almost) one wrap...
bel_wait:
				CMP ticks	; ...until it arrives
				BNE bel_wait
			PLA
			STA ACR			; restore ACR
			LDA #%00100000	; was %111xxxxx, TRB will turn into %110xxxxx
			TRB PCR			; CB2 low stops sound, no matter PB7 status
			LDX #>t1ct		; restore standard T1 interrupt speed
			LDY #<t1ct
			STY T1CL
			STX T1CH		; (re)start counting!
			PLP				; restore previous interrupt status
			BRA cio_exit
no_bell:
; placeholder for a much better CONIO *** TO DO
		JSR l_ldat			; send character
		INC fw_ciop			; update position
		BRA cio_exit		; restore and exit
c_in:
	SEC						; *** placeholder ***
cio_exit:					; *** standard CONIO exit ***
	PLY
	PLX
	PLA						; restore registers
	RTS						; and exit

; ****************
; *** READ_PAD *** TBD *** TBD *** TBD
; ****************
rpad:
	SEC						; placeholder
	RTS

; ***************
; *** SEL_DEV *** TBD *** TBD *** TBD
; ***************
sel_dev:
	SEC						; placeholder
	RTS

; ****************
; *** READ_BLK ***
; ****************
; read single sector specified in arg, into buffer pointed by ptr
; ptr MUST be even, NOT starting at $DF00 and certainly (two) page-aligned (really?)
; doesn't care about selected device this far
ssec_rd:
; set token to none
	LDA #$FF
	STA token				; *token = 0xFF;
	JSR cs_enable			; assert chip select
; send CMD17 (sector already at arg.l)
	STZ crc					; ** assume CMD17_CRC is 0 **
	LDA #CMD17
	BIT sd_ver				; *** check whether SC or HC/XC
	BPL is_hcxc
		JSR ba_cmd			; SD_command(CMD17, sector, CMD17_CRC); *** a special version for SDSC cards is needed
		BRA cmd_ok
is_hcxc:
	JSR sd_cmd				; SD_command(CMD17, sector, CMD17_CRC); *** regular block-addressed version
cmd_ok:
; read response
	JSR rd_r1				; res1 = SD_readRes1();
	CMP #$FF
	BEQ no_res				; if(res1 != 0xFF) {
; if response received from card wait for a response token (timeout = 100ms)
		LDX #SD_MAX_READ_ATTEMPTS		; readAttempts = 0;
rd_wtok:
			DEX
		BEQ chk_tok			; while(++readAttempts != SD_MAX_READ_ATTEMPTS)
			LDA #$FF
			JSR spi_tr
			CMP #$FF
		BNE chk_tok			; this is done twice for a single-byte timeout loop
			LDA #$FF
			JSR spi_tr
			CMP #$FF
			BEQ rd_wtok		; if((read = SPI_transfer(0xFF)) != 0xFF)		break; (759t ~494µs)
chk_tok:
		STA res				; read = ...
		CMP #$FE
		BNE set_tk			; if(read == 0xFE) {
; read 512 byte block
block:
			LDX #0			; 256-times loop reading 2-byte words => 512 bytes/sector
byte_rd:					; for(u_int16_t i = 0; i < 512; i++) {
				LDA #$FF
				JSR spi_tr
				STA (ptr)	; *buf++ = SPI_transfer(0xFF);
				INC ptr		; won't do any page crossing here, as long as the base address is EVEN
				LDA #$FF
				JSR spi_tr
				STA (ptr)	; *buf++ = SPI_transfer(0xFF);
				INC ptr
				BNE brd_nw
					INC ptr+1
; no I/O page to skip here!
brd_nw:
				INX
				BNE byte_rd	; ... i < 512; i++)
; discard 16-bit CRC
rd_crc:
			LDA #$FF
			JSR spi_tr		; SPI_transfer(0xFF);
			LDA #$FF
			JSR spi_tr		; SPI_transfer(0xFF);
			LDA res			; ... = read
set_tk:
; set token to card response
		STA token			; *token = read;
no_res:
	JSR cs_disable			; deassert chip select
	LDA res					; return res1;
;	BRA rb_ok
; *** should check some errors...
rb_ok:
	CLC						; *** placeholder ***
	RTS

; *********************************
; *** save current sector to SD ***
; *********************************
; write single sector specified in arg, from buffer pointed by ptr
; doesn't care about selected device this far
flush_sd:
	LDA #>buffer
;	LDY #<buffer			; expected to be page-aligned
	STA ptr+1
	STZ ptr					; or STY, if set
; * standard sector write, assume arg set with sector number *
; set token to none
	LDA #$FF
	STA token
	JSR cs_enable			; assert chip select
; send CMD24 (sector already at arg.l)
	STZ crc					; ** assume CMD24_CRC is 0 **
	LDA #CMD24
	BIT sd_ver				; *** check whether SC or HC/XC
	BPL sv_hcxc
		JSR ba_cmd			; SD_command(CMD24, sector, CMD24_CRC); *** a special version for SDSC cards is needed
		BRA svcmd_ok
sv_hcxc:
	JSR sd_cmd				; SD_command(CMD24, sector, CMD24_CRC); *** regular block-addressed version
svcmd_ok:
; read response
	JSR rd_r1
	LDA res					; EEEEEEEEEEEK
	BNE no_wres				; if(res[0]==SD_READY) {
; send start token
		LDA #$FE
		JSR spi_tr			; SPI_transfer(SD_START_TOKEN);
; write buffer to card		; for(uint16_t i = 0; i < SD_BLOCK_LEN; i++) SPI_transfer(buf[i]);
wblock:
			LDX #0			; 256-times loop reading 2-byte words => 512 bytes/sector
byte_wr:
				LDA (ptr)	; get one byte
				JSR spi_tr
				INC ptr		; won't do any page crossing here, as long as the base address is EVEN
				LDA (ptr)	; get a second byte
				JSR spi_tr
				INC ptr
				BNE bwr_nw
					INC ptr+1
bwr_nw:
				INX
				BNE byte_wr
; wait for a response token (timeout = 250ms)
wr_done:
		LDX #SD_MAX_WRITE_ATTEMPTS
wr_tok:
			DEX
		BEQ chk_wtok		; this is done FOUR times for a single-byte timeout loop, each iteration ~1 ms
			LDA #$FF
			JSR spi_tr
			CMP #$FF
		BNE brk_wtok
			LDA #$FF
			JSR spi_tr
			CMP #$FF
		BNE brk_wtok
			LDA #$FF
			JSR spi_tr
			CMP #$FF
		BNE brk_wtok
			LDA #$FF
			JSR spi_tr
			CMP #$FF
			BEQ wr_tok		; if((read = SPI_transfer(0xFF)) != 0xFF)
brk_wtok:
		LDY #$FF
		STY token			; { *token = 0xFF; break; }
chk_wtok:
		AND #$1F
		CMP #5				; if((read & 0x1F) == 0x05)
		BNE no_wres
			STA token		; *token = 0x05
; wait for write to finish (timeout = 250ms)
			LDX #SD_MAX_WRITE_ATTEMPTS
wr_end:
				LDA #$FF
				JSR spi_tr	; again, this is done FOUR times for ~1 ms iteration time
			BNE no_wres
				LDA #$FF
				JSR spi_tr
			BNE no_wres
				LDA #$FF
				JSR spi_tr
			BNE no_wres
				LDA #$FF
				JSR spi_tr
			BNE no_wres
				DEX
				BNE wr_end
			STZ token
no_wres:
	JSR cs_disable			; deassert chip select
	LDA res
; * restore buffer access for convenience * SHOULD I DO THIS?
;	DEC ptr+1				; wrap buffer pointer (assume page aligned) eeeeek
;	DEC ptr+1				; eeeeek
;	BRA wb_ok
; *** should check some errors
wb_ok:
	CLC						; *** placeholder ***
	RTS

; ***********************************************
; *** initialise SD card interface for access ***
; ***********************************************
; doesn't care about selected device this far
sd_init:
	JSR cs_disable			; EEEEEEEEEEEEEEEKKKKKKKKKKKKK
	LDX #200				; ** may substitute SD logo load for this delay **
sdpu_dl:
		DEX
		BNE sdpu_dl			; delayMicroseconds(1000);
; continue with powerup sequence
	LDX #9					; for (u_int8_t i = 0; i < 10; i++)		; one less as cs_disable sends another byte
sd80c:
		LDA #$FF
		JSR spi_tr			; SPI_transfer(0xFF);
		DEX
		BNE sd80c			; this sends 80 clocks to synchronise
	JSR cs_disable
; command card to idle
	LDX #10
set_idle:
; ** SD_goIdleState is inlined here **
		JSR cs_enable		; assert chip select
; send CMD0
		STZ arg
		STZ arg+1
		STZ arg+2
		STZ arg+3			; ** assume CMD0_ARG is 0 *
		LDA #CMD0_CRC
		STA crc
		LDA #CMD0
		JSR sd_cmd			; SD_command(CMD0, CMD0_ARG, CMD0_CRC);
; read response
		JSR rd_r1			; u_int8_t res1 = SD_readRes1();
		JSR cs_disable		; deassert chip select

; continue set_idle loop
		LDA res
		CMP #1
	BEQ is_idle				; while((res[0] = SD_goIdleState()) != 0x01)
		DEX					; cmdAttempts++;
		BNE set_idle
	LDY #IDLE_ERR
	JMP sd_fail				; if(cmdAttempts > 10)	return SD_ERROR;
is_idle:
; no lateral effects here!
; ** SD_sendIfCond is inlined here **
	JSR cs_enable			; assert chip select
; send CMD8
	STZ arg
	STZ arg+1				; CMD8_ARG upper 16 bits are zero
	LDA #>CMD8_ARG
	STA arg+2
	LDA #<CMD8_ARG
	STA arg+3
	LDA #CMD8_CRC
	STA crc
	LDA #CMD8
	JSR sd_cmd				; SD_command(CMD8, CMD8_ARG, CMD8_CRC);
; read response
	JSR rd_r7				; SD_readRes7(res);
	JSR cs_disable			; deassert chip select

	STZ sd_ver				; ### default (0) is modern SD card ###
	LDA res
	CMP #1					; check valid response
	BEQ sdic_ok
; ### if error, might be 1.x card, notify and skip to CMD58 or ACMD41 ###
		LDX #OLD_SD			; ### message for older cards ###
		STX sd_ver			; ### store as flag ###
		JSR disp_code
		BRA not_cmd8
sdptec:
		LDY #SDIF_ERR
		JMP sd_fail			; if(res[0] != 0x01) return SD_ERROR;
sdic_ok:
; no lateral effects here!
; check pattern echo
	LDX #ECHO_ERR			; *** ERROR 2 in red ***
	LDA res+4
	CMP #$AA
		BNE sdptec			; if(res[4] != 0xAA) return SD_ERROR;
	LDA #'.'				; step 2 (ECHO) passed
	JSR l_ldat				; direct dot print
; ### jump here for 1.x cards ###
not_cmd8:
; attempt to initialize card *** could add CMD58 for voltage check
	LDX #101				; cmdAttempts = 0;
sd_ia:
; send app cmd
; ** res[0] = SD_sendApp() inlined here **
		JSR cs_enable		; assert chip select
; send CMD55
		STZ arg
		STZ arg+1
		STZ arg+2
		STZ arg+3
		STZ crc				; ** assume CMD55_ARG and CMD55_CRC are 0 **
		LDA #CMD55
		JSR sd_cmd			; SD_command(CMD55, CMD55_ARG, CMD55_CRC);
; read response
		JSR rd_r1			; u_int8_t res1 = SD_readRes1();
		JSR cs_disable		; deassert chip select
		LDA res				; return res1;

; if no error in response
		CMP #2
		BCS sa_err			; if(res[0] < 2)	eeeeeeeeek
; ** res[0] = SD_sendOpCond() inlined here **
			JSR cs_enable	; assert chip select
; send CMD55
			LDA #ACMD41_ARG	; only MSB is not zero
			STA arg
			STZ arg+1
			STZ arg+2
			STZ arg+3
			STZ crc			; ** assume rest of ACMD41_ARG and ACMD41_CRC are 0 **
			LDA #ACMD41
			JSR sd_cmd		; SD_command(ACMD41, ACMD41_ARG, ACMD41_CRC);
; read response
			JSR rd_r1		; u_int8_t res1 = SD_readRes1();
			JSR cs_disable	; deassert chip select
sa_err:
		LDA res				; return res1; (needed here in case of error)
	BEQ apc_rdy				; while(res[0] != SD_READY);
; wait 10 ms
		LDA #12
d10m:
				INY
				BNE d10m
			DEC
			BNE d10m		; delayMicroseconds(10000);
		DEX					; cmdAttempts++;
		BNE sd_ia
	LDY #INIT_ERR
	JMP sd_fail				; if(cmdAttempts > 100) return SD_ERROR;
apc_rdy:
; no lateral effects here!
; ### old SD cards are always SC ###
	LDA sd_ver
		BNE sd_sc
; read OCR
; ** SD_readOCR(res) is inlined here **
	JSR cs_enable			; assert chip select
; send CMD58
	STZ arg
	STZ arg+1
	STZ arg+2
	STZ arg+3
	STZ crc					; ** assume CMD58_ARG and CMD58_CRC are 0 **
	LDA #CMD58
	JSR sd_cmd				; SD_command(CMD58, CMD58_ARG, CMD58_CRC);
; read response
	JSR rd_r7				; SD_readRes7(res); actually R3
	JSR cs_disable			; deassert chip select

; check whether card is ready
	LDY #READY_ERR
	BIT res+1				; eeeeeeeeek ### will check CCS as well ###
	BMI card_rdy			; eeeeeeeeek
		JMP sd_fail			; if(!(res[1] & 0x80)) return SD_ERROR;
card_rdy:					; * SD_init OK! *
; ### but check whether standard or HC/XC, as the former needs asserting 512-byte block size ###
; ### if V is set then notify and skip CMD16 ###
	BVS hcxc
; ### set 512-byte block size ###
sd_sc:
		SEC
		ROR sd_ver			; *** attempt of marking D7 for SDSC cards, byte-addressed!
		JSR cs_enable		; assert chip select ### eeeeeeeeek
		STZ arg
		STZ arg+1			; assume CMD16_ARG upper 16 bits are zero
		LDA #>CMD16_ARG		; actually 2 for 512 bytes per sector
		STA arg+2
;		LDA #<CMD16_ARG
;		STA arg+3
		STZ arg+3			; assume CMD16_ARG LSB is zero (512 mod 256)
		STZ crc				; assume CMD16_CRC is zero
		LDA #CMD16
		JSR sd_cmd
; should I check errors?
		JSR rd_r1
		JSR cs_disable		; deassert chip select ###
		LDA #'.'			; step 4 (CARD OK) passed
		JSR l_ldat			; direct dot print
		BRA card_ok
hcxc:
;	LDX #HC_XC				; ### notify this instead ### NOPE!
;	JSR disp_code			; maybe store type somewhere? *** *** ***
card_ok:
;	JMP vol_find			; find and mount volume * NEW
; ******************************************************
; *** mount volume, either from raw sectors or FAT32 *** NEW
; ******************************************************
vol_find:
	STZ arg					; first of all, try raw card format
	STZ arg+1
	STZ arg+2
	STZ arg+3
	LDX #>buffer			; temporary load address EEEEEEEEEEEEK
	STX ptr+1
	STZ ptr					; assume buffer is page-aligned (this is needed)
	JSR ssec_rd				; read very first sector on device
	JSR chk_head			; and look for a valid header
		BCS try_fat			; not valid? try FAT32
	JMP vol_ok				; if RAW formatted, this will be a valid header
try_fat:
; this should be the MBR, check it out *** some cards have no MBR, thus non-fatal
		LDA buffer+$1C2		; first partition type
		CMP #$0C			; is it FAT32LBA?
		BEQ mbr_ptype_ok
			CMP #$0B		; or FAT32CHS?
		BEQ mbr_ptype_ok
			LDX #mbr_ptype-msg_sd
			JSR fat_err
			BRA vbr_chk		; try with VBR as this is non-fatal
mbr_ptype_ok:
		LDA #$55
		CMP buffer+$1FE		; boot signature
			BNE mbr_bsig_bad
		ASL
		CMP buffer+$1FF		; second byte
		BEQ mbr_bsig_ok
mbr_bsig_bad:
			LDX #mbr_bsig-msg_sd
			JSR fat_err
			BRA vbr_chk		; try with VBR as this is non-fatal
mbr_bsig_ok:
; let's get the partition's first sector
	LDY #0
	LDX #3					; four bytes to copy
vbr_sector:
		LDA buffer+$1C6, Y	; first sector on first partition (little endian)
		STA arg, X			; SD card expects block number BIG endian
		INY
		DEX
		BPL vbr_sector
; read VBR
	LDX #>buffer			; temporary load address
	STX ptr+1
;	STZ ptr					; assume buffer is page-aligned
	JSR ssec_rd				; read first sector on partition
; check out VBR
vbr_chk:
	LDA buffer				; first byte on VBR...
	CMP #$E9				; ...could be jump long...
	BEQ vbr_jump_ok
		CMP #$EB			; ...or short...
	BNE vbr_jump_bad
		LDA buffer+2
		CMP #$90			; ...followed by NOP
	BEQ vbr_jump_ok
vbr_jump_bad:
		LDX #vbr_jump-msg_sd
		JMP fatal			; non-MBR errors ARE fatal
vbr_jump_ok: 
	LDA buffer+$15			; media descriptor
	CMP #$F0				; 3.5" or other media
	BEQ bpb_media_ok
		CMP #$F8			; also hard disk?
	BEQ bpb_media_ok
		LDX #bpb_media-msg_sd
		JMP fatal
bpb_media_ok:
	LDA buffer+$42			; extended boot signature
	AND #%11111110			; ignore LSB
	CMP #$28				; $28 or $29
	BEQ bpb_extbs_ok
		LDX #bpb_extbs-msg_sd
		JMP fatal
bpb_extbs_ok:
	LDA buffer+$B			; bytes per sector
	BNE bpb_bps_bad			; LSB must be zero for 512
		LDA buffer+$C		; check MSB
		CMP #2				; 512 bytes/sector is the standard
	BEQ bpb_bps_ok
bpb_bps_bad:
		LDX #bpb_bps-msg_sd
		JMP fatal
bpb_bps_ok:
; VBR appears compatible, let's compute directory sector
	LDA buffer+$10			; number of FATs (may assume it's one or two, at least a power of two)
fat_shift:
		LSR
	BEQ all_fats			; all shifts done (none if 1, once if 2)
		ASL buffer+$24		; multiply sectors per FAT
		ROL buffer+$25
		ROL buffer+$26
		ROL buffer+$27
		BRA fat_shift
all_fats:
	LDA buffer+$24
	CLC
	ADC buffer+$E			; add reserved sectors
	STA buffer+$24
	LDA buffer+$25
	ADC buffer+$F
	STA buffer+$25
		BCC fat_total
	INC buffer+$26
		BNE fat_total
	INC buffer+$27
fat_total:
; we've computed the offset from VBR where the directory begins, let's compute absolute sector
	LDY #0
	LDX #3					; four bytes to copy
	CLC						; eeeeek
dir_sector:
		LDA arg, X			; EEEEEEEEEEEEEEEEEEK
		ADC buffer+$24, Y	; ADD modified sectors/FAT (times # of FATs plus reserved sectors, little endian)
		STA arg, X			; SD card expects block number BIG endian
		STA mnt_point, X	; keep this sector temporarily! BIG endian too!
		LDA buffer+$2C, X	; while we're on it, copy the root directory cluster as well
		STA dir_clus, X
		INY					; next iteration
		DEX
		BPL dir_sector
; before loading directory sectors, take note of the limit (only first cluster is explored)
	LDA buffer+$D			; number of sectors per cluster
	STA cnt					; store as directory scan limit!
	STA sec_clus			; keep for later volume access!
; read directory sector...
dir_rd:
		LDX #>buffer		; temporary load address
		STX ptr+1
		STZ ptr				; assume buffer is page-aligned EEEEEEEEEEEK
		JSR ssec_rd			; read first sector on partition
;		JSR chk_brk			; ** check for BREAK key
;		BCC cont_mnt		; ** if pressed...
		JSR l_pad
		CMP #%01010000		; ** check for SELECT + START eeek
		BNE cont_mnt		; ** if pressed...
			JMP abort		; ** ...complain a bit and exit...
cont_mnt:					; ** ...or continue as usual
; ...and scan its entries
		LDX #>buffer		; temporary load address
		STX ptr+1			; assume LSB stays at zero
dir_scan:
			LDY #0
dir_entry:
				LDA (ptr), Y			; compare name in directory entry...
				CMP vol_name, Y			; ...with desired volume name
			BNE next_entry	; if mismatched, try next entry
				INY			; otherwise, check next char
				CPY #11		; all matching?
				BNE dir_entry
			BEQ vol_found	; we got it!
next_entry:
			LDA ptr
			CLC
			ADC #32			; next entry is 32 bytes ahead
			STA ptr
			BNE dir_scan	; if still within page, check next entry
		INC ptr+1
		LDA ptr+1
		CMP #>(buffer+512)	; still within sector?
			BNE dir_scan	; keep trying
		INC arg+3			; otherwise read following sector
		BNE next_dirs
			INC arg+2
		BNE next_dirs
			INC arg+1
		BNE next_dirs
			INC arg
next_dirs:
		DEC cnt				; one sector less in the first directory cluster
		BNE dir_rd
	JMP fail_brk			; notify error and lock
vol_found:
; * compute volume header position from cluster in entry *
; first, subtract directory cluster from entry cluster 
	LDY #$1A				; location of LSW cluster in entry
	LDA (ptr), Y
	SEC
	SBC dir_clus			; subtract directory cluster (non indexed)
	STA dir_clus			; store temporarily
	INY						; next byte
	LDA (ptr), Y
	SBC dir_clus+1			; note manual indexing, needed because of the strange entry format
	STA dir_clus+1
	LDY #$14				; location of MSW cluster in entry
	LDA (ptr), Y
	SEC
	SBC dir_clus+2			; subtract directory cluster, manually indexed
	STA dir_clus+2			; store temporarily
	INY						; next byte
	LDA (ptr), Y
	SBC dir_clus+3			; note manual indexing, needed because of the strange entry format
	STA dir_clus+3
; now dir_clus is the cluster offset, turn it into sector offset
	LDA sec_clus			; cluster offset times this (always power of two)
sec_mul:
		LSR
	BEQ mul_done			; check whether more shifts are needed
		ASL dir_clus		; multiply by two as needed
		ROL dir_clus+1
		ROL dir_clus+2
		ROL dir_clus+3
	BRA sec_mul
mul_done:
; finally, add that number of sectors to the start of directory! note endianness
	LDY #0
	LDX #3					; four bytes to copy
	CLC						; eeeeek
vol_sector:
		LDA mnt_point, X	; was BIG endian EEEEEEEEEEEEK
		ADC dir_clus, Y		; add sector offset
		STA arg, X			; SD card expects block number BIG endian
		INY					; next iteration
		DEX
		BPL vol_sector
; MUST read first sector on DURANGO.AV!
	LDX #>buffer			; temporary load address
	STX ptr+1
	STZ ptr					; assume buffer is page-aligned (needed here!)
	JSR ssec_rd				; read first sector on partition
	BRA vol_ok
sd_fail:
	SEC						; will return error code in Y
	RTS
; * volume mounted some way or another *
vol_ok:
	CLC
	RTS

; TO DO *** TO DO ** TO DO

; ************************
; *** support routines ***

; *** *** standard SD card support *** ***
; *** send command in A to card *** arg.l, crc.b
sd_cmd:
; send command header
	ORA #$40
	JSR spi_tr				; SPI_transfer(cmd|0x40);
; send argument
	LDA arg
	JSR spi_tr				; SPI_transfer((u_int8_t)(arg >> 24));
	LDA arg+1
	JSR spi_tr				; SPI_transfer((u_int8_t)(arg >> 16));
	LDA arg+2
	JSR spi_tr				; SPI_transfer((u_int8_t)(arg >> 8));
	LDA arg+3
	JSR spi_tr				; SPI_transfer((u_int8_t)(arg));
; send CRC
	LDA crc
	ORA #1
	JMP spi_tr				; SPI_transfer(crc|0x01); ...and return

; * special version of the above, in case SDSC is byte-addressed, CMD17 and CMD24 only *
ba_cmd:
; send command header
	ORA #$40
	JSR spi_tr				; SPI_transfer(cmd|0x40);
; precompute byte-addressed sector
	LDA arg+3
	ASL
	STA tmpba+2				; only two bytes actually used (+1...+2)
	LDA arg+2
	ROL
	STA tmpba+1
	LDA arg+1
	ROL
;	STA tmpba
; send argument
;	LDA tmpba
	JSR spi_tr
	LDA tmpba+1
	JSR spi_tr
	LDA tmpba+2
	JSR spi_tr
	LDA #0					; always zero as 512 bytes/sector
	JSR spi_tr
; send CRC
	LDA crc
	ORA #1
	JMP spi_tr				; SPI_transfer(crc|0x01); ...and return

; *** read R1 response *** return result in res and A
rd_r1:
	PHX						; eeeeeeeek
	LDX #8					; u_int8_t i = 0, res1;
; keep polling until actual data received
r1_l:
		LDA #$FF
		JSR spi_tr
		CMP #$FF
	BNE r1_got				; while((res1 = SPI_transfer(0xFF)) == 0xFF)
		DEX					; i++;
		BNE r1_l			; if(i > 8) break;
r1_got:
	STA res					; return res1; (also in A)
	PLX
	RTS

; *** read R7 response *** return result in res[]
rd_r7:
	JSR rd_r1				; res[0] = SD_readRes1();
	CMP #2
	BCS r7end				; if(res[0] > 1) return; {in case of error}
; read remaining bytes
		LDX #1
r7loop:
			LDA #$FF
			JSR spi_tr
			STA res, X		; res[ X ] = SPI_transfer(0xFF);
			INX
			CPX #5
			BNE r7loop
r7end:
	RTS

; *** *** *********************************** *** ***
; *** *** hardware SD interface for Zacatecas *** ***
; *** *** *********************************** *** ***
; *** send data in A, return received data in A *** nominally ~3 kiB/s, around 2 kiB/s in practice
spi_tr:
	STA mosi
	LDY #8					; x = 8;
	LDA #SD_CLK
	TRB IORB				; digitalWrite(SCK, 0); (13t)
tr_l:						; while (x)
		ASL mosi
		LDA IORB
		AND #SD_MOSI^$FF
		BCC mosi_set
			ORA #SD_MOSI
mosi_set:
		STA IORB			; digitalWrite(MOSI, data & 128); data <<= 1;
		INC IORB			; digitalWrite(SCK, 1);	** assume SD_CLK  is   1 **
		LSR					; in <<= 1;				** SD_MISO is no longer $80 **
		LSR
		LSR
		ROL miso			; if(digitalRead(MISO)) in++;
		DEC IORB			; digitalWrite(SCK, 0);	** assume SD_CLK  is   1 **
		DEY					; x--;
		BNE tr_l			; (worst case, 8*43 = 344t)
	LDA miso				; return in; (total including call overhead = 372t)
	RTS

; *** enable card transfer ***
cs_enable:
	LDA #$FF
	JSR spi_tr				; SPI_transfer(0xFF);
	LDA #SD_CS
	TRB IORB				; CS_ENABLE();
	LDA #$FF
	JMP spi_tr				; SPI_transfer(0xFF); ...and return

; *** disable card transfer ***
cs_disable:
	LDA #$FF
	JSR spi_tr				; SPI_transfer(0xFF);
	LDA #SD_CS
	TSB IORB				; CS_DISABLE();
	LDA #$FF
	JMP spi_tr				; SPI_transfer(0xFF); ...and return
