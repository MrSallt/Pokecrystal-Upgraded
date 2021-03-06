GetFrontpic:
	ld a, [wCurPartySpecies]
	ld [wCurSpecies], a
	and a
	ret z
	ldh a, [rSVBK]
	push af
	call _GetFrontpic
	pop af
	ldh [rSVBK], a
	jp CloseSRAM

FrontpicPredef:
	ld a, [wCurPartySpecies]
	ld [wCurSpecies], a
	and a
	ret z
	ldh a, [rSVBK]
	push af
	xor a
	ldh [hBGMapMode], a
	call _GetFrontpic
	ld a, BANK(vTiles3)
	ldh [rVBK], a
	call GetAnimatedFrontpic
	xor a
	ldh [rVBK], a
	pop af
	ldh [rSVBK], a
	jp CloseSRAM

_GetFrontpic:
	ld a, BANK(sScratch)
	call GetSRAMBank
	push de
	call GetBaseData ; [wCurSpecies] and [wCurForm] are already set
	ld a, [wBasePicSize]
	and $f
	ld b, a
	push bc
	call GetFrontpicPointer
	ld a, BANK(wDecompressScratch)
	ldh [rSVBK], a
	ld a, b
	ld de, wDecompressScratch
	call FarDecompress
	; Save decompressed size
	swap e
	swap d
	ld a, d
	and $f0
	or e
	ld [sScratch], a
	pop bc
	ld hl, sScratch + 1 tiles
	ld de, wDecompressScratch
	call PadFrontpic
	pop hl
	push hl
	ld de, sScratch + 1 tiles
	ld c, 7 * 7
	ldh a, [hROMBank]
	ld b, a
	call Get2bpp
	pop hl
	ret

GetFrontpicPointer:
	; c = species
	ld a, [wCurPartySpecies]
	ld c, a
	; b = form
	ld a, [wCurForm]
	ld b, a
	; bc = index
	call GetCosmeticSpeciesAndFormIndex
	dec bc
	ld hl, FrontPicPointers
rept 3
	add hl, bc
endr
	ld a, BANK(FrontPicPointers)
	call GetFarByte
	push af
	inc hl
	ld a, BANK(FrontPicPointers)
	call GetFarHalfword
	pop bc
	ret

GetAnimatedFrontpic:
	ld a, $1
	ldh [rVBK], a
	push hl
	ld de, sScratch + 1 tiles
	ld c, 7 * 7
	ldh a, [hROMBank]
	ld b, a
	call Get2bpp
	pop hl
	ld de, 7 * 7 tiles
	add hl, de
	push hl
	ld a, BANK(wBasePicSize)
	ld hl, wBasePicSize
	call GetFarWRAMByte
	pop hl
	and $f
	ld de, wDecompressScratch + 5 * 5 tiles
	ld c, 5 * 5
	cp 5
	jr z, .got_dims
	ld de, wDecompressScratch + 6 * 6 tiles
	ld c, 6 * 6
	cp 6
	jr z, .got_dims
	ld de, wDecompressScratch + 7 * 7 tiles
.got_dims
	; Get animation size (total - base sprite size)
	ld a, [sScratch]
	sub c
	ret z ; Return if there's no animation
	ld c, a
	push hl
	push bc
	call LoadFrontpicTiles
	pop bc
	pop hl
	ld de, wDecompressScratch
	ldh a, [hROMBank]
	ld b, a
; Improved routine by pfero
; https://gitgud.io/pfero/axyllagame/commit/486f4ed432ca49e5d1305b6402cc5540fe9d3aaa
	; If we can load it in a single pass, just do it
	ld a, c
	sub (128 - 7 * 7)
	jr c, .no_overflow
	; Otherwise, we load the first part...
	inc a
	ld [sScratch], a
	ld c, (127 - 7 * 7)
	call Get2bpp
	; Then move up a bit and load the rest
	ld de, wDecompressScratch + (127 - 7 * 7) tiles
	ld hl, vTiles4
	ldh a, [hROMBank]
	ld b, a
	ld a, [sScratch]
	ld c, a
.no_overflow
	jp Get2bpp

LoadFrontpicTiles:
	ld hl, wDecompressScratch
; bc = c * $10
	swap c
	ld a, c
	and $f
	ld b, a
	ld a, c
	and $f0
	ld c, a
; load the first c bytes to round down bc to a multiple of $100
	push bc
	call LoadFrontpic
	pop bc
; don't access echo ram
	ld a, c
	and a
	jr z, .handle_loop
	inc b
	jr .handle_loop
; load the remaining bytes in batches of $100
.loop
	push bc
	ld c, $0
	call LoadFrontpic
	pop bc
.handle_loop
	dec b
	jr nz, .loop
	ret

GetBackpic:
	ld a, [wCurPartySpecies]
	and a
	ret z
	; c = species
	ld a, [wCurPartySpecies]
	ld c, a
	; b = form
	ld a, [wCurForm]
	ld b, a
	ldh a, [rSVBK]
	push af
	ld a, $6
	ldh [rSVBK], a
	push de
	; bc = index
	call GetCosmeticSpeciesAndFormIndex
	dec bc
	ld hl, BackPicPointers
rept 3
	add hl, bc
endr
	ld a, BANK(BackPicPointers)
	call GetFarByte
	push af
	inc hl
	ld a, BANK(BackPicPointers)
	call GetFarHalfword
	ld de, wDecompressScratch
	pop af
	call FarDecompress
	ld hl, wDecompressScratch
	ld c, 6 * 6
	call FixBackpicAlignment
	pop hl
	ld de, wDecompressScratch
	ldh a, [hROMBank]
	ld b, a
	call Get2bpp
	pop af
	ldh [rSVBK], a
	ret

