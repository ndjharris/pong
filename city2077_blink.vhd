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
    MAX10_CLK1_50 : in    std_logic;
    ADC_CLK_10    : in    std_logic;
    KEY           : in    std_logic_vector(1 downto 0);  -- Reset and toggle buttons
    SW            : in    std_logic_vector(9 downto 0);
    LEDR          : out   std_logic_vector(9 downto 0);
    HEX0          : out   std_logic_vector(7 downto 0);
    HEX1          : out   std_logic_vector(7 downto 0);
    HEX2          : out   std_logic_vector(7 downto 0);
    HEX3          : out   std_logic_vector(7 downto 0);
    HEX4          : out   std_logic_vector(7 downto 0);
    HEX5          : out   std_logic_vector(7 downto 0);
    VGA_R         : out   std_logic_vector(3 downto 0);
    VGA_G         : out   std_logic_vector(3 downto 0);
    VGA_B         : out   std_logic_vector(3 downto 0);
    VGA_HS        : out   std_logic;
    VGA_VS        : out   std_logic;
    GPIO          : inout std_logic_vector(35 downto 0);
    ARDUINO_IO    : out   std_logic_vector(15 downto 0)

    );

end entity;


architecture rtl of city2077_blink is
  -- Define constants for readability
  constant ASCII_OFFSET        : std_logic_vector(7 downto 0) := "00110000";  -- ASCII for '0'
  constant BLOCK_FULL          : std_logic_vector(7 downto 0) := "10000000";
  constant BLOCK_MISSING_LAST  : std_logic_vector(7 downto 0) := "10000001";
  constant BLOCK_EMPTY         : std_logic_vector(7 downto 0) := "00000000";
  constant GAME_OVER_G_ASCII   : std_logic_vector(7 downto 0) := "01000111";  -- ASCII for 'G'
  constant GAME_OVER_A_ASCII   : std_logic_vector(7 downto 0) := "01000001";  -- ASCII for 'A'
  constant GAME_OVER_M_ASCII   : std_logic_vector(7 downto 0) := "01001101";  -- ASCII for 'M'
  constant GAME_OVER_E_ASCII   : std_logic_vector(7 downto 0) := "01000101";  -- ASCII for 'E'
  constant GAME_OVER_O_ASCII   : std_logic_vector(7 downto 0) := "01001111";  -- ASCII for 'O'
  constant GAME_OVER_V_ASCII   : std_logic_vector(7 downto 0) := "01010110";  -- ASCII for 'V'
  constant SCORE_0_ASCII       : std_logic_vector(7 downto 0) := "00110000";  -- ASCII for '0'
  constant GAME_OVER_R_ASCII   : std_logic_vector(7 downto 0) := "01010010";  -- ASCII for 'R'
  constant PLAYER2_WIN_W_ASCII : std_logic_vector(7 downto 0) := "01010111";  -- ASCII for 'W'
  constant PLAYER2_WIN_I_ASCII : std_logic_vector(7 downto 0) := "01001001";  -- ASCII for 'I'
  constant PLAYER2_WIN_N_ASCII : std_logic_vector(7 downto 0) := "01001110";  -- ASCII for 'N'
  constant SPACE_ASCII         : std_logic_vector(7 downto 0) := "00100000";  -- ASCII for ' '
  constant clk_frequency_hz    : integer                      := 50000000;  -- 50 MHz main clock
  constant pwm_frequency_hz    : integer                      := 20000;  -- 20 KHz
  constant sound_addr_width    : integer                      := 4;  -- 16 different tunes/samples


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

  component quadrature_decoder is
    port(
      clk          : in     std_logic;  --system clock
      a            : in     std_logic;  --quadrature encoded signal a
      b            : in     std_logic;  --quadrature encoded signal b
      set_origin_n : in     std_logic;  --active-low synchronous clear of position counter
      direction    : out    std_logic;  --direction of last change, 1 = positive, 0 = negative
      position     : buffer integer range 0 to 639 := 320  --current position relative to index or initial value
      );
  end component quadrature_decoder;

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

  component pwm_sound
    generic (
      clk_frequency_hz : integer;
      pwm_frequency_hz : integer;
      sound_addr_width : integer
      );
    port (
      clk_i          : in  std_logic;   -- System clock input
      reset_i        : in  std_logic;
      tune_addr_i    : in  std_logic_vector(sound_addr_width - 1 downto 0);  -- Address of sound to play
      sound_strobe_i : in  std_logic;  -- Strobe signal to trigger sound playback
      gpio_o         : out std_logic;   -- PWM output to GPIO pin
      working        : out std_logic
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
  type t_Row_Col is array (0 to 39) of std_logic;
  signal blockPresent : t_Row_Col := ('1', '1', '1', '1', '1', '1', '1', '1',
                                      '1', '1', '1', '1', '1', '1', '1', '1',
                                      '1', '1', '1', '1', '1', '1', '1', '1',
                                      '1', '1', '1', '1', '1', '1', '1', '1',
                                      '1', '1', '1', '1', '1', '1', '1', '1');

  --signal blockPresent : function (index : integer) return std_logic; -- Assuming this function exists
  signal clk             : std_logic;
  signal reset           : std_logic;
  signal resetn          : std_logic;
  signal button          : std_logic;
  signal ledState        : std_logic;
  signal state           : std_logic_vector(1 downto 0);
  signal serveState      : std_logic_vector(1 downto 0);
  signal served          : std_logic;
  signal waitingForServe : std_logic;


  signal plyr1unit : std_logic_vector(7 downto 0);
  signal plyr1tens : std_logic_vector(7 downto 0);
  signal plyr1hund : std_logic_vector(7 downto 0);
  signal plyr1thou : std_logic_vector(7 downto 0);
  signal liveslsb  : std_logic_vector(7 downto 0);
  signal livesmsb  : std_logic_vector(7 downto 0);


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

  signal ballX       : integer range -10 to 650 := 320;
  signal ballXdir    : integer range -2 to 2    := 1;
  signal ballY       : integer range 0 to 479   := 240;
  signal ballydir    : integer range -2 to 2    := 1;
  signal ballSize    : integer                  := 12;
  signal scaleBL     : integer range 1 to 32    := 1;  -- ball sprite scaling
  signal ballspeed   : integer range 0 to 9     := 1;
  signal drawbl      : std_logic;
  signal player1Wins : std_logic                := '0';
  signal player2Wins : std_logic                := '0';
  signal Lives       : integer                  := 25;
  signal GameOver    : std_logic                := '0';
  signal newTiles    : std_logic                := '1';
  signal blockHit    : integer range -40 to 1000;
  signal tilesHit    : integer range 0 to 100   := 0;


  signal paddlepos1 : std_logic_vector (11 downto 0);  -- adc player 1 - Y direction
  signal paddlepos2 : std_logic_vector (11 downto 0);  -- adc player 2 - Y direction
  signal paddlepos3 : std_logic_vector (11 downto 0);  -- adc player 1 - X direction
  signal paddlepos4 : std_logic_vector (11 downto 0);  -- adc player 2 - X direction
  signal paddlepos5 : std_logic_vector (11 downto 0);  -- adc spare
  signal paddlepos6 : std_logic_vector (11 downto 0);  -- adc spare
  signal paddlepos7 : std_logic_vector (11 downto 0);  -- adc spare
  signal paddlepos8 : std_logic_vector (11 downto 0);  -- adc spare
  signal adcCycle   : integer := 0;

  signal paddleSel    : std_logic;
  signal paddlein1pos : integer range 0 to 650 := 320;
  signal paddle1pos   : integer range 0 to 650 := 320;
  signal paddle1sz    : integer range 0 to 100 := 40;
  signal player1scr   : integer                := 0;
  signal scoreAdded   : integer := 0;
  signal acknowledged : std_logic := '0';
  signal paddlein2pos : integer range 0 to 650 := 320;
  signal paddle2pos   : integer range 0 to 650 := 320;
  signal paddle2sz    : integer range 0 to 100 := 40;
  signal player2scr   : integer                := 0;
  signal encoder1     : std_logic_vector(2 downto 0);
  signal encoder2     : std_logic_vector(2 downto 0);
  signal direction1   : std_logic;  -- quadrature decoder direction (up or down)
  signal direction2   : std_logic;
  signal position1    : integer;        -- current paddle position (numeric)
  signal position2    : integer;        -- current paddle position (numeric)

  signal cycle   : integer                 := 0;  -- memory write cycle
  signal charpos : integer range 0 to 4191 := 0;  -- character position from start of screen memory

  signal txtaddress : std_logic_vector(11 downto 0);  -- ram address for screen memory
  signal txtdata    : std_logic_vector(7 downto 0);   -- data for screen memory
  signal wren       : std_logic;        -- active low write strobe
  signal txtpixel   : std_logic;  -- output from screen memory to indicate pixel

  signal blipcount : integer   := 0;
  signal blip      : std_logic;
  signal blipped   : std_logic;
  signal blopcount : integer   := 0;
  signal blop      : std_logic;
  signal blopped   : std_logic;
  signal bang      : std_logic;
  signal banged    : std_logic;
  signal playing   : std_logic;
  signal played    : std_logic := '0';
  signal audio     : std_logic;
  signal tune      : std_logic_vector(3 downto 0);  -- room for 16 sounds of
                                                    -- 1024 bytes
  signal playTune  : std_logic;                     -- sound_strobe
  signal pwmOut    : std_logic;

  type SoundState is (IDLE, PLAY_TUNE, PLAY_DONE);
  signal Sound_State : SoundState := IDLE;  -- machine to drive sound generator

  signal aiControl : std_logic;

  -- Define an internal state for the writing process
  type WriteState is (IDLE, WRITE_DATA, WAIT_STROBE);
  signal write_state : WriteState := IDLE;

  -- Internal signal for character position
  signal charpos_int : unsigned(11 downto 0) := (others => '0');  -- reAdjusted size



begin
  clk           <= Max10_clk1_50;
  reset         <= key(1);
  resetn        <= not reset;
  button        <= key(0);
  ARDUINO_IO(5) <= pwmOut and not ledstate;  -- conect buzzer/speaker to arduino hat
  ARDUINO_IO(7) <= pwmOut and not ledstate;  -- digital io D5/D7

  encoder1(0) <= gpio(1);
  encoder1(1) <= gpio(3);
  encoder1(2) <= gpio(5);
  encoder2(0) <= gpio(0);
  encoder2(1) <= gpio(2);
  encoder2(2) <= gpio(4);

--  plyr1unit <= std_logic_vector(to_unsigned(blockhit mod 10, 8));
--  plyr1tens <= std_logic_vector(to_unsigned((blockhit / 10)mod 10, 8));
--  plyr1hund <= std_logic_vector(to_unsigned((blockhit /100)mod 10, 8));
--  plyr1thou <= std_logic_vector(to_unsigned((blockhit /1000)mod 10, 8));
  plyr1unit <= std_logic_vector(to_unsigned(player1scr mod 10, 8));
  plyr1tens <= std_logic_vector(to_unsigned((player1scr / 10)mod 10, 8));
  plyr1hund <= std_logic_vector(to_unsigned((player1scr /100)mod 10, 8));
  plyr1thou <= std_logic_vector(to_unsigned((player1scr /1000)mod 10, 8));

--  liveslsb <= std_logic_vector(to_unsigned((((bally*10)/24)+ballx/64) mod 10, 8));
--  livesmsb <= std_logic_vector(to_unsigned((((bally*10)/24)+ballx/64)/ 10, 8));
  liveslsb <= std_logic_vector(to_unsigned(lives mod 10, 8));
  livesmsb <= std_logic_vector(to_unsigned(lives / 10, 8));

  Xpi    <= to_integer(unsigned(Xp));
  ypi    <= to_integer(unsigned(Yp));
  VGA_VS <= VSync;
  VGA_HS <= HSync;
  VGA_R  <= RGB_R;
  VGA_G  <= RGB_G;
  VGA_B  <= RGB_B;

  SP(xpi, ypi, ballx, bally, ball, scaleBL, DRAWBL);
  aiControl <= sw(0);
  paddleSel <= SW(1);
  ledr(4)   <= playtune;                -- Debug LEDS
  ledr(5)   <= playing;
  ledr(6)   <= tune(0);
  ledr(7)   <= tune(1);
  ledr(8)   <= tune(2);
  ledr(9)   <= tune(3);


  -- Logic to toggle Led state

  process (clk, resetn, button)

  -- Get Inputs
  begin

    if resetn = '1' then
      state <= "00";
    elsif (rising_edge(max10_clk1_50)) then  -- LED off waiting for button press
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


  process (clk, resetn, button)

  -- Debounce serve button (vsync 6oHz)
  begin

    if resetn = '1' then
      serveState <= "00";
      served     <= '0';
    elsif (rising_edge(Vsync)) then
      if waitingForServe = '1' then  -- waiting for button press to serve ball
        if (serveState = "00") then
          if (encoder1(2) = '0') then
            serveState <= "01";
          else
            serveState <= "00";
          end if;
        elsif (serveState = "01") then  -- button pressed waiting, checking for button stable
          if (encoder1(2) = '1') then
            serveState <= "00";
          else
            serveState <= "10";
          end if;
        elsif (serveState = "10") then  -- stable press, waiting for button release
          if (encoder1(2) = '0') then
            serveState <= "10";
          else
            serveState <= "11";
          end if;
        elsif (serveState = "11") then  -- One clock here after button released
          serveState <= "00";
          served     <= '1';  -- could be in state '10' or here for served on
        -- release of the button
        end if;
      else
        served <= '0';
      end if;
    end if;
  end process;



  process (vgaclk)
  begin
    if rising_edge(vgaclk) then
      if resetn = '1' then              -- Active high reset
        txtaddress  <= (others => '0');
        txtdata     <= (others => '0');
        wren        <= '0';
        write_state <= IDLE;
        charpos_int <= (others => '0');
      else
        if blanking = '1' then
          case write_state is
            when IDLE =>
              -- Start writing if not blanking
              write_state <= WRITE_DATA;

            when WRITE_DATA =>
              wren <= '0';              -- Default to no write

              case to_integer(charpos_int) is
                when 2 =>
                  txtdata <= livesmsb or ASCII_OFFSET;
                  wren    <= '1';
                when 3 =>
                  txtdata <= liveslsb or ASCII_OFFSET;
                  wren    <= '1';
                when 33 =>
                  txtdata <= plyr1thou or ASCII_OFFSET;
                  wren    <= '1';
                when 34 =>
                  txtdata <= plyr1hund or ASCII_OFFSET;
                  wren    <= '1';
                when 35 =>
                  txtdata <= plyr1tens or ASCII_OFFSET;
                  wren    <= '1';
                when 36 =>
                  txtdata <= plyr1unit or ASCII_OFFSET;
                  wren    <= '1';
                when 37 =>
                  txtdata <= SCORE_0_ASCII;  -- articial big scores
                  wren    <= '1';
                when 41 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_G_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 42 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_A_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 43 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_M_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 44 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_E_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 46 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_O_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 47 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_V_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 48 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_E_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 49 =>
                  if GameOver = '1' then
                    txtdata <= GAME_OVER_R_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 76 =>
                  if player2wins = '1' then
                    txtdata <= PLAYER2_WIN_W_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 77 =>
                  if player2wins = '1' then
                    txtdata <= PLAYER2_WIN_I_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 78 =>
                  if player2wins = '1' then
                    txtdata <= PLAYER2_WIN_N_ASCII;
                    wren    <= '1';
                  else
                    txtdata <= SPACE_ASCII;
                    wren    <= '1';
                  end if;
                when 160 to 163 =>
                  if blockPresent(0) = '1' then
                    if to_integer(charpos_int) = 163 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 164 to 167 =>
                  if blockPresent(1) = '1' then
                    if to_integer(charpos_int) = 167 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 168 to 171 =>
                  if blockPresent(2) = '1' then
                    if to_integer(charpos_int) = 171 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 172 to 175 =>
                  if blockPresent(3) = '1' then
                    if to_integer(charpos_int) = 175 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 176 to 179 =>
                  if blockPresent(4) = '1' then
                    if to_integer(charpos_int) = 179 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 180 to 183 =>
                  if blockPresent(5) = '1' then
                    if to_integer(charpos_int) = 183 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 184 to 187 =>
                  if blockPresent(6) = '1' then
                    if to_integer(charpos_int) = 187 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 188 to 191 =>
                  if blockPresent(7) = '1' then
                    if to_integer(charpos_int) = 191 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 192 to 195 =>
                  if blockPresent(8) = '1' then
                    if to_integer(charpos_int) = 195 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 196 to 199 =>
                  if blockPresent(9) = '1' then
                    if to_integer(charpos_int) = 199 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 200 to 203 =>
                  if blockPresent(10) = '1' then
                    if to_integer(charpos_int) = 203 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 204 to 207 =>
                  if blockPresent(11) = '1' then
                    if to_integer(charpos_int) = 207 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 208 to 211 =>
                  if blockPresent(12) = '1' then
                    if to_integer(charpos_int) = 211 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 212 to 215 =>
                  if blockPresent(13) = '1' then
                    if to_integer(charpos_int) = 215 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 216 to 219 =>
                  if blockPresent(14) = '1' then
                    if to_integer(charpos_int) = 219 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 220 to 223 =>
                  if blockPresent(15) = '1' then
                    if to_integer(charpos_int) = 223 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 224 to 227 =>
                  if blockPresent(16) = '1' then
                    if to_integer(charpos_int) = 227 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 228 to 231 =>
                  if blockPresent(17) = '1' then
                    if to_integer(charpos_int) = 231 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 232 to 235 =>
                  if blockPresent(18) = '1' then
                    if to_integer(charpos_int) = 235 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 236 to 239 =>
                  if blockPresent(19) = '1' then
                    if to_integer(charpos_int) = 239 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 240 to 243 =>
                  if blockPresent(20) = '1' then
                    if to_integer(charpos_int) = 243 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 244 to 247 =>
                  if blockPresent(21) = '1' then
                    if to_integer(charpos_int) = 247 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 248 to 251 =>
                  if blockPresent(22) = '1' then
                    if to_integer(charpos_int) = 251 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 252 to 255 =>
                  if blockPresent(23) = '1' then
                    if to_integer(charpos_int) = 255 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 256 to 259 =>
                  if blockPresent(24) = '1' then
                    if to_integer(charpos_int) = 259 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 260 to 263 =>
                  if blockPresent(25) = '1' then
                    if to_integer(charpos_int) = 263 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 264 to 267 =>
                  if blockPresent(26) = '1' then
                    if to_integer(charpos_int) = 267 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 268 to 271 =>
                  if blockPresent(27) = '1' then
                    if to_integer(charpos_int) = 271 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 272 to 275 =>
                  if blockPresent(28) = '1' then
                    if to_integer(charpos_int) = 275 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 276 to 279 =>
                  if blockPresent(29) = '1' then
                    if to_integer(charpos_int) = 279 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 280 to 283 =>
                  if blockPresent(30) = '1' then
                    if to_integer(charpos_int) = 283 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 284 to 287 =>
                  if blockPresent(31) = '1' then
                    if to_integer(charpos_int) = 287 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 288 to 291 =>
                  if blockPresent(32) = '1' then
                    if to_integer(charpos_int) = 291 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 292 to 295 =>
                  if blockPresent(33) = '1' then
                    if to_integer(charpos_int) = 295 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 296 to 299 =>
                  if blockPresent(34) = '1' then
                    if to_integer(charpos_int) = 299 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 300 to 303 =>
                  if blockPresent(35) = '1' then
                    if to_integer(charpos_int) = 303 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 304 to 307 =>
                  if blockPresent(36) = '1' then
                    if to_integer(charpos_int) = 307 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 308 to 311 =>
                  if blockPresent(37) = '1' then
                    if to_integer(charpos_int) = 311 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 312 to 315 =>
                  if blockPresent(38) = '1' then
                    if to_integer(charpos_int) = 315 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when 316 to 319 =>
                  if blockPresent(39) = '1' then
                    if to_integer(charpos_int) = 319 then
                      txtdata <= BLOCK_MISSING_LAST;
                    else
                      txtdata <= BLOCK_FULL;
                    end if;
                    wren <= '1';
                  else
                    txtdata <= BLOCK_EMPTY;
                    wren    <= '1';
                  end if;
                when others =>
                  wren <= '0';
              end case;
              txtAddress  <= std_logic_vector(charpos_int);
              write_state <= WAIT_STROBE;

            when WAIT_STROBE =>
              -- Strobe wren high for one clock cycle
              wren        <= '0';
              write_state <= IDLE;
              if charpos_int < 1023 then
                charpos_int <= charpos_int + 1;
              else
                charpos_int <= (others => '0');
              end if;
          end case;
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
        if yPi > 100 and yPi < 124 then  -- colour bands as we go down the screen
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
      elsif (((ypi > 460) and (ypi < 470) and (xpi > (paddle1pos - paddle1sz)) and (xpi < (paddle1pos + paddle1sz))))
      then
        RGB_R <= x"f";
        RGB_G <= x"f";
        RGB_B <= x"f";

      -- Draw the Ball
      elsif drawbl = '1' then  --((Xpi > ballX-(ballSize/2)) and (Xpi < ballX+(ballSize/2)) and
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
      blipped     <= '0';
      blopped     <= '0';
      banged      <= '0';
      audio       <= '0';
      playtune    <= '0';
      Sound_State <= IDLE;
    elsif (rising_edge(clk)) then

      case Sound_State is
        when IDLE =>
          playtune <= '0';
          if bang = '1' or blip = '1' or blop = '1' then
            sound_State <= PLAY_TUNE;
            if bang = '1' then
              tune <= "0000";
            elsif blip = '1' then
              tune <= "0001";
            else tune <= "0010";
            end if;
          else
            sound_State <= IDLE;
          end if;
        when PLAY_TUNE =>
          playtune <= '1';
          if playing = '1' then
            Sound_State <= PLAY_DONE;
          else
            Sound_State <= PLAY_TUNE;
          end if;
        when PLAY_DONE =>
          playtune <= '0';
          if playing = '0' then
            played      <= '1';
            Sound_State <= IDLE;
          else
            sound_State <= PLAY_DONE;
          end if;
      end case;
    end if;
  end process;


  blockHit <= (((ballY - 96) / 24) * 10) + (ballX/64);  -- Block 0 at 120, 0 and ten blocks (24 x 64) per row

  -- move Ball - synchronised to Vsync 60Hz
  process(VSync, ballX, BallY, adcCycle, blipped, blopped, resetn)
  begin
    if resetn = '1' then
      ballX           <= 320;
      ballY           <= 220;
      WaitingForServe <= '1';
      ballspeed       <= 2;
      ballXDir        <= 1;
      ballYDir        <= 1;
      player1scr      <= 0;
      scoreAdded      <= 0;
      player2scr      <= 0;
      player1Wins     <= '0';
      player2Wins     <= '0';
      lives           <= 15;
      gameOver        <= '0';
      adcCycle        <= 0;
      blip            <= '0';
      blop            <= '0';
      bang            <= '0';
      tilesHit        <= 0;
      newTiles        <= '1';
    -- blockHit        <= -1;
    elsif (rising_edge(VSync)) then
      if played = '1' then
        blip <= '0';
        blop <= '0';
        bang <= '0';
      end if;
      if scoreAdded > 0 and acknowledged = '0' then
        player1scr <= player1scr + scoreAdded;
        acknowledged <= '1';
        scoreAdded <= 0;
      else acknowledged <= '0';
      end if;
      if served = '0' and WaitingForServe = '1' then
        if newTiles = '1' then
          blockPresent <= ('1', '1', '1', '1', '1', '1', '1', '1',
                           '1', '1', '1', '1', '1', '1', '1', '1',
                           '1', '1', '1', '1', '1', '1', '1', '1',
                           '1', '1', '1', '1', '1', '1', '1', '1',
                           '1', '1', '1', '1', '1', '1', '1', '1');
          newTiles <= '0';
        end if;
        ballX    <= 320;
        ballY    <= 220;
        ballydir <= 1;

      else
        waitingForServe <= '0';
        scoreAdded <= 0;
        ballx           <= ballx + ballXDir*ballspeed;
        bally           <= bally + BallYDir*ballspeed;
        -- which block is ball hitting?
--        blockHit        <= (((ballY - 96 - ballydir * 12 + ballydir*scalebl*6) / 24) * 10) + (ballX/64);  -- Block 0 at 120, 0 and ten blocks (24 x 64) per row
--        blockHit        <= (((ballY - 96) / 24) * 10) + (ballX/64);  -- Block 0 at 120, 0 and ten blocks (24 x 64) per row
        -- AI player control
        -- paddle1pos <= ballx;
        case bally is
          when 0 to 60 =>
            -- ball hits top edge
            ballYdir <= 1;              --abs (ballydir);
            bally    <= 60 + scalebl*2;


          when 96 to 192 =>
            if blockPresent(blockHit) = '1' and blockHit >= 0 then
              blockPresent(blockHit) <= '0';
              if acknowledged = '0' then
                scoreAdded             <= 8 - (bally) / 24;
              else
                scoreAdded <= 0;
              end if;
              tilesHit               <= tilesHit + 1;
              if tilesHit = 39 then
                tilesHit        <= 0;
                --blockHit        <= -5;
                newTiles        <= '1';
                blop            <= '1';
                bally           <= 220;
                ballydir        <= 1;
                WaitingForServe <= '1';
              end if;
              bang <= '1';
              if bally < 99 then
                ballYdir <= -abs(ballydir);
                bally    <= bally - scalebl *4;
              elsif bally < 116 then
                if ballx mod 64 > 60 then
                  ballxdir <= abs(ballxdir);
                elsif ballx mod 64 < 4 then
                  ballxdir <= - abs(ballxdir);
                end if;
              elsif bally < 119 then
                ballYdir <= abs(ballydir);
                bally    <= bally + scalebl *4;
              elsif bally < 122 then
                ballYdir <= -abs(ballydir);
                bally    <= bally - scalebl *4;
              elsif bally < 140 then
                if ballx mod 64 > 60 then
                  ballxdir <= abs(ballxdir);
                elsif ballx mod 64 < 4 then
                  ballxdir <= - abs(ballxdir);
                end if;
              elsif bally < 143 then
                ballYdir <= abs(ballydir);
                bally    <= bally + scalebl *4;
              elsif bally < 146 then
                ballYdir <= -abs(ballydir);
                bally    <= bally - scalebl *4;
              elsif bally < 164 then
                if ballx mod 64 > 60 then
                  ballxdir <= abs(ballxdir);
                elsif ballx mod 64 < 4 then
                  ballxdir <= - abs(ballxdir);
                end if;
              elsif bally < 167 then
                ballYdir <= abs(ballydir);
                bally    <= bally + scalebl *4;
              elsif bally < 170 then
                ballYdir <= -abs(ballydir);
                bally    <= bally - scalebl *4;
              elsif bally < 188 then
                if ballx mod 64 > 60 then
                  ballxdir <= abs(ballxdir);
                elsif ballx mod 64 < 4 then
                  ballxdir <= - abs(ballxdir);
                end if;
              elsif bally < 191 then
                ballYdir <= abs(ballydir);
                bally    <= bally + scalebl *4;
              end if;
            end if;
          when 460 - scalebl*3 to 470 - scalebl*3 =>  -- line of paddle vertically

            -- player 1 paddle hit

            if ballx > paddle1pos - paddle1sz and ballx < (paddle1pos - 3*(paddle1sz) /4)then
              ballxdir <= -2;
              ballydir <= -1;
              blip     <= '1';
              bally    <= bally - 1;
            elsif ballx > paddle1pos - 3* (paddle1sz)/4 and ballx < (paddle1pos - paddle1sz/3) then
              ballxdir <= -1;
              ballydir <= -1;
              blip     <= '1';
              bally    <= bally - 1;
            elsif ballx >= paddle1pos - (paddle1sz)/3 and ballx < (paddle1pos + paddle1sz/3) then
              ballydir <= -1;
              blip     <= '1';
              bally    <= bally - 1;
            elsif ballx >= paddle1pos + paddle1sz/3 and ballx < paddle1pos + (3* (paddle1sz)/4) then
              ballxdir <= 1;
              ballydir <= -1;
              blip     <= '1';
              bally    <= bally - 1;
            elsif ballx > paddle1pos + 3*(paddle1sz) /4 and ballx < paddle1pos + paddle1sz then
              ballxdir <= 2;
              ballydir <= -1;
              blip     <= '1';
              bally    <= bally - 1;
            else
              ballxdir <= ballxdir;     -- paddle missed
            end if;

          when 475 to 479 =>
            Lives <= Lives - 1;
            blop  <= '1';
            if Lives = 1 then
              gameOver <= '1';
              ballxdir <= 0;
              ballydir <= 0;
              ballx    <= 320;
              bally    <= 220;
            else
              bally           <= 220;
              waitingForServe <= '1';
              ballydir        <= 1;
            end if;
          when others =>
            ballydir <= ballydir;

        end case;

        -- ball hits right edge
        if ballX >= 639 - ballsize/2 then
          ballXdir <= -abs(ballxdir);
--        blop <= '1'; 
        -- ball hits left edge
        elsif ballX < ballsize/2 then
          ballXdir <= abs(ballxdir);
          ballx    <= ballx + abs(ballxdir);
--        blop <= '1';
        end if;
      end if;
      if aicontrol = '1' then
        paddle1pos <= ballx + 30 - player1scr mod 60;
      else
        -- player controlled paddles
        if paddleSel = '1' then
          if (adcCycle = 0) then  -- adcCycle allows time for conversions to complete
            paddlein1pos <= (to_integer(unsigned(paddlepos1(11 downto 3))));
            adcCycle     <= 1;
            -- ledr(9)      <= '1';

          elsif adcCycle = 1 then
            adcCycle <= 0;
            if paddlein1pos > 640 then
              paddle1pos <= 640;
            elsif paddlein1pos < 1 then
              paddle1pos <= 1;
            else
              paddle1pos <= paddlein1pos;
            end if;
          end if;
        else
          paddle1Pos <= position1 * 4 mod 640;

        end if;
      end if;

      --debugmsb <= std_logic_vector(to_unsigned(paddle2pos / 10, 8));
      --debuglsb <= std_logic_vector(to_unsigned(paddle2pos mod 10, 8));

    end if;
  end process;



  -- Instantiate components

  pwmAudio : pwm_sound
    generic map (
      clk_frequency_hz => clk_frequency_hz,
      pwm_frequency_hz => pwm_frequency_hz,
      sound_addr_width => sound_addr_width
      )
    port map(
      clk_i          => clk,
      reset_i        => resetn,
      tune_addr_i    => tune,
      sound_strobe_i => playTune,
      gpio_o         => pwmOut,
      working        => playing
      );

  hexlsb    : hexdisplay port map(plyr1thou(3 downto 0), HEX3(7 downto 0));
  hexmsb    : hexdisplay port map(plyr1hund(3 downto 0), HEX2(7 downto 0));
  hexlsb2   : hexdisplay port map(plyr1tens(3 downto 0), HEX1(7 downto 0));
  hexmsb2   : hexdisplay port map(plyr1unit(3 downto 0), HEX0(7 downto 0));
  hexlsbd   : hexdisplay port map(livesmsb(3 downto 0), HEX5(7 downto 0));
  hexmsbd   : hexdisplay port map(liveslsb(3 downto 0), HEX4(7 downto 0));
  display   : video_sync_generator port map(resetn, vgaClk, blanking, Hsync, Vsync, Xp, Yp);
  vgaClock  : vgaClockPLL port map(clk, vgaClk);
-- Get the current paddle positions
  -- from encoder reading
  paddleone : quadrature_decoder port map (clk, encoder1(0), encoder1(1), not resetn, direction1, position1);
  paddletwo : quadrature_decoder port map (clk, encoder2(0), encoder2(1), not resetn, direction2, position2);

  -- or adc reading
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
  ledr(1)  <= not player1wins;
  ledr(2)  <= not player2wins;

  ledr(3) <= encoder1(2);
end rtl;
