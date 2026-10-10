library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_uart_loopback is
    generic (BAUD_DIV : positive := 10);
end entity;

architecture test of tb_uart_loopback is
    constant CLOCK_PERIOD : time := 20 ns;
    constant BIT_PERIOD   : time := CLOCK_PERIOD * BAUD_DIV;
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal key            : std_logic_vector(0 downto 0) := "1";
    signal uart_tx        : std_logic;
    signal uart_rx        : std_logic;
    signal tx_led         : std_logic_vector(0 downto 0);
    signal rx_led         : std_logic_vector(7 downto 0);
begin
    clk <= not clk after CLOCK_PERIOD / 2;
    uart_rx <= uart_tx;
    transmitter : entity work.simple_uart_tx
        generic map (BAUD_DIV => BAUD_DIV)
        port map (clk => clk, reset => reset, key => key,
                  uart_tx => uart_tx, ledr => tx_led);
    receiver : entity work.simple_uart_rx
        generic map (BAUD_DIV => BAUD_DIV)
        port map (clk => clk, reset => reset, uart_rx => uart_rx, ledr => rx_led);

    stimulus : process
        variable start_time : time;
    begin
        wait for 5 * CLOCK_PERIOD;
        wait until falling_edge(clk);
        reset <= '0';
        wait for BIT_PERIOD;
        key <= "0";
        wait until falling_edge(uart_tx);
        start_time := now;
        wait for 9 * BIT_PERIOD;
        assert rx_led = x"00" report "Loopback RX updated before stop" severity error;
        wait until rx_led = x"48";
        assert now - start_time >= 9 * BIT_PERIOD + BIT_PERIOD / 2 and
               now - start_time < 10 * BIT_PERIOD
            report "Loopback byte published outside stop bit" severity error;
        wait for 3 * BIT_PERIOD;
        assert rx_led = x"48" and uart_tx = '1' and tx_led = "0"
            report "Loopback idle/received byte wrong" severity error;
        report "PASS loopback: one button press received as H (0x48)";
        report "PASS tb_uart_loopback BAUD_DIV=" & integer'image(BAUD_DIV);
        finish;
    end process;

    watchdog : process
    begin
        wait for 30 * BIT_PERIOD + 1 us;
        assert false report "Loopback watchdog timeout" severity failure;
    end process;
end architecture;
