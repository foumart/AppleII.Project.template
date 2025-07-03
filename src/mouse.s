********************************
* MOUSE.TRACK.HGR.POINTER      *
* RECOLLECTED BY NONCHO SAVOV  *
* AT FOUMARTGAMES.COM 2024-25  *
********************************
* ORIGINAL TEXT BASED TRACKER  *
* WRITTEN BY SANDY MOSSBERG    *
* (C) 1985 BY MICROSPARC. INC  *
********************************
* FOR MERLIN COMPILER
* SOURCE: https://www.applefritter.com/appleii-box/APPLE2/AppleMouseII/AppleMouseII.pdf
********************************
PTR = $06        ;POINTER, TEMP STORAGE
CH = $24         ;COLUMN
CV = $25         ;ROW
BASL = $28       ;LEFT CHAR OF CURRENT ROW
DOSWARM = $3D0   ;WRM-START (PRO)DOS
KBD = $C000      ;KEYBOARD INPUT
STROBE = $C010   ;KEYBOARD STROBE
LINPRT = $ED24   ;PRINTDECIMAL OF A,X
PRBLNK = $F948   ;PRINT 3 BLANKS
TEXT = $FB39     ;SETNORMAL TEXT WINDOW
TABV = $FB5B     ;SETROW IN A-REG
HOME = $FC58     ;HOMECURSOR, CLEAR SCREEN
CROUT = $FD8E    ;OUTPUT CR
COUT = $FDED     ;OUTPUT CHAR
********************************
* SCREENHOLE EQUATES:
********************************
FIRMXL = $478
FIRMYL = $4F8
FIRMXH = $578
FIRMYH = $5F8
FIRMBTN = $778
********************************
* OFFSETS TO MOUSE ENTRY POINTS:
********************************
SETMSE = $12
READMSE = $14
CLMPMSE = $17
HOMEMSE = $18
INITMSE = $19
*
**********************************************
* TEMPORARY STORAGE FOR BLIT CURSOR AND STATE:
**********************************************
SRCXLO = $7400
SRCXHI = $7401
SRCYLO = $7402
SRCYHI = $7403
HGRXLO = $7404
HGRXHI = $7405
HGRYLO = $7406
HGRYHI = $7407
TMPA   = $7408
TMPB   = $7409
TMPQ   = $740A
TXTX   = $740B
TXTY   = $740C
MODVAL = $7410      ; Modulo value (HGR cell width)
*****************************
* BLITLIB PARAMETER ADDRESSES
*****************************
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

    ORG $7500
********************************
*        INITIALIZE            *
********************************
    JSR CHKMOUS     ;CHECK FOR MOUSE FIRMWARE
    LDA #$91        ;CTRL-Q
    JSR COUT        ;SET 40 COL
    LDY #INITMSE
    JSR CALLFRM     ;INITIALIZE MOUSE FIRMWARE
    JSR FMTSCR      ;FORMAT SCREEN
    LDY #SETMSE
    LDA #1          ;SET PASSIVE MODE
    JSR CALLFRM     ;START MOUSE
    LDY #CLMPMSE
    JSR SETCLMP     ;SET NEW CLAMPING VALUES
    LDA #0          ; FOR X-COORDINATE
    JSR CALLFRM     ;CLAMP-X COORDINATE
    LDY #CLMPMSE
    JSR SETCLMP     ;SET NEW CLAMPING VALUES
    LDA #1          ; FOR Y-COORDINATE
    JSR CALLFRM     ;CLAMP-Y COORDINATE
    LDY #HOMEMSE
    JSR CALLFRM     ;HOME MOUSE POSITION
    LDA #14         ;Initialize modulo value for HGR width
    STA MODVAL
    BIT STROBE      ;RESET KEYBOARD STROBE
********************************
* TRACK THE MOUSE
********************************
    LDY #READMSE
    JSR CALLFRM     ;READ INITIAL POS
    BCC IN2         ;SET INITIAL CURSOR (ALWAYS)
IN1
    LDY #READMSE
    JSR CALLFRM     ;Read Mouse position
    JSR PRTDATA     ;Print data to screen
    LDA FIRMBTN,Y   ;Get Mouse button status
    LDY CH
    AND #%00100000  ;TEST BIT 5
    BEQ IN3         ;X,Y unchanged
    LDA OLDCHAR     ;X,Y changed so
    STA (BASL),Y    ; restore screen char over text cursor
    JSR SETCOR      ;Calculate cursor position
    JSR DRWCUR      ;Set BLITLIB cursor position
IN2
    JSR SETPOSN     ;Set text cursor position
    LDA (BASL),Y
    STA OLDCHAR     ;Save screen char under text cursor
IN3
    LDA #"^"
    STA (BASL),Y    ;Print text cursor
    JSR BLITLIB     ;Draw Cursor
    BIT KBD         ;Check keypress
    BPL IN1         ;No keypress, Loop back
