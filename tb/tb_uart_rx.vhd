library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_uart_rx is
    generic (BAUD_DIV : positive := 10);
end entity;

architecture test of tb_uart_rx is
    constant CLOCK_PERIOD : time := 20 ns;
    constant BIT_PERIOD   : time := CLOCK_PERIOD * BAUD_DIV;
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal uart_rx        : std_logic := '1';
    signal ledr           : std_logic_vector(7 downto 0);
    signal expected_led   : std_logic_vector(7 downto 0) := x"00";
    signal allow_update   : boolean := false;
begin
    clk <= not clk after CLOCK_PERIOD / 2;
    dut : entity work.simple_uart_rx
        generic map (BAUD_DIV => BAUD_DIV)
        port map (clk => clk, reset => reset, uart_rx => uart_rx, ledr => ledr);

    -- Detect transient/early updates as well as wrong final values.
    led_monitor : process
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        if reset = '0' then
            assert ledr = expected_led or allow_update
                report "RX LEDs changed before valid stop, or on rejected frame"
                severity error;
        end if;
    end process;

    stimulus : process
        procedure send_frame(
            constant value : std_logic_vector(7 downto 0);
            constant valid_stop : boolean := true
        ) is
        begin
            uart_rx <= '0';
            wait for BIT_PERIOD;
            for bit_number in 0 to 7 loop
                uart_rx <= value(bit_number);
                wait for BIT_PERIOD;
            end loop;
            if valid_stop then
                uart_rx <= '1';
                -- Output may update only after validating the stop midpoint.
                wait for BIT_PERIOD / 2;
                allow_update <= true;
                wait for BIT_PERIOD / 2;
                assert ledr = value
                    report "RX wrong byte: expected " & to_hstring(value) &
                           ", got " & to_hstring(ledr) severity error;
                expected_led <= value;
                allow_update <= false;
                report "PASS RX: received 0x" & to_hstring(value);
            else
                uart_rx <= '0';
                wait for BIT_PERIOD;
                assert ledr = expected_led
                    report "Invalid stop published a byte" severity error;
            end if;
        end procedure;
    begin
        wait for 5 * CLOCK_PERIOD;
        wait until falling_edge(clk);
        reset <= '0';
        wait for BIT_PERIOD + 7 ns; -- intentionally asynchronous to clk
        assert ledr = x"00" report "RX reset value wrong" severity error;

        -- Exactly one stop bit, no inserted gap between these five frames.
        send_frame(x"48");
        send_frame(x"00");
        send_frame(x"FF");
        send_frame(x"55");
        send_frame(x"AA");
        report "PASS RX: consecutive 8N1 frames without idle gaps";

        wait for 2 * BIT_PERIOD;
        uart_rx <= '0';
        wait for BIT_PERIOD / 5; -- shorter than half a bit
        uart_rx <= '1';
        wait for 12 * BIT_PERIOD;
        assert ledr = x"AA" report "False start updated LEDs" severity error;
        report "PASS RX: false start rejected";

        send_frame(x"33", false);
        wait for 12 * BIT_PERIOD; -- sustained break must not publish data
        assert ledr = x"AA" report "Bad stop/break updated LEDs" severity error;
        uart_rx <= '1';
        wait for 2 * BIT_PERIOD;
        report "PASS RX: invalid stop and sustained low rejected";
        send_frame(x"48");
        report "PASS RX: recovery after framing error";

        -- Reset in a partial frame must clear the display and abort reception.
        uart_rx <= '0';
        wait for 3 * BIT_PERIOD;
        wait until falling_edge(clk);
        reset <= '1';
        uart_rx <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert ledr = x"00" report "RX reset did not clear LEDs" severity error;
        expected_led <= x"00";
        wait until falling_edge(clk);
        reset <= '0';
        wait for 2 * BIT_PERIOD + 3 ns;
        send_frame(x"55");
        report "PASS RX: partial-frame reset and recovery";
        report "PASS tb_uart_rx BAUD_DIV=" & integer'image(BAUD_DIV);
        finish;
    end process;

    watchdog : process
    begin
        wait for 150 * BIT_PERIOD + 1 us;
        assert false report "RX watchdog timeout" severity failure;
    end process;
end architecture;
