NVC ?= nvc
SURFER ?= surfer
BUILD ?= build
DIVIDERS ?= 10 5208
TESTBENCHES := tb_uart_tx tb_uart_rx tb_uart_loopback
SOURCES := rtl/simple_uart_tx.vhd rtl/simple_uart_rx.vhd \
           tb/tb_uart_tx.vhd tb/tb_uart_rx.vhd tb/tb_uart_loopback.vhd

.PHONY: all test check-tools wave-tx wave-rx wave-loopback clean
all: test

check-tools:
	@command -v $(NVC) >/dev/null || { echo 'Missing NVC. Install: brew install nvc'; exit 1; }
	@command -v $(SURFER) >/dev/null || { echo 'Missing Surfer. Install: brew install surfer'; exit 1; }

# Use a separate library per divider. This remains safe under make -j.
# Redirect first, then print: a failed simulator cannot be hidden by tee.
test: check-tools
	@mkdir -p $(BUILD)
	@{ uname -sm; $(NVC) --version; $(SURFER) --version; } > $(BUILD)/tool-versions.txt
	@set -eu; for div in $(DIVIDERS); do \
	    dir="$(BUILD)/div_$$div"; mkdir -p "$$dir"; \
	    if ! $(NVC) --std=2008 --work=work:$$dir/work \
	        -a --check-synthesis $(SOURCES) > "$$dir/compile.log" 2>&1; then \
	        cat "$$dir/compile.log"; exit 1; \
	    fi; \
	    for tb in $(TESTBENCHES); do \
	        if ! $(NVC) --std=2008 --work=work:$$dir/work \
	            -e -g BAUD_DIV=$$div $$tb > "$$dir/$$tb.log" 2>&1; then \
	            cat "$$dir/$$tb.log"; exit 1; \
	        fi; \
	        if ! $(NVC) --std=2008 --work=work:$$dir/work \
	            -r $$tb --wave="$$dir/$$tb.fst" --exit-severity=error \
	            >> "$$dir/$$tb.log" 2>&1; then \
	            cat "$$dir/$$tb.log"; exit 1; \
	        fi; \
	        cat "$$dir/$$tb.log"; \
	        grep -q "PASS $$tb BAUD_DIV=$$div" "$$dir/$$tb.log"; \
	    done; \
	done
	@echo 'PASS: all UART simulations completed.'

wave-tx: check-tools
	$(SURFER) $(BUILD)/div_10/tb_uart_tx.fst -c tools/surfer/tx.sucl
wave-rx: check-tools
	$(SURFER) $(BUILD)/div_10/tb_uart_rx.fst -c tools/surfer/rx.sucl
wave-loopback: check-tools
	$(SURFER) $(BUILD)/div_10/tb_uart_loopback.fst -c tools/surfer/loopback.sucl

clean:
	rm -rf $(BUILD)
