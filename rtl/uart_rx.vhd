----------------------------------------------------------------------------------
-- uart_rx.vhd
-- Serial port receiver: 8 data bits, no parity, 1 stop bit.
-- CLKS_PER_BIT = clock frequency / baud rate = 50 000 000 / 9600 = 5208
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_rx is
    Generic ( CLKS_PER_BIT : integer := 5208 );
    Port ( clk     : in  STD_LOGIC;
           rst     : in  STD_LOGIC;
           rx      : in  STD_LOGIC;
           rx_dv   : out STD_LOGIC;                       -- '1' for one clock: byte received
           rx_byte : out STD_LOGIC_VECTOR (7 downto 0));
end uart_rx;

architecture Behavioral of uart_rx is
    type state_type is (S_IDLE, S_START, S_DATA, S_STOP);
    signal state   : state_type := S_IDLE;
    signal rx_s1   : std_logic := '1';
    signal rx_s2   : std_logic := '1';
    signal clk_cnt : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_idx : integer range 0 to 7 := 0;
    signal data    : std_logic_vector (7 downto 0) := (others => '0');
begin

    process (clk)
    begin
        if rising_edge(clk) then
            -- synchronize the asynchronous input
            rx_s1 <= rx;
            rx_s2 <= rx_s1;

            if rst = '1' then
                state   <= S_IDLE;
                rx_dv   <= '0';
                clk_cnt <= 0;
                bit_idx <= 0;
            else
                rx_dv <= '0';

                case state is
                    when S_IDLE =>
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        if rx_s2 = '0' then              -- start bit detected
                            state <= S_START;
                        end if;

                    when S_START =>                      -- wait for the middle of the start bit
                        if clk_cnt = (CLKS_PER_BIT - 1) / 2 then
                            if rx_s2 = '0' then
                                clk_cnt <= 0;
                                state   <= S_DATA;
                            else
                                state   <= S_IDLE;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when S_DATA =>                       -- sample every bit in its middle
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            data(bit_idx) <= rx_s2;
                            if bit_idx = 7 then
                                bit_idx <= 0;
                                state   <= S_STOP;
                            else
                                bit_idx <= bit_idx + 1;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when S_STOP =>
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            rx_dv   <= '1';
                            state   <= S_IDLE;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    rx_byte <= data;

end Behavioral;
