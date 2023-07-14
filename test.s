			processor	6502

			include		"7800.h"

			SEG.U		data
			ORG			$40

;-------------------------------------------------------------------------------
; Simple sprite example

xpos		ds.b	1	      	;X Position of sprite
ypos    	ds.b    1           ;Y Position of sprite
temp    	ds.b    1
dlpnt		ds.w	1
dlend		ds.b	12			;Index of end of each DL
sprite		ds.b	0			;sprite, changed by controller button

;-------------------------------------------------------------------------------
; Mega7800 variables

JOYMODE		ds.b	1			; Mega7800 state or standard pad dir read
								; Bits: 7-4, player 0, 3-0, player 1
								
								; Bits 3-2 low (of player) indicate Mega7800 attached
			
								; If mega7800 is attached --
								
								; Bit 0:	0: Extended (3/6 button) mode
								;			1: Standard (2 button / light gun) mode
								
								; Bit 1:	Extended:	0: 6 button
								;						1: 3 button
								;			Standard:	0: light gun mode
								;						1: controller mode
	
JOYDIR		ds.b	1			; RLDU directions (of player)
JOYBTN0		ds.b	1			; SACB (0|1)
JOYBTN1		ds.b	1			; MXYZ (0|1)
JOYBTN0P	ds.b	1			; SACB (0|1)

AUDIOSTATE	ds.b	1
AUDIOVOL	ds.b	1

;-------------------------------------------------------------------------------

			SEG			ROM
			ORG			$8000

RESET:		

	sei                     ;Disable interrupts
	cld                     ;Clear decimal mode
	

;******** Atari recommended startup procedure

	lda     #$07
	sta     INPTCTRL        ;Lock into 7800 mode
	lda     #$7F
	sta     CTRL            ;Disable DMA
	lda     #$00            
	sta     OFFSET
	sta     INPTCTRL
	ldx     #$FF            ;Reset stack pointer
	txs
	
;************** Clear zero page and hardware ******

	ldx     #$40
	lda     #$00
crloop1    
	sta     $00,x           ;Clear zero page
	sta	$100,x		;Clear page 1
	inx
	bne     crloop1

;************* Clear RAM **************************

    ldy     #$00            ;Clear Ram
    lda     #$18            ;Start at $1800
    sta     $81             
    lda     #$00
    sta     $80
crloop3
    lda     #$00
    sta     ($80),y         ;Store data
    iny                     ;Next byte
    bne     crloop3         ;Branch if not done page
    inc     $81             ;Next page
    lda     $81
    cmp     #$20            ;End at $1FFF
    bne     crloop3         ;Branch if not

    ldy     #$00            ;Clear Ram
    lda     #$22            ;Start at $2200
    sta     $81             
    lda     #$00
    sta     $80
crloop4
    lda     #$00
    sta     ($80),y         ;Store data
    iny                     ;Next byte
    bne     crloop4         ;Branch if not done page
    inc     $81             ;Next page
    lda     $81
    cmp     #$27            ;End at $27FF
    bne     crloop4         ;Branch if not

    ldx     #$00
    lda     #$00
crloop5                         ;Clear 2100-213F
    sta     $2100,x
    inx
    cpx     #$40
    bne     crloop5
        
;************* Reset Audio Stream **********

	jsr		AudioStreamReset

;************* Build DLL *******************

; 20 blank lines

    ldx	#$00                   
    lda     #$4F            ;16 lines
    sta     $1800,x  	      
    inx
    lda     #$21		;$2100 = blank DL
    sta	$1800,x
    inx
    lda     #$00
    sta	$1800,x
    inx                   
	lda     #$44            ;4 lines
	sta     $1800,x        
	inx
	lda     #$21
	sta	$1800,x
	inx
	lda     #$00
	sta	$1800,x
    	inx
        
; 192 mode lines divided into 12 regions

    ldy     #$00
DLLloop2                         
    lda     #$4F            ;16 lines
    sta     $1800,x        
    inx
    lda     DLPOINTH,y
    sta	$1800,x
    inx
    lda     DLPOINTL,y
    sta	$1800,x
    inx
    iny
    cpy     #$0D            ;12 DLL entries
    bne     DLLloop2


; 26 blank lines
                 
    lda     #$4F            ;16 lines
    sta     $1800,x  	      
    inx
    lda     #$21		;$2100 = blank DL
    sta	$1800,x
    inx
    lda     #$00
    sta	$1800,x
    inx                   
	lda     #$4A            ;10 lines
	sta     $1800,x        
	inx
	lda     #$21
	sta	$1800,x
	inx
	lda     #$00
	sta	$1800,x

    	
