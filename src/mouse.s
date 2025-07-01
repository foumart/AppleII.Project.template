********************************
* MOUSE.TRACK                  *
* RECOLLECTED BY NONCHO SAVOV  *
* AT FOUMARTGAMES.COM IN 2024  *
********************************
* WRITTEN BY SANDY MOSSBERG    *
* (C) 1985 BY MICROSPARC. INC  *
********************************
* FOR MERLIN COMPILER
* SOURCE: https://www.applefritter.com/appleii-box/APPLE2/AppleMouseII/AppleMouseII.pdf
*
* CODE AND VARIABLES ARE NOW ASSEMBLED AT $7400
* BLITLIB parameters remain at their original addresses
*
PTR = $06 ;POINTER, TEMP STORAGE
CH = $24 ;COLUMN
CV = $25 ;ROW
BASL = $28 ;LEFT CHAR OF CURRENT ROW
DOSWARM = $3D0 ;WRM-START (PRO)DOS
KBD = $C000 ;KEYBOARD INPUT
STROBE = $C010 ;KEYBOARD STROBE
LINPRT = $ED24 ;PRINTDECIMAL OF A,X
PRBLNK = $F948 ;PRINT 3 BLANKS
TEXT = $FB39 ;SETNORMAL TEXT WINDOW
TABV = $FB5B ;SETROW IN A-REG
HOME = $FC58 ;HOMECURSOR, CLEAR SCREEN
CROUT = $FD8E ;OUTPUT CR
COUT = $FDED ;OUTPUT CHAR
*
* SCREENHOLE EQUATES:
*
XL = $478
YL = $4F8
XH = $578
YH = $5F8
BUTTON = $778
*
* OFFSETS TO MOUSE ENTRY POINTS:
*
SETMSE  = $12
READMSE = $14
CLMPMSE = $17
HOMEMSE = $18
INITMSE = $19
*
* =========================
* TEMPORARY STORAGE FOR BLIT/BIRD CURSOR AND STATE
* =========================
TMPXLO = $7400
TMPXHI = $7401
TMPYLO = $7402
TMPYHI = $7403
SCDXLO = $7404
SCDXHI = $7405
SCDYLO = $7406
SCDYHI = $7407
*
* BLITLIB PARAMETER ADDRESSES
BLITLIB = $6000
B_WDTH  = $600C
B_HGHT  = $6006
B_DXLO  = $600B
B_DXHI  = $600A
B_DY    = $6009
B_MODE  = $6012
B_OVRWR = $6013
B_SRCX  = $6003
B_SRCY  = $6004
*
 ORG $7500
********************************
*        INITIALIZE            *
********************************
* JSR TEXT ;SET TEXT MODE
 JSR CHKMOUS ;CHECK FOR MOUSE FIRMWARE
 LDA #$91 ;CTRL-Q
 JSR COUT ;SET 40 COL
 LDY #INITMSE
 JSR CALLFRM ;INITIALIZE MOUSE FIRMWARE
 JSR FMTSCR ;FORMAT SCREEN
 LDY #SETMSE
 LDA #1 ;SET PASSIVE MODE
 JSR CALLFRM ;START MOUSE
 LDY #CLMPMSE
 JSR SETCLMP ;SET NEW CLAMPING VALUES
 LDA #0 ; FOR X-COORDINATE
 JSR CALLFRM ;CLAMP-X COORDINATE
 LDY #CLMPMSE
 JSR SETCLMP ;SET NEW CLAMPING VALUES
 LDA #1 ; FOR Y-COORDINATE
 JSR CALLFRM ;CLAMP-Y COORDINATE
 LDY #HOMEMSE
 JSR CALLFRM ;HOME MOUSE POSITION
 BIT STROBE ;RESET KEYBOARD STROBE
********************************
* TRACK THE MOUSE
********************************
* TRACKMOUS
 LDY #READMSE
 JSR CALLFRM ;READ INITIAL POS
 BCC IN2 ;SET INITIAL CURSOR (ALWAYS)
IN1 LDY #READMSE
 JSR CALLFRM ;Read Mouse position
 JSR PRTDATA ;Print data to screen
 JSR SETCOR
 JSR DRWCUR
 JSR BLITLIB
 LDA BUTTON,Y ;Get Mouse button status
 LDY CH
 AND #%00100000 ;TEST BIT 5
 BEQ IN3 ;X,Y unchanged
 LDA OLDCHAR ;X,Y changed so
 STA (BASL),Y ; restore screen char
IN2 JSR SETPOSN ;Set cursor position
 LDA (BASL),Y
 STA OLDCHAR ;Save screen char
IN3 LDA #"^"
 STA (BASL),Y ;Print cursor
 BIT KBD ;Check keypress
 BPL IN1 ;No keypress, Loop back
