10  TEXT : NORMAL : HOME : PRINT  CHR$ (17) : D$ =  CHR$ (4)
20  PRINT D$;"PR#3": PRINT  CHR$ (12); : REM ENABLE 80 COL
25  POKE 49239,0: REM TURN ON HIRES

27  REM =====
28  REM VARS:
29  REM =====
30  DB% = 0: REM Debug Print (1) or Release mode (0)
32  MB% = 0: REM should we use MOUSE Binary (1) or Basic (0)
40  ME% = 0: REM is Mouse Enabled

50  IF PEEK(50188) = 32 AND PEEK(50427) = 214 THEN ME% = 1
55  PRINT "[D]ebug or [R]elease"
56  GET A$
57  IF A$ = CHR$ (68) THEN DB% = 1
58  HOME
60  IF ME% = 1 AND DB% = 1 THEN PRINT "Found Mouse in SLOT #4"
70  IF ME% = 0 THEN PRINT "MOUSE NOT FOUND!"
80  IF ME% = 0 THEN PRINT "Demo will not be functional."
82  IF ME% = 0 THEN PRINT CHR$ (7)
85  REM IF ME% = 0 THEN GOTO 25000

90  IF DB% = 1 THEN PRINT "Loading title image..."
100  IF DB% = 1 THEN PRINT "->TITLE (MAIN)"
110  POKE 49237,0: PRINT D$;"BLOAD TITLE, A$2000, L$2000"
120  IF DB% = 1 THEN PRINT "->TITLE (AUX)"
130  POKE 49236,0: PRINT D$;"BLOAD TITLE, A$2000, L$2000, B$2000"
135  POKE 49237,0
140  IF DB% = 0 THEN GOSUB 30000 : REM Turn Graphics ON when not debugging

200  REM INITIAL BINARY LOAD
210  IF DB% = 1 THEN PRINT "Loading modules..."
220  IF DB% = 1 THEN PRINT "->FDRAW.FAST"
230  PRINT D$"BLOAD FDRAW.FAST"
240  IF DB% = 1 THEN PRINT "->SOUND #128"
250  PRINT D$"BLOAD SOUND"
270  IF DB% = 1 THEN POKE 32767, 128 : REM SET SOUND ARG
280  IF DB% = 1 THEN CALL 32512 : REM PLAY SOUND
290  IF MB% = 0 THEN GOTO 400

300  IF ME% = 1 AND DB% = 1 THEN PRINT "->MOUSE"
310  IF ME% = 1 THEN PRINT D$"BLOAD MOUSE"

320  IF DB% = 1 THEN PRINT "Initialization..."
325  IF DB% = 1 THEN PRINT "=>FDRAW"
330  CALL 24576 : REM INIT FDRAW LIBRARY

390  GOTO 600

400  IF DB% = 1 THEN PRINT "Binary execution..."
410  IF DB% = 1 THEN PRINT "=>AMPERFDRAW"
430  PRINT D$"BRUN AMPERFDRAW"
440  IF DB% = 1 THEN PRINT "=>FDRAW"
500  &  NEW : REM INIT FDRAW LIBRARY

600  IF DB% = 0 THEN GOTO 610
604  PRINT "Ready to start.\n                 Press Any Key..."
605  GET A$
606  REM IF A$ = CHR$ (13) THEN TEXT
610  IF DB% = 1 THEN GOSUB 30000 : REM Turn Graphics ON when debugging

4000  IF ME% = 0 THEN GOTO 25000
5000  IF MB% = 1 THEN GOTO 24000

10000  REM BASIC MOUSE IMPLEMENTATION
20000  CR% = 1 : CC% = 1 : BA% = 0 : BB% = 0 : REM  Setup Initial pointer position
22030  GOSUB 34000: REM  Turn Mouse ON

22040  REM V = PEEK(49152)
22042  REM IF V = 141 THEN GOTO 22220
22043  REM PRINT V
22045  REM THEN GOTO 22040 : REM Repeat

22050  GOSUB 36000 : REM  Goto BASIC Follow Mouse with AMPERFDRAW plotting
22060  GOTO 22050 : REM repeat

22230  GOSUB 35000 : REM  Turn Mouse OFF
22250  GOTO 25000

24000  IF DB% = 1 THEN PRINT "=>MOUSE"
24100  CALL 32768 : REM Call Mouse binary

25000  GET A$
25100  IF A$ = CHR$ (13) THEN TEXT 
25200  REM TEXT
25300  END

30000  POKE 49232,0: REM TURN ON GRAPHICS
30020  POKE 49235,0: REM TURN ON FULLSCREEN /49234 FULLSCREEN, 49235 MIXED/
30030  POKE 49246,0: REM TURN ON DHR
30050  RETURN

34000  PRINT : PRINT D$;"PR#4": PRINT  CHR$ (1): REM  Turn mouse on
34100  PRINT : PRINT D$;"PR#0": REM  Switch back to screen output
34200  PRINT : PRINT D$;"IN#4": REM   Get input from mouse
34250  PRINT "MOUSE ON"
34300  RETURN 

35000  PRINT : PRINT D$;"IN#0": REM  Turn mouse off,  switch back keyboard input
35100  PRINT : PRINT D$;"PR#4": PRINT  CHR$ (0): REM  Turn mouse off
35200  PRINT : PRINT D$;"PR#0": REM  switch back to screen output
35250  PRINT "MOUSE OFF"
35300  POKE 49168,0: REM  clear keyboard buffer, effectively discarding any key presses that might be stored
35400  RETURN 

36000  IF CC% = PC% AND CR% = PR% THEN  GOTO 37000 : REM Begin BASIC Mouse Follow
36500  &  HCOLOR = 3 : REM RND (1) * 6 + 1 : REM Set Random color
37000  REM  Set Mouse coordinates
37200  PC% = CC% : REM  Previous pointer position = current position
37300  PR% = CR% : REM  Previous pointer position = current position
37400  INPUT CC%,CR%,BA%: REM  Read mouse position and status
37500  CC% = CC% / 3.7: REM coordinates conversion 1024 to less than 280
37600  CR% = CR% / 5.4: REM coordinates conversion 1024 to less than 192
37700  XL = CC%
37800  YT = CR%
37900  REM PRINT XL : PRINT YT
38000  &  XDRAW XL,YT,XL + 2,YT + 2 : REM Plot Cursor (NO REDRAWING TODO)
39000  RETURN 
