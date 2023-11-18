#!/bin/bash

rm -f bin/*

(cd src && rgbasm -L -o ../bin/main.o main.asm)
rgblink -o bin/unbricked.gb bin/main.o
rgbfix -v -p 0xFF bin/unbricked.gb

java -jar ../emu/Emulicious.jar bin/unbricked.gb