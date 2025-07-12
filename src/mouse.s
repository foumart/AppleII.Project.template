*******************************
* Mouse TEXT/HGR/DHGR Cursor  *
* Developed by NONCHO SAVOV   *
* (C) 2025 FoumartGames.com   *
*******************************
* Github: https://github.com/foumart/AppleII.Project.template

*******************************
* Credits: Text based Tracker *
* Written by SANDY MOSSBERG   *
* (C) 1985 Microsparc. inc    *
*******************************
* Source: https://www.applefritter.com/appleii-box/APPLE2/AppleMouseII/AppleMouseII.pdf

*******************************
* Credits: BLITTERANG by      *
* CROW COUSINS Micro Software *
*******************************
* Retro Apple II Software: https://crowcousins.com/retro-apple-ii-software/

*
* For MERLIN Compiler
* CALL 26368 from BASIC to run
* 

**********************
* Zero Page locations
**********************
PTR = $06           ; POINTER, temp storage
CH = $24            ; COLUMN - Horizontal Cursor Position (0 - 39/79)
CV = $25            ; ROW - Vertical Cursor Position (0 - 23)
BASL = $28          ; Left Char of current Row - Base Address of Text Cursor's Position

********************************
* RAM/ROM Soft switch locations
********************************
DOSWARM = $3D0      ; WRM-START (PRO)DOS
KBD = $C000         ; KEYBOARD INPUT
STROBE = $C010      ; KEYBOARD STROBE
LINPRT = $ED24      ; PRINT DECIMAL OF A,X
PRBLNK = $F948      ; PRINT 3 BLANKS
TEXT = $FB39        ; SETNORMAL TEXT WINDOW
TABV = $FB5B        ; SETROW IN A-REG
HOME = $FC58        ; HOME, CLEAR SCREEN
CROUT = $FD8E       ; OUTPUT CR
COUT = $FDED        ; OUTPUT CHAR

*********************
* SCREENHOLE EQUATES
*********************
FIRMAL = $478
FIRMBL = $4F8
FIRMAH = $578
FIRMBH = $5F8
FIRMBTN = $778

********************************
* OFFSETS TO MOUSE ENTRY POINTS
********************************
SETMSE = $12
READMSE = $14
CLMPMSE = $17
HOMEMSE = $18
INITMSE = $19

******************************
* BLITLIB Parameter Addresses
******************************
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

    ORG $6700       ; Not using BLITSHIFT, but if needed change the start address to $7400.

*********************************************************
* INITIALIZE - CALL 26368 ($6700), or CALL 29696 ($7400)
*********************************************************
** Check if we're already in 80-column mode and exit to 40 column mode or vice-versa
    LDA $C01F       ; Read 80-column status
    STA COL80       ; Switch 80 Col ON(1) or OFF(0)
    BMI SKIP40COL   ; If bit 7 is set, we're in 80-col mode
    LDA #$91        ; CTRL-Q to exit into
    JSR COUT        ; 40 COL
SKIP40COL
    JSR CHKMOUS     ; Check for Mouse Firmware
    LDY #INITMSE
    JSR CALLFRM     ; Initialize Mouse Firmware
    JSR FMTSCR      ; Format Text Screen
    LDY #SETMSE
    LDA #1          ; SET PASSIVE MODE
    JSR CALLFRM     ; Start Mouse
    LDY #CLMPMSE
    JSR SETCLAMPX   ; Set Clamping Values
    LDA #0          ;  for X-Coordinate
    JSR CALLFRM     ; CLAMP-X Coordinate
    LDY #CLMPMSE
    JSR SETCLAMPY   ; Set Clamping Values
    LDA #1          ;  for Y-Coordinate
    JSR CALLFRM     ; CLAMP-Y Coordinate
    LDY #HOMEMSE
    JSR CALLFRM     ; Home Mouse position
    LDA #14         ; Initialize modulo value for HGR width
    STA MODVAL
    BIT STROBE      ; Reset Keyboard Strobe
******************
* TRACK THE MOUSE
******************
    LDY #READMSE
    JSR CALLFRM     ; Read Initial Position
    BCC IN2         ; Set Initial Cursor
