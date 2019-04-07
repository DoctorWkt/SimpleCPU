run: simplecpu.v
	iverilog simplecpu.v
	vvp a.out

clean:
	rm -f a.out test.vcd
