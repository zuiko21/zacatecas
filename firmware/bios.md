# miniBIOS

Common **BIOS interface** for my _6502-based_ computers (Durango, Chihuahua, Zacatecas...)

## Interface

Address|Label|Name|Input|Output|Effect
-------|-----|----|-----|------|------
`$FF00`|`b_conio`|CONIO|`A` (0 or char to print)|read char (if `A`=0)|Prints `A` or reads key (if `A`=0) 

_Last modified 2026-09-01_
