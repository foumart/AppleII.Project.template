100  TEXT : NORMAL : HOME
150  D$ =  CHR$(4)
200  PRINT D$;"PR#3" : REM ENABLE 80 COL
250  PRINT  CHR$(12); : REM MOVE CURSOR TO UPPER LEFT AND CLEAR WINDOW
300  POKE 49239,0: REM TURN ON HIRES

400  REM =====
500  REM VARS:
600  REM =====
700  DB% = 0: REM Debug Print (1) or Release mode (0)
800  MB% = 1: REM should we use MOUSE Binary (1) or Basic (0)
900  ME% = 0: REM is Mouse Enabled

1000  IF PEEK(50188) = 32 AND PEEK(50427) = 214 THEN ME% = 1
1100  PRINT "[D]ebug or [R]elease"
1200  GET A$
1300  IF A$ = CHR$ (68) THEN DB% = 1
1400  HOME
1500  IF ME% = 1 AND DB% = 1 THEN PRINT "Found Mouse in SLOT #4"
1600  IF ME% = 0 THEN PRINT "MOUSE NOT FOUND!"
1700  IF ME% = 0 THEN PRINT "Demo will not be functional."
1800  IF ME% = 0 THEN PRINT CHR$ (7)

2000  IF DB% = 1 THEN PRINT "Loading title image..."
2100  IF DB% = 1 THEN PRINT "->TITLE (MAIN)"
2200  rem : POKE 49237,0
2250  PRINT D$;"BLOAD TITLE, A$2000, L$2000"
2300  rem : IF DB% = 1 THEN PRINT "->TITLE (AUX)"
2400  rem : POKE 49236,0: PRINT D$;"BLOAD TITLE, A$2000, L$2000, B$2000"
2500  rem : POKE 49237,0
2600  IF DB% = 0 THEN GOSUB 30000 : REM Turn Graphics ON when not debugging

2700  REM INITIAL BINARY LOAD
2800  IF DB% = 1 THEN PRINT "Loading modules..."
2900  IF DB% = 1 THEN PRINT "->BLITLIB"
3000  PRINT D$"BLOAD BLITLIB,A$6000"
3020  IF DB% = 1 THEN PRINT "->PRESHIFT"
3050  PRINT D$"BLOAD PRESHIFT,A$6700"
3070  IF DB% = 1 THEN PRINT "->PI.BIRDS"
3080  PRINT D$"BLOAD PI.BIRDS,A$4000,L$1FFF"
3100  rem : IF DB% = 1 THEN PRINT "->SOUND #128"
3200  rem : PRINT D$"BLOAD SOUND"
3300  rem : IF DB% = 1 THEN POKE 32767, 128 : REM SET SOUND ARG
3400  rem : IF DB% = 1 THEN CALL 32512 : REM PLAY SOUND

4200  IF MB% = 1 THEN PRINT "Binary execution..." : GOTO 4700
4220  PRINT "Basic execution..."

4700  IF DB% = 0 THEN GOTO 5100
4800  PRINT "Ready to start.\n                 Press Any Key..."
4900  GET A$
5000  IF A$ = CHR$ (13) THEN TEXT

5100  IF DB% = 1 THEN GOSUB 30000 : REM Turn Graphics ON when debugging

5200  IF ME% = 0 THEN GOTO 25000 : REM Mouse disabled ?
5300  IF MB% = 1 THEN GOTO 24000 : REM Binary implementation


6000  text : CR% = 1 : CC% = 1 : REM  Setup Initial pointer position
6100  GOSUB 34000: REM  Turn Mouse ON

6200  GOSUB 36000 : REM  Goto BASIC Follow Mouse LOOP
6300  GOTO 6200 : REM repeat


6500  GOSUB 35000 : REM  Turn Mouse OFF
6600  GOTO 25000


23999  REM BINARY ASM MOUSE ROUTINE
24000  rem  IF DB% = 1 THEN PRINT "=>FLAPPY.BIN"
24050  rem  PRINT D$"BLOAD FLAPPY.BIN,A$300"
24100  rem  CALL 768 : REM Call Mouse binary
24150  IF DB% = 1 THEN PRINT "=>MOUSE"
24160  PRINT D$"BLOAD MOUSE"
24200  CALL 29952 : REM Call Mouse binary at $7500

25000  GET A$
25100  IF A$ = CHR$ (13) THEN TEXT 
25200  REM TEXT
25300  END

30000  POKE 49232,0: REM TURN ON GRAPHICS
30020  POKE 49235,0: REM TURN ON FULLSCREEN /49234 FULLSCREEN, 49235 MIXED/
30030  rem : POKE 49246,0: REM TURN ON DHR
30050  RETURN

34000  PRINT "MOUSE ..."
34050  PRINT D$;"PR#4": PRINT  CHR$ (1): REM  Turn mouse on
34100  PRINT D$;"PR#0": REM  Switch back to screen output
34200  PRINT D$;"IN#4": REM   Get input from mouse
34250  PRINT "MOUSE ON"
34300  RETURN 

35000  PRINT D$;"IN#0": REM  Turn mouse off,  switch back keyboard input
35100  PRINT D$;"PR#4": PRINT  CHR$ (0): REM  Turn mouse off
35200  PRINT D$;"PR#0": REM  switch back to screen output
35250  PRINT "MOUSE OFF"
35300  POKE 49168,0: REM  clear keyboard buffer, effectively discarding any key presses that might be stored
35400  RETURN 

35980  REM === Draw Bird Cursor ===
36000  rem PC% = CC%
36005  rem PR% = CR%: REM  PEEK  END  VTAB  PEEK  END  VTAB  Previous pointer pos. = current pos.

36010  INPUT CC%,CR%: REM  PEEK  END  VTAB  PEEK  END  VTAB  Read mouse pos. and status

36020  CC% = CC% / 3.7 : REM Scale mouse X
36030  CR% = CR% / 5.4 : REM Scale mouse Y
36040  XL = CC% : YT = CR%
36045  HOME : VTAB(22) : HTAB(1) : PRINT XL;" X ";YT; 

36050  REM Set width and height
36060  REM POKE 24588,12     : REM width in pixels
36070  REM POKE 24582,12     : REM height in pixels

36080  REM Set destination X/Y
36090  REM POKE 24587,XL AND 255
36100  REM POKE 24586,XL / 256
36110  REM POKE 24585,YT

36120  REM Blit mode and overwrite
36130  REM POKE 24594,0      : REM mode 0 = pixel-aligned
36140  REM POKE 24595,0      : REM overwrite

36150  REM Set source coordinates (Bird Frame 1)
36160  REM POKE 24579,1      : REM source X (byte offset)
36170  REM POKE 24580,30     : REM source Y (pixel)

36180  REM CALL 24576        : REM draw the bird!
36190  RETURN