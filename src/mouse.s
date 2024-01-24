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
PTR = $06 ;POINTER, TEMP STORAGE
CH = $24 ;COLUMN
CV = $25 ;ROW
BASL = $28 ;LEFT CHAR OF CURRENT ROW (to be explored how it draws in double hi-res with $29)
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
SETMSE = $12
READMSE = $14
CLAMPMSE = $17
HOMEMSE = $18
INITMSE = $19
*
    ORG $8000
********************************
*        INITIALIZE            *
********************************
    ;JSR TEXT ;SET TEXT MODE
    JSR CHKMOUSE ;CHECK FOR MOUSE FIRMWARE
    ;LDA #$91 ;CTRL-Q SET 40 COL
    ;LDA #$12 ;CTRL-R SET 80 COL
    ;JSR COUT ;set mode ^^
    LDY #INITMSE
    JSR CALLFIRM ;INITIALIZE MOUSE FIRMWARE
    JSR FMTSCR ;FORMAT SCREEN
    LDY #SETMSE
    LDA #1 ;SET PASSIVE MODE
    JSR CALLFIRM ;START MOUSE
    LDY #CLAMPMSE
    JSR SETCLAMP ;SET NEW CLAMPING VALUES
    LDA #0 ; FOR X-COORDINATE
    JSR CALLFIRM ;CLAMP-X COORDINATE
    LDY #CLAMPMSE
    JSR SETCLAMP ;SET NEW CLAMPING VALUES
    LDA #1 ; FOR Y-COORDINATE
    JSR CALLFIRM ;CLAMP-Y COORDINATE
    LDY #HOMEMSE
    JSR CALLFIRM ;HOME MOUSE POSITION
    BIT STROBE ;RESET KEYBOARD STROBE
********************************
* TRACK THE MOUSE
********************************
TRACKMOUS
    LDY #READMSE
    JSR CALLFIRM ;READ INITIAL POS
    BCC IN2 ;SET INITIAL CURSOR (ALWAYS)
IN1
    LDY #READMSE
    JSR CALLFIRM ;Read Mouse position
    JSR PRTDATA ;Print data to screen
    JSR DCURSOR
    LDA BUTTON,Y ;Get Mouse button status
    LDY CH
    AND #%00100000 ;TEST BIT 5
    BEQ IN3 ;X,Y unchanged
    LDA OLDCHAR ;X,Y changed so
    STA (BASL),Y ; restore screen char
IN2
    JSR SETPOSN ;Set cursor position
    LDA (BASL),Y
    STA OLDCHAR ;Save screen char
IN3
    LDA #"^"
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
    JSR CALLFIRM ;Turn Mouse off
    LDA #4
    JSR TABV
    JSR CROUT
    JMP DOSWARM ;Exit to Applesoft
*********************************
*SET CURSOR POS
*********************************
*SET CURSOR ROW:
*
SETPOSN
    LDX N
    LDA YH,X
    STA PTR+2
    LDY #-1
    LDA YL,X
IN4
    SEC
IN5
    SBC #40 ;Y-units per row
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
IN6
    SEC
IN7
    SBC #24 ;X-units per column
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
SETCLAMP
    LDA #0 ;Min=0
    STA XL
    STA XH
    LDA #$BF ;Max=959 ($3BF)
    STA YL
    LDA #3
    STA YH
    RTS
*********************************
* PRINT Data Line TO SCREEN
*********************************
PRTDATA
    LDA CV
    PHA ;Save entry row
    LDA CH
    PHA ;Save entry column
    LDA #23
    JSR TABV
    LDA #3
    STA CH
    LDY N ;Slot offset
    LDA XH,Y ;Hi byte X-coordinate
    LDX XL,Y ;Lo byte X-coordinate
    JSR LINPRT ;Print X-coordinate
    JSR PRBLNK
    LDA #11
    STA CH
    LDY N ;Slot offset
    LDA YH,Y ;Hi byte Y-coordinate
    LDX YL,Y ;Lo bytre Y-coordinate
    JSR LINPRT ;Print Y-coordinate
    JSR PRBLNK
    LDA #20
    STA CH
    LDY N ;Slot offset
    LDA BUTTON,Y
    LDX #8 ;Bit counter