********************************
* QUIT
********************************
 BIT STROBE ;Reset keyboard strobe
 LDA OLDCHAR
 STA (BASL),Y ;Kill cursorY
 LDY #SETMSE
 LDA #0
 JSR CALLFRM ;Turn Mouse off
 LDA #4
 JSR TABV
 JSR CROUT
 JMP DOSWARM ;Exit to Applesoft
* Draw graphic cursor
DRWCUR LDA #$07         ; width in pixels
 STA $600C
 LDA #$07         ; height in pixels
 STA $6006
 LDA SCDXHI      ; dest X high byte (0 or 1)
 STA $600B
 LDA SCDXLO      ; dest X low byte (0–255)
 STA $600A
 LDA SCDYLO      ; dest Y (0–191)
 STA $6009
 LDA #$01        ; XOR mode; Bite-level blit mode
 STA $6012
 LDA #$00        ; overwrite mode
 STA $6013
 LDA #$00        ; source X byte offset
 STA $6003
; Calculate source Y offset as (SCDXHI % 8) * 7
 LDA SCDXLO
 AND #$07      ; SCDXLO % 8
 ASL A         ; *2
 ADC SCDXLO    ; *3 (A = 2A + A = 3A)
 ASL A         ; *6
 CLC
 ADC SCDXLO    ; *7
 STA $6004     ; BLIT
 RTS
SETCOR LDY N ; Slot offset
 LDA XL,Y
 STA TMPXLO
 LDA XH,Y
 STA TMPXHI
 LDA YL,Y
 STA TMPYLO
 LDA YH,Y
 STA TMPYHI
; --- X: MouseX (0–959) to HGR X (0–279) ---
 ; Scale X = MouseX / 4 + MouseX / 16 + MouseX / 32 (approximates MouseX * 280 / 960)
 LDA TMPXHI
 LSR A
 LSR A
 STA SCDXHI
 LDA TMPXLO
 LSR A
 LSR A
 STA SCDXLO
 ; Add MouseX / 16
 LDA TMPXHI
 LSR A
 LSR A
 LSR A
 LSR A
 CLC
 ADC SCDXHI
 STA SCDXHI
 LDA TMPXLO
 LSR A
 LSR A
 LSR A
 LSR A
 CLC
 ADC SCDXLO
 STA SCDXLO
 ; Handle carry
 LDA SCDXHI
 ADC #0
 STA SCDXHI
 ; Add MouseX / 32
 LDA TMPXHI
 LSR A
 LSR A
 LSR A
 LSR A
 LSR A
 CLC
 ADC SCDXHI
 STA SCDXHI
 LDA TMPXLO
 LSR A
 LSR A
 LSR A
 LSR A
 LSR A
 CLC
 ADC SCDXLO
 STA SCDXLO
 ; Handle carry
 LDA SCDXHI
 ADC #0
 STA SCDXHI
 ; Clamp to 0-279 (no branch needed)
 LDA SCDXHI
 CMP #$02
 BCS CLAMP_X
 JMP NO_CLAMP_X
CLAMP_X
 LDA #$01
 STA SCDXHI
 LDA #$17  ; 279 decimal
 STA SCDXLO
NO_CLAMP_X
; --- Improved Scale Y: MouseY (0–639) to HGR Y (0–191) ---
 LDA TMPYHI
 LSR A
 LSR A
 STA SCDYHI
 LDA TMPYLO
 LSR A
 LSR A
 STA SCDYLO
 ; Add MouseY / 16 (16-bit add)
 LDA TMPYLO
 LSR A
 LSR A
 LSR A
 LSR A
 CLC
 ADC SCDYLO
 STA SCDYLO
 LDA TMPYHI
 LSR A
 LSR A
 LSR A
 LSR A
 ADC SCDYHI
 STA SCDYHI
 ; Clamp SCDY to 0–191
 LDA SCDYLO
 CMP #$C0 ; 192
 BCC OK_Y
 LDA #$BF ; 191
 STA SCDYLO
OK_Y
 RTS
*********************************
*SET CURSOR POS
*********************************
*SET CURSOR ROW:
*
SETPOSN LDX N
 LDA YH,X
 STA PTR+2
 LDY #-1
 LDA YL,X
IN4 SEC
IN5 SBC #40 ;Y-units per row
 INY
 BCS IN5
 DEC PTR+2
 BPL IN4
 TYA
 JSR TABV
*
* SET COLUMN
*
 LDA XH,X
 STA PTR+2
 LDY #-1
 LDA XL,X
IN6 SEC
IN7 SBC #24 ;X-units per column
 INY
 BCS IN7
 DEC PTR+2
 BPL IN6
 STY CH
 RTS
*********************************
* SET NEW CLAMPING VALUES
*********************************
* Entry conditions:
*   XL/H = lo boundary
*   YL/H = hi boundary
*
SETCLMP LDA #0 ;Min=0
 STA XL
 STA XH
 LDA #$BF ;Max=959 ($3BF)
 STA YL
 LDA #3
 STA YH
 RTS
