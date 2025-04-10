-- **Problem 1: Basic LED Control**

--* **Objective:** Control a single LED on the DE10-Lite using a push-button.  The LED should toggle its state each time the button is pressed.
--* **VHDL Concepts:** Input/output ports, signals, processes, concurrent statements, `if` statements.
--* **Hardware:**  One push-button, one LED.
--* **Steps:**
--    1. Create a new VHDL project in Quartus.
--    2. Define input and output ports for the button and LED.
--   3. Use a process to monitor the button's state.
--    4. When the button is pressed, toggle the LED's output.
--    5. Synthesize, compile, and download the design to the DE10-Lite.
--    6. Test the functionality.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.dw.all;
use work.dw2.all;
use work.CHAR2STD.all;


entity city2077_blink is

  port(
    MAX10_CLK1_50 : in  std_logic;
    ADC_CLK_10    : in  std_logic;
    KEY           : in  std_logic_vector(1 downto 0);  -- Reset and toggle buttons
    LEDR          : out std_logic_vector(9 downto 0);
    HEX0          : out std_logic_vector(7 downto 0);
    HEX1          : out std_logic_vector(7 downto 0);
    HEX2          : out std_logic_vector(7 downto 0);
    HEX3          : out std_logic_vector(7 downto 0);
    HEX4          : out std_logic_vector(7 downto 0);
    HEX5          : out std_logic_vector(7 downto 0);
    VGA_R         : out std_logic_vector(3 downto 0);
    VGA_G         : out std_logic_vector(3 downto 0);
    VGA_B         : out std_logic_vector(3 downto 0);
    VGA_HS        : out std_logic;
    VGA_VS        : out std_logic;
    ARDUINO_IO    : out std_logic_vector(15 downto 0)

    );

end entity;


architecture rtl of city2077_blink is

  component counter is

    port(
      countclock : in  std_logic;
      reset      : in  std_logic;
      leds       : out std_logic_vector(3 downto 0)
      );
  end component;

  component hexdisplay is

    port(
      values : in  std_logic_vector(3 downto 0);
      hexout : out std_logic_vector(7 downto 0)
      );
  end component;

  component video_sync_generator is
    port(
      reset   : in  std_logic;
      vga_clk : in  std_logic;
      blank_n : out std_logic;
      HS      : out std_logic;
      VS      : out std_logic;
      xPos    : out std_logic_vector(10 downto 0);
      yPos    : out std_logic_vector(9 downto 0)
      );
  end component;


  component vgaClockPLL
    port
      (
        inclk0 : in  std_logic := '0';
        c0     : out std_logic
        );
  end component;

  component paddle
    port (
      CLOCK : in  std_logic := 'X';               -- clk
      RESET : in  std_logic := 'X';               -- reset
      CH0   : out std_logic_vector(11 downto 0);  -- CH0
      CH1   : out std_logic_vector(11 downto 0);  -- CH1
      CH2   : out std_logic_vector(11 downto 0);  -- CH2
      CH3   : out std_logic_vector(11 downto 0);  -- CH3
      CH4   : out std_logic_vector(11 downto 0);  -- CH4
      CH5   : out std_logic_vector(11 downto 0);  -- CH5
      CH6   : out std_logic_vector(11 downto 0);  -- CH6
      CH7   : out std_logic_vector(11 downto 0)   -- CH7
      );
  end component paddle;

  component txtScreen
