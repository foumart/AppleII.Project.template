UPDATE_POS = $FB5B  ; Routine to update the text screen position

HOME = $FC58        ; HOME, clear text screen
COUT = $FDED        ; Output character loaded in the accumulator

HELLO_WORLD_TEXT
    ASC "Have fun coding on Apple II !", $8D,
    DFB 00
