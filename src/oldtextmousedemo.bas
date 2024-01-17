1000 GOSUB 10000: REM •• InitiaUze varhbles
1010 PRINT CHR$ (21): REM DEACTIVATE 80 COL CARD
1020 REM DISPLAY WIDTH IS 40
1030 GOSUB 11000: REM •• DisplayEntryWindow
1040 FOR X1 = 1 TO LF%
1050 FIELD% = X1: GOSUB 23500: REM •• Display field description
1060 NEXT X1
1070 FOR X1 = 1 TO 5: REM •• Enter all fields
1080 FIELD% = X1
1090 GOSUB 23000: GOSUB 12000: GOSUB 23500: REM •• SelectField:EnterField:DeselectField
1100 NEXT X1
1110 FIELD% = 6: GOSUB 23000: REM •• SelectField
1120 GOSUB 22000: REM •• GetFieldNumber
1130 IF FIELD% = 6 THEN FR% = 4:LR% = 8: GOSUB 30100: GOSUB 23500: GOTO 1040 : REM •• If field=6, blank last entries, deselect and get another
1135 rem page 2
1140 IF FIELD% < LF% THEN GOSUB 12000: GOTO 1120: REM •• EnterField
1150 REM ••• Quit? •••
1160 T%= 12:L% = 4:B% = 17:R% = 37: GOSUB 30200: REM •• DisplayBox
1170 VTAB 14: HTAB 5: PRINT BEEP$;"Are you sure you want to quit?";
1180 VTAB 16: HTAB 8: C$ = "Y": GOSUB 21000: REM •• GetYesNo
1190 IF NTRY$ ="NO" THEN FR% = 12:LR% = 17: GOSUB 30100: GOSUB 23000: GOTO 1120: REM •• If no, erase box, restore field, and get another field
1200 HOME: END: REM if yes, then quit
9989 REM
9990 REM ••• InitializeVariables •••
9991 REM
10000 D$ = CHR$ (4): REM •• ProDOS/DOS 3.3 prefix
10010 W4$ = CHR$ (17): REM •• Display width 40
10020 BEEP$ = CHR$ (07): REM •• Beep char.
10030 FOR X1 = 1 TO 40
10040 EF$ = EF$ + "." : REM •• Entry field chars.
10050 TL$ = TL$ + "_" : REM •• Top line chars.
10060 BL$ = BL$ + "_" : REM •• Bottom line chars.
10070 NEXT X1
10080 SL$ ="|": REM •• Side line chars.
10090 LF% = 7: REM •• Last field number
10100 DIM FR%(2,LF%),FC%(2,LF%),FD$(2,LF%)
10110 FOR X1 = 1 TO LF%: REM •• Read field locations and descriptions
10120 READ FR%(1,X1),FC%(1,X1),FD$(1,X1)
10130 READ FR%(2,X1),FC%(2,X1),FD$(2,X1)
10140 NEXT X1
10150 PTR$ = "^": REM .•• Pointer shape
10160 TRACK = 0.25: REM •• Mouse-poi~ter tracking factor
10170 RETURN
10489 REM
10490 REM ••• Field Descriptions and Locations •••
10491 REM
10500 DATA 4,3," 1. <NAME:>  "
10510 DATA 4,3," 1.  Name:   "
10520 DATA 5,3," 2. <STREET:>"
10530 DATA 5,3," 2.  Street: "
10540 DATA 6,3," 3. <CITY:>  "
10545 rem page 2
10550 DATA 6,3," 3.  City:   "
10560 DATA 7,3," 4. <STATE:> "
10570 DATA 7,3," 4.  State:  "
10580 DATA 8,3," 5. <ZIP:>   "
10590 DATA 8,3," 5. Zip: II  "
10600 DATA 11,3," 6. <ANOTHER RECORD>"
10610 DATA 11,3," 6.  Another Record "
10620 DATA 12,3," 7. <QUIT>"
10630 DATA 12,3," 7.  Quit"
10989 REM
10990 REM ••• DisplayEntryWindow •••
10991 REM
11000 HOME
11010 T% = 1:L% = 1:B% = 22:R% = 39: GOSUB 30200: REM •• DisplayBox
11020 TITLE$ = "MAILING LIST ENTRY"
11030 INVERSE: VTAB 1: HTAB (40 - LEN (TITLE$)) / 2: PRINT TITLE$;: NORMAL: REM •• Display title
11040 RETURN
11989 REM
11990 REM ••• EnterField •••
11991 REM
12000 VTAB 19: HTAB 3: PRINT "Enter the selected field."
12010 HTAB 3: PRINT "Then press RETURN to confirm entry.";
12020 ON FIELD% GOSUB 13100,13200,13300,13400,13500
12030 FR% = 19:LR% = 21: GOSUB 30100: REM •• ClearDisplayLines
12040 RETURN
13089 REM
13090 REM ••• EnterName •••
13100 ML% = 20: VTAB 4: HTAB 17: GOSUB 20000
13110 NAME$ = NTRY$: RETURN
13189 REM
13190 REM ••• EnterStreet •••
13200 ML% = 20: VTAB 5: HTAB 17: GOSUB 20000
13210 STREET$ = NTRY$: RETURN
13289 REM
13290 REM ••• EnterCity •••
13300 ML% = 20: VTAB 6: HTAB 17: GOSUB 20000
13310 CITY$ = NTRY$: RETURN
13389 REM
13390 REM ••• EnterState •••
13400 ML% = 2: VTAB 7: HTAB 17: GOSUB 20000
13405 rem page 3
13410 SE$ = NTRY$: RETURN
13489 REM
13490 REM ••• EnterZip •••
13500 ML% = 9: VTAB 8: HTAB 17: GOSUB 20000
13510 ZIP$ = NTRY$: RETURN
19989 REM
19990 REM ••• GetEntry •••
19991 REM
20000 HT% = PEEK (36) + 1: REM •• cursor column
20010 NTRY$ = "" : REM •• Empty entry
20020 CL% = LEN (NTRY$): REM •• Current entry length
20030 HTAB HT%: PRINT NTRY$;
20040 IF ML% > CL% THEN PRINT LEFT$ (EF$,ML% - CL%);: REM •• Fill unused entry field
20050 HTAB HT% + CL%: GOSUB 30000: REM •• Get one character
20060 IF C$ = CHR$ (127) AND CL% < = 1 THEN 20010: REM •• Delete key with empty entry?
20070 IF C$ = CHR$ (127) THEN NTRY$ = LEFT$ (NTRY$,CL% - 1): GOTO 20020: REM •• Delete key?
20080 IF C$ = CHR$ (24) THEN 20010: REM •• Control-X means cancel
20090 IF C$ = CHR$ (13) THEN PRINT SPC( ML% - CL%);: RETURN: REM •• Return means done
20100 IF C$ > = " " AND C$ < = "~" AND CL% < ML% THEN NTRY$ = NTRY$ + C$: REM •• Add valid characters if room
20110 GOTO 20020: REM •• Get another keystroke
20989 REM
20990 REM ••• GetYesNo •••
20991 REM
21000 HT% = PEEK (36) + 1:VT% = PEEK (37) + 1: REM •• Cursor position
21010 IF C$ = "Y" OR C$ = "y" OR (C$ = CHR$ (8) AND NTRY$ = "NO") THEN VTAB VT%: HTAB HT%: PRINT "<YES> No ";:NTRY$ = "YES"
21020 IF C$ = "N" OR C$ = "n" OR (C$ = CHR$ (21) AND NTRY$ ="YES") THEN VTAB VT%: HTAB HT%: PRINT "Yes <NO>";:NTRY$ = "NO"
21030 VTAB 19: HTAB 3: PRINT "Type Y for Yes or N for No,"
21040 HTAB 3: PRINT "or press <-- or --> to change."
21050 HTAB 3: PRINT "Then press RETURN. ";
21055 rem page 4
21060 GOSUB 30000: REM •• GetChar
21070 IF C$ = " " THEN C$ = CHR$ (21): REM •• Accommodate 80-col. card "feature"
21080 IF C$ < > CHR$ (13) THEN 21010: REM •• Only RETURN confirms
21090 FR% = 19:LR% = 21: GOSUB 30100: REM •• ClearDisplayLines
21100 RETURN
21989 REM
21990 REM ••• GetfieldNumber •••
21991 REM
22000 CR% = 1:CC% = 1: REM •• Initial pointer position
22010 VTAB 19: HTAB 3: PRINT "POint with the mouse to select a"
22020 HTAB 3: PRINT "field. Then click the mouse button.";
22030 GOSUB 30400: REM •• Mouseon
22040 GOSUB 30600: REM •• Follow~ouse
22050 IF CR%= PR% THEN 22130: REM •• If no row chang~, sktp selection ch~ng~
22060 IF FIELD% < > 0 THEN GOSUB 23500: REM •• Deselect previ OU$ .selectfon
22070 FIELD% = 0: REM •• Clear previous field selection
22080 FOR X1 = 1 TO LF%: REM •• Find current field $election
22090 IF CR% < > FR%(2,X1) THEN 22120: REM •• Is pointer on a field?.
22100 FIELD% = X1: GOSUB 23000: REM •• Yes; select it.
22110 X1 = LF%: REM •• and stop loo,ing
22120 NEXT X1
22130 IF ABS (MS%) > 2 OR FIELD% = 0 THEN 22040: REM •• Keep polling until valid sel~ction
22140 FR% = 19:LR% = 21: GOSUB 30100: REM •• ClearDisplayLines
22150 GOSUB 30500: REM .;.MouseOff
22160 RETURN
22989 REM
22990 REM ••• S e l e c t F i e l d •••
22991 REM
23000 VT% = PEEK (37) + 1:HT% = PEEK (36) + 1: REM •• Cursor location
23010 VTAB FR%(1,FIELD%): HTAB FC%(1,FIELD%): PRINT FD$(1,FIELD%);: REM •• Display selected description
23015 rem page 5
23020 VTAB VT%: HTAB HT%: REM •• Reset cursor
23030 RETURN
23489 REM
23490 REM ••• DeselectField •••
23491 REM
23500 VT% = PEEK (37) + 1:HT% = PEEK (36) + 1: REM •• Cursor location
23510 VTAB FR%(2,FIELD%): HTAB FC%(2,FIELD%): PRINT FD$(2,FIELD%);: REM •• Display deselected description
23520 VTAB VT%: HTAB HT%: REM •• Reset cursor
23530 RETURN
29989 REM
29990 REM ••• GetCharacter •••
29991 REM
30000 GET C$: REM •• Wait for keystroke
30010 RETURN
30089 REM
30090 REM ••• ClearDisplayLines •••
30091 REM
30100 FOR ROW = FR% TO LR%
30110 VTAB ROW: HTAB 2: PRINT SPC( 37);
30120 NEXT ROW
30130 RETURN
30189 REM
30190 REM ••• Di sp layBox •••
30191 REM
30200 VTAB T%: HTAB L% + 1
30210 PRINT LEFT$ (TL$,R% - L% - 1);: REM •• Top line
30220 FOR ROW = T% + 1 TO B%: REM •• Side lines
30230 VTAB ROW: HTAB L%: PRINT SL$;
30240 HTAB R%: PRINT SL$
30250 NEXT ROW
30260 VTAB B%: HTAB L% + 1: PRINT LEFT$ (BL$,R% - L% - 1);: REM •• Bottom line
30270 RETURN
30389 REM
30390 REM ••• MouseOn •••
30391 REM
30400 PRINT: PRINT D$;"PR#4": PRINT CHR$ (1): REM •• Turn mouse on
30410 PRINT: PRINT D$;"PR#0": REM •• Switch back to screen output
30420 PRINT: PRINT D$;"IN#4": REM •• Get input from mouse
30430 RETURN
30435 rem page 6
30489 REM
30490 REM ••• MouseOff •••
30491 REM
30500 PRINT: PRINT D$;"IN#0": REM •• switch ba t~ keyboard input
30510 PRINT: PRINT D$;"PR#4": PRINT CHR$ (0):REM •• Turn mouse off
30520 PRINT: PRINT D$;"PR#0": REM •• switch back to screen output
30530 POKE 49168,0: REM •• c Lear keyboard
30540 RETURN
30589 REM
30590 REM ••• F o l low Mouse •••
30591 REM
30600 FCC% = SCRN( CC% - 1,2 * (CR% - 1)) + 16 * SCRN( CC% - 1,2 * (CR% - 1) + 1): REM .•• Former character's code
30610 VTAB CR%: HTAB CC%: PRINT PTR$;: REM •• D i s p lay poi n t e r
30620 PC% = CC%:PR% = CR%: REM •• Previous pointer pos. = current pos.
30630 VTAB 23: HTAB 39: REM •• Accomodate INPUT "feature"
30640 INPUT "";CC%,CR%,MS%: REM •• Read mouse pos. and status
30650 CC% = CC% / 25.6 / TRACK + 1: REM •• Compute cur rent co Lu mn no.
30660 CR% = CR% / 42.667 / TRACK + 1: REM •• Compute cur rent row no.
30670 IF CC% > 40 THEN CC% = 40: REM •• Restrict col. to 40 max.
30680 IF CR% > 24 THEN CR% = 24: REM •• Rest r i ct r'OW to 24 max.
30690 IF CR% = PR% AND CC% = PC% AND ABS (MS%) > 2 THEN 30630: REM •• If mouse hasn't moved and button is up, read again
30700 VTAB PR%: HTAB PC%: REM •• If it has, redisplay prev. character
30710 If FCC% > 127 THEN PRINT CHR$ (FCC%);: GOTO 30740: REM •• Redisplay normal character
30720 If FCC% < 32 THEN INVERSE: PRINT CHR$ (FCC% + 64);: NORMAL: GOTO 30740: REM •• Redisplay inverse uppercase
30730 INVERSE: PRINT CHR$ (FCC%);: NORMAL: REM •• Redisplay other inverse
30740 RETURN 