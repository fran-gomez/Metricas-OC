#!/bin/bash

yasm -f elf -m x86 Fuentes/metricas.asm
ld -m elf_i386 -o metricas metricas.o
rm metricas.o
