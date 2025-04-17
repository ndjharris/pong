library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_sound is
    generic (
        -- System clock frequency in Hz
        clk_frequency_hz : integer := 50_000_000;  -- Default: 50 MHz
        -- PWM frequency in Hz (adjust for desired sound quality)
        pwm_frequency_hz : integer := 20_000;      -- Default: 20 kHz
        -- Width of the address bus for sound data
        sound_addr_width : integer := 4         -- Default: 10 bits (1024 samples)
    );
    port (
        clk_i       : in  std_logic;                     -- System clock input
        reset_i     : in  std_logic;                    -- reset active High
        tune_addr_i  : in  std_logic_vector(sound_addr_width - 1 downto 0);  -- Address of
                                                                             -- sound sample to play
        sound_strobe_i: in  std_logic;                     -- Strobe signal to trigger sound playback
        gpio_o      : out std_logic;                      -- PWM output to GPIO pin
        working     : out std_logic
    );
end pwm_sound;

architecture Behavioral of pwm_sound is
    -- Calculate the period of the PWM signal in clock cycles.
    constant pwm_period_cycles : integer := clk_frequency_hz / pwm_frequency_hz;
    component soundrom
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (13 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
    end component;
    
    -- Define a type for the sound data.  Using std_logic_vector to represent
    -- the amplitude of the sound at each address.  The width of this vector
    -- determines the resolution of the sound.  For example, 8 bits gives 256
    -- levels of amplitude.
    type sound_data_t is array (0 to 2**sound_addr_width - 1) of std_logic_vector(7 downto 0);  -- Example: 8-bit sound data
    signal sample_addr : std_logic_vector(13 downto 0);
    signal sound_data : std_logic_vector (7 downto 0);
    -- Example sound data (replace with your actual sound data).  This example
    -- contains a simple tone, but in a real application, this would come from
    -- a memory or be generated algorithmically.
    signal sound_data1 : sound_data_t := (
        0 => "10000000",
        1 => "10100000",
        2 => "11000000",
        3 => "11100000",
        4 => "11110000",
        5 => "11111000",
        6 => "11111100",
        7 => "11111110",
        8 => "11111111",
        9 => "11111110",
        10 => "11111100",
        11 => "11111000",
        12 => "11110000",
        13 => "11100000",
        14 => "11000000",
        15 => "10100000"--,
--        16 to 1023 => (others => "10000000")  -- Repeat first value for the rest
    );

    signal pwm_counter : integer := 0;
    signal current_sound_addr : unsigned(9 downto 0) := (others => '0');
    signal current_amplitude : unsigned(7 downto 0) := (others => '0'); -- Matches the width of the sound data
    signal is_playing    : std_logic := '0';

begin
    process (clk_i, reset_i)
    begin
        if reset_i = '1' then
            pwm_counter <= 0;
            gpio_o <= '0';
            current_sound_addr(9 downto 0) <= (others => '0');
            is_playing <= '0';
            working <= '0';
        elsif rising_edge(clk_i) then
            if sound_strobe_i = '1' then
                is_playing <= '1';
                working <= '1';
                current_sound_addr <= (others => '0');
                pwm_counter <= 0; --restart counter
            end if;

            if is_playing = '1' then
              -- Get the amplitude from the sound data.
              -- current_amplitude <= unsigned(sound_data);
              -- read from ROM

              -- Generate the PWM signal.  The duty cycle is determined by the
              -- current amplitude.
              if pwm_counter < to_integer(current_amplitude) then
                  gpio_o <= '1';
              else
                  gpio_o <= '0';
              end if;

              -- Increment the PWM counter.
              pwm_counter <= pwm_counter + 1;

              -- If the PWM counter reaches the end of the period, reset it.
              if pwm_counter >= pwm_period_cycles - 1 then
                  pwm_counter <= 0;
              end if;

              -- Advance to the next address in the sound data.
              if pwm_counter = 0 then  -- Only advance address once per PWM period
                if current_sound_addr < 2**10 - 1 then
                    current_sound_addr <= current_sound_addr + 1;
                else
                    current_sound_addr <= (others => '0');
                    is_playing <= '0';  -- Stop playing at the end of the sound data
                    working <= '0';
                end if;
              end if;
            else
                gpio_o <= '0';
                pwm_counter <= 0;
            end if;
        end if;
    end process;
    sample_addr(13 downto 10) <= tune_addr_i;
    sample_addr(9 downto 0)   <= std_logic_vector(current_sound_addr);
    current_amplitude <= unsigned(sound_data);
    soundrom_inst : soundrom PORT MAP (
		address	 => sample_addr,
		clock	 => clk_i,
		q	 => sound_data
	);

end Behavioral;