IN1
    LDY #READMSE
    JSR CALLFRM     ; Read Mouse position
    JSR PRTDATA     ; Print data to screen
    LDA FIRMBTN,Y   ; Get Mouse button status
    LDY CH
    AND #%00100000  ; Test Bit 5
    BEQ IN3         ; X,Y have not changed, skip
    LDA OLDCHAR     ; X,Y have changed so
    STA (BASL),Y    ;  restore screen char over text cursor
    JSR BLITLIB
IN2
    JSR GETPOS      ; Set cursor positions
    JSR SETCURSOR   ; Set BLITLIB cursor position
    JSR BLITLIB     ; Draw cursor arrow on HGR screen
    JSR GETPOS      ; Set cursor positions (again, TODO: check how to avoid)
    LDA (BASL),Y    ; Get screen char symbol under text cursor
    STA OLDCHAR     ;  and save it
IN3
    LDA COL80       ; Check if we're in 80-column mode
    BEQ USE40COL    ; If COL80 = 0, use 40-col cursor
    LDA #66         ; 80-column mode arrow symbol
    JMP CURSORDONE
USE40COL
    LDA #"^"        ; 40-column mode arrow-like
CURSORDONE
    STA (BASL),Y    ; Print text cursor
    BIT KBD         ; Check keypress
    BPL IN1         ; No keypress, Loop back
************************
* QUIT - AFTER KEYPRESS
************************
    JSR TEXT        ; Set Text mode
    BIT STROBE      ; Reset keyboard strobe
    LDA OLDCHAR
    STA (BASL),Y    ; Kill cursorY
    LDY #SETMSE
    LDA #0
    JSR CALLFRM     ; Turn Mouse off
    LDA #4
    JSR TABV
    JSR CROUT
    JMP DOSWARM     ; Exit to Applesoft

***********************************
* Draw graphic cursor with BLITLIB
***********************************
SETCURSOR
    LDA #$01        ; Set Bite-level blit mode
    STA B_MODE      ;  for BLITLIB - $6012
    LDA #$01        ; Set Overwrite mode or XOR mode
    STA B_OVRWR     ;  for BLITLIB - $6013
    LDA #$04        ; Set sprite width in pixels
    STA B_WDTH      ;  for BLITLIB - $600C
    LDA #$07        ; Set sprite height in pixels
    STA B_HGHT      ;  for BLITLIB - $6006
    
    LDA TXTX        ; Load text X position (0-40)
    JSR MULBY7      ; Multiply by 7 to get byte-level blit position
    STA B_DXLO      ; dest X - Low byte (0-255)
    LDA #0
    BCC NOOVERFLOW  ; If no carry, high byte is 0
    LDA #1          ; If carry, high byte is 1
NOOVERFLOW
    STA B_DXHI      ; dest X - High byte (0-1)
    
    LDA SRCYLO      ; Set destination on Screen for Y (0–191)
    STA B_DY        ;  for BLITLIB - $6009

** Calculate source spritesheet Y offset from the mouse source firmware clamped value for X (0-1119).
** With 40 positions for X we have to fill the 7 HGR (14 DHGR) pixel gap with frames from the spritesheet.
** There are a couple of micro-management checks regarding precise cursor position. TODO: to be improved.
    LDA SRCXHI
    CMP #1
    BEQ SCREEN1
    CMP #2
    BEQ SCREEN2
    CMP #3
    BEQ SCREEN3
    CMP #4
    BEQ SCREEN4
    LDA SRCXLO
    JMP SCREENDONE
SCREEN1
    LDA SRCXLO
    CMP #240
    BCC SCREEN1LOW
    CLC
    ADC #36
    JMP SCREENDONE
SCREEN1LOW
    CLC
    ADC #32
    JMP SCREENDONE
SCREEN2
    LDA SRCXLO
    CMP #240
    BCC SCREEN2_LOW
    CLC
    ADC #40
    JMP SCREENDONE
SCREEN2_LOW
    CLC
    ADC #36
    JMP SCREENDONE
SCREEN3
    LDA SRCXLO
    CLC
    ADC #12
    JMP SCREENDONE
