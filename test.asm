;**************
;Попытка написть игру для nes
;
;
;***************

; Заголовок файла iNES
.segment "HEADER"


	.byte "NES"
	.byte $1a
	.byte $02		;4 -2*16k PRG Rom
	.byte $01		;5 - 8k CHR ROM
	.byte %00000001 ;6 - mapper-горизонтальная зерколо
	.byte $00		;7 - ram
	.byte $00		;8 - NULL
	.byte $00		;9 - NTSC(00) PAL(01)
	.byte $00

	;filter

	.byte $00, $00, $00, $00, $00
;=======================================================
.scope EntityType
	NoEntity=0
	PlaeyrType=1
	Bullet=2
	Fly=3
.endscope 

.struct Entity

        xpos .byte
        ypos .byte
        type .byte
.endstruct

.segment "STARTUP"

.segment "ZEROPAGE"

	controller: .res 1
	scrollx:    .res 1
	scrolly:    .res 1
	MAXENTITIES =	10
	entities:   .res .sizeof(Entity)*MAXENTITIES
	TOTALENTITIRS = .sizeof(Entity)*MAXENTITIES
	buttonflag:	.res 1
	swap:		.res 1
	hswaph:		.res 1
	bgloadlo:	.res 1
	bgloadhi:	.res 1
	bglow:		.res 1
	bghi:		.res 1
	seed:		.res 2
	flicker:	.res 1
	spritemem:	.res 2

.segment "CODE"

	prng:
		lxd 	#8	;интерактивное значение (генератор 8 битовый)
		lda     speed+0

	:
		asl 		;сдвиг ригистров 
		rol 	seed+1
		bcc 	:+      ; Условный переход, если нет переноса 
		eor 	#$2D	; Принятие XOR по событию 1 бит после сдвига

	:
	dex
	bne  :--