********************************
* QUIT - AFTER KEYPRESS
********************************
    JSR TEXT        ;SET TEXT MODE
    BIT STROBE      ;Reset keyboard strobe
    LDA OLDCHAR
    STA (BASL),Y    ;Kill cursorY
    LDY #SETMSE
    LDA #0
    JSR CALLFRM     ;Turn Mouse off
    LDA #4
    JSR TABV
    JSR CROUT
    JMP DOSWARM     ;Exit to Applesoft

************************
* Draw graphic cursor
************************
DRWCUR
    LDA #$04        ; width in pixels
    STA B_WDTH      ; $600C
    LDA #$07        ; height in pixels
    STA B_HGHT      ; $6006
    LDA HGRXHI      ; dest X high byte (0 or 1)
    STA B_DXLO      ; $600B
    LDA HGRXLO      ; dest X low byte (0-255)
    STA B_DXHI      ; $600A
    LDA HGRYLO      ; dest Y (0–191)
    STA B_DY        ; $6009
    LDA #$01        ; Bite-level blit mode
    STA B_MODE      ; $6012
    LDA #$00        ; overwrite mode or XOR mode
    STA B_OVRWR     ; $6013
    LDA #$00        ; source X byte offset
    STA B_SRCX      ; $6003 store X
** Calculate source Y offset as (SRCXLO % MODVAL) * 7
    LDA SRCXLO      ; Using the source mouse X
    JSR MODULO      ; apply % MODVAL
    STA TMPQ        ; TMPQ = SRCXLO % MODVAL
    LDA TMPQ
    ASL A           ; *2
    CLC
    ADC TMPQ        ; *3 (A = 2A + SRCXLO)
    ASL A           ; *6
    CLC
    ADC TMPQ        ; *7
    ; lda #$00 ;tmp
    STA B_SRCY      ; $6004 store Y
    RTS

*********
* MODULO
*********
MODULO
    LSR A
MODULOLOOP
    CMP MODVAL
    BCC MODULODONE
    SEC
    SBC MODVAL
    BCS MODULOLOOP
MODULODONE
    RTS

*****************
* SET HGR COORDS
*****************
SETCOR
    LDY N         ; Slot offset
    LDA FIRMXL,Y
    STA SRCXLO
    LDA FIRMXH,Y
    STA SRCXHI
    LDA FIRMYL,Y
    STA SRCYLO
    LDA FIRMYH,Y
    STA SRCYHI
** X: MouseX (0–959) to HGR X (0–279) ---
** MouseX / 4
    LDA SRCXHI
    LSR A
    STA TMPA
    LDA SRCXLO
    ROR A
    STA TMPB
    LDA TMPA
    LSR A
    STA HGRXHI
    LDA TMPB
    ROR A
    STA HGRXLO
** MouseX / 16
    LDA SRCXHI
    LSR A
    STA TMPA
    LDA SRCXLO
    ROR A
    STA TMPB
    LDA TMPA
    LSR A
    STA TMPA
    LDA TMPB
    ROR A
    STA TMPB
    LDA TMPA
    LSR A
    STA TMPA
    LDA TMPB
    ROR A
    STA TMPB
    LDA TMPA
    LSR A
    STA TMPA
    LDA TMPB
    ROR A
    STA TMPB
    LDA TMPA
    LSR A
    STA TMPA
    LDA TMPB
    ROR A
    STA TMPB
** Add TMPA:TMPB to HGRXHI:HGRXLO with carry
    CLC
    LDA HGRXLO
    ADC TMPB
    STA HGRXLO
    LDA HGRXHI
    ADC TMPA
    STA HGRXHI
** Clamp SCDX to 0–279
    LDA HGRXHI
    CMP #$02
    BCC OKX
    LDA #$01
    STA HGRXHI
    LDA #$17
    STA HGRXLO
OKX
** Y: MouseY (0–959) to HGR Y (0–191) ---
    LDA SRCYHI
    STA TMPA
    LDA SRCYLO
    STA TMPB
** Divide TMPA:TMPB by 5, result in HGRYHI:HGRYLO
    LDA #0
    STA HGRYHI
    STA HGRYLO
YDIV5LOOP
    LDA TMPA
    CMP #0
    BNE YDIV5CONT
    LDA TMPB
    CMP #5
    BCC YDIV5DONE
YDIV5CONT
    SEC
    LDA TMPB
    SBC #5
    STA TMPB
    LDA TMPA
    SBC #0
    STA TMPA
    INC HGRYLO
    BNE YDIV5LOOP
    INC HGRYHI
    JMP YDIV5LOOP
** Clamp SCDY to 0–191
YDIV5DONE
    LDA HGRYLO
    CMP #$C0
    BCC OKY
    LDA #$BF
    STA HGRYLO
OKY
    RTS

***************************
* SET TEXT CURSOR POSITION
***************************
** Set Cursor row
SETPOSN
    LDX N
    LDA FIRMYH,X
    STA PTR+2
    LDY #-1
    LDA FIRMYL,X
IN4
    SEC
IN5
    SBC #40      ;Y-units per row
    INY
    BCS IN5
    DEC PTR+2
    BPL IN4
    TYA
    STA TXTY     ; Save row here
    JSR TABV