;***************** Setup Maria Registers ****************
	
        lda     #$18            ;DLL at $1800
	sta	DPPH
	lda	#$00
	sta	DPPL
	lda	#$18		;Setup Palette 0
	sta	P0C1
	lda	#$38
	sta	P0C2
	lda	#$58
	sta	P0C3
	lda	#$43		;Enable DMA
	sta	CTRL
	lda	#$00		;Setup ports to read mode
	sta	CTLSWA
	lda		#$14			; Setup ports to dual firebutton mode
	sta	CTLSWB
	
	lda	#$40		;Set initial X position of sprite
	sta	xpos
        
mainloop
	bit		MSTAT		;Wait for VBLANK to start
	bpl 	mainloop

	; store last button state to get pressed buttons
	lda		JOYBTN0
	sta		JOYBTN0P
	
	jsr		Mega7800ReadControllers

	; do audio controls based on pressed buttons
	; pressed = ~last | current, active low
	
	lda		JOYBTN0P
	eor		#$ff
	ora		JOYBTN0
	sta		JOYBTN0P

	; A button, play, pause, resume
	
	lda		JOYBTN0P
	and		#%01000000
	bne		.anbtna

	; play / pause / resume audio track 0 on A press
	bit		AUDIOSTATE
	bpl		.play		; not playing, play!
	bvc		.pause		; playing but not paused, pause!

	; otherwise were playing and paused, so unpause!
	jsr		AudioStreamResume		; resume stream
	lda		#$80
	bne		.doneas

.pause
	jsr		AudioStreamPause		; pause stream
	lda		#$c0
	bne		.doneas

.play	
	lda		#0						; track 0
	jsr		AudioStreamPlayTrack	; play it!
	lda		#31
	sta		AUDIOVOL				; set volume to max
	jsr		AudioStreamSetVolume
	lda		#$80
.doneas
	sta		AUDIOSTATE
	bne		.anbtnb

.anbtna
	lda		JOYBTN0P
	and		#%00010000
	bne		.anbtnb
	
	; stop audio track on B press
	jsr		AudioStreamStop			; stop stream
	lda		#0
	sta		AUDIOSTATE
	
.anbtnb

	; and do some volume up and down too

	lda		JOYDIR		; directions
    and     #$20		;Pushed Down?
    bne     .notvdown		

	lda		AUDIOVOL
	beq		.notvdown	; decrement downto 0
	dec		AUDIOVOL
	bpl		.setvol

.notvdown
	lda		JOYDIR		; directions
    and     #$10		;Pushed Up?
    bne     .notvup		

	lda		AUDIOVOL
	cmp		#31			; increment upto 31
	beq		.notvup
	inc		AUDIOVOL
	
.setvol
	lda		AUDIOVOL
	jsr		AudioStreamSetVolume

.notvup

	; set sprite based on button press

	lda		JOYBTN0
	and		#%10000000
	beq		.btns
	lda		JOYBTN0
	and		#%01000000
	beq		.btna
	lda		JOYBTN0
	and		#%00100000
	beq		.btnc
	lda		JOYBTN0
	and		#%00010000
	beq		.btnb

	lda		JOYBTN1
	and		#%01000000
	beq		.btnx
	lda		JOYBTN1
	and		#%00100000
	beq		.btny
	lda		JOYBTN1
	and		#%00010000
	beq		.btnz
	
	lda		#0
	beq		.done
	
.btns
	lda		#1
	bne		.done
.btna
	lda		#2
	bne		.done
.btnb
	lda		#3
	bne		.done
.btnc
	lda		#4
	bne		.done
.btnx
	lda		#5
	bne		.done
.btny
	lda		#6
	bne		.done
.btnz
	lda		#7

.done	sta	sprite


	lda		JOYDIR		; directions
	and	#$80		;Pushed Right?
	bne	skip1
	ldx	xpos		;Move sprite to right
	inx
	stx	xpos
skip1
	lda		JOYDIR		; directions
	and 	#$40		;Pushed Left?
	bne 	skip2
	ldx 	xpos		;Move sprite to left
	dex
	stx 	xpos
skip2
	lda		JOYDIR		; directions
    and     #$20		;Pushed Down?
    bne     skip3		
    ldx     ypos		;Move sprite down
    cpx	#176	
    beq	skip3		;Dont move if we are at the bottom
    inx
    stx     ypos	
skip3
	lda		JOYDIR		; directions
    and     #$10		;Pushed Up?
    bne     skip4		
    ldx     ypos		;Move sprite up
    beq	skip4		;Dont move if we are at the top
    dex			
    stx     ypos
skip4

;********************** reset DL ends ******************
	
	ldx 	#$0C
	lda	#$00
dlclearloop
	dex
	sta	dlend,x
	bne	dlclearloop
	
	
