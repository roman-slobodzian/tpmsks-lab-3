library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_uart_tx is
    generic (BAUD_DIV : positive := 10);
end entity;

architecture test of tb_uart_tx is
    constant CLOCK_PERIOD : time := 20 ns;
    constant BIT_PERIOD   : time := CLOCK_PERIOD * BAUD_DIV;
    constant EXPECTED     : std_logic_vector(7 downto 0) := x"48";
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal key            : std_logic_vector(0 downto 0) := "1";
    signal uart_tx        : std_logic;
    signal ledr           : std_logic_vector(0 downto 0);
    signal frames         : natural := 0;
    signal check_frames   : boolean := true;
begin
    clk <= not clk after CLOCK_PERIOD / 2;
    dut : entity work.simple_uart_tx
        generic map (BAUD_DIV => BAUD_DIV)
        port map (clk => clk, reset => reset, key => key,
                  uart_tx => uart_tx, ledr => ledr);

    -- Independent decoder checks every clock-sized slice of all ten bits.
    decoder : process
        variable decoded : std_logic_vector(7 downto 0);
        variable expected_level : std_logic;
    begin
        wait until falling_edge(uart_tx);
        if check_frames then
            wait for 1 ns; -- settle concurrent LED assignments
            for slot in 0 to 9 loop
                if slot = 0 then
                    expected_level := '0';
                elsif slot = 9 then
                    expected_level := '1';
                else
                    expected_level := EXPECTED(slot - 1);
                    decoded(slot - 1) := uart_tx;
                end if;
                for cycle in 0 to BAUD_DIV - 1 loop
                    assert uart_tx = expected_level
                        report "TX level/bit duration wrong, slot " & integer'image(slot)
                        severity error;
                    assert ledr(0) = '1'
                        report "TX activity LED dropped during frame" severity error;
                    wait for CLOCK_PERIOD;
                end loop;
            end loop;
            assert decoded = x"48" report "TX did not decode as H" severity error;
            assert uart_tx = '1' and ledr(0) = '0'
                report "TX did not return to idle after stop bit" severity error;
            frames <= frames + 1;
            report "PASS TX: decoded H, exact bit lengths, stop bit and LED";
        end if;
    end process;

    -- Measure real output transition times, independently of the decoder's
    -- sampling schedule. H has observable boundaries at 4, 5, 7, 8, 9 bits.
    transition_checker : process
        variable start_time : time;
    begin
        wait until falling_edge(uart_tx);
        if check_frames then
            start_time := now;
            wait until uart_tx'event;
            assert uart_tx = '1' and now - start_time = 4 * BIT_PERIOD
                report "TX first rising edge is not at bit 3" severity error;
            wait until uart_tx'event;
            assert uart_tx = '0' and now - start_time = 5 * BIT_PERIOD
                report "TX bit 4 edge timing wrong" severity error;
            wait until uart_tx'event;
            assert uart_tx = '1' and now - start_time = 7 * BIT_PERIOD
                report "TX bit 6 edge timing wrong" severity error;
            wait until uart_tx'event;
            assert uart_tx = '0' and now - start_time = 8 * BIT_PERIOD
                report "TX bit 7 edge timing wrong" severity error;
            wait until uart_tx'event;
            assert uart_tx = '1' and now - start_time = 9 * BIT_PERIOD
                report "TX stop edge timing wrong" severity error;
            wait until falling_edge(ledr(0));
            assert now - start_time = 10 * BIT_PERIOD
                report "TX frame/stop duration wrong" severity error;
        end if;
    end process;

    stimulus : process
    begin
        wait for 5 * CLOCK_PERIOD;
        wait until falling_edge(clk);
        reset <= '0';
        wait for BIT_PERIOD;
        assert uart_tx = '1' and ledr = "0"
            report "TX initial idle wrong" severity error;
        key <= "0";
        wait until frames = 1;
        wait for 12 * BIT_PERIOD;
        assert frames = 1 and uart_tx = '1' and ledr = "0"
            report "Held button retransmitted" severity error;
        report "PASS TX: held button sends only once";

        key <= "1";
        wait for BIT_PERIOD;
        key <= "0";
        wait until falling_edge(uart_tx);
        wait for BIT_PERIOD;
        key <= "1";
        wait for BIT_PERIOD;
        key <= "0"; -- another synchronized press while still busy
        wait until frames = 2;
        wait for 12 * BIT_PERIOD;
        assert frames = 2 and uart_tx = '1' and ledr = "0"
            report "Busy request was queued or corrupted TX" severity error;
        report "PASS TX: busy press discarded without frame corruption";

        key <= "1";
        wait for BIT_PERIOD;
        key <= "0";
        wait until frames = 3;
        report "PASS TX: release and new press re-arm transmitter";

        -- Abort a fourth frame, then verify reset recovery independently.
        key <= "1";
        wait for BIT_PERIOD;
        check_frames <= false;
        key <= "0";
        wait until falling_edge(uart_tx);
        wait for 2 * BIT_PERIOD;
        wait until falling_edge(clk);
        key <= "1";
        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert uart_tx = '1' and ledr = "0"
            report "Reset did not abort TX" severity error;
        wait until falling_edge(clk);
        reset <= '0';
        wait for BIT_PERIOD;
        check_frames <= true;
        key <= "0";
        wait until frames = 4;
        report "PASS TX: reset abort and recovery";
        report "PASS tb_uart_tx BAUD_DIV=" & integer'image(BAUD_DIV);
        finish;
    end process;

    watchdog : process
    begin
        wait for 100 * BIT_PERIOD + 1 us;
        assert false report "TX watchdog timeout" severity failure;
    end process;
end architecture;
