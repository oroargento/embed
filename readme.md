# embed: A tiny embeddable Forth interpreter 

| Project   | Forth SoC written in VHDL |
| --------- | ------------------------- |
| Author    | Richard James Howe        |
| Copyright | 2017 Richard James Howe   |
| License   | MIT                       |
| Email     | howe.r.j.89@gmail.com     |

Available at <https://github.com/howerj/embed>

This project was derived from a simulator for a Forth CPU available from here: 
<https://github.com/howerj/forth-cpu>. The simulator and compiler have been
modified so they can be used as a C like Forth for the PC.

The project is a word in progress, but most of the system is in place.

## To Do / Wish List

* Add error messages to generated block, as well as a simple help file
* Make short example programs
* Documentation of the project, some words, and the instruction set, as well as
the memory layout
* Make prepared images, as C code and as binary files
* Remove the compiler after a cross compiler has been made within the Forth
interpreter
* A simple run length compressor would reduce the size of the blocks, as well
as other simple memory compression techniques
* Improve the instruction set with a better choice of ALU operation, as well
as fixing the store instruction.
