; Example of main Assembly file, to be compiled and run from address $4000

    ORG $4000

    PUT macros.s

START
    JSR HOME

    ; Example of macros usage and how to pass parameters in
    POS_UPDATE #0;#21

    LDX #0             ; Counter

UNDERLINE_LOOP
    LDA #83            ; ASCII "–"
    JSR COUT           ; print it
    INX
    CPX #40
    BNE UNDERLINE_LOOP

    POS_UPDATE #4;#22
    LDX #0

HELLO_WORLD_TYPE
    LDA HELLO_WORLD_TEXT,X   ; Print message letter-by-letter
    BEQ COMPLETE
    ORA #$80
    JSR COUT
    INX
    BNE HELLO_WORLD_TYPE

COMPLETE
    RTS

    PUT vars.s
