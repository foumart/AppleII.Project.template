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
LINPRT = $ED24   ;PRINT DECIMAL OF A,X
PRBLNK = $F948   ;PRINT 3 BLANKS
TEXT = $FB39     ;SETNORMAL TEXT WINDOW
TABV = $FB5B     ;SETROW IN A-REG
HOME = $FC58     ;HOMECURSOR, CLEAR SCREEN
CROUT = $FD8E    ;OUTPUT CR
COUT = $FDED     ;OUTPUT CHAR
********************************
* SCREENHOLE EQUATES:
********************************
FIRMAL = $478
FIRMBL = $4F8
FIRMAH = $578
FIRMBH = $5F8
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
SRCXLO = $7400   ;Firmware provided mouse X low byte (0-959; 0-255)
SRCXHI = $7401   ;Firmware provided mouse X high byte (0-959; 0-4)
SRCYLO = $7402   ;Firmware provided mouse Y low byte (0-959; 0-255)
SRCYHI = $7403   ;Firmware provided mouse Y high byte (0-959; 0-4)
HGRXLO = $7404   ;Graphic Cursor X position low byte (0-279; 0-255 step:7)
HGRXHI = $7405   ;Graphic Cursor X position high byte (0-279; 0-1)
HGRY   = $7406   ;Graphic Cursor Y position (0-192)
TMPA   = $7407
TMPB   = $7408
TMPX   = $7409
TMPY   = $740A
TXTX   = $740B   ;Text cursor X position (0-40)
TXTY   = $740C   ;Text cursor Y position (0-24)
SLOT   = $740D   ; Slot number the Mouse firmware resides
COL80  = $740F   ; Use 80 COL and Double Hi-Res
MODVAL = $7410   ; Modulo value (HGR cell width)
MULTPCD = $7411
PRODUCTLO = $7412
PRODUCTHI = $7413
MULTPLR = $7414
*****************************
* BLITLIB PARAMETER ADDRESSES
*****************************
BLITLIB = $6000
B_WDTH  = $600C
B_HGHT  = $6006
B_DXHI  = $600B
B_DXLO  = $600A
B_DY    = $6009
B_MODE  = $6012
B_OVRWR = $6013
B_SRCX  = $6003
B_SRCY  = $6004

    ORG $7500
********************************
*        INITIALIZE            *
********************************
    ; Check if we're already in 80-column mode
    LDA $C01F       ; Read 80-column status
    STA COL80       ; Switch 80 Col ON(1) or OFF(0)
    BMI SKIP40COL   ; If bit 7 is set, we're in 80-col mode
    LDA #$91        ; CTRL-Q to exit into
    JSR COUT        ; 40 COL
SKIP40COL
    JSR CHKMOUS     ; CHECK FOR MOUSE FIRMWARE
    LDY #INITMSE
    JSR CALLFRM     ;INITIALIZE MOUSE FIRMWARE
    JSR FMTSCR      ;FORMAT SCREEN
    LDY #SETMSE
    LDA #1          ;SET PASSIVE MODE
    JSR CALLFRM     ;START MOUSE
    LDY #CLMPMSE
    JSR SETCLAMPX   ;SET NEW CLAMPING VALUES
    LDA #0          ; FOR X-COORDINATE
    JSR CALLFRM     ;CLAMP-X COORDINATE
    LDY #CLMPMSE
    JSR SETCLAMPY   ;SET NEW CLAMPING VALUES
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
IN2
    JSR SETPOSN     ;Set cursor positions
    JSR DRWCUR      ;Set BLITLIB cursor position
    LDA (BASL),Y
    STA OLDCHAR     ;Save screen char under text cursor
IN3
    LDA COL80       ; Check if we're in 80-column mode
    BEQ USE40COL    ; If COL80 = 0, use 40-col cursor
    LDA #66         ; 80-column mode arrow symbol
    JMP CURSORDONE
USE40COL
    LDA #"^"        ; 40-column mode arrow-like
CURSORDONE
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

***********************************
* Draw graphic cursor with BLITLIB
***********************************
DRWCUR
    LDA #$04        ; width in pixels
    STA B_WDTH      ; $600C
    LDA #$07        ; height in pixels
    STA B_HGHT      ; $6006
    
    LDA TXTX        ; Load text X position (0-40)
    JSR MULBY7      ; Multiply by 7 to get byte-level blit position
    STA B_DXLO      ; dest X - Low byte (0-255)
    LDA #0
    BCC NOOVERFLOW  ; If no carry, high byte is 0
    LDA #1          ; If carry, high byte is 1
