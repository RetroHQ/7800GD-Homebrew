;-------------------------------------------------------------------------------
; Read full state of controller port including mega7800 extended button read
; and fall-back to standard pad read if not present.
; This routine reads both control ports. If a Vox/SaveKey is present in port 1
; this will interfere with its functioning.
;-------------------------------------------------------------------------------

; JOYMODE	equ		xxxx				; Mega7800 state or standard pad dir read
 										; Bits: 7-4, player 0, 3-0, player 1
 										
 										; Bits 3-2 low (of player) indicate Mega7800 attached
										; Note: Just bit 3 can be used as non-Mega7800
										; controllers are sanitised to %111x in JOYMODE
 		
 										; If mega7800 is attached --
 									
 										; Bit 0:	0: Extended (3/6 button) mode
 										;			1: Standard (2 button / light gun) mode
 										
 										; Bit 1:	Extended:	0: 6 button
 										;						1: 3 button
 										;			Standard:	0: light gun mode
 										;						1: controller mode

										; Bits 3-2 high (of player) indicate a standard 7800 pad
										
										; Bit 0:	0: Single button stick detected

 	
; JOYDIR	equ		xxxx				; RLDU directions (of player)
; JOYBTN0	equ		xxxx				; SACB (0|1)
; JOYBTN1	equ		xxxx				; MXYZ (0|1)

;-------------------------------------------------------------------------------

			SUBROUTINE
Mega7800ReadControllers:
			ldy		#%00000000			; read select and strobe low
			ldx		#%00100010			; read select low, strobe high

			; directions are on the port always, so read first

			lda		SWCHA				; read directions
			sta		JOYDIR				; RLDU

			sty		SWCHA				; all bits low, starts extended pad read
			lda		#%00110011
			sta		CTLSWA				; drive u/d bits for both ports

			; first read is pad state (mega7800 connection and controller type)

			jsr		.read4bits			; for non-mega7800 this will be direction again
			sta		JOYMODE				; for mega7800, bits 3-2 will be 0, bits 1-0 are the mode

			; second read is 3 button support (SACB)

			jsr		.read4bits			; second read
			sta		JOYBTN0				; SACB
			
			; third read is 6 button support (MXYZ)
			
			jsr		.read4bits			; third read
			sta		JOYBTN1				; MXYZ

			sty		CTLSWA				; all back to read

			; sanitise the data a bit so people can just check button bits
			; regardless of what controller is connected
			
			lda		#%11000000			; mega7800 detection bits, port 0
			ldy		#%10000000			; mode/start button mask
			ldx		#%11110000			; button disable mask (active low)
			jsr		.sanitise

			lda		#%00001100			; mega7800 detection bits, port 1
			ldy		#%00001000			; mode/start button mask
			ldx		#%00001111			; button disable mask (active low)
			jsr		.sanitise

			; now read the proline buttons as well, if the controller is
			; mega7800 then A/B match LB/RB so adding them again wont hurt,
			; otherwise if its a 7800 controller, they need setting

			; port 0 read

			lda		#$04				; dual fire button for p0?
			and		CTLSWB
			beq		.p0s				; no, single

			bit		INPT4				; check for single fire, if set then revert to single button mode
			bmi		.p0dok
			
			lda		CTLSWB
			and		#~$04				; remove transistor driver for p0 dual fire
			sta		CTLSWB
			
.p0s:		lda		JOYMODE				; set single button joystick flag for p0
			and		#%11101111
			sta		JOYMODE
			
			lda		JOYBTN0
			bit		INPT4				; single fire down for p0?
			bpl		.p0sf				; yes, set A
			
			lda		CTLSWB				; no, re-enable dual button mode incase of stick swap
			ora		#$04				; add transistor driver for p0 dual fire
			sta		CTLSWB
			bne		.np0lf				; onto port 1

.p0dok:		lda		JOYBTN0
			bit		INPT0				; P0 right fire
			bpl		.np0rf
			and		#~$10				; set p0 B
.np0rf:		bit		INPT1				; P0 left fire
			bpl		.np0lf
.p0sf:		and		#~$40				; set p0 A

			; port 1 read

.np0lf:		tax							; save current button state for port 0
			lda		#$10				; dual fire button for p1?
			and		CTLSWB
			beq		.p1s				; no, single

			bit		INPT5				; check for single fire, if set then revert to single button mode
			bmi		.p1dok
			
			lda		CTLSWB
			and		#~$10				; remove transistor driver for p0 dual fire
			sta		CTLSWB
			
.p1s:		lda		JOYMODE				; set single button joystick flag for p1
			and		#%11111110
			sta		JOYMODE
			
			txa							; restore button state
			bit		INPT5				; single fire down for p0?
			bpl		.p1sf				; yes, set A

			lda		CTLSWB				; no, re-enable dual button mode incase of stick swap
			ora		#$10				; add transistor driver for p1 dual fire
			sta		CTLSWB
			bne		.np1lf				; done!

.p1dok:		txa							; restore button state
			bit		INPT2				; P0 right fire
			bpl		.np1rf
			and		#~$01				; set p1 B
.np1rf:		bit		INPT3				; P0 left fire
			bpl		.np1lf
.p1sf:		and		#~$04				; set p1 A
.np1lf:		sta		JOYBTN0

			rts

.read4bits:	tya							; zero
			jsr		.read2bits			; read 2 bits of controller data
			lsr							; shift them into correct position
			lsr

.read2bits:	sty		SWCHA				; strobe low, selects next data bit pair
			ora		SWCHA				; read 2 bits through l/r, u/d will be low as we are driving them
			stx		SWCHA				; strobe high
			rts

; Masks required to sanitise input data

DetectBits:	.byte	%11000000,%00001100	; port0 / port1 detect bits (L+R)
ModeMsk:	.byte	%10000000,%00001000	; start / mode bit
DisableMsk:	.byte	%11110000,%00001111	; all bits for port

; Enter with X as the port number (0,1)

.sanitise:	lda		DetectBits,x		; mega7800 detect bits for port X (LEFT+RIGHT)
			tay
			and		JOYMODE				; see if we have a mega7800 adapter
			bne		.nomega				; no, just read proline

			tya							; possible mega7800
			and		JOYDIR				; check direction bit also
			bne		.mega				; if they are also low, its bad joy data, otherwise mega7800 read

			; no, get button mask and remove any buttons for this port
			
.nomega		lda		DisableMsk,x		; set JOYMODE to %1111 when 7800 pad is present
			tay
			ora		JOYMODE
			sta		JOYMODE
			
			tya							; set SACB to high
			bne		.clear

			; this is a mega7800 read, if mode is pressed remove reserved
			; buttons and clear mode

.mega:		lda		ModeMsk,x			; mode button mask
			and		JOYBTN1				; mask just mode
			bne		.noMode				; no, skip
			
			; mode is pressed, remove mode, x, y, z and start

			lda		ModeMsk,x			; start mask

.clear:		ora		JOYBTN0				; clear S (mega mode) or SACB (7800 mode)
			sta		JOYBTN0

			lda		DisableMsk,x		; mask for MXYZ
			ora		JOYBTN1				; clear MXYZ
			sta		JOYBTN1

.noMode:	rts