*********************************
* PRINT Data Line TO SCReeN
*********************************
PRTDATA LDA CV
 PHA ;Save entry row
 LDA CH
 PHA ;Save entry column
 LDA #22
 JSR TABV
 LDA #5
 STA CH
 LDY N ;Slot offset
 LDA XH,Y ;Hi byte X-coordinate
 LDX XL,Y ;Lo byte X-coordinate
 JSR LINPRT ;Print X-coordinate
 JSR PRBLNK
 LDA #15
 STA CH
 LDY N ;Slot offset
 LDA YH,Y ;Hi byte Y-coordinate
 LDX YL,Y ;Lo bytre Y-coordinate
 JSR LINPRT ;Print Y-coordinate
 JSR PRBLNK
 LDA #26
 STA CH
 LDY N ;Slot offset
 LDA BUTTON,Y
 LDX #8 ;Bit counter
IN8 ASL
 PHA
 BCC IN9 ;Clear bit found
 LDA #"1" ;Set bit found
 HEX 2C ;Skip next 2 bytes
IN9 LDA #"0"
 JSR COUT ;Print bit status
 PLA
 DEX ;Decrement bit counter
 BPL IN8 ;Get another bit
 PLA
 STA CH ;Restore entry column
 PLA
 JMP TABV ;Restore entry row
*********************************
* CALL MOUSE FIRMWARE:
*********************************
* ENTRY CONDITIONS:
*    X = Cn
*    Y = n0
*    A = USER DEFINED
*
CALLFRM PHA
 LDA (PTR),Y ;Set lo byte of Mouse
 STA FIRMADR+1 ; firmware routine
 LDX CN ;Entry X-reg
 LDY N0 ;Entry Y-reg
 PLA ;Entry A-reg
FIRMADR JMP $0000 ;Set by CHKMOUS & CALLFRM
*********************************
* FORMAT SCREEN:
*********************************
FMTSCR JSR HOME
 LDA #20
 JSR TABV
 LDX #0
INA LDA TXHDR,X ;Print header
 BEQ INB
 JSR COUT
 INX
 BNE INA ;Always
INB LDA #22
 JSR TABV
 LDA #3
 STA CH
 LDA #"X" ;Print status line
 JSR COUT
 LDA #"="
 JSR COUT
 LDA #13
 STA CH
 LDA #"Y"
 JSR COUT
 LDA #"="
 JSR COUT
 LDA #23
 STA CH
 LDA #"B"
 JSR COUT
 LDA #"="
 JSR COUT
 LDA #"%"
 JMP COUT
*
TXHDR ASC "  *** APPLE MOUSE TRACKING STATION ***"
 DFB 00
**********************************
* CHECK SLOTS FOR MOUSE FIRMWARE
**********************************
* SIGNATURE BYTES OF MOUSE FIRMWARE:
*     Cn0C = $20
*     CnFB = $D6
*
* Look for Mouse firmware:
* 
CHKMOUS LDX #8 ;Slot counter (+1)
 LDA #0 ;Lo byte of Cn00
 STA PTR
 LDA #$C8 ;Hi byte of Cn00 (+1)
 STA PTR+1
INC DEC PTR+1 ;Decrement Cn
 DEX ;Decrement slot counter
 BEQ NOMOUSE ;Mouse firmware not found
 LDY #$C ;Offset to Cn0C
 LDA (PTR),Y ;Get byte
 CMP #$20 ;Is it 1st ID byte?
 BNE INC ;No. Check next slot
 LDY #$FB ;Offset to CnFB
 LDA (PTR),Y ;Get byte
 CMP #$D6 ;Is it 2nd byte?
 BNE INC ;No. Check next slot
*********************************
* MOUSE FIRMWARE FOUND:
*********************************
 LDA PTR+1
 STA FIRMADR+2 ;Set hi byte of slot
 STA CN ;Save Cn for X-reg
 ASL ;Shift n to hi nibble
 ASL
 ASL
 ASL
 STA N0 ;Save n0 for Y-reg
 STX N ;Sve slot #
 RTS
*********************************
* MoUSE FIRMWARE NOT LOCATED:
*********************************
NOMOUSE JSR HOME
 LDX #0
IND LDA TXNOMSE,X ;Print message
 BEQ TOBASIC
 JSR COUT
 INX
 BNE IND ;Always
TOBASIC JMP DOSWARM
*
TXNOMSE HEX 878D
 ASC "MOUSE FIRMWARE NOT FOUND..."
 DFB 00
***********************
* STORAGE LOCATIONS:
***********************
N DS 1,0 ;Slot #
CN DS 1,0 ;X-reg setup
N0 DS 1,0 ;Y-reg setup
OLDCHAR DS 1,0 ;Screen char replaced by cursor