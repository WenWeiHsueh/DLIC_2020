#!/bin/bash

timestamp=$(date +%Y/%m/%d-%H:%M:%S)
printf "// This is generated automatically on ${timestamp}\n"
printf "// Check the # of bits for state registers !!!\n"
printf "// Check the # of bits for flag registers !!!\n\n"

STATES=("S_READY"            \
        "S_READ_WEIGHT"      \
        S_READ_INPUT""       \
        "S_MULTIPLY"         \
        "S_ADD"              \
        "S_WRITE"            \
        "S_FINISH")

FLAGS=("F_GEN_IN_ADDR"      \
       "F_READ_IN_ENB"      \
       "F_CONV_RELU_ENB"    \
       "F_WRITE_CONV_ENB"   \
       "F_GEN_CONV_ADDR"    \
       "F_READ_CONV_ENB"    \
       "F_WRITE_POOL_ENB"   \
       "F_WRITE_FLAT_ENB")

def_pattern="%-30s \t %-3s\n"

# Generate macro
printf "\`ifndef __FLAG_DEF__\n"
printf "\`define __FLAG_DEF__\n"

# Generate flags
len=${#FLAGS[@]}
printf "\n// There're ${len} flags in this design\n"
for((idx=0; idx<${len}; idx++))
do
  printf "$def_pattern" "\`define ${FLAGS[$idx]}" "${idx}"
done

# Generate flag width
printf "$def_pattern" "\`define FLAG_WIDTH" "`expr ${idx}`"

# Generate FSM states
len=${#STATES[@]}
printf "\n// There're ${len} states in this design\n"
for((idx=0; idx<${len}; idx++))
do
  printf "$def_pattern" "\`define ${STATES[$idx]}" "${idx}"
done

# Generate FSM init vector
printf "$def_pattern" "\`define S_INIT" "${len}'b0"

# Generate state width
printf "$def_pattern" "\`define STATE_WIDTH" "`expr ${idx}`"

# Generate other macro
printf "\n// Other macro in this design\n"
IN_BUFFER_SIZE="8'd66"
OUT_BUFFER_SIZE="8'd64"
printf "$def_pattern" "\`define IN_BUFFER_SIZE"       "$IN_BUFFER_SIZE"
printf "$def_pattern" "\`define OUT_BUFFER_SIZE"      "$OUT_BUFFER_SIZE"
printf "$def_pattern" "\`define READ_MEM_DELAY"       "2'd2"

printf "$def_pattern" "\`define EMPTY_ADDR"           "{32{1'b0}}"
printf "$def_pattern" "\`define EMPTY_DATA"           "{20{1'b0}}"

printf "$def_pattern" "\`define LOCAL_IDX_WIDTH"      "10"
printf "$def_pattern" "\`define DATA_WIDTH"           "20"

# Generate end macro
printf "\n\`endif\n"
