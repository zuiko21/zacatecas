; Zacatecas progress indicator v1.0b1
; (c) 2026 Carlos J. Santisteban
; last modified 20261121-1754

#ifndef	PROGRESS
#define		PROGRESS	_PROGRESS

; * new progress indicator *
; create empty bar (end_pg=page after last, ptr+1=first page)
makebar:
.(
	LDA #$C0				; first char of second line
	JSR l_lcmd				; send command (set DDRAM address, LLL call)
	LDY #0					; block 0, up to 2K (rarely used)
mb_loop:
		LDA #' '			; space by default
		CPY ptr+1			; will start here?
		BCC no_und
			LDA #'_'		; use underscore on 2K blocks to be loaded
no_und:
		JSR l_ldat			; direct print (Y is intact)
		TYA
		CLC
		ADC #8				; 2K = 8 pages
		TAY					; update index
	BMi bar_exit			; outside RAM? we're done
		CPY end_pg			; are we over the top?
	BCC mb_loop
		LDA #' '			; otherwise keep printing trailing spaces
		BRA no_und
bar_exit:
	RTS
.)
; display updated bar
progress:
.(
	LDA ptr+1				; check current page...
	DEC						; ...which means last one is complete
	LSR
	LSR
	LSR						; divide-by-8 turns pages into 2K blocks
	ORA #$C0				; offset for bottom row
	JSR l_lcmd				; send command (set DDRAM address, LLL call)
	LDA #'>'				; progress indicator
	JMP l_ldat				; direct print and return (LLL call)
;	RTS
.)
#endif