--       generic(); -- pixel position
    port(
      hp, vp :    integer;
      addr   : in std_logic_vector(11 downto 0);  -- text screen ram
      data   : in std_logic_vector(7 downto 0);
      nWr    : in std_logic;
      pClk   : in std_logic;
      nblnk  : in std_logic;

      pix : out std_logic

      );
  end component;

  -- sprite for ball
  signal ball : std_logic_vector(99 downto 0) :=
    ('0', '0', '0', '0', '1', '1', '0', '0', '0', '0',
     '0', '0', '1', '1', '1', '1', '1', '1', '0', '0',
     '0', '1', '1', '1', '1', '1', '1', '1', '1', '0',
     '0', '1', '1', '1', '1', '1', '1', '1', '1', '0',
     '1', '1', '1', '1', '0', '0', '1', '1', '1', '1',
     '1', '1', '1', '1', '0', '0', '1', '1', '1', '1',
     '0', '1', '1', '1', '1', '1', '1', '1', '1', '0',
     '0', '1', '1', '1', '1', '1', '1', '1', '1', '0',
     '0', '0', '1', '1', '1', '1', '1', '1', '0', '0',
     '0', '0', '0', '0', '1', '1', '0', '0', '0', '0');

  -- Creates a 4x3 array for blocks
  type t_Row_Col is array (0 to 39) of integer range 0 to 9;
  signal blockPresent : t_Row_Col := (1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
                                      1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
                                      1,1,1,1,1,1,1,1,1,1);

  signal clk      : std_logic;
  signal reset    : std_logic;
  signal resetn   : std_logic;
  signal button   : std_logic;
  signal ledState : std_logic;
  signal state    : std_logic_vector(1 downto 0);

  signal plyr1lsb : std_logic_vector(7 downto 0);
  signal plyr1msb : std_logic_vector(7 downto 0);
  signal plyr2lsb : std_logic_vector(7 downto 0);
  signal plyr2msb : std_logic_vector(7 downto 0);
  signal debuglsb : std_logic_vector(7 downto 0);
  signal debugmsb : std_logic_vector(7 downto 0);


  signal blanking : std_logic;
  signal vgaClk   : std_logic;
  signal HSync    : std_logic;
  signal VSync    : std_logic;
  signal RGB_R    : std_logic_vector(3 downto 0);
  signal RGB_G    : std_logic_vector(3 downto 0);
  signal RGB_B    : std_logic_vector(3 downto 0);

  signal Xp  : std_logic_vector(10 downto 0);
  signal Xpi : integer range 0 to 639;
  signal Yp  : std_logic_vector(9 downto 0);
  signal Ypi : integer range 0 to 479;

  signal ballX       : integer range 0 to 639 := 320;
  signal ballXdir    : integer range -2 to 2  := 1;
  signal ballY       : integer range 0 to 479 := 240;
  signal ballydir    : integer range -2 to 2  := 1;
  signal ballSize    : integer                := 12;
  signal scaleBL     : integer range 1 to 32  := 2;  -- ball sprite scaling
  signal ballspeed   : integer                := 2;
  signal drawbl      : std_logic;
  signal player1Wins : std_logic              := '0';
  signal player2Wins : std_logic              := '0';


  signal paddlepos1 : std_logic_vector (11 downto 0);  -- adc player 1 - Y direction
  signal paddlepos2 : std_logic_vector (11 downto 0);  -- adc player 2 - Y direction
  signal paddlepos3 : std_logic_vector (11 downto 0);  -- adc player 1 - X direction
  signal paddlepos4 : std_logic_vector (11 downto 0);  -- adc player 2 - X direction
  signal paddlepos5 : std_logic_vector (11 downto 0);  -- adc spare
  signal paddlepos6 : std_logic_vector (11 downto 0);  -- adc spare
  signal paddlepos7 : std_logic_vector (11 downto 0);  -- adc spare
  signal paddlepos8 : std_logic_vector (11 downto 0);  -- adc spare
  signal adcCycle   : integer := 0;

  signal paddlein1pos : integer range 0 to 479 := 240;
  signal paddle1pos   : integer range 0 to 479 := 240;
  signal paddle1sz    : integer range 0 to 100 := 40;
  signal player1scr   : integer                := 0;
  signal paddlein2pos : integer range 0 to 479 := 240;
  signal paddle2pos   : integer range 0 to 479 := 240;
  signal paddle2sz    : integer range 0 to 100 := 40;
  signal player2scr   : integer                := 0;

  signal cycle   : integer                 := 0;  -- memory write cycle
  signal charpos : integer range 0 to 4191 := 0;  -- character position from start of screen memory

  signal txtaddress : std_logic_vector(11 downto 0);  -- ram address for screen memory
  signal txtdata    : std_logic_vector(7 downto 0);   -- data for screen memory
  signal wren       : std_logic;        -- active low write strobe
  signal txtpixel   : std_logic;  -- output from screen memory to indicate pixel

  signal blipcount : integer := 0;
  signal blip      : std_logic;
  signal blipped   : std_logic;
  signal blopcount : integer := 0;
  signal blop      : std_logic;
  signal blopped   : std_logic;
  signal audio     : std_logic;

