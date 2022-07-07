include "hardware.inc"

; some game definitons

; OAM stuff
; -----------------

_PLAYER_SPRITE_POS_Y				EQU		_OAMRAM
_PLAYER_SPRITE_POS_X				EQU 	_PLAYER_SPRITE_POS_Y + 1
_PLAYER_SPRITE_INDEX				EQU		_PLAYER_SPRITE_POS_X + 1
_PLAYER_SPRITE_ATTR				EQU		_PLAYER_SPRITE_INDEX + 1

_ITEM_SPRITE_POS_Y				EQU		_PLAYER_SPRITE_ATTR + 1
_ITEM_SPRITE_POS_X				EQU 	_ITEM_SPRITE_POS_Y + 1
_ITEM_SPRITE_INDEX				EQU		_ITEM_SPRITE_POS_X + 1
_ITEM_SPRITE_ATTR				EQU		_ITEM_SPRITE_INDEX + 1

_SCORE_DIGIT_1_SPRITE_POS_Y			EQU		_ITEM_SPRITE_ATTR + 1
_SCORE_DIGIT_1_SPRITE_POS_X			EQU		_SCORE_DIGIT_1_SPRITE_POS_Y + 1
_SCORE_DIGIT_1_SPRITE_INDEX			EQU		_SCORE_DIGIT_1_SPRITE_POS_X + 1
_SCORE_DIGIT_1_SPRITE_ATTR			EQU		_SCORE_DIGIT_1_SPRITE_INDEX + 1

_SCORE_DIGIT_2_SPRITE_POS_Y			EQU		_SCORE_DIGIT_1_SPRITE_ATTR + 1
_SCORE_DIGIT_2_SPRITE_POS_X			EQU		_SCORE_DIGIT_2_SPRITE_POS_Y + 1
_SCORE_DIGIT_2_SPRITE_INDEX			EQU		_SCORE_DIGIT_2_SPRITE_POS_X + 1
_SCORE_DIGIT_2_SPRITE_ATTR			EQU		_SCORE_DIGIT_2_SPRITE_INDEX + 1

_SCORE_DIGIT_3_SPRITE_POS_Y			EQU		_SCORE_DIGIT_2_SPRITE_ATTR + 1
_SCORE_DIGIT_3_SPRITE_POS_X			EQU		_SCORE_DIGIT_3_SPRITE_POS_Y + 1
_SCORE_DIGIT_3_SPRITE_INDEX			EQU		_SCORE_DIGIT_3_SPRITE_POS_X + 1
_SCORE_DIGIT_3_SPRITE_ATTR			EQU		_SCORE_DIGIT_3_SPRITE_INDEX + 1

; numeric constants
; -----------------

_PLAYER_TILE_HORIZONTAL_VALUE			EQU		8
_PLAYER_TILE_VERTICAL_VALUE			EQU		9
_PLAYER_SPEED_DELAY_VALUE			EQU		9000
_PLAYER_INITIAL_POS_Y 				EQU 		16 + (10 * 8)
_PLAYER_INITIAL_POS_X 				EQU 		8 + (3 * 8)
_PLAYER_INITIAL_SEGMENTS			EQU 		4 ; after setting the segments they're decremented, so the final viewed segments will be -1

_ITEM_TILE					EQU		10
_ITEM_INITIAL_POS_Y				EQU 		16 + (5 * 8)
_ITEM_INITIAL_POS_X				EQU 		8 + (10 * 8)

_SEGMENTS_TTL_TOTAL 				EQU		32 * 16 + 19 ; the "right" part will be unused, indeed, maybe we can map this to a continuous segment...
_BLANK_TILE					EQU 		0
_SEGMENT_TILE 					EQU 		7

_TILE_NUMBERS_OFFSET				EQU		$10 ; tile with "0"
_TILE_NUMBERS_OFFSET_MAX			EQU		$19 ; tile with "9"

; ram values
; ----------

_JOYPAD_STATE					EQU 		_RAM
_PLAYER_INDEX_SPRITE 				EQU 		_RAM + 1
_PLAYER_DIR_Y					EQU		_RAM + 2
_PLAYER_DIR_X					EQU 		_RAM + 3
_PLAYER_POS_Y					EQU		_RAM + 4
_PLAYER_POS_X					EQU 		_RAM + 5 
_PLAYER_MIRRORED_Y				EQU		_RAM + 6 ; mirrored for sprites
_PLAYER_MIRRORED_X				EQU 		_RAM + 7