GetTrainerPic:
	ld a, [wTrainerClass]
	and a
	ret z
	cp NUM_TRAINER_CLASSES
	ret nc
	call ApplyTilemapInVBlank
	xor a
	ldh [hBGMapMode], a
	ld hl, TrainerPicPointers
	ld a, [wTrainerClass]
	dec a
	ld bc, 3
	rst AddNTimes
	ldh a, [rSVBK]
	push af
	ld a, $6
	ldh [rSVBK], a
	push de
	ld a, BANK(TrainerPicPointers)
	call GetFarByte
	push af
	inc hl
	ld a, BANK(TrainerPicPointers)
	call GetFarHalfword
	pop af
_Decompress7x7Pic:
	ld de, wDecompressScratch
	call FarDecompress
	pop hl
	ld de, wDecompressScratch
	ld c, 7 * 7
	ldh a, [hROMBank]
	ld b, a
	call Get2bpp
	pop af
	ldh [rSVBK], a
	call ApplyTilemapInVBlank
	ld a, $1
	ldh [hBGMapMode], a
	ret

GetPaintingPic:
	ld a, [wTrainerClass]
	call ApplyTilemapInVBlank
	xor a
	ldh [hBGMapMode], a
	ld hl, PaintingPicPointers
	ld a, [wTrainerClass]
	ld bc, 3
	rst AddNTimes
	ldh a, [rSVBK]
	push af
	ld a, $6
	ldh [rSVBK], a
	push de
	ld a, BANK(PaintingPicPointers)
	call GetFarByte
	push af
	inc hl
	ld a, BANK(PaintingPicPointers)
	call GetFarHalfword
	pop af
	jr _Decompress7x7Pic

FixBackpicAlignment:
	push de
	push bc
	ld a, [wBoxAlignment]
	and a
	jr z, .keep_dims
	ld a, c
	cp 7 * 7
	ld de, 7 * 7 tiles
	jr z, .got_dims
	cp 6 * 6
	ld de, 6 * 6 tiles
	jr z, .got_dims
	ld de, 5 * 5 tiles

.got_dims
	ld a, [hl]
	lb bc, $0, $8
.loop
	rra
	rl b
	dec c
	jr nz, .loop
	ld a, b
	ld [hli], a
	dec de
	ld a, e
	or d
	jr nz, .got_dims

.keep_dims
	pop bc
	pop de
	ret

PadFrontpic:
	ld a, b
	sub 5
	jr z, .five
	dec a
	jr z, .six

.seven_loop
	ld c, 7 tiles
	call LoadFrontpic
	dec b
	jr nz, .seven_loop
	ret

.six
	ld c, 7 tiles
	xor a
	call .Fill
.six_loop
	ld c, 1 tiles
	xor a
	call .Fill
	ld c, 6 tiles
	call LoadFrontpic
	dec b
	jr nz, .six_loop
	ret

.five
	ld c, 7 tiles
	xor a
	call .Fill
.five_loop
	ld c, 2 tiles
	xor a
	call .Fill
	ld c, 5 tiles
	call LoadFrontpic
	dec b
	jr nz, .five_loop
	ld c, 7 tiles
	xor a
	; fallthrough

.Fill:
	ld [hli], a
	dec c
	jr nz, .Fill
	ret

LoadFrontpic:
	ld a, [wBoxAlignment]
	and a
	jr nz, .x_flip
.left_loop
	ld a, [de]
	inc de
	ld [hli], a
	dec c
	jr nz, .left_loop
	ret

.x_flip
	push bc
.right_loop
	ld a, [de]
	inc de
	ld b, a
	xor a
	rept 8
	rr b
	rla
	endr
	ld [hli], a
	dec c
	jr nz, .right_loop
	pop bc
	ret

PICS_FIX EQU $36
EXPORT PICS_FIX

	push hl
	push bc
	sub BANK("Pics 1") - PICS_FIX
	ld c, a
	ld b, 0
	ld hl, .PicsBanks
	add hl, bc
	ld a, [hl]
	pop bc
	pop hl
	ret

.PicsBanks:
	db BANK("Pics 1")  ; BANK("Pics 1") + 0
	db BANK("Pics 2")  ; BANK("Pics 1") + 1
	db BANK("Pics 3")  ; BANK("Pics 1") + 2
	db BANK("Pics 4")  ; BANK("Pics 1") + 3
	db BANK("Pics 5")  ; BANK("Pics 1") + 4
	db BANK("Pics 6")  ; BANK("Pics 1") + 5
	db BANK("Pics 7")  ; BANK("Pics 1") + 6
	db BANK("Pics 8")  ; BANK("Pics 1") + 7
	db BANK("Pics 9")  ; BANK("Pics 1") + 8
	db BANK("Pics 10") ; BANK("Pics 1") + 9
	db BANK("Pics 11") ; BANK("Pics 1") + 10
	db BANK("Pics 12") ; BANK("Pics 1") + 11
	db BANK("Pics 13") ; BANK("Pics 1") + 12
	db BANK("Pics 14") ; BANK("Pics 1") + 13
	db BANK("Pics 15") ; BANK("Pics 1") + 14
	db BANK("Pics 16") ; BANK("Pics 1") + 15
	db BANK("Pics 17") ; BANK("Pics 1") + 16
	db BANK("Pics 18") ; BANK("Pics 1") + 17
	db BANK("Pics 19") ; BANK("Pics 1") + 18
	db BANK("Pics 20") ; BANK("Pics 1") + 19
	db BANK("Pics 21") ; BANK("Pics 1") + 20
	db BANK("Pics 22") ; BANK("Pics 1") + 21
	db BANK("Pics 23") ; BANK("Pics 1") + 22
	db BANK("Pics 24") ; BANK("Pics 1") + 23
	