begin
  clk           <= Max10_clk1_50;
  reset         <= key(1);
  resetn        <= not reset;
  button        <= key(0);
  ARDUINO_IO(5) <= audio and ledstate;  -- conect buzzer/speaker to arduino hat
  ARDUINO_IO(7) <= audio and ledstate;  -- digital io D5/D7

  plyr1lsb <= std_logic_vector(to_unsigned(player1scr mod 10, 8));
  plyr1msb <= std_logic_vector(to_unsigned(player1scr / 10, 8));

  plyr2lsb <= std_logic_vector(to_unsigned(player2scr mod 10, 8));
  plyr2msb <= std_logic_vector(to_unsigned(player2scr / 10, 8));

  Xpi    <= to_integer(unsigned(Xp));
  ypi    <= to_integer(unsigned(Yp));
  VGA_VS <= VSync;
  VGA_HS <= HSync;
  VGA_R  <= RGB_R;
  VGA_G  <= RGB_G;
  VGA_B  <= RGB_B;

  SP(xpi, ypi, ballx, bally, ball, scaleBL, DRAWBL);


  -- Logic to toggle Led state

  process (clk, resetn, button)

  -- Get Inputs
  begin

    if resetn = '1' then
      state <= "00";
    elsif (rising_edge(max10_clk1_50)) then       -- LED off waiting for button press
      if (state = "00") then
        if (button = '1') then
          state <= "01";
        else
          state <= "00";
        end if;
      elsif (state = "01") then  -- LED off button pressed waiting for button release
        if (button = '0') then
          state <= "10";
        else
          state <= "01";
        end if;
      elsif (state = "10") then         -- LED on waiting for button press
        if (button = '1') then
          state <= "11";
        else
          state <= "10";
        end if;
      elsif (state = "11") then  -- LED on button pressed waiting for button release
        if (button = '0') then
          state <= "00";
        else
          state <= "11";
        end if;
      end if;
    end if;
  end process;
  process(vgaclk, blanking)
  begin  -- update the display with player scores
    if (rising_edge(vgaclk)) then
      if resetn = '1' then
        txtaddress <= "000000000000";
        txtdata    <= "00000000";
        wren       <= '0';
        cycle      <= 0;
        charpos    <= 0;
      else
        if blanking = '0' then
          if cycle = 0 then             -- state machine for writing to text
            -- memory with ascii code values
            cycle      <= 1;
            wren       <= '0';
            txtAddress <= std_logic_vector(to_unsigned(charpos, txtAddress'length));
            if charpos = 2 then
              txtdata <= plyr1msb or "00110000";  -- write p1 tens to display and convert to ascii
              wren <= '1';
            elsif charpos = 3 then  -- adding 48 to the numeric value eg 3 + 48 = 51 == '3'
              txtdata <= plyr1lsb or "00110000";  -- write p1 units to display and convert to ascii
              wren <= '1';
            elsif charpos = 36 then
              txtdata <= plyr2msb or "00110000";  -- write p2 tens to display and convert to ascii
              wren <= '1';
            elsif charpos = 37 then
              txtdata <= plyr2lsb or "00110000";  -- write p2 units to display and convert to ascii
              wren <= '1';
            elsif charpos = 41 then
              case player1wins is
                when '0' => txtdata <= char2std(' ');
                when '1' =>  txtdata <= char2std('W');
              end case;
 --             txtdata <= char2std('W') when player1wins = 1 else char2std(' ');
              wren <= '1';
            elsif charpos = 42 then
              case player1wins is
                when '0' => txtdata <= char2std(' ');
                when '1' => txtdata <= char2std('O');
              end case;
 --              txtdata <= char2std('I') when player1wins = 1 else char2std(' ');
              wren <= '1';
            elsif charpos = 43 then
              case player1wins is
                when '0' => txtdata <= char2std(' ');
                when '1' =>  txtdata <= char2std('N');
              end case;
 --              txtdata <= char2std('N') when player1wins = 1 else char2std(' ');
              wren <= '1';
            elsif charpos = 76 then
              case player2wins is
                when '0' => txtdata <= char2std(' ');
                when '1' =>  txtdata <= char2std('W');
              end case;
 --              txtdata <= char2std('W') when player2wins = 1 else char2std(' ');
              wren <= '1';
            elsif charpos = 77 then
              case player2wins is
                when '0' => txtdata <= char2std(' ');
                when '1' =>  txtdata <= char2std('I');
              end case;
 --              txtdata <= char2std('O') when player2wins = 1 else char2std(' ');
              wren <= '1';
            elsif charpos = 78 then
              case player2wins is
                when '0' => txtdata <= char2std(' ');
                when '1' => txtdata <= char2std('N');
              end case;
 --              txtdata <= char2std('N') when player2wins = 1 else char2std(' ');
              wren <= '1';
            elsif charpos >= 160 and charpos < 164 then
              if blockPresent(0) = 1 then
                if charpos = 163 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 164 and charpos < 168 then
              if blockPresent(1) = 1 then
                if charpos = 167 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 168 and charpos < 172 then
              if blockPresent(2) = 1 then
                if charpos = 171 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 172 and charpos < 176 then
              if blockPresent(3) = 1 then
                if charpos = 175 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 176 and charpos < 180 then
              if blockPresent(4) = 1 then
                if charpos = 179 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 180 and charpos < 184 then
              if blockPresent(5) = 1 then
                if charpos = 183 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 184 and charpos < 188 then
              if blockPresent(6) = 1 then
                if charpos = 187 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 188 and charpos < 192 then
              if blockPresent(7) = 1 then
                if charpos = 191 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "10000001";
              end if;
              wren <= '1';
            elsif charpos >= 192 and charpos < 196 then
              if blockPresent(8) = 1 then
                if charpos = 195 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 196 and charpos < 200 then
              if blockPresent(9) = 1 then
                if charpos = 199 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 200 and charpos < 204 then
              if blockPresent(10) = 1 then
                if charpos = 203 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 204 and charpos < 208 then
              if blockPresent(11) = 1 then
                if charpos = 207 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 208 and charpos < 212 then
              if blockPresent(12) = 1 then
                if charpos = 211 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 212 and charpos < 216 then
              if blockPresent(13) = 1 then
                if charpos = 215 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 216 and charpos < 220 then
              if blockPresent(14) = 1 then
                if charpos = 219 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 220 and charpos < 224 then
              if blockPresent(15) = 1 then
                if charpos = 223 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 224 and charpos < 228 then
              if blockPresent(16) = 1 then
                if charpos = 227 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 228 and charpos < 232 then
              if blockPresent(17) = 1 then
                if charpos = 231 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 232 and charpos < 236 then
              if blockPresent(18) = 1 then
                if charpos = 235 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 236 and charpos < 240 then
              if blockPresent(19) = 1 then
                if charpos = 239 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 240 and charpos < 244 then
              if blockPresent(20) = 1 then
                if charpos = 243 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 244 and charpos < 248 then
              if blockPresent(21) = 1 then
                if charpos = 247 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 248 and charpos < 252 then
              if blockPresent(22) = 1 then
                if charpos = 251 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 252 and charpos < 256 then
              if blockPresent(23) = 1 then
                if charpos = 255 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "10000001";
              end if;
              wren <= '1';
            elsif charpos >= 256 and charpos < 260 then
              if blockPresent(24) = 1 then
                if charpos = 259 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 260 and charpos < 264 then
              if blockPresent(25) = 1 then
                if charpos = 263 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 264 and charpos < 268 then
              if blockPresent(26) = 1 then
                if charpos = 267 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 268 and charpos < 272 then
              if blockPresent(27) = 1 then
                if charpos = 271 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 272 and charpos < 276 then
              if blockPresent(28) = 1 then
                if charpos = 275 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 276 and charpos < 280 then
              if blockPresent(29) = 1 then
                if charpos = 279 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 280 and charpos < 284 then
              if blockPresent(30) = 1 then
                if charpos = 283 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 284 and charpos < 288 then
              if blockPresent(31) = 1 then
                if charpos = 287 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 288 and charpos < 292 then
              if blockPresent(32) = 1 then
                if charpos = 291 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 292 and charpos < 296 then
              if blockPresent(33) = 1 then
                if charpos = 295 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 296 and charpos < 300 then
              if blockPresent(34) = 1 then
                if charpos = 299 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 300 and charpos < 304 then
              if blockPresent(35) = 1 then
                if charpos = 303 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 304 and charpos < 308 then
              if blockPresent(36) = 1 then
                if charpos = 307 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 308 and charpos < 312 then
              if blockPresent(37) = 1 then
                if charpos = 311 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 312 and charpos < 316 then
              if blockPresent(38) = 1 then
                if charpos = 315 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "00000000";
              end if;
              wren <= '1';
            elsif charpos >= 316 and charpos < 320 then
              if blockPresent(39) = 1 then
                if charpos = 319 then
                  txtdata <= "10000001"; -- missing last column block
                else
                  txtdata <= "10000000"; -- full block
                end if;  
              else
                txtdata <= "10000001";
              end if;
              wren <= '1';
            else
              wren <= '0';
            end if;

          elsif cycle = 1 then          -- strobe wren high for one clock
--            wren  <= '0';
            cycle <= 2;
          else                              -- cycle is 2, reset cycle and increment
                                            -- memory address for next
                                            -- character position
            wren  <= '0';
            cycle <= 0;
            if charpos < 1023 then
              charpos <= charpos + 1;
            else
              charpos <= 0;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Update Display

  process(vgaClk, Xpi, Ypi, blanking, adcCycle)
  begin
--              -- clear
    RGB_R <= x"0";
    RGB_G <= x"0";
    RGB_B <= x"0";
    if (blanking = '1') then  -- Only update display while blanking is high
      -- Draw Text
      if txtPixel = '1' then
        RGB_R <= x"f";
        RGB_G <= x"f";
        RGB_B <= x"f";
        if yPi > 100 and yPi < 124 then -- colour bands as we go down the screen
          RGB_R <= x"0";
          RGB_G <= x"f";
          RGB_B <= x"f";
        elsif yPi > 124 and yPi < 148 then
          RGB_R <= x"f";
          RGB_G <= x"0";
          RGB_B <= x"f";
        elsif yPi > 148 and yPi < 172 then
          RGB_R <= x"f";
          RGB_G <= x"0";
          RGB_B <= x"0";
        elsif yPi > 172 and yPi < 196 then
          RGB_R <= x"0";
          RGB_G <= x"0";
          RGB_B <= x"f";
        end if;

      -- Draw Paddles
      elsif (((Xpi > 30) and (Xpi < 40) and (Ypi > (paddle1pos - paddle1sz)) and (Ypi < (paddle1pos + paddle1sz)))
             or ((Xpi > 600) and (Xpi < 610) and (Ypi > (paddle2pos - paddle2sz)) and (Ypi < (paddle2pos + paddle2sz))))
      then
        RGB_R <= x"f";
        RGB_G <= x"f";
        RGB_B <= x"f";

      -- Draw the Ball
      elsif drawbl = '1' then --((Xpi > ballX-(ballSize/2)) and (Xpi < ballX+(ballSize/2)) and
            -- (Ypi > ballY-(ballSize/2)) and (Ypi < ballY+(ballSize/2))) then
        RGB_R <= x"f";
        RGB_G <= x"f";
        RGB_B <= x"0";
      -- draw the playfield edges
      elsif (YPi = 50 or Ypi = 479 or (Xpi = 1 and Ypi > 50) or (xpi = 639 and Ypi > 50)) then
        RGB_R <= x"f";
        RGB_G <= x"f";
        RGB_B <= x"f";
      -- Background
      elsif (Xpi > 0 and Xpi < 640 and Ypi > 50 and yPi < 480) then
        RGB_R <= x"0";
        RGB_G <= x"7";
        RGB_B <= x"0";
      end if;
    end if;
  end process;

  -- Make some noise
  process(clk, resetn, blip, blop)
  begin
    if resetn = '1' then
      blipped <= '0';
      audio   <= '0';
    elsif (rising_edge(clk)) then
      if (blip = '1') then
        blipped <= '1';
      end if;

      if blipped = '1' then
        blipcount <= blipcount + 1;
        if (blipcount mod 25000) = 1 then
          audio <= not audio;           -- 800 Hz
        end if;
        if (blipcount > 5000000) then
          blipped   <= '0';
          blipcount <= 0;
          audio     <= '0';             -- silence beeper
        end if;
      end if;

      if (blop = '1') then
        blopped <= '1';
      end if;

      if blopped = '1' then
        blopcount <= blopcount + 1;
        if (blopcount mod 40000) = 1 then
          audio <= not audio;           -- 500 Hz
        end if;
        if (blopcount > 5000000) then
          blopped   <= '0';
          blopcount <= 0;
          audio     <= '0';             -- silence beeper
        end if;
      end if;
    end if;
  end process;


  -- move Ball - synchronised to Vsync 60Hz
  process(VSync, ballX, BallY, adcCycle, blipped, blopped, resetn)
  begin
    if resetn = '1' then
      ballX       <= 320;
      ballY       <= 240;
      ballspeed   <= 4;
      ballXDir    <= 1;
      ballYDir    <= 1;
      player1scr  <= 0;
      player2scr  <= 0;
      player1Wins <= '0';
      player2Wins <= '0';
      adcCycle    <= 0;
      blip        <= '0';
      blop        <= '0';
      blockPresent <= (1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
                       1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
                       1,1,1,1,1,1,1,1,1,1);      
    elsif (rising_edge(VSync)) then
      ballx <= ballx + ballXDir*ballspeed;
      bally <= bally + BallYDir*ballspeed;
      -- AI player2 control
      -- paddle2pos <= bally;
      if blipped = '1' then             -- noise started
        blip <= '0';
      end if;
      if blopped = '1' then             -- noise started
        blop <= '0';
      end if;
      -- player 1 paddle hit
      if ((ballX < 40 + (ballSize /2)) and
          ((ballY >= paddle1pos - paddle1sz) and (ballY < paddle1pos + paddle1sz)))
      then
        if (bally > paddle1pos + paddle1sz/2) then
          ballYdir <= 2;
        elsif (bally > paddle1pos + paddle1sz/4) then
          ballydir <= 1;
        elsif (bally < paddle1pos - paddle1sz/2) then
          ballydir <= -2;
        elsif (bally < paddle1pos - paddle1sz/4) then
          ballydir <= -1;
        else
          ballydir <= 0;
        end if;
        ballXdir <= 1;
        ballx    <= ballX + 1;
        blip     <= '1';

      -- player 2 paddle hit
      elsif ((ballX > 600 - (ballSize /2)) and
             ((ballY >= paddle2pos - paddle2sz) and (ballY < paddle2pos + paddle2sz)))
      then
        if (bally > paddle2pos + paddle2sz/2) then
          ballYdir <= 2;
        elsif (bally > paddle2pos + paddle2sz/4) then
          ballydir <= 1;
        elsif (bally < paddle2pos - paddle2sz/2) then
          ballydir <= -2;
        elsif (bally < paddle2pos - paddle2sz/4) then
          ballydir <= -1;
        else
          ballydir <= 0;
        end if;
        ballXdir <= -1;
        ballx    <= ballX - 1;
        blip     <= '1';

      -- ball hits left edge
      elsif ballX > 630 then
        ballXdir   <= -1;
        ballx      <= 320;
        player1scr <= player1scr + 1;
        if player1scr = 10 then
          player1Wins <= '1';
          ballX       <= 320;
          ballY       <= 240;
          ballXdir    <= 0;
        end if;
        blop <= '1';
      -- ball hits right edge
      elsif ballX < 20 then
        ballXdir   <= 1;
        ballx      <= 320;
        player2scr <= player2scr + 1;
        if player2scr = 10 then
          player2Wins <= '1';
          ballX       <= 320;
          ballY       <= 240;
          ballXdir    <= 0;
        end if;
        blop <= '1';
      end if;
      -- ball hits bottom edge
      if ballY > 470 then
        ballYdir <= -ballYdir;
        bally <= 469;
      -- ball hits top edge
      elsif ballY < 60 then
        ballYdir <= -ballydir;
        bally <= 61;
      end if;
      -- player controlled paddles
      if (adcCycle = 0)
      then  -- adcCycle allows time for conversions to complete
        paddlein1pos <= (to_integer(unsigned(paddlepos1(11 downto 3))));
        adcCycle     <= 1;
        ledr(9)      <= '1';

      elsif adcCycle = 1 then
        adcCycle <= 2;
        if paddlein1pos > 460 then
          paddle1pos <= 460;
        elsif paddlein1pos < 70 then
          paddle1pos <= 70;
        else
          paddle1pos <= paddlein1pos;
        end if;

      elsif adcCycle = 2
      then
        paddlein2pos <= (to_integer(unsigned(paddlepos2(11 downto 3))));
        adcCycle     <= 3;
        ledr(9)      <= '0';
      else
        adcCycle <= 0;
        if paddlein2pos > 460 then
          paddle2pos <= 460;
        elsif paddlein2pos < 70 then
          paddle2pos <= 70;
        else
          paddle2pos <= paddlein2pos;
        end if;

      end if;

      debugmsb <= std_logic_vector(to_unsigned(paddle2pos / 10, 8));
      debuglsb <= std_logic_vector(to_unsigned(paddle2pos mod 10, 8));

    end if;
  end process;



  -- Instantiate components

  

  hexlsb   : hexdisplay port map(plyr1msb(3 downto 0), HEX5(7 downto 0));
  hexmsb   : hexdisplay port map(plyr1lsb(3 downto 0), HEX4(7 downto 0));
  hexlsb2  : hexdisplay port map(plyr2msb(3 downto 0), HEX1(7 downto 0));
  hexmsb2  : hexdisplay port map(plyr2lsb(3 downto 0), HEX0(7 downto 0));
  hexlsbd  : hexdisplay port map(debugmsb(3 downto 0), HEX3(7 downto 0));
  hexmsbd  : hexdisplay port map(debuglsb(3 downto 0), HEX2(7 downto 0));
  display  : video_sync_generator port map(resetn, vgaClk, blanking, Hsync, Vsync, Xp, Yp);
  vgaClock : vgaClockPLL port map(clk, vgaClk);
  paddling : paddle
    port map (
      CLOCK => ADC_CLK_10,              --      clk.clk
      RESET => resetn,                  --    reset.reset
      CH0   => paddlepos1,              -- readings.CH0
      CH1   => paddlepos2,              --         .CH1
      CH2   => paddlepos3,              --         .CH2
      CH3   => paddlepos4,              --        .CH3
      CH4   => paddlepos5,              --                        .CH4
      CH5   => paddlepos6,              --         .CH5
      CH6   => paddlepos7,              --         .CH6 not de10-lite
      CH7   => paddlepos8               --         .CH7 not de10-lite
      );
  txtscreenInst : component txtscreen port map (
    xPi,
    yPi,
    txtaddress,
    txtdata,
    wren,
    vgaclk,
    blanking,
    txtpixel
    );
  ledState <= state(1);
  LEDR(0)  <= ledState;
  ledr(1) <= not player1wins;
  ledr(2) <= not player2wins;

end rtl;
