# PacManFPGA

This project is a digital circuit which emulates our version of the classical
Pac-Man arcade game. It was written as a college demonstration project which I
developed along with [Bruno Baldochi](https://www.linkedin.com/in/bruno-baldochi-0b300496/)
in 2007.

The design originally targeted Altera FLEX-10K boards and required Altera
Quartus II to synthesize. It outputs directly to VGA and receives input from
a serial keyboard. The dip switches on the board are used to control the speed
and difficulty settings of the game.

As I recall, the game had a single Pac-Man map, with all four ghosts, pellets
and power pellets, but no fruits. Ghosts had rudimentary AI support, and all
four of them could mercilessly track Pac-Man in the highest difficulty setting.

VGA output is performed at 640x480x8x60Hz — thus the circuit needs a 25.4MHz
clock. Since the circuit doesn't use a framebuffer, all the logic share the
same clock through a clock divider, which didn't work quite well because the
FLEX-10K board doesn't have PLLs. Also, as evidenced by the synthesis logs, the
circuit could not afford to be run at full frequency when the AI circuitry was
synthesized in — almost all of the available routing in the FPGA was consumed
in this situation, so the game had some funny glitches such as ghosts "jumping"
on the screen, or getting stuck between walls. These are features, of course :)

The three initial commits represent the state of the code from my latest three
backups. All source code and synthesis artifacts are offered in case anyone is
interested.

Have fun!

## License

Source code and assets are licensed under Creative Commons CC BY 4.0.