SCREEN4
    LDA SRCXLO
    CLC
    ADC #16
    JMP SCREENDONE
SCREENDONE
    JSR MODULO      ; reduced to % MODVAL
    JSR MULBY7      ; and multiplied by 7 to accomodate the spritesheet height of each frame
    STA B_SRCY      ; BLITLIB $6004 - store Y spritesheet offset

** Check if we are near the right edge of the screen so we can avoid wrapping the cursor graphic.
** There are a few frames in the spritesheet that represent the cursor cropped at the edge.
    LDA SRCXHI
    CMP #4
    BNE SKIPXOFFSET
    LDA SRCXLO
    CMP #78
    BCC SKIPXOFFSET
    LDA #$00
    CLC
    ADC #2          ; Add offset to accumulator
    JMP STOREXOFFSET
SKIPXOFFSET
    LDA #$00
STOREXOFFSET
    STA B_SRCX      ; BLITLIB $6003 - store X spritesheet offset
    RTS

****************
* MULTIPLY BY 7
****************
MULBY7
    STA TMPA
    ASL A           ; *2
    CLC
    ADC TMPA        ; *3 (A = 2A + TMPA)
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

*********************************************
* Set Cursor Positions for both TEXT and HGR
*********************************************
** Get mouse position values from Firmware
GETPOS
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
    SBC #8          ; Y-units per row
    INY
    BCS IN5
    DEC PTR+2
    BPL IN4
    TYA
    STA TXTY        ; Save text cursor position Y (row)
    JSR TABV

    LDA FIRMAH,X
    STA PTR+2
    STA SRCXHI
    LDY #-1
    LDA FIRMAL,X
    STA SRCXLO

IN6
    SEC
IN7
    SBC #28         ; X-units per column
    INY
    BCS IN7
    DEC PTR+2
    BPL IN6
    TYA
    STA TXTX        ; Save text cursor position X (column)
    STA CH

    RTS

***********************************
* SET NEW FIRMWARE CLAMPING VALUES
***********************************
SETCLAMPX
    LDA #0
    STA FIRMAL
    STA FIRMAH      ; Max = 1120
    LDA #$60        ; #96 (1120 - 1024)
    STA FIRMBL
    LDA #4          ; #4 (*256)
    STA FIRMBH
    RTS

SETCLAMPY
    LDA #0
    STA FIRMAL
    STA FIRMAH
    LDA #$C0        ; Max = 192
    STA FIRMBL
    LDA #0
    STA FIRMBH
    RTS

****************************
* PRINT DATA LINE TO SCREEN
****************************
PRTDATA
    LDA CV
    PHA             ; Save entry row
    LDA CH
    PHA             ; Save entry column
    LDA #22
    JSR TABV
    LDA #3
    STA CH
    LDY N           ; Slot offset
    LDA SRCXHI      ; Hi byte X-coordinate
    LDX SRCXLO      ; Lo byte X-coordinate
    JSR LINPRT      ; Print HGR cursor X-coordinate
    JSR PRBLNK      ; Print 3 spaces
    LDA #10
    STA CH
    LDY N
    LDA #0
    LDX TXTX        ; Text cursor X-coordinate
    JSR LINPRT
    JSR PRBLNK
    LDA #17
    STA CH
    LDY N
    LDA SRCYHI      ; Hi byte Y-coordinate
    LDX SRCYLO      ; Lo bytre Y-coordinate
    JSR LINPRT      ; Print HGR cursor Y-coordinate
    JSR PRBLNK
    LDA #22
    STA CH
    LDY N
    LDA #0
    LDX TXTY        ; Text cursor Y-coordinate
    JSR LINPRT
    JSR PRBLNK
    LDA #30
    STA CH
    LDY N
    LDA FIRMBTN,Y
    LDX #8          ; Bit counter
IN8
    ASL
    PHA
    BCC IN9         ; Clear bit found
    LDA #"1"        ; Set bit found
    HEX 2C          ; Skip next 2 bytes
IN9
    LDA #"0"
    JSR COUT        ; Print bit status
    PLA
    DEX             ; Decrement bit counter
    BPL IN8         ; Get another bit
    PLA
    STA CH          ; Restore entry column
    PLA
    JMP TABV        ; Restore entry row