_ITEM_POS_Y					EQU		_RAM + 8
_ITEM_POS_X					EQU 		_RAM + 9
_ITEM_PICKED					EQU		_RAM + 10

_PSEUDORANDOM_VAL				EQU		_RAM + 11 ; from FF04, Divider Register, updated on every joypad interrupt
_SCORE_VAL					EQU		_RAM + 12

_PLAYER_SEGMENTS_COUNT				EQU 		_RAM + 13 ; limited to 255 segments (8 bits)
_SEGMENTS_TTL 					EQU 		_RAM + 14 ; the rest of the ram, basically


section "Joypad interrupt", ROM0[$60] ; joypad interrupt entry point (8 instr max)

	; update pseudorandom_val on every "valid" button press
	; (enough for our "random stuff")
	ld a, [rDIV]
	ld [_PSEUDORANDOM_VAL], a

	call set_joypad_state
	ret ; do not enable interrupts again

section "Header", ROM0[$100]

	di ; Disable interrupts
	jp start ; 

	; set space for the header
	rept $150 - $104
		db 0
	endr

section "Game code", ROM0
	start:

	; set BG and first palette (the same)
	ld a, %11100100
	ld [rBGP], a
	ld [rOBP0], a

	; rSCY and rSCX, the scroll
	xor a
	ld [rSCY], a
	ld [rSCX], a
	
	; prepare the interrupts (joypad only)
	ld hl, rIE
	ld a, IEF_HILO
	ld [hl], a

	; set default variables, clean unclear values, etc
	call init_logic
	call shutdown_LCD

	; before entering the game loop show a title screen
	; (kinda "press any key to continue")
	; -----------------------------------------------

	; just load some initial tiles and one background

	call clean_oam

	; load intro tiles to VRAM
	ld bc, Intro_tiles ; data source
	ld de, Intro_tiles_end - Intro_tiles ; data length
	ld hl, _VRAM ; data destination, in this case VRAM + offset 0 (it's the first element)
	call memcopy

	; load intro map
	ld bc, Intro_map
	ld de, Intro_map_end - Intro_map
	ld hl, _SCRN0
	call memcopy

	; show screen
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON
	ld [rLCDC], a

	.intro_loop:
	call set_joypad_state
	ld a, [_JOYPAD_STATE]
	or a
	jr z, .intro_loop

	;button press, do fade out and shutdown screen
	call wait_vblank
	call fade_out
	call shutdown_LCD

	; reset joypad state
	xor a
	ld [_JOYPAD_STATE], a

	; reset the palette
	ld a, %11100100
	ld [rBGP], a
	ld [rOBP0], a

	; -----------------------------------------------

	; continue with regular game init	
	call load_graphics

	; show screen
	; tiles on $80000 (init of _VRAM)
	; background on $9800 (init of _SCRN0)
	; show background and enable objects (8x8)
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON
	ld [rLCDC], a

	game_loop:

		call move_player

		di ; disable interrupts while drawing stuff on screen (not the best way to handle controls, I know)

		call process_draw_segments

		ei

		call draw_player

		call draw_item

		call check_collisions

		; "speed" delay
		ld bc, _PLAYER_SPEED_DELAY_VALUE
		call delay

		; repeat
		jp game_loop


; ------------------------------------------

; only one call when start playing; set the backgrounds, oam...
; calls some graphics functions that are called after each game_over
; event (like the one that restarts the background)
load_graphics:
	; load tiles to VRAM
	ld bc, Back_tiles ; data source
	ld de, Back_tiles_end - Back_tiles ; data length
	ld hl, _VRAM ; data destination, in this case VRAM + offset 0 (it's the first element)
	call memcopy

	ld bc, Snake_heads_tiles ; data source
	ld de, Snake_heads_tiles_end - Snake_heads_tiles ; data length 2 8x8 tiles (hor and ver), 32 bytes
	ld hl, _VRAM + (Back_tiles_end - Back_tiles) ; previous tiles
	call memcopy

	ld bc, Item_tiles ; data source
	ld de, Item_tiles_end - Item_tiles
	ld hl, _VRAM + (Snake_heads_tiles_end - Snake_heads_tiles) + (Back_tiles_end - Back_tiles) ; previous tiles
	call memcopy

	ld bc, Font_tiles
	ld de, Font_tiles_end - Font_tiles
	ld hl, _VRAM + $100 ; numbers start at $8100 (tile 10)
	call memcopy

	; load _SCRN0
	call load_board_scrn

	; clean OAM
	call clean_oam

	; load score digits
	xor a
	ld [_SCORE_DIGIT_1_SPRITE_ATTR], a
	ld [_SCORE_DIGIT_2_SPRITE_ATTR], a
	ld [_SCORE_DIGIT_3_SPRITE_ATTR], a

	; common Y
	ld a, 16 ; 16
	ld [_SCORE_DIGIT_1_SPRITE_POS_Y], a
	ld [_SCORE_DIGIT_2_SPRITE_POS_Y], a
	ld [_SCORE_DIGIT_3_SPRITE_POS_Y], a

	ld a, 8 + (8 * 2)
	ld [_SCORE_DIGIT_1_SPRITE_POS_X], a
	ld a, 8 + (8 * 3)
	ld [_SCORE_DIGIT_2_SPRITE_POS_X], a
	ld a, 8 + (8 * 4)
	ld [_SCORE_DIGIT_3_SPRITE_POS_X], a

	; set digit sprites
	call reset_score_digits_sprite_index

	; set item sprite
	call reset_item_sprite

	ret

; first init before each run; also called when reseting after crash
; set the player states vars
init_logic:

	; set player stuff
	ld a, _PLAYER_INITIAL_POS_Y ; pos Y
	ld [_PLAYER_POS_Y], a
	ld a, _PLAYER_INITIAL_POS_X ; pos X
	ld [_PLAYER_POS_X], a
	ld a, _PLAYER_TILE_HORIZONTAL_VALUE ; sprite right
	ld [_PLAYER_INDEX_SPRITE], a
	xor a
	ld [_PLAYER_MIRRORED_Y], a
	ld [_PLAYER_MIRRORED_X], a
	ld [_PLAYER_DIR_Y], a
	ld a, 8
	ld [_PLAYER_DIR_X], a

	; set item stuff
	ld a, _ITEM_INITIAL_POS_Y ; pos Y
	ld [_ITEM_POS_Y], a
	ld a, _ITEM_INITIAL_POS_X ; pos X
	ld [_ITEM_POS_X], a
	xor a
	ld [_ITEM_PICKED], a ; item not picked

	; set segments number
	ld a, _PLAYER_INITIAL_SEGMENTS
	ld [_PLAYER_SEGMENTS_COUNT], a

	; set _SEGMENTS_TTL to 0 as ttl for segments
	ld hl, _SEGMENTS_TTL
	ld bc, _SEGMENTS_TTL_TOTAL
	.init_logic_segments_ttl_loop:
	xor a
	ld [hli], a
	dec bc
	ld a, b
	or c
	jr nz, .init_logic_segments_ttl_loop

	; reset joypad info
	ld hl, _JOYPAD_STATE
	xor a
	ld [hl], a

	; reset pseudorandom_val
	ld a, [rDIV]
	ld [_PSEUDORANDOM_VAL], a

	; reset score
	xor a
	ld [_SCORE_VAL], a

	ret

; ------------------------------------------

move_player:

	; --------------------
	; SET PLAYER DIRECTION
	; --------------------

	; check directions
	ld hl, _JOYPAD_STATE

	; get current dir Y
	; if it's not 0, check only for dir X
	ld a, [_PLAYER_DIR_Y]
	or a ; set flags
	jr nz, .check_left_right
	; 0 -> "moving left-right", so check up/down to change directions
	; 1 -> "moving up-down", so check left/right to change directions
	; this works because cannot change from up to down or left to right,
	; it's always an "axis change"

	; check UP
	; --------
	ld a, [hl]
	and _JOYPAD_BUTTON_UP
	jr z, .move_player_check_down

	ld a, -8
	ld [_PLAYER_DIR_Y], a
	xor a
	ld [_PLAYER_DIR_X], a
	ld [_PLAYER_MIRRORED_X], a ; reset the X flip option since we're changing to up/down
	; point UP, VERTICAL sprite
	; point UP, flip the sprite (Y)
	ld a, _PLAYER_TILE_VERTICAL_VALUE
	ld [_PLAYER_INDEX_SPRITE], a
	ld a, 1
	ld [_PLAYER_MIRRORED_Y], a
	ret

	; check DOWN
	; --------
	.move_player_check_down:
	ld a, [hl]
	and _JOYPAD_BUTTON_DOWN
	ret z

	ld a, 8
	ld [_PLAYER_DIR_Y], a
	xor a
	ld [_PLAYER_DIR_X], a
	ld [_PLAYER_MIRRORED_X], a ; reset the X flip option since we're changing to up/down
	; point DOWN, VERTICAL sprite
	; point DOWN, do not flip the sprite
	ld a, _PLAYER_TILE_VERTICAL_VALUE
	ld [_PLAYER_INDEX_SPRITE], a
	xor a
	ld [_PLAYER_MIRRORED_Y], a
	ret


	.check_left_right:

	; check RIGHT
	; --------
	ld a, [hl]
	and _JOYPAD_BUTTON_RIGHT
	jr z, .move_player_check_left

	xor a
	ld [_PLAYER_DIR_Y], a
	ld [_PLAYER_MIRRORED_Y], a ; reset the Y flip option since we're changing to left/right
	ld a, 8
	ld [_PLAYER_DIR_X], a
	; point RIGHT, HORIZONTAL sprite
	; point RIGHT, do not flip the sprite
	ld a, _PLAYER_TILE_HORIZONTAL_VALUE
	ld [_PLAYER_INDEX_SPRITE], a
	xor a
	ld [_PLAYER_MIRRORED_X], a
	ret

	; check LEFT
	; ----------
	.move_player_check_left:
	ld a, [hl]
	and _JOYPAD_BUTTON_LEFT
	ret z

	xor a
	ld [_PLAYER_DIR_Y], a
	ld [_PLAYER_MIRRORED_Y], a ; reset the Y flip option since we're changing to left/right
	ld a, -8
	ld [_PLAYER_DIR_X], a
	; point LEFT, HORIZONTAL sprite
	; point LEFT, flip the sprite (X)
	ld a, _PLAYER_TILE_HORIZONTAL_VALUE
	ld [_PLAYER_INDEX_SPRITE], a
	ld a, 1
	ld [_PLAYER_MIRRORED_X], a

	ret


; since segments are part of the background this
; function will use some wait_vblanks to handle it
process_draw_segments:

	; draw the current segment
	ld a, [_PLAYER_POS_X]
	ld b, a
	ld a, [_PLAYER_POS_Y]
	ld c, a

	call pixels_to_map_index
	; now HL contains the full line from _SCRN0
	; change the background
	push hl
	call wait_vblank
	ld bc, _SCRN0
	add hl, bc
	ld a, _SEGMENT_TILE ; current segments as ttl
	ld [hl], a

	pop hl
	ld bc, _SEGMENTS_TTL
	add hl, bc
	ld a, [_PLAYER_SEGMENTS_COUNT] ; current segments as ttl
	ld [hl], a

	; if _ITEM_PICKED, _PLAYER_SEGMENTS_COUNT++ and not decrement the list
	; else DECREMENT the current _SEGMENTS_TTL list without _PLAYER_SEGMENT_COUNT++
	; this will create a new segment without decrementing and the next ones will
	; have the TTL increased by 1

	; check item
	ld a, [_ITEM_PICKED]
	or a
	jr z, .draw_segments_no_item

	; item picked
	xor a
	ld [_ITEM_PICKED], a ; reset flag

	ld a, [_PLAYER_SEGMENTS_COUNT]
	add 1
	ld [_PLAYER_SEGMENTS_COUNT], a
	; check for max segments
	cp 255
	jr z, .draw_segments_max_segments_reached

	jr .draw_segments_end
	.draw_segments_no_item:

	; check all the SEGMENTS_TTL and decrement until reaching 0
	ld hl, _SEGMENTS_TTL
	ld bc, _SEGMENTS_TTL_TOTAL
	ld de, _SCRN0
	.draw_segments_loop:
	ld a, [hl]
	or a ; is 0?
	jr z, .draw_segments_loop_end_iteration ; already 0, so do nothing
	dec a
	ld [hl], a

	or a
	jr nz, .draw_segments_loop_end_iteration ; is 0 now?

	ld a, _BLANK_TILE
	call wait_vblank
	ld [de], a

	.draw_segments_loop_end_iteration:
	inc hl
	inc de
	dec bc
	ld a, b
	or c
	jr nz, .draw_segments_loop

	.draw_segments_end:
	ret

	.draw_segments_max_segments_reached:
	; well...
	call game_over
	ret


; player sprite (OAM)
draw_player:

	; --------------------------------
	; PLAYER
	; --------------------------------

	call wait_vblank

	; player X
	ld hl, _PLAYER_POS_X 
	ld a, [_PLAYER_DIR_X]
	add a, [hl]
	ld [hl], a ; save position
	ld hl, _PLAYER_SPRITE_POS_X ; update the OAM with the new position
	ld [hl], a

	; player Y
	ld hl, _PLAYER_POS_Y
	ld a, [_PLAYER_DIR_Y]
	add a, [hl]
	ld [hl], a ; save position
	ld hl, _PLAYER_SPRITE_POS_Y ; update the OAM with the new position
	ld [hl], a

	; player sprite index
	ld hl, _PLAYER_SPRITE_INDEX
	ld a, [_PLAYER_INDEX_SPRITE]
	ld [hl], a

	; since we mirror only X or Y but not X AND Y at the same time,
	; use those absolute values (always the same palette and default params)

	; mirror Y?
	ld a, [_PLAYER_MIRRORED_Y]
	or a
	jr nz, .draw_mirror_y
	; no mirror
	ld a, %00000000
	ld [_PLAYER_SPRITE_ATTR], a
	jr .draw_check_mirror_x
	.draw_mirror_y:
	ld a, %01000000
	ld [_PLAYER_SPRITE_ATTR], a
	jr .draw_check_mirror_end

	; mirror X?
	.draw_check_mirror_x:
	ld a, [_PLAYER_MIRRORED_X]
	or a
	ld a, [_PLAYER_SPRITE_ATTR]
	jr nz, .draw_mirror_x
	; no mirror
	ld a, %00000000
	ld [_PLAYER_SPRITE_ATTR], a
	jr .draw_check_mirror_end
	.draw_mirror_x:
	ld a, %00100000
	ld [_PLAYER_SPRITE_ATTR], a

	.draw_check_mirror_end:

	ret


; check for collisions between walls, segments and/or items;
; if collided with an item, add score and relocate - in that
; case some VRAM operations will be performed
check_collisions:

	; --------------------------------
	; CHECK COLLISIONS WITH WALLS
	; --------------------------------

	; check colisions with WALLS

	; col X
	ld a, [_PLAYER_POS_X]

	cp 160 ; 20 * 8, right wall
	jr z, .check_collisions_set_game_over

	cp 8 ; left wall (+8 "offset")
	jr z, .check_collisions_set_game_over

	;col Y
	ld a, [_PLAYER_POS_Y]

	cp 152 ; (18 * 8) + 8, the last tile the player can move (18 tiles height plus half of the 16 offset - our sprites are 8x8)
	jr z, .check_collisions_set_game_over

	cp 16 ; the first tile the player can move (8 + 16 'cause it begins "off screen")
	jr z, .check_collisions_set_game_over

	; --------------------------------
	; CHECK COLLISIONS WITH ITSELF
	; --------------------------------

	; get the position from the segments block
	ld a, [_PLAYER_POS_X]
	ld b, a
	ld a, [_PLAYER_POS_Y]
	ld c, a
	push bc ; save x / y

	call pixels_to_map_index
	; HL now have the _SEGMENTS_TTL position
	ld bc, _SEGMENTS_TTL
	add hl, bc
	ld a, [hl] ; current position
	or a
	pop bc ; B, player_x / c, player_y

	jr nz, .check_collisions_set_game_over

	; --------------------------------
	; CHECK COLLISIONS WITH ITEM
	; --------------------------------
	
	ld a, [_ITEM_POS_X]
	cp b ; X axis
	jr nz, .no_col_item

	ld a, [_ITEM_POS_Y]
	cp c ; Y axis
	jr nz, .no_col_item

	ld a, 1
	ld [_ITEM_PICKED], a

	call get_free_position ; BC

	ld a, b
	ld [_ITEM_POS_X], a
	ld a, c
	ld [_ITEM_POS_Y], a

	; draw_item in the NEW position
	; (this will call a wait_vblank)
	call draw_item

	; inc score and draw
	; (this will call a wait_vblank)
	call inc_score_and_draw

	; check it score > 255
	ld a, [_SCORE_VAL]
	sub 255
	jr z, .check_collisions_set_game_over

	.no_col_item:
	ret

	.check_collisions_set_game_over:
	call game_over
	ret


; "game over" function
; stop the game for a while, turn screen black, reset
game_over:
	
	ld bc, 8000
	call delay

	call wait_vblank

	call fade_out

	call shutdown_LCD

	call load_board_scrn
	call reset_score_digits_sprite_index
	call reset_item_sprite

	call init_logic

	; show screen
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON
	ld [rLCDC], a

	call draw_player

	call draw_item

	call fade_in

	ret


; ------------------------------------------

include "utils.asm"
include "tiles.asm"
include "maps.asm"