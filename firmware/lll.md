# Zacatecas LLL

**Low Level Library** for _Zacatecas_.

## Interface

Address|Label|Name|Input|Output|Effect
-------|-----|----|-----|------|------
`$FFBD`|`l_lcdd`|LCD Data output|`A` (data to be sent)|-|Sends `A` as data for LCD
`$FFBA`|`l_lcdc`|LCD Command output|`A` (command to be sent)|-|Sends `A` as command for LCD
`$FFB7`|`l_pad`|Pad value|-|`A`=pad value|Reads pad value into `A` (from `$0226`) as `AtBeULDR`*

*) `t`=_START_, `e`=_SELECT_, `U`=UP, `L`=LEFT, `D`=DOWN, `R`=RIGHT

_Last modified 2026-09-01_