IN8
    ASL
    PHA
    BCC IN9 ;Clear bit found
    LDA #"1" ;Set bit found
    HEX 2C ;Skip next 2 bytes
IN9
    LDA #"0"
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
CALLFIRM
    PHA
    LDA (PTR),Y ;Set lo byte of Mouse
    STA FIRMADR+1 ; firmware routine
    LDX CN ;Entry X-reg
    LDY N0 ;Entry Y-reg
    PLA ;Entry A-reg
FIRMADR
    JMP $0000 ;Set by CHKMOUSE & CALLFIRM
*********************************
* FORMAT SCREEN:
*********************************
FMTSCR
    ;JSR HOME
    LDA #22
    JSR TABV
    LDX #0
INA
    LDA TXHDR,X ;Print header
    BEQ INB
    JSR COUT
    INX
    BNE INA ;Always
INB
    LDA #23
    JSR TABV
    LDA #1
    STA CH
    LDA #"X" ;Print status line
    JSR COUT
    LDA #"="
    JSR COUT
    LDA #9
    STA CH
    LDA #"Y"
    JSR COUT
    LDA #"="
    JSR COUT
    LDA #17
    STA CH
    LDA #"B"
    JSR COUT
    LDA #"="
    JSR COUT
    LDA #"%"
    JMP COUT
*
TXHDR
    ASC "Mouse debug:"
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
CHKMOUSE
    LDX #8 ;Slot counter (+1)
    LDA #0 ;Lo byte of Cn00
    STA PTR
    LDA #$C8 ;Hi byte of Cn00 (+1)
    STA PTR+1
INC
    DEC PTR+1 ;Decrement Cn
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
NOMOUSE
    JSR HOME
    LDX #0
IND
    LDA TXNOMSE,X ;Print message
    BEQ TOBASIC
    JSR COUT
    INX
    BNE IND ;Always
TOBASIC
    JMP DOSWARM

DCURSOR
    RTS ; TODO : FIX!
    ; Define coordinates
    ; X coordinates are in the range 0-279, which is more than 256, hence the need for low and high bytes
    ; write lo X0
    LDA CH
    LSR A
    STA $6006
    ; write hi X0
    ;LDA CH
    STA $6007

    ; write lo X1
    ;LDA CH
    TAX ; transfer the accumulator value to the X register
    INX ; increment the X register by 1
    TXA ; transfer the X register value to the accumulator
    STA $6009
    ; write hi X1
    ;LDA CH
    STA $600A

    ; write Y0
    LDA CV
    LSR A
    STA $6008
    ; write Y1
    ;LDA $6008
    TAX ; transfer the accumulator value to the X register
    INX ; increment the X register by 1
    TXA ; transfer the X register value to the accumulator
    STA $600B
    
    ;LDA #$03
    ;STA $6005 ; Address to set Arguments for Color and Page
    ;JSR $6010 ; Call the FDRAW SetColor function - set the COLOR to current ARG

    ; Draw the rectangle
    JSR $6022 ; Call the FDRAW FillRect function - draws a rectangle filled with the current color

    ; switch to AUX to draw there as well
    ;STA $C055 ; Set write to auxiliary bank

    ; Draw the rectangle
    ;JSR $6022 ; Call the FDRAW FillRect function - draws a rectangle filled with the current color

   ; STA $C054 ; Set write back to main memory bank
    
    ; Return
    RTS

TXNOMSE
    HEX 878D
    ASC "MOUSE FIRMWARE NOT FOUND..."
    DFB 00
***********************
* STORAGE LOCATIONS:
***********************
N
    DS 1,0 ;Slot #
CN
    DS 1,0 ;X-reg setup
N0
    DS 1,0 ;Y-reg setup
OLDCHAR
    DS 1,0 ;Screen char replaced by cursor
