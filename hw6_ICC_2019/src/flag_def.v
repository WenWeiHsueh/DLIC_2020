`ifndef FLAG_DEF
`define FLAG_DEF

// Flags
`define F_GEN_IN_ADDR       0
`define F_READ_IN_ENB       1
`define F_CONV_RELU_ENB     2
`define F_WRITE_CONV_ENB    3
`define F_GEN_CONV_ADDR     4
`define F_READ_CONV_ENB     5
`define F_WRITE_POOL_ENB    6
`define F_WRITE_FLAT_ENB    7

// Buffer size
`define IN_BUFFER_SIZE 66
`define OUT_BUFFER_SIZE ((`IN_BUFFER_SIZE) - 2)

`endif
