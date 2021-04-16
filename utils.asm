; aux functions commons and constants

; directions (1 for pressed - directions on high bits, buttons on right)
_JOYPAD_BUTTON_UP			EQU 	%01000000
_JOYPAD_BUTTON_RIGHT		EQU 	%00010000
_JOYPAD_BUTTON_DOWN			EQU 	%10000000
_JOYPAD_BUTTON_LEFT			EQU 	%00100000
_JOYPAD_BUTTON_A			EQU 	%00000001
_JOYPAD_BUTTON_B			EQU 	%00000010
_JOYPAD_BUTTON_START		EQU 	%00001000
_JOYPAD_BUTTON_SELECT		EQU 	%00000100

_DELAY_SHORT				EQU		2000
_DELAY_MED					EQU		8000

; -----------------------------------------------
; BASIC ONES
; -----------------------------------------------
; Basic functions used everywhere with little
; or zero game-logic relation (like reading
; button states, waiting for vblank...)
; -----------------------------------------------

; shutdown_LCD - wait until we can shutdown the lcd, then return
; if it's already off, instant return
; if not, wait until it's off and then return
; PARAMS - none
shutdown_LCD:
	ld a, [rLCDC]
	rlca 			; rotate left the bits from the register, since the bit 7 is the on/off one, this bit is now in the CARRY flag
	ret nc 			; ret ONLY if carry == 0, that means the 7 bit (previously rotated) is 0, so the LCD is already off

	call wait_vblank

	xor a 			; A = 0x00 (basically bit 7)
	ld [rLCDC], a   ; LCD off now!

	ret


; wait_vblank - wait until
; PARAMS - none
wait_vblank:
	ld a, [rLY]		; load the current vertical line. Values range from 0->153. 144->153 is the VBlank period
	cp 144
	jp c, wait_vblank ; if there's carry that means A ([rLY]) is < 144, so it's a non-blank vertical line, so wait

	ret


; read joypad state and add it to _JOYPAD_STATE ram register
; PARAMS
; 		- none
; RETURN
; 		- none
set_joypad_state:

	push bc
	push hl
	push af
	
	ld hl, rP1 ; joypad register $FF00
	ld a, P1F_4 ; get buttons
	ld [hl], a

	ld a, [hl]
	ld a, [hl]
	ld a, [hl]
	ld a, [hl] ; read multiple times to prevent bouncing

	and %00001111 ; remove the last bits (unused info)
	ld b, a

	ld a, P1F_5 ; get pad
	ld [hl], a

	ld a, [hl]
	ld a, [hl]
	ld a, [hl]
	ld a, [hl]

	swap a ; directions on the last bits, so swap
	and %11110000 ; remove the first bits (unused info)
	or b ; b have, on the low bits, the buttons, so now the 7-4 bits have the directions and the 3-1 have the buttons
	cpl ; since the state is "0 for pressed" change to "1 for pressed" using complement

	ld [_JOYPAD_STATE], a ; save the state on ram

	pop bc
	pop hl
	pop bc

	ret


; memcopy - copy data (length set on DE) from BC to HL
; PARAMS
; 		BC, memadress source
;		HL, memadress destination
; 		DE, data length
; RETURN
; 		- none
memcopy:
	ld a, [bc]
	ld [hl], a
	dec de
	ld a, d
	or e
	ret z ; ret if all data has been copied

	inc bc
	inc hl
	jp memcopy


; delay - iterates some time to create a delay
; PARAMS
;		BC delay
; RETURN
; 		- none
delay:
	.delay_loop:
	dec bc
	ld a, b
	or c
	ret z
	nop
	jr .delay_loop


