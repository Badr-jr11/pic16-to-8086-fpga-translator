----------------------------------------------------------------------------------
-- uart_tx.vhd
-- Serial port transmitter: 8 data bits, no parity, 1 stop bit.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_tx is
    Generic ( CLKS_PER_BIT : integer := 5208 );
    Port ( clk      : in  STD_LOGIC;
           rst      : in  STD_LOGIC;
           tx_start : in  STD_LOGIC;                      -- '1' for one clock: send tx_byte
           tx_byte  : in  STD_LOGIC_VECTOR (7 downto 0);
           tx       : out STD_LOGIC;
           tx_done  : out STD_LOGIC);                     -- '1' for one clock: byte sent
end uart_tx;

architecture Behavioral of uart_tx is
    type state_type is (S_IDLE, S_START, S_DATA, S_STOP);
    signal state   : state_type := S_IDLE;
    signal clk_cnt : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_idx : integer range 0 to 7 := 0;
    signal data    : std_logic_vector (7 downto 0) := (others => '0');
begin

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state   <= S_IDLE;
                tx      <= '1';
                tx_done <= '0';
                clk_cnt <= 0;
                bit_idx <= 0;
            else
                tx_done <= '0';

                case state is
                    when S_IDLE =>
                        tx      <= '1';
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        if tx_start = '1' then
                            data  <= tx_byte;
                            state <= S_START;
                        end if;

                    when S_START =>
                        tx <= '0';
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            state   <= S_DATA;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when S_DATA =>
                        tx <= data(bit_idx);
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
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
                        tx <= '1';
                        if clk_cnt = CLKS_PER_BIT - 1 then
                            clk_cnt <= 0;
                            tx_done <= '1';
                            state   <= S_IDLE;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
