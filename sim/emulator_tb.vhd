----------------------------------------------------------------------------------
-- emulator_tb.vhd   (TEST BENCH - simulation only)
-- Sends PIC16F887 instructions through the serial port and shows the
-- Intel 8086 bytes that the emulator sends back (signal x86_byte).
--
-- Self-checking: every received byte and the final AL / flag values are
-- compared with the expected results; the run ends with TEST PASSED or FAILED.
--
-- For a short simulation the serial speed is increased: 1 bit = 16 clocks.
-- Simulation run time: 150 us
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity emulator_tb is
end emulator_tb;

architecture behavior of emulator_tb is

    component emulator_top
        Generic ( CLKS_PER_BIT : integer := 5208 );
        Port ( clk : in  STD_LOGIC;
               rst : in  STD_LOGIC;
               rxd : in  STD_LOGIC;
               sw  : in  STD_LOGIC_VECTOR (1 downto 0);
               txd : out STD_LOGIC;
               led : out STD_LOGIC_VECTOR (7 downto 0));
    end component;

    constant CLK_PERIOD : time := 20 ns;                 -- 50 MHz
    constant BIT_PERIOD : time := 320 ns;                -- 16 clocks

    -- PIC16F887 instructions to send (2 bytes each, high byte first)
    type byte_array is array (0 to 9) of std_logic_vector (7 downto 0);
    constant PIC_PROGRAM : byte_array := (
        x"3E", x"25",        -- ADDLW 0x25     ->  04 25         AL = 25
        x"07", x"A0",        -- ADDWF 0x20, F  ->  00 06 20 00   [0020] = 25
        x"07", x"20",        -- ADDWF 0x20, W  ->  02 06 20 00   AL = 4A
        x"3E", x"C0",        -- ADDLW 0xC0     ->  04 C0         AL = 0A, CF = 1
        x"30", x"25" );      -- MOVLW 0x25     ->  90 (not an addition)

    -- Intel 8086 bytes expected back from the FPGA, in order
    type exp_array is array (0 to 12) of std_logic_vector (7 downto 0);
    constant EXPECTED : exp_array := (
        x"04", x"25",                    -- ADD AL, 25h
        x"00", x"06", x"20", x"00",      -- ADD [0020h], AL
        x"02", x"06", x"20", x"00",      -- ADD AL, [0020h]
        x"04", x"C0",                    -- ADD AL, C0h
        x"90" );                         -- NOP (not an addition)

    signal rx_count : integer := 0;                        -- bytes received so far
    signal errors   : integer := 0;                        -- mismatches seen by the monitor

    -- explicit binding (portable across ISE, ISim, ModelSim and GHDL)
    for uut : emulator_top use entity work.emulator_top(Behavioral);

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal rxd : std_logic := '1';
    signal sw  : std_logic_vector (1 downto 0) := "00";
    signal txd : std_logic;
    signal led : std_logic_vector (7 downto 0);

    -- signals for watching in the wave window
    signal pic_byte  : std_logic_vector (7 downto 0) := x"00";   -- byte sent to the FPGA
    signal x86_byte  : std_logic_vector (7 downto 0) := x"00";   -- byte received from the FPGA
    signal x86_valid : std_logic := '0';

begin

    uut : emulator_top
        generic map ( CLKS_PER_BIT => 16 )
        port map ( clk => clk, rst => rst, rxd => rxd, sw => sw, txd => txd, led => led );

    -- 50 MHz clock
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- stimulus: send the PIC instructions through the serial port
    stim_proc : process
    begin
        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        for n in 0 to 9 loop
            pic_byte <= PIC_PROGRAM(n);
            rxd <= '0';                                  -- start bit
            wait for BIT_PERIOD;
            for i in 0 to 7 loop                         -- data bits, LSB first
                rxd <= PIC_PROGRAM(n)(i);
                wait for BIT_PERIOD;
            end loop;
            rxd <= '1';                                  -- stop bit
            wait for BIT_PERIOD;

            if (n mod 2) = 1 then                        -- instruction complete:
                wait for 60 * BIT_PERIOD;                -- wait for the answer
            end if;
        end loop;

        -- status after the last instruction (MOVLW): error = 1, ready = 1, 1 byte
        assert led = x"C1"
            report "Status LEDs wrong after MOVLW (expected C1h)" severity error;

        -- show the results of the execution on the LEDs
        sw <= "01";                                      -- led = register AL  (0A)
        wait for 1 us;
        assert led = x"0A"
            report "Register AL wrong (expected 0Ah)" severity error;
        wait for 4 us;
        sw <= "10";                                      -- led = flags        (01: CF = 1)
        wait for 1 us;
        assert led = x"01"
            report "Flags wrong (expected 01h: CF = 1)" severity error;
        wait for 4 us;
        sw <= "00";                                      -- led = status
        wait for 1 us;

        -- final verdict
        assert rx_count = 13
            report "Wrong number of 8086 bytes received: " & integer'image(rx_count)
            severity error;
        if rx_count = 13 and errors = 0 and led = x"C1" then
            report "TEST PASSED: all 13 bytes, AL = 0Ah, flags = 01h" severity note;
        else
            report "TEST FAILED" severity error;
        end if;

        wait;
    end process;

    -- monitor: receive the bytes sent by the FPGA
    mon_proc : process
        variable b : std_logic_vector (7 downto 0);
    begin
        wait until txd = '0';                            -- start bit
        wait for BIT_PERIOD + BIT_PERIOD / 2;            -- middle of bit 0
        for i in 0 to 7 loop
            b(i) := txd;
            wait for BIT_PERIOD;
        end loop;
        x86_byte  <= b;
        x86_valid <= '1';
        if rx_count > 12 then
            report "Unexpected extra byte from the FPGA" severity error;
            errors <= errors + 1;
        elsif b /= EXPECTED(rx_count) then
            report "Byte " & integer'image(rx_count) & " wrong" severity error;
            errors <= errors + 1;
        end if;
        rx_count <= rx_count + 1;
        wait for BIT_PERIOD / 4;
        x86_valid <= '0';
    end process;

end behavior;
