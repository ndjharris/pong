library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

PACKAGE DW2 IS -- sprite for paddle type objects (2x10)
PROCEDURE SPR(SIGNAL Xcur,Ycur,Xpos,Ypos:IN INTEGER RANGE 0 to 639 ;signal sprite:IN std_logic_vector(19 downto 0);
signal scale: in integer; SIGNAL DRAW: OUT STD_LOGIC);
END DW2;

PACKAGE BODY DW2 IS
PROCEDURE SPR(SIGNAL Xcur,Ycur,Xpos,Ypos:IN INTEGER;signal sprite:IN std_logic_vector(19 downto 0);
signal scale: in integer; SIGNAL DRAW: OUT STD_LOGIC) IS
BEGIN
 IF ((Xcur>=Xpos) AND (Xcur < (Xpos + scale*2)) AND (Ycur>=Ypos) AND (Ycur < ypos + (10*scale))) THEN
	 if sprite((ABS(xcur - xpos)/scale) + ((ABS(ycur - ypos)/scale)*2)) = '1' then 
		DRAW<='1';
	 else
		DRAW<='0';
	 end if;
 ELSE
	 DRAW<='0';
 END IF;
 
END SPR;
END DW2;