# Zacatecas
Chihuahua-based 65C02 SBC with integrated peripherals (LCD text screen, microSD card reader, 8-key pad)

## Specs

- 65C02 CPU at 1 MHz
- 32 KiB RAM
- 16 KiB ROM
- VIA 65C22 (Versatile Interface Adapter)
- 16x2 LCD text screen (HD44780-based, 4-bit parallel interface) with software-controlled backlight
- microSD card reader (_bit-banged_ SPI)
- Piezo buzzer (programmable thru VIA outputs `PB7` and `CB2`)
- Independent LED output, plus software-controlled microSD card activity LED
- _nanoLink_ input for card-less boot and development
- _SS22_ synchronous serial port (developed from a [6502.org](https://6502.org/forum/viewtopic.php?p=19484) idea by Garth Wilson and Samuel Falvo)
