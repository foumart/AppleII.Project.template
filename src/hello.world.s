; Example of main Assembly file, to be compiled and run from address $4000

    ORG $4000

    PUT macros.s

START
    JSR HOME

    ; Example of macros usage and how to pass parameters in
    POS_UPDATE #6;#21

    LDA #0
    TAX

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
