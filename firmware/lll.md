# Zacatecas LLL

**Low Level Library** for _Zacatecas_.

## Interface

Address|Label|Name|Input|Output|Effect
-------|-----|----|-----|------|------
`$FFBD`|`l_ldat`|LCD_DATA|`A` (data to be sent)|-|Sends `A` as data for LCD
`$FFBA`|`l_lcmd`|LCD_COMMAND|`A` (command to be sent)|-|Sends `A` as command for LCD
`$FFB7`|`l_lrst`|LDC_RESET|-|`A`=pad value|Reads pad value into `A` (from `$0226`) as `AtBeULDR`*
`$FFB4`|`l_pad`|Pad value|-|`A`=pad value|Reads pad value into `A` (from `$0226`) as `AtBeULDR`*

*) `t`=_START_, `e`=_SELECT_, `U`=UP, `L`=LEFT, `D`=DOWN, `R`=RIGHT

_Last modified 2026-10-25_
