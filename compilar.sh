#!/bin/bash

yasm -f elf -m x86 Fuentes/main.asm
ld -m elf_i386 -o metricas main.o
rm main.o
