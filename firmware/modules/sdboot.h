; sdboot.s definitions file
; (c) 2026 Carlos J. Santisteban
; last modified 20261127-0909

; flags for convenience, note they're fixed b/c of the BIT instruction
#define	CACH_EN		%01000000
#define	DISP_EN		%10000000

; *****************
; *** RAM usage ***
; *****************
; *** zeropage usage *** LOCALS
; ### directory position ### new, 8-bit so far
#define	cur_ix		$E8		
#define	old_c		$E9
; ### directory storage ### 8-bit so far
#define	en_ix		$EA
; flags to enable caching (D6) and display (D7)
#define	flags		$EB

; *** directory storage ***
; now taking all available RAM, will need indirect-indexed (32-byte entries)
#define	en_tab		$0800
;end_pg		= $300			; originally at buffer+255, no longer the ugly hack... *** CHECK, AS MUST BE (internal?) PARAMETER FOR PROGRESS BAR
