#!/bin/bash

timestamp=$(date +%Y/%m/%d-%H:%M:%S)
printf "// This is generated automatically on ${timestamp}\n"
printf "// Check the # of bits for state registers !!!\n"
printf "// Check the # of bits for flag registers !!!\n\n"

STATES=("S_IDLE_0"          \
        "S_GEN_IN_ADDR"     \
        "S_READ_IN"         \
        "S_CONV_RELU"       \
        "S_WRITE_CONV"      \
        "S_CHECK_FINISH"    \
        "S_GEN_CONV_ADDR"   \
        "S_READ_CONV"       \
        "S_WRITE_POOL"      \
        "S_WRITE_FLAT"      \
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
printf "$def_pattern" "\`define STATE_W" "`expr ${idx}`"

# Generate other macro
printf "\n// Other macro in this design\n"
IN_BUFFER_SIZE="8'd66"
OUT_BUFFER_SIZE="8'd64"
printf "$def_pattern" "\`define IN_BUFFER_SIZE"       "$IN_BUFFER_SIZE"
printf "$def_pattern" "\`define OUT_BUFFER_SIZE"      "$OUT_BUFFER_SIZE"
printf "$def_pattern" "\`define READ_MEM_DELAY"       "2'd2"

printf "$def_pattern" "\`define EMPTY_ADDR"           "{12{1'b0}}"
printf "$def_pattern" "\`define EMPTY_DATA"           "{20{1'b0}}"

printf "$def_pattern" "\`define LOCAL_IDX_WIDTH"      "16"
printf "$def_pattern" "\`define DATA_WIDTH"           "20"

# Generate end macro
printf "\n\`endif\n"
