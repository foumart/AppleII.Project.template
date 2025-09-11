; Sets cursor position (HTAB / VTAB)
POS_UPDATE MAC
    LDA ]1          ; Set cursor horizontal position
    STA $24         ; Store in HTAB

    LDA ]2          ; Set cursor vertical position
    STA $25         ; Store in VTAB

    JSR UPDATE_POS  ; Call routine to update screen position
    <<<
