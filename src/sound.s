    ORG $7F00

TIMER = $7FFD ;Hopefully empty Addresses
PASS = $7FFE
TYPE = $7FFF

INIT
    LDA #$FF
    STA TIMER
    LDA #$FF
    STA PASS
    LDA #$00
    STA TYPE
    LDY TIMER
    
SOUND
    LDA $C030 ; BEEP HARDWARE
    LDA TYPE
    BEQ TYPE2SOUND ; Branch if ZERO
    ; TODO : FIX EFFECT TYPE1SOUND and TYPE2SOUND
    LDA TYPE
    CLC
    DEC TYPE
    BEQ TYPE1SOUND ; Branch if ZERO
    SBC TYPE,Y
    STA PASS
    JMP TYPE1SOUND


TYPE1SOUND
    DEC PASS
    DEC PASS
    LDX PASS
    JMP PAUSE

TYPE2SOUND
    DEC PASS
    LDX PASS

PAUSE
    DEX ; Decrement X reg
    BNE PAUSE ; Branch if not zero
    DEY
    BNE SOUND ; Branch if not zero

DONE
    RTS
