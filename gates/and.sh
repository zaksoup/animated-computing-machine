#!/bin/sh
set -x

a=$(cat in1/bit)
b=$(cat in2/bit)

echo $(expr "$a" \* "$b") > out/bit

cat out/bit
