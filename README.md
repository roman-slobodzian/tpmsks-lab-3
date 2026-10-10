# Lab 3: UART on an Apple Silicon Mac

VHDL-2008 implementation of the assignment's transmitter and receiver, tested
with native NVC 1.23.0 and viewed with Surfer 0.7.0. No VM or FPGA is needed
for this simulation scope.

## Test

From this repository:

```sh
make test
```

Success ends with `PASS: all UART simulations completed.` A failed assertion,
watchdog, compilation, or missing completion marker gives a nonzero exit code.
The suite runs independent TX, independent RX, and loopback tests at both
`BAUD_DIV=10` and `BAUD_DIV=5208` (six simulations).

```sh
make test DIVIDERS=10       # accelerated tests only
make test DIVIDERS=5208     # nominal 9600 baud only
make wave-tx               # open accelerated TX waveform in Surfer
make wave-rx               # open accelerated RX waveform in Surfer
make wave-loopback         # open accelerated loopback waveform in Surfer
```

To inspect the nominal waveform:

```sh
surfer build/div_5208/tb_uart_loopback.fst
```

The `make wave-*` commands add the relevant signals automatically. In Surfer,
choose **Settings > Time unit > ns** for readable accelerated waveforms.
If opening an FST directly, expand the testbench scope and add `clk`, `reset`, `key`, `uart_tx`,
`uart_rx`, and the LED signals that exist in that testbench. Zoom to the first
frame. Set the RX LED bus to hexadecimal: it must become `48` during the stop
bit. The serial sequence is `0 | 0 0 0 1 0 0 1 0 | 1` (start, LSB-first data,
stop). The TX LED stays high for the complete ten-bit frame.

At 50 MHz the bit period is 200 ns with divider 10, or 104.16 us with divider
5208. A complete frame takes 2 us or 1.0416 ms respectively.

## Files and behavior

- `rtl/simple_uart_tx.vhd`: one synchronized active-low key press sends ASCII
  `H` (`0x48`), with `ledr(0)` high while sending. A held key sends once; a press
  while busy is discarded. Release and press again to send another byte.
- `rtl/simple_uart_rx.vhd`: two-stage input synchronization, start validation,
  midpoint data sampling, stop validation, and last-valid-byte LED display.
- `tb/`: self-checking independent TX/RX and loopback tests, including reset
  recovery, consecutive frames, false starts, and framing errors.
- `build/div_10/` and `build/div_5208/`: compiler logs, simulation logs, FST
  waveforms, and NVC work libraries. `build/tool-versions.txt` records tools.
- `report/`: Markdown notebook, PDF report, results, and waveform captures.

Both modules have a synchronous active-high `reset`; hold it high across a
rising clock edge before use. The RTL default divider is 5208. RX supports
dividers of at least 4. The key synchronizer does not debounce a physical
mechanical switch. This lab sends a fixed byte and implements 8N1 only.

The PDF's mixed timing units/dividers and unbounded RX counter increment are
corrected. Counters advance only in active states and explicitly wrap or count
down; the design uses the single system clock with clock enables.

## Export the report

The editable report is `report/lab3-fpga.ipynb`. It contains Markdown cells
with embedded waveform images and preserves the original cover page. The
previous notebook is saved as `report/lab3-fpga.before-uart.ipynb`.

From this repository, using the installed Conda environment and Chromium:

```sh
source /opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh
conda activate py314
jupyter nbconvert --to webpdf report/lab3-fpga.ipynb --output-dir report
```

This writes `report/lab3-fpga.pdf`. The existing `report/lab-3-report.pdf` is
a copy of the same exported report. Neither includes control questions.
The earlier PDF was generated with ReportLab; its script is now
`report/create_report.py`.

## Submission scope

The report covers native Mac functional simulation with NVC testbenches and
Surfer waveforms. The assignment specifies Quartus/VWF. No Quartus synthesis,
pin constraints, VWF files, FPGA programming, or level-2 hardware results are
claimed.

The report deliverable is the PDF. The editable notebook and local evidence
remain available for future changes. `build/` and `report/` are ignored by the
existing `.gitignore`. `make clean` removes only the build outputs.
