----------------------------------------------------------------------------------
-- emulator_top.vhd   (TOP MODULE)
-- Hardware emulator: PIC16F887 addition instructions -> Intel 8086 machine code.
--
-- Input  (serial port, 9600 8N1): 2 bytes of the PIC instruction, high byte first
--                                 byte 1 = "00" & code(13..8),  byte 2 = code(7..0)
-- Output (serial port):           1..4 bytes of the Intel 8086 instruction
-- The converted instruction is also executed by the 8086 execution unit
-- (register AL, memory of 128 bytes and flags).
--
-- LEDs:  sw = "00" or "11":  led(7) = error (not an addition instruction)
--                            led(6) = result ready
--                            led(2..0) = number of 8086 bytes
--        sw = "01":          led = register AL
--        sw = "10":          led = flags  "000" & AF & OF & SF & ZF & CF
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity emulator_top is
    Generic ( CLKS_PER_BIT : integer := 5208 );          -- 50 MHz / 9600 baud
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           rxd : in  STD_LOGIC;
           sw  : in  STD_LOGIC_VECTOR (1 downto 0);
           txd : out STD_LOGIC;
           led : out STD_LOGIC_VECTOR (7 downto 0));
end emulator_top;

architecture Behavioral of emulator_top is

    component uart_rx
        Generic ( CLKS_PER_BIT : integer := 5208 );
        Port ( clk     : in  STD_LOGIC;
               rst     : in  STD_LOGIC;
               rx      : in  STD_LOGIC;
               rx_dv   : out STD_LOGIC;
               rx_byte : out STD_LOGIC_VECTOR (7 downto 0));
    end component;

    component uart_tx
        Generic ( CLKS_PER_BIT : integer := 5208 );
        Port ( clk      : in  STD_LOGIC;
               rst      : in  STD_LOGIC;
               tx_start : in  STD_LOGIC;
               tx_byte  : in  STD_LOGIC_VECTOR (7 downto 0);
               tx       : out STD_LOGIC;
               tx_done  : out STD_LOGIC);
    end component;

    component pic_to_8086
        Port ( pic_code : in  STD_LOGIC_VECTOR (13 downto 0);
               x86_b0   : out STD_LOGIC_VECTOR (7 downto 0);
               x86_b1   : out STD_LOGIC_VECTOR (7 downto 0);
               x86_b2   : out STD_LOGIC_VECTOR (7 downto 0);
               x86_b3   : out STD_LOGIC_VECTOR (7 downto 0);
               x86_len  : out STD_LOGIC_VECTOR (2 downto 0);
               error    : out STD_LOGIC);
    end component;

    component x86_exec
        Port ( clk     : in  STD_LOGIC;
               rst     : in  STD_LOGIC;
               exec    : in  STD_LOGIC;
               x86_b0  : in  STD_LOGIC_VECTOR (7 downto 0);
               x86_b1  : in  STD_LOGIC_VECTOR (7 downto 0);
               x86_b2  : in  STD_LOGIC_VECTOR (7 downto 0);
               al      : out STD_LOGIC_VECTOR (7 downto 0);
               flags   : out STD_LOGIC_VECTOR (7 downto 0));
    end component;

    type state_type is (S_HIGH, S_LOW, S_DECODE, S_SEND, S_WAIT);
    signal state    : state_type := S_HIGH;

    signal rx_dv    : std_logic;
    signal rx_byte  : std_logic_vector (7 downto 0);
    signal tx_start : std_logic := '0';
    signal tx_byte  : std_logic_vector (7 downto 0) := (others => '0');
    signal tx_done  : std_logic;

    signal pic_code : std_logic_vector (13 downto 0) := (others => '0');
    signal b0, b1, b2, b3 : std_logic_vector (7 downto 0);
    signal len      : std_logic_vector (2 downto 0);
    signal err      : std_logic;

    signal r0, r1, r2, r3 : std_logic_vector (7 downto 0) := (others => '0');
    signal r_len    : integer range 0 to 4 := 0;
    signal idx      : integer range 0 to 3 := 0;
    signal led_r    : std_logic_vector (7 downto 0) := (others => '0');

    signal exec_en  : std_logic := '0';                   -- execute the instruction
    signal al       : std_logic_vector (7 downto 0);      -- register AL
    signal flags    : std_logic_vector (7 downto 0);      -- 8086 flags

begin

    U_RX : uart_rx
        generic map ( CLKS_PER_BIT => CLKS_PER_BIT )
        port map ( clk => clk, rst => rst, rx => rxd, rx_dv => rx_dv, rx_byte => rx_byte );

    U_TX : uart_tx
        generic map ( CLKS_PER_BIT => CLKS_PER_BIT )
        port map ( clk => clk, rst => rst, tx_start => tx_start, tx_byte => tx_byte,
                   tx => txd, tx_done => tx_done );

    U_CONV : pic_to_8086
        port map ( pic_code => pic_code, x86_b0 => b0, x86_b1 => b1, x86_b2 => b2,
                   x86_b3 => b3, x86_len => len, error => err );

    U_EXEC : x86_exec
        port map ( clk => clk, rst => rst, exec => exec_en, x86_b0 => b0, x86_b1 => b1,
                   x86_b2 => b2, al => al, flags => flags );

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= S_HIGH;
                tx_start <= '0';
                exec_en  <= '0';
                idx      <= 0;
                led_r    <= (others => '0');
            else
                tx_start <= '0';
                exec_en  <= '0';

                case state is
                    when S_HIGH =>                       -- first byte: bits 13..8
                        if rx_dv = '1' then
                            pic_code(13 downto 8) <= rx_byte(5 downto 0);
                            state <= S_LOW;
                        end if;

                    when S_LOW =>                        -- second byte: bits 7..0
                        if rx_dv = '1' then
                            pic_code(7 downto 0) <= rx_byte;
                            state <= S_DECODE;
                        end if;

                    when S_DECODE =>                     -- store the converter outputs
                        r0 <= b0;
                        r1 <= b1;
                        r2 <= b2;
                        r3 <= b3;
                        case len is
                            when "010"  => r_len <= 2;
                            when "100"  => r_len <= 4;
                            when others => r_len <= 1;
                        end case;
                        led_r(7)          <= err;      -- error
                        led_r(6)          <= '1';      -- result ready
                        led_r(5 downto 3) <= "000";
                        led_r(2 downto 0) <= len;      -- number of bytes
                        exec_en <= '1';                  -- execute it in the 8086 unit
                        idx   <= 0;
                        state <= S_SEND;

                    when S_SEND =>                       -- send one byte of the 8086 code
                        case idx is
                            when 0      => tx_byte <= r0;
                            when 1      => tx_byte <= r1;
                            when 2      => tx_byte <= r2;
                            when others => tx_byte <= r3;
                        end case;
                        tx_start <= '1';
                        state    <= S_WAIT;

                    when S_WAIT =>                       -- wait until the byte is sent
                        if tx_done = '1' then
                            if idx = r_len - 1 then
                                state <= S_HIGH;
                            else
                                idx   <= idx + 1;
                                state <= S_SEND;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- the switches select what the LEDs show
    with sw select
        led <= al    when "01",
               flags when "10",
               led_r when others;

end Behavioral;
