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
.scope Entity_Type
	No_Entity=0
	Plaeyr_Type=1
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
	
	MAX_ENTITIES =	10
	entities:   .res .sizeof(Entity)*MAX_ENTITIES
	TOTAL_ENTITIRS = .sizeof(Entity)*MAX_ENTITIES
	
	buttonflag:	.res 1
	swap:		.res 1
	hswaph:		.res 1
	bg_load_lo:	.res 1
	bg_load_hi:	.res 1
	bglow:		.res 1
	bghi:		.res 1
	seed:		.res 2
	flicker:	.res 1
	sprite_mem:	.res 2

.segment "CODE"
 
	prng:
		;Генератор случайных чисел
		LDX 	#8			;счетчик  (генератор 8 битовый)
		LDA     seed+0

	:
		ASL 				;сдвиг ригистров 
		ROL 	seed+1
		BCC 	:+      	; Условный переход, если нет переноса 
		EOR 	#$2D		; Принятие XOR по событию 1 бит после сдвига

	:
		DEX
		BNE  	:--
		STA   	seed+0
		CMP		#0			;перезагружаем флаг
		RTS
	
	WAIT_FOR_BLANK:
		
		BIT		$2002
		BPL		WAIT_FOR_BLANK
		RTS
		
	RESET:
	
		SEI
		CLD
		LDX		#$40
		STX		$4017
		LDX		#$FF
		TXS		
		INX		
		STX		$2000
		STX		$2001
		STX		$4010
		
		JSR		WAIT_FOR_BLANK
		
		TXA
		
	CLEAR_MEM:
		
		STA		$0000, x
		STA		$0100, x
		STA		$0300, x
		STA		$0400, x
		STA		$0500, x
		STA		$0600, x
		STA		$0700, x
		LDA		#$FF
		STA		$0200, x
		LDA		#$00
		STA		controller
		INX
		BNE		CLEAR_MEM
		
		LDA		#$21
		STA		hswaph
		
		;инстализируем entities+Entity::xpos
		LDA		#$80
		STA		entities+Entity::xpos
		LDA		#$78
		STA		entities+Entity::ypos
		LDA		Entity_Type::Plaeyr_Type
		STA		entities+Entity::type
		
		LDX		#$03
		LDA		#$FF
		
		
	CLEAR_ENTITIES:
		STA		entities+Entity::xpos, x
		STA		entities+Entity::ypos, x
		LDA		#$00
		INX		
		INX	
		INX		
		CPX		#TOTAL_ENTITIRS
		BNE		CLEAR_ENTITIES
		
		;Очистка регистров и установка 
		;палитры адрес
		LDA		$2002
		LDA		#$3F
		STA		$2006
		LDA		#$10
		STA		$2006
		
		;инстализация фона hi и low
		LDA		#$10
		STA		seed
		STA		seed+1
		
		LDA		#$02
		STA		scrolly
		
		LDX		#$00
		
	PALETTE_LOAD:
	
		LDA		PALETTE,	x
		STA		$2007	
		INX		
		CPX		#$20
		BNE		PALETTE_LOAD
		
		LDA		#$C0
		STA		bg_load_lo
		LDA		#$03
		STA		bg_load_hi
		LDY		#$00
		
		LDA		$2002
		LDA		#$20
		STA		$2006
		LDA		$00
		STA		$2006
	
	BG_LOAD:
			
		JSR		prng
		LSR
		STA		$2007
		INY
		CPY		#$00
		BNE		SKIP_BG_INC
		INC		bghi
		
	SKIP_BG_INC:
	
		DEC		bg_load_lo
		LDA		bg_load_lo
		CMP		#$FF
		BNE		BG_LOAD
		DEC		bg_load_hi
		LDA		bg_load_hi
		CMP		#$FF
		BNE		BG_LOAD
		
		;конфигурация для загруски атрибутов
		LDA		$2002
		LDA		#$23
		STA		$2006
		LDA		#$C0
		TXA
		
	ATT_LOAD:
		
		STA		$2007
		INX	
		CPX		#$08
		BNE		ATT_LOAD
		
		JSR		WAIT_FOR_BLANK
		
		LDA 	#%10000000
		STA		$2000
		LDA		#%00011110
		STA		$2001
		
	FOREVER:
		JMP		FOREVER
	
	VBANK:
	
		LDA		#$02
		STA		$07FF
		
		LDX 	#$00
		LDA		#$00
		LDY		#$00
		STA		sprite_mem
		LDA		#$02
		STA		sprite_mem+1
		
	DRAW_ENTITIES:
	
		LDA		entities+Entity::type, x
		CMP		#Entity_Type::Plaeyr_Type
		BEQ		PLAYER_SPRITE
		CMP		#Entity_Type::Bullet
		BEQ		BULLET
		JMP		CHECK_END_SPRITE
		
	BULLET:
		
		LDA		entities+Entity::ypos, x; y
		STA		(sprite_mem),	y
		INY
		LDA		#$01
		STA		(sprite_mem),	y
		INY		
		LDA		#$02
		STA		(sprite_mem), 	y
		INY
		LDA		entities+Entity::xpos,	x
		STA		(sprite_mem),	y
		INY		
		
		JMP		CHECK_END_SPRITE
		
	FLYBY:
	PLAYER_SPRITE:
		
		LDA		entities+Entity::ypos,	x
		STA		(sprite_mem),	y
		INY
		LDA		#$00			;Tile
		STA		(sprite_mem),	y
		INY		
		LDA		#$01
		STA		(sprite_mem),	y
		INY
		LDA		entities+Entity::xpos,	x
		STA		(sprite_mem),	y
		INY
		
		LDA		entities+Entity::ypos,	x
		CLC
		ADC		#$08
		STA		(sprite_mem),	y
		INY	
		LDA		#$10
		STA		(sprite_mem),	y
		INY
		LDA		#$01
		STA		(sprite_mem),	y
		INY
		LDA		entities+Entity::xpos, 	x
		STA		(sprite_mem),	y
		INY
		
		LDA		entities+Entity::ypos,x
		STA		(sprite_mem),	y
		INY
		LDA		#$00
		STA		(sprite_mem),	y
		INY		
		LDA		#$41
		STA		(sprite_mem),	y
		INY
		LDA		entities+Entity::xpos,	x
		CLC
		ADC		#$08
		STA		(sprite_mem),	y
		INY
		
		LDA		entities+Entity::ypos,x
		CLC
		ADC		#$08
		STA		(sprite_mem),	y
		INY
		LDA		#$10
		STA		(sprite_mem),	y
		INY		
		LDA		#$41
		STA		(sprite_mem),	y
		INY
		LDA		entities+Entity::xpos, x
		CLC
		ADC		#$08
		STA		(sprite_mem),	y
		INY
	
	CHECK_END_SPRITE:
		TXA
		CLC
		ADC		#.sizeof(Entity)
		TAX
		CPX		#TOTAL_ENTITIRS
		BEQ		Done_Sprite
		JMP		DRAW_ENTITIES
		
	Done_Sprite:
		
		INC		flicker
		LDA		flicker	
		AND		#$0C
		BNE		no_flicker
		
		INC		hswaph
		LDA		hswaph
		CMP		#$23
		BNE		Skip_Roll
		LDA		#$21
		STA		hswaph
		; надо дописать
	
	Skip_Roll:
		
		LDA		$2002
		LDA		#$3F
		STA		$2006
		LDA		#$17
		STA		$2006
		
		LDA		hswaph
		STA		$2007
		
		
	no_flicker:
	
	; DMA копирование спрайта
	
		LDA		#$00
		STA		$2003 			;Сброс счетчика
		LDA		#$02
		STA		$4014
		NOP						;ожидание скана синхронизации
		
		LDA		#$00			;очиска выходного регистра
		STA		$2006
		STA		$2006
		
		LDA		scrollx
		STA		$2005
		LDA		scrolly
		STA		$2005
		
		LDA		#%10001000
		ORA		swap
		LDX		$2002 		;чистим регистры после перенастройки в vblank
		STA		$2000
		
	done_with_ppu:
		
		LDA		#$01
		STA		$07FF
		
	INILIZE_SPRITE:
		
		LDY		#$00
		LDA		#$FF
		
	INILIZE_SPRITE_LOOP:
	
		STA		(sprite_mem),	y
		INY		
		EOR		#$FF
		STA		(sprite_mem),	y
		INY
		STA		(sprite_mem),	y
		INY
		EOR		#$FF
		STA		(sprite_mem),	y
		INY
		BEQ		start_read_controllers
		JMP		INILIZE_SPRITE_LOOP
		
	start_read_controllers:
		
		;читаем состояние контролера
		LDA		#$01
		STA		$4016
		LDA		#$00
		STA		$4016
		
	read_controller_buttons:
		
		LDA		$4016		;a
		ROR		A
		ROL		controller
		
		LDA		$4016		;b	
		ROR		A
		ROL		controller
		
		LDA		$4016		;select
		ROR		A
		ROL		controller
		
		LDA		$4016		;start
		ROR		A
		ROL		controller
		
		LDA		$4016		;UP
		ROR		A
		ROL		controller
		
		LDA		$4016		;DOWN
		ROR		A
		ROL		controller
		
		LDA		$4016		;LEFT
		ROR		A
		ROL		controller
		
		LDA		$4016		;RITHE
		ROR		A
		ROL		controller
	;======================================	
	add_buillet:
		
		NOP
		NOP
		NOP
		NOP
		LDX		#$00
		
	add_buillet_loop:
		
		CPX		#TOTAL_ENTITIRS- .sizeof(Entity)
		BEQ		Finish_Controls
		LDA		entities+Entity::type
		CMP		#Entity_Type::No_Entity
		BEQ		Add_Buillet_Entity
		TXA
		CLC
		ADC		#.sizeof(Entity)
		TAX
		JMP		add_buillet_loop
		
	Add_Buillet_Entity:
	
		LDA		entities+Entity::xpos
		CLC
		ADC		#$04
		STA		entities+Entity::xpos, X
		LDA		entities+Entity::ypos
		STA		entities+Entity::ypos, X
		LDA		#Entity_Type::Bullet
		STA		entities+Entity::type,	X
		JMP		Finish_Controls
	;=============================	
	Finish_Controls:
	Proces_Scrolling:
		LDA		scrolly
		SEC
		SBC		#$02
		STA		scrolly
		BNE		Done_Scroll
		LDA		#$EE
		STA		scrolly
	Done_Scroll:
		NOP
	Process_Entities_Loop:
		
		LDA		entities+Entity::type,	x
		CMP		#Entity_Type::Bullet
		BNE		skip_entity
	
	Process_Bullet:
		
		LDA		entities+Entity::ypos,	x
		SEC	
		SBC		#$03
		STA		entities+Entity::ypos, 	x
		BCS		entity_complete
		LDA		#Entity_Type::No_Entity
		STA		entities+Entity::type,	x
		LDA		#$FF
		STA		entities+Entity::xpos,  x
		STA		entities+Entity::ypos,	x
	entity_complete:
	skip_entity:
		TXA
		CLC
		ADC		#.sizeof(Entity)
		TAX
		CMP		#$1E
		BNE		Process_Entities_Loop
		
	Done_Process_Entities:
		
		RTI
		
	PALETTE:
		.byte	$0d, $30, $16, $27
		.byte	$0d, $00, $10, $12
		.byte	$0d, $0c, $1c, $3c
		.byte	$0d, $00, $10, $12
		.byte	$0d, $00, $10, $12
		.byte	$0d, $00, $10, $12
		.byte	$0d, $00, $10, $12
		.byte	$0d, $00, $10, $12

.segment "VECTORS"

		.word	VBANK
		.word	RESET
		.word	0

.segment "CHARS"

		.incbin 	"shooter.chr"
		;.incbin 	"fons_eng.chr"
		;.incbin	"fons_rus.chr"