; turn the screen "black" gradually by changing
; all the palettes from the "regular" ones to %11111111
; (change BACKGROUND palette and OBJECT0 palette
; - ignore OBJECT1 since we're not using it here)
; PARAMS
; 		- none
; RETURNS
; 		- none
fade_out:
	; asume initial palette -> 11100100
	; (yes, this won't work with different ones,
	; but won't be using anything different here)

	ld a, %11100101
	ld [rBGP], a
	ld [rOBP0], a

	ld bc, _DELAY_MED
	call delay
	
	ld a, %11101010
	ld [rBGP], a
	ld [rOBP0], a

	ld bc, _DELAY_MED
	call delay

	ld a, %11111111
	ld [rBGP], a
	ld [rOBP0], a

	ld bc, _DELAY_MED
	call delay

	ret


; reverts the fade_out by restoring a %1111111
; palette to the "original" %11100100
; PARAMS
; 		- none
; RETURNS
; 		- none
fade_in:
	; asume final palette -> 11100100
	; (yes, this won't work with different ones,
	; but won't be using anything different here)
	

	ld a, %11101010
	ld [rBGP], a
	ld [rOBP0], a

	ld bc, _DELAY_MED
	call delay
	
	ld a, %11100101
	ld [rBGP], a
	ld [rOBP0], a

	ld bc, _DELAY_MED
	call delay

	ld a, %11100100
	ld [rBGP], a
	ld [rOBP0], a

	ld bc, _DELAY_MED
	call delay

	ret


; -----------------------------------------------
; GAME LOGIC
; -----------------------------------------------
; Minor game logic utility, like coordinates
; conversion or score modification
; -----------------------------------------------

; given two x-y pixel coordinates, return
; the index for that tile in the map 
; (assume scroll 0, so the range will be the one
; available in the top-left corner)
; PARAMS
; 		B - X
; 		C - Y
; RETURN
;		HL - the index in the map
pixels_to_map_index:
	
	; X / 8
	; first remove the "X padding" (-8)
	ld a, b
	sub 8
	ld b, a

	srl b
	srl b
	srl b

	; Y / 8
	; first remove the "Y padding" (-16)
	ld a, c
	sub 16
	ld c, a

	srl c
	srl c
	srl c

	xor a
	ld h, a
	ld l, b

	; increment Y until c == 0
	.pixels_to_map_index_loop:
	ld a, c
	or 0
	ret z

	ld de, 32
	add hl, de ; full line

	dec c
	jr .pixels_to_map_index_loop


; return a pair of pixel coordinates X - Y (on BC)
; PARAMS
;		none
; RETURN
; 		B - X coordinate
; 		C - Y coordinate
; if all the positions are invalid, this will be
; trapped in an endless loop, but since the max segments
; is limited by a single 8-bits register, we cannot fill
; the whole background with segments, so no worries for now
get_free_position:
	
	; --------------------------------
	; X POSITION
	; --------------------------------

	ld a, [_PSEUDORANDOM_VAL]
	.pseudorandom_x_loop:
	cp (20 - 2) ; 18 valid tiles on x (20 - 2 walls)
	jr c, .pseudorandom_x_end_loop ; jr z will be exact 18, so if we start at 8, 18 will be the right wall

	sub 18
	jr .pseudorandom_x_loop

	.pseudorandom_x_end_loop:
	ld d, a

	; ----------------------

	; initial point, the upper-left pixels (the actual "0,0" valid playground)
	ld a, 8 + 8 ; remember the 8 offset
	ld b, a
	
	.position_x_loop:
	ld a, d
	or a
	jr z, .position_x_done

	ld a, b
	add 8
	ld b, a
	dec d
	jr .position_x_loop
	.position_x_done:

	; --------------------------------
	; Y POSITION
	; --------------------------------

	ld a, [_PSEUDORANDOM_VAL]
	.pseudorandom_y_loop:
	cp (18 - 2) ; 16 valid tiles on y (16 - 2 walls)
	jr c, .pseudorandom_y_end_loop

	sub 16
	jr .pseudorandom_y_loop

	.pseudorandom_y_end_loop:
	ld d, a

	; ----------------------

	; initial point, the upper-left pixels (the actual "0,0" valid playground)
	ld a, 16 + 8 ; 16 offset on Y
	ld c, a
	
	.position_y_loop:
	ld a, d
	or a
	jr z, .position_y_done

	ld a, c
	add 8
	ld c, a
	dec d
	jr .position_y_loop
	.position_y_done:

	; --------------------------------
	; CHECK IF POSITION IS "FREE"
	; --------------------------------

	; position free if
	; - different than current item
	; - different than player
	; - different than any segment background

	; check current item
	ld a, [_ITEM_POS_X]
	cp b
	jr nz, .check_player
	ld a, [_ITEM_POS_Y]
	cp c
	jr nz, .check_player
	; position not empty, try again with differnet _PSEUDORANDOM
	ld a, [_PSEUDORANDOM_VAL]
	add a
	ld [_PSEUDORANDOM_VAL], a
	jp get_free_position

	; check player
	.check_player:
	ld a, [_PLAYER_POS_X]
	cp b
	jr nz, .ceck_segments
	ld a, [_PLAYER_POS_Y]
	cp c
	jr nz, .ceck_segments
	; position not empty, try again
	ld a, [_PSEUDORANDOM_VAL]
	add a
	ld [_PSEUDORANDOM_VAL], a
	jp get_free_position

	; check background segment
	.ceck_segments:

	push bc
	call pixels_to_map_index
	pop bc
	ld de, _SEGMENTS_TTL
	add hl, de
	ld a, [hl]
	or a
	jr z, .position_free
	ld a, [_PSEUDORANDOM_VAL]
	add a
	ld [_PSEUDORANDOM_VAL], a
	jp get_free_position

	.position_free:

	ret


; increments the score by 1
; also draws the proper sprites
inc_score_and_draw:

	ld a, [_SCORE_VAL]
	add 1
	ld [_SCORE_VAL], a

	call wait_vblank

	ld a, [_SCORE_DIGIT_3_SPRITE_INDEX]
	add 1
	cp _TILE_NUMBERS_OFFSET_MAX + 1 ; the first invalid tile number
	jr z, .draw_score_2

	; just inc 1 and return
	ld [_SCORE_DIGIT_3_SPRITE_INDEX], a
	ret

	.draw_score_2
	ld a, _TILE_NUMBERS_OFFSET
	ld [_SCORE_DIGIT_3_SPRITE_INDEX], a

	ld a, [_SCORE_DIGIT_2_SPRITE_INDEX]
	add 1
	cp _TILE_NUMBERS_OFFSET_MAX + 1 ; the first invalid tile number
	jr z, .draw_score_1

	; just inc 1 and return
	ld [_SCORE_DIGIT_2_SPRITE_INDEX], a
	ret

	.draw_score_1
	ld a, _TILE_NUMBERS_OFFSET
	ld [_SCORE_DIGIT_1_SPRITE_INDEX], a

	ret


; -----------------------------------------------
; GRAPHICS
; -----------------------------------------------
; Only graphic operations like loading _SCRN0
; with a tilemap, reseting the score tiles to
; the initial index ("0") or drawing the item
; -----------------------------------------------


; load the board map in _SCRN0 and reset the SEGMENTS_TTL values
; (also called when reseting the game)
; notice that this DOESN'T CALL WAIT_VBLANK
; PARAMS
; 		- none
; RETURNS
; 		- none
load_board_scrn:
	ld bc, Board_map
	ld de, Board_map_end - Board_map
	ld hl, _SCRN0 ; $9800
	call memcopy

	ret


; reset the score digits back to 0
; (also called when reseting the game)
; notice that this DOESN'T CALL WAIT_VBLANK
; PARAMS
; 		- none
; RETURNS
; 		- none
reset_score_digits_sprite_index:
	ld a, _TILE_NUMBERS_OFFSET
	ld [_SCORE_DIGIT_1_SPRITE_INDEX], a
	ld [_SCORE_DIGIT_2_SPRITE_INDEX], a
	ld [_SCORE_DIGIT_3_SPRITE_INDEX], a

	ret


; reset the item sprite
; notice that this DOESN'T CALL WAIT_VBLANK
; PARAMS
; 		- none
; RETURNS
; 		- none
reset_item_sprite:

	; item X
	ld a, [_ITEM_POS_X]
	ld [_ITEM_SPRITE_POS_X], a

	; item Y
	ld a, [_ITEM_POS_Y]
	ld [_ITEM_SPRITE_POS_Y], a

	; item sprite index
	ld hl, _ITEM_SPRITE_INDEX
	ld a, _ITEM_TILE
	ld [hl], a

	ret


; draws an item on the given positions
; (do not change anything)
; this will be called only when the item needs
; to be moved (after colliding) NOT on every step
; PARAMS
; 		- none
; RETURNS
; 		- none
draw_item:
	
	call wait_vblank

	; item X
	ld a, [_ITEM_POS_X]
	ld [_ITEM_SPRITE_POS_X], a

	; item Y
	ld a, [_ITEM_POS_Y]
	ld [_ITEM_SPRITE_POS_Y], a

	ret
	

; clean the OAM
; PARAMS
; 		- none
; RETURNS
; 		- none
clean_oam:
	ld hl, _OAMRAM ; _OAM END
	ld de, 160; _OAM length ($FE9F - $FE00)
	.clean_oam_loop
	ld a, 0
	ld [hli], a
	dec de
	ld a, d
	or e
	jr nz, .clean_oam_loop

	ret