;******************** build DL entries *********************

        lda     ypos		;Get Y position
   	and	#$F0		
   	lsr 			;Divide by 16
   	lsr	
   	lsr	
   	lsr	
   	tax
   	lda	DLPOINTL,x	;Get pointer to DL that this sprite starts in
   	sta	dlpnt
   	lda	DLPOINTH,x
   	sta	dlpnt+1
   	
   	;Create DL entry for upper part of sprite
   	
   	ldy	dlend,x		;Get the index to the end of this DL
   	lda	sprite
	sta     (dlpnt),y	;Low byte of data address
	iny
	lda	#$40		;Mode 320x1
	sta     (dlpnt),y
	iny 
	lda	ypos		
	and	#$0F		
	ora	#$a0
	sta     (dlpnt),y
	iny
	lda	#$1F		;Palette 0, 1 byte wide
	sta     (dlpnt),y
	iny
	lda	xpos		;Horizontal position
    sta     (dlpnt),y
    sty	dlend,x
        
    lda	ypos
    and	#$0F		;See if sprite is entirely within this region
    beq	doneDL		;branch if it is
        
    ;Create DL entry for lower part of sprite 
        
    inx			;Next region
    lda	DLPOINTL,x	;Get pointer to next DL
   	sta	dlpnt
   	lda	DLPOINTH,x
   	sta	dlpnt+1
        ldy	dlend,x		;Get the index to the end of this DL
	lda	sprite
	sta     (dlpnt),y
	iny
	lda	#$40		;Mode 320x1
	sta     (dlpnt),y
	iny 
	lda	ypos
	and	#$0F
	eor	#$0F
	sta	temp
	lda	#$a0
	clc
	sbc 	temp
	sta     (dlpnt),y
	iny
	lda	#$1F		;Palette 0, 1 byte wide
	sta     (dlpnt),y
	iny
	lda	xpos		;Horizontal position
	sta     (dlpnt),y
	sty	dlend,x
doneDL

;************** add DL end entry on each DL *****************************

	ldx	#$0C
dlendloop
	dex
	lda	DLPOINTL,x
	sta	dlpnt
	lda	DLPOINTH,x
   	sta	dlpnt+1
   	ldy 	dlend,x
   	iny
   	lda	#$00
   	sta	(dlpnt),y
   	txa
	bne 	dlendloop   	
   	
vbloop
	bit		MSTAT		;Wait for VBLANK to end
	bmi 	vbloop
	
	jmp     mainloop	;Loop



;Pointers to the DLs

DLPOINTH
    .byte   $22,$22,$22,$22,$23,$23,$23,$23,$24,$24,$24,$24
DLPOINTL
    .byte   $00,$40,$80,$C0,$00,$40,$80,$C0,$00,$40,$80,$C0

;************** Graphic Data *****************************
; Simley face, S, A, B, C, X, Y, Z

	org $a000	
	.byte     %00111100, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
	org $a100	
	.byte     %00111100, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
    org $a200	
	.byte     %01000010, %01111100, %10000010, %11111100, %01111100, %10000010, %00010000, %11111110 
    org $a300	
	.byte     %01000010, %01111100, %10000010, %11111100, %01111100, %10000010, %00010000, %11111110 
    org $a400	
	.byte     %10011001, %10000010, %10000010, %10000010, %10000010, %01000100, %00010000, %01000000
    org $a500	
	.byte     %10011001, %10000010, %10000010, %10000010, %10000010, %01000100, %00010000, %01000000
    org $a600	
	.byte     %10100101, %00000010, %10000010, %10000010, %10000000, %00101000, %00010000, %00100000
    org $a700	
	.byte     %10100101, %00000010, %10000010, %10000010, %10000000, %00101000, %00010000, %00100000
    org $a800	
	.byte     %10000001, %01111100, %11111110, %11111100, %10000000, %00010000, %00010000, %00010000
    org $a900	
	.byte     %10000001, %01111100, %11111110, %11111100, %10000000, %00010000, %00010000, %00010000
    org $aA00	
	.byte     %10100101, %10000000, %10000010, %10000010, %10000000, %00101000, %00101000, %00001000
    org $aB00	
	.byte     %10100101, %10000000, %10000010, %10000010, %10000000, %00101000, %00101000, %00001000
    org $aC00	
	.byte     %01000010, %10000010, %01000100, %10000010, %10000010, %01000100, %01000100, %00000100
    org $aD00	
	.byte     %01000010, %10000010, %01000100, %10000010, %10000010, %01000100, %01000100, %00000100
    org $aE00	
	.byte     %00111100, %01111100, %00111000, %11111100, %01111100, %10000010, %10000010, %11111110
    org $aF00	
	.byte     %00111100, %01111100, %00111000, %11111100, %01111100, %10000010, %10000010, %11111110

;-------------------------------------------------------------------------------

			include		"mega7800.s"
			include		"AudioStream.s"

;-------------------------------------------------------------------------------

IRQ			rti

;-------------------------------------------------------------------------------
; Cart reset vector
;-------------------------------------------------------------------------------

			ORG		$fff8
			.byte	$FF			; Region verification
			.byte	$87			; ROM start $8000
			.word	#IRQ		; fffa		NMI
			.word	#RESET		; fffc		RESET
			.word	#IRQ		; fffe		IRQ