** Set Cursor column
    LDA FIRMXH,X
    STA PTR+2
    LDY #-1
    LDA FIRMXL,X
IN6
    SEC
IN7
    SBC #24      ;X-units per column
    INY
    BCS IN7
    DEC PTR+2
    BPL IN6
    STY TXTX     ; Save column here
    STY CH
    RTS

***********************************
* SET NEW FIRMWARE CLAMPING VALUES
***********************************
*   FIRMXL/H = lo boundary
*   FIRMYL/H = hi boundary
*
SETCLMP
    LDA #0         ;Min=0
    STA FIRMXL
    STA FIRMXH
    LDA #$BF       ;Max=959 ($3BF)
    STA FIRMYL
    LDA #3
    STA FIRMYH
    RTS

*********************************
* PRINT Data Line TO SCREEN
*********************************
PRTDATA
    LDA CV
    PHA           ;Save entry row
    LDA CH
    PHA           ;Save entry column
    LDA #22
    JSR TABV
    LDA #5
    STA CH
    LDY N         ;Slot offset
    LDA FIRMXH,Y  ;Hi byte X-coordinate
    LDX FIRMXL,Y  ;Lo byte X-coordinate
    JSR LINPRT    ;Print X-coordinate
    JSR PRBLNK    ;Print 3 spaces
    LDA #15
    STA CH
    LDY N         ;Slot offset
    LDA FIRMYH,Y  ;Hi byte Y-coordinate
    LDX FIRMYL,Y  ;Lo bytre Y-coordinate
    JSR LINPRT    ;Print Y-coordinate
    JSR PRBLNK    ;Print 3 spaces
    LDA #26
    STA CH
    LDY N         ;Slot offset
    LDA FIRMBTN,Y
    LDX #8        ;Bit counter
IN8
    ASL
    PHA
    BCC IN9       ;Clear bit found
    LDA #"1"      ;Set bit found
    HEX 2C        ;Skip next 2 bytes
IN9
    LDA #"0"
    JSR COUT      ;Print bit status
    PLA
    DEX           ;Decrement bit counter
    BPL IN8       ;Get another bit
    PLA
    STA CH        ;Restore entry column
    PLA
    JMP TABV      ;Restore entry row

*********************************
* CALL MOUSE FIRMWARE:
*********************************
*    X = Cn
*    Y = n0
*    A = USER DEFINED
*
CALLFRM
    PHA
    LDA (PTR),Y      ;Set lo byte of Mouse
    STA FIRMADR+1    ; firmware routine
    LDX CN           ;Entry X-reg
    LDY N0           ;Entry Y-reg
    PLA              ;Entry A-reg
FIRMADR
    JMP $0000        ;Set by CHKMOUS & CALLFRM

*********************************
* FORMAT SCREEN:
*********************************
FMTSCR
    JSR HOME
    LDA #20
    JSR TABV
    LDX #0
INA
    LDA TXHDR,X  ;Print header
    BEQ INB
    JSR COUT
    INX
    BNE INA         ;Always
INB
    LDA #22
    JSR TABV
    LDA #3
    STA CH
    LDA #"X"        ;Print status line
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

TXHDR
    ASC "  *** APPLE MOUSE TRACKING STATION ***"
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
CHKMOUS
    LDX #8         ;Slot counter (+1)
    LDA #0         ;Lo byte of Cn00
    STA PTR
    LDA #$C8       ;Hi byte of Cn00 (+1)
    STA PTR+1
INC
    DEC PTR+1      ;Decrement Cn
    DEX            ;Decrement slot counter
    BEQ NOMOUSE    ;Mouse firmware not found
    LDY #$C        ;Offset to Cn0C
    LDA (PTR),Y    ;Get byte
    CMP #$20       ;Is it 1st ID byte?
    BNE INC        ;No. Check next slot
    LDY #$FB       ;Offset to CnFB
    LDA (PTR),Y    ;Get byte
    CMP #$D6       ;Is it 2nd byte?
    BNE INC        ;No. Check next slot
*********************************
* MOUSE FIRMWARE FOUND:
*********************************
    LDA PTR+1
    STA FIRMADR+2  ;Set hi byte of slot
    STA CN         ;Save Cn for X-reg
    ASL            ;Shift n to hi nibble
    ASL
    ASL
    ASL
    STA N0         ;Save n0 for Y-reg
    STX N          ;Sve slot #
    RTS

*********************************
* MOUSE FIRMWARE NOT LOCATED:
*********************************
NOMOUSE
    JSR HOME
    LDX #0
IND
    LDA TXNOMSE,X   ;Print message
    BEQ TOBASIC
    JSR COUT
    INX
    BNE IND         ;Always
TOBASIC
    JMP DOSWARM
*
TXNOMSE
    HEX 878D
    ASC "MOUSE FIRMWARE NOT FOUND..."
    DFB 00

***********************
* STORAGE LOCATIONS:
***********************
N DS 1,0       ;Slot #
CN DS 1,0      ;X-reg setup
N0 DS 1,0      ;Y-reg setup
OLDCHAR DS 1,0 ;Screen char replaced by cursor
