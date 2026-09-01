# miniBIOS

Common **BIOS interface** for my _6502-based_ computers (Durango, Chihuahua, Zacatecas...)

## Interface

Address|Label|Name|Input|Output|Effect
-------|-----|----|-----|------|------
`$FF00`|`b_conio`|CONIO|`A` (0 or char to print)|read char (if `A`=0)|Prints `A` or reads key (if `A`=0) 
`$FF03`|`b_pad`|PAD_UPD|-|new pad value in `A`, `C` set otherwise|Reads pad value, if changed since last read
`$FF06`|`b_sdev`|SEL_DEV|`A`=device ID _(TBD)_|`C` set if unavailable|Selects storage device _(TBD)_
`$FF09`|`b_rblk`|READ_BLK|`$FC`.w = `ptr`, `$F0`.l = _block_|`C` if failed|Reads specified _block_ from selected device at buffer address `ptr` (usually `$0300`)
`$FF0C`|`b_wblk`|WRITE_BLK|`$FC`.w = `ptr`, `$F0`.l = _block_|`C` if failed|Write specified _block_ to selected device from buffer address `ptr` (usually `$0300`)

_Last modified 2026-09-01_