**********************
* CALL MOUSE FIRMWARE
**********************
*    X = Cn
*    Y = n0
*    A = USER DEFINED

CALLFRM
    PHA
    LDA (PTR),Y     ; Set low byte of Mouse firmware routine
    STA FIRMADR+1
    LDX CN          ; Entry X-reg
    LDY N0          ; Entry Y-reg
    PLA             ; Entry A-reg
FIRMADR
    JMP $0000       ; Set by CHKMOUS & CALLFRM

****************
* Format Screen
****************
FMTSCR
    JSR HOME
    LDA #20
    JSR TABV
    LDX #0
INA
    LDA TXHDR,X     ; Print header
    BEQ INB
    JSR COUT
    INX
    BNE INA         ; Always
INB
    LDA #22
    JSR TABV
    LDA #1
    STA CH
    LDA #"X"        ; Print status line
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

*********************************
* CHECK SLOTS FOR MOUSE FIRMWARE
*********************************
* SIGNATURE BYTES OF MOUSE FIRMWARE:
*     Cn0C = $20
*     CnFB = $D6

** Look for Mouse firmware:
CHKMOUS
    LDX #8          ; Slot counter (+1)
    LDA #0          ; Lo byte of Cn00
    STA PTR
    LDA #$C8        ; Hi byte of Cn00 (+1)
    STA PTR+1
INC
    DEC PTR+1       ; Decrement Cn
    DEX             ; Decrement slot counter
    BEQ NOMOUSE     ; Mouse firmware not found
    LDY #$C         ; Offset to Cn0C
    LDA (PTR),Y     ; Get byte
    CMP #$20        ; Is it 1st ID byte?
    BNE INC         ; No. Check next slot
    LDY #$FB        ; Offset to CnFB
    LDA (PTR),Y     ; Get byte
    CMP #$D6        ; Is it 2nd byte?
    BNE INC         ; No. Check next slot
***********************
* MOUSE FIRMWARE FOUND
***********************
    LDA PTR+1
    STA FIRMADR+2   ; Set hi byte of slot
    STA CN          ; Save Cn for X-reg
    ASL             ; Shift n to hi nibble
    ASL
    ASL
    ASL
    STA N0          ; Save n0 for Y-reg
    STX N           ; Save slot #
    STX SLOT
    RTS

*****************************
* MOUSE FIRMWARE NOT LOCATED
*****************************
NOMOUSE
    JSR HOME
    LDX #0
IND
    LDA TXNOMSE,X   ; Print message
    BEQ TOBASIC
    JSR COUT
    INX
    BNE IND         ; Always
TOBASIC
    JMP DOSWARM

TXHDR
    ASC "  *** APPLE MOUSE TRACKING STATION ***"
    DFB 00

TXNOMSE
    HEX 878D
    ASC "MOUSE FIRMWARE NOT FOUND..."
    DFB 00

********************
* Storage Locations
********************
N DS 1,0            ; Slot #
CN DS 1,0           ; X-reg setup
N0 DS 1,0           ; Y-reg setup
OLDCHAR DS 1,0      ; Screen char replaced by cursor

*****************************
* Storage for BLITLIB Cursor
*****************************
SRCXLO DS 1,0       ; Firmware provided mouse X low byte (0-959; 0-255)
SRCXHI DS 1,0       ; Firmware provided mouse X high byte (0-959; 0-4)
SRCYLO DS 1,0       ; Firmware provided mouse Y low byte (0-959; 0-255)
SRCYHI DS 1,0       ; Firmware provided mouse Y high byte (0-959; 0-4)
TMPA   DS 1,0       ; Helper temporary variable
TXTX   DS 1,0       ; Text cursor X position (0-40)
TXTY   DS 1,0       ; Text cursor Y position (0-24)
SLOT   DS 1,0       ; Slot number where the Mouse firmware resides
COL80  DS 1,0       ; Use 80 COL and Double Hi-Res
TEXTON DS 1,0       ; Text only
MODVAL DS 1,0       ; Modulo value (HGR cell width)