NOOVERFLOW
    STA B_DXHI      ; dest X - High byte (0-1)
    
    LDA SRCYLO      ; dest Y (0–191)
    STA B_DY        ; $6009

** Calculate source spritesheet Y byte offset from mouse SRC X (0-560)
** With 40 positions for X we have to fill the 7 HGR (14 DHGR) pixels gap with frames from the spritesheet
    LDA SRCXLO
    JSR MODULO      ; reduced to % MODVAL
    JSR MULBY7      ; multiplied by 7
    STA B_SRCY      ; $6004 store Y
    
    LDA #$01        ; Bite-level blit mode
    STA B_MODE      ; $6012
    LDA #$00        ; overwrite mode or XOR mode
    STA B_OVRWR     ; $6013
    LDA #$00        ; source X byte offset
    STA B_SRCX      ; $6003 store X
    RTS

****************
* MULTIPLY BY 7
****************
MULBY7
    STA TMPA
    ASL A           ; *2
    CLC
    ADC TMPA        ; *3 (A = 2A + SRCXLO)
    ASL A           ; *6
    CLC
    ADC TMPA        ; *7
    RTS

***********
* MODULO %
***********
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

************************************
* SET CURSOR POSITIONS TEXT and HGR
************************************
** Get mouse position values from Firmware
SETPOSN
    LDX N
    LDA FIRMBH,X
    STA PTR+2
    STA SRCYHI
    LDY #-1
    LDA FIRMBL,X
    STA SRCYLO

IN4
    SEC
IN5
    SBC #8      ; Y-units per row
    INY
    BCS IN5
    DEC PTR+2
    BPL IN4
    TYA
    STA TXTY     ; Save text cursor position Y (row)
    JSR TABV

    LDA FIRMAH,X
    STA PTR+2
    STA SRCXHI
    LDY #-1
    LDA FIRMAL,X
    ;LSR A
    STA SRCXLO

IN6
    SEC
IN7
    SBC #28     ; X-units per column
    INY
    BCS IN7
    DEC PTR+2
    BPL IN6
    TYA
    STA TXTX     ; Save text cursor position X (column)
    STA CH

    RTS

***********************************
* SET NEW FIRMWARE CLAMPING VALUES
***********************************
SETCLAMPX
    LDA #0       
    STA FIRMAL
    STA FIRMAH
    LDA #$60        ;#193       ;Max=1120 ($230)
    STA FIRMBL
    LDA #4         ;#4
    STA FIRMBH
    RTS

SETCLAMPY
    LDA #0
    STA FIRMAL
    STA FIRMAH
    LDA #$C0       ;Max=192
    STA FIRMBL
    LDA #0
    STA FIRMBH
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
    LDA #3
    STA CH
    LDY N         ;Slot offset
    LDA SRCXHI    ;Hi byte X-coordinate
    LDX SRCXLO    ;Lo byte X-coordinate
    JSR LINPRT    ;Print hgr cursor X-coordinate
    JSR PRBLNK    ;Print 3 spaces
    LDA #10
    STA CH
    LDY N
    LDA #0
    LDX TXTX      ;Text cursor X-coordinate
    JSR LINPRT
    JSR PRBLNK
    LDA #17
    STA CH
    LDY N
    LDA SRCYHI    ;Hi byte Y-coordinate
    LDX SRCYLO    ;Lo bytre Y-coordinate
    JSR LINPRT    ;Print hgr cursor Y-coordinate
    JSR PRBLNK
    LDA #22
    STA CH
    LDY N
    LDA #0
    LDX TXTY      ;Text cursor Y-coordinate
    JSR LINPRT
    JSR PRBLNK
    LDA #30
    STA CH
    LDY N
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
    LDA #1
    STA CH
    LDA #"X"        ;Print status line
    JSR COUT
    LDA #"="
    JSR COUT
    LDA #15
    STA CH
    LDA #"Y"
    JSR COUT
    LDA #"="
    JSR COUT
    LDA #27
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
    STX N          ;Save slot #
    STX SLOT
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
