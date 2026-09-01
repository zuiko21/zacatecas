# Zacatecas LLL

**Low Level Library** for _Zacatecas_.

## Interface

Address|Name|Input|Output|Effect
-------|----|-----|------|------
`$FFBD`|LCD Data output|`A` (data to be sent)|-|Sends `A` as data for LCD
`$FFBA`|LCD Command output|`A` (command to be sent)|-|Sends `A` as command for LCD
`$FFB7`|Pad value|-|`A`=pad value|reads pad value into `A` (from `$0226`)
