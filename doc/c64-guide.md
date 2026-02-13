# C64 Sgetting Started Guide
This guide specifically targets the C64 version of the Sgetti Pasta Machine.

Notable C64 specific features are:
- Blocks use `[]` instead of the missing characters `{}`
- Loops are sensitive to `run/stop` (`esc` in many emulators)
- `load` and `save` are implemented (still TBD on Neo6502 version)
- There is C64 specific hardware to address

## Building
Sgetti is built using the `64tass` assembler. The disk image (optional, but
useful) is compiled using the tool `cc1541`. (Both `64tass` and `cc1541` are
available in the standard Debian and Raspberry Pi Linux distributions.)

Just type `make` in the root directory to build everything. Relevant result
files for the C64 are `sgetti64.prg` and the disk image, `sgetti.d64`.

To run within the `VICE` emulator, type `x64 sgetti.d64`.

Sgetti64 also runs on the `kernalemu` and `tmce64` projects. If you are
interested in either version, you should checkout and compile these projects
from their own instructions.

Sgetti was _not_ tested on real hardware. The basic functionality should work,
but I'm curious about serial port timing on a real 1541 disk drive.

## C64 Style "Hello, World"
Once you have run `sgetti64`, you can type:

        loop [ print "hello " ]

Press `run/stop` / `esc` to exit the loop. You will see a number in square
brackets following the print output; this is the return value of the `loop`
expression.

(On the Neo6502 implementation, the standard Pasta block notation `{}` should
be used instead of the `[]`. Also, this implementation does not have a loop
stop mechanism yet!)

## More Fun With Loops
Pasta style loops combine the test and body into a single code block. The final
statement of any block serves as its return value; for a loop, if the block
returns nonzero (= 'true'), it will be run again.  This means that we can
construct a finite loop as follows:

        define "x" 100
        loop [
          print "hello ";
          set "x" (- x 1)
        ]

Note that while the `define` statement is evaluated on the spot, the multi-line
`loop` statement is not evaluated until fully entered. This is because the REPL
(read-eval-print-loop; the command line interpreter) waits on any open brackets
to close before evaluating the line. As any expressions within the brackets can
now span multiple lines, the must be consistently separated by a `;`.

Pasta variable slot references are always written as strings, so that their
unquoted label form always implies value substitution. Pasta expressions are
always in prefixed form, and sub-expressions must always be in brackets.

After running this loop, Pasta will print `[0]`. This is the outcome of the
`(- x 1)` subexpression as returned by `set` as the final result of the block;
by extension, it is also the outcome of the `loop` function. (Which means that
the seemingly random result of our previous loop was actually the memory
address of the `"hello "` string.)

## Writing a Program
If, after having entered the above, we now type `list`, the result will only
read:

        define "x" 100

This is because `list` only picks out all toplevel `define` statements, in the
assumption that they combine to make a program. So let's `define` our loop as
a function this time:

        define "run" (bind [
          loop [
            print "hello ";
            set "x" (- x 1)
          ]
        ])

Having conveniently called this function `run`, we can now invoke it by simply
typing `run`. However it won't do much, since `x` was previously run to zero.
Currently typing `list` will not confirm this; but you can type `hist` to get a
full transcript; or just `return x` to verify its current value. To fix this,
first type `set "x" 100`; then `run` again.

## Saving a Program
To save the current program, type:

        save "runloop"

(Note: `tmce64` has no save support!)

To reload the program from new, type:

        reset
        load "runloop"
        list
        run

## Defining a More Useful Function
Let's explore the expressive abilities of Pasta, by making our own for-loop
function:

        define "for" (bind [
          args "start" "end" "step" "fn";
          
          loop [if (!= start end) [
            fn;
            set "start" (+ start step)
          ]]
        ])

You may want to save your work first, but then we can try:

        for 1 10 1 (bind [print "hello "])

Notice that while `bind` is required to reify a block to a (lexically scoped)
function, it does not specify arguments like `lambda` does in LISP. Instead,
any `args` are to be specified immediately after opening the block.

Within this loop, the `if` function should eventually produce a zero value for
a 'false' result. Using `if` inside a `loop` in this fashion allows for the
loop to run zero times or more (`do while` vs `while`).

The first argument to `if` only needs brackets because it is a sub-expression;
there may also be an 'else' block. So: `if 0 [print "yes"] [print "no"]` should
(always) print `no`.

Bound blocks, i.e. functions, can be stored and passed as callbacks, as we do
here; however, a function does not outlive its binding scope. This implies that
you should not `set` a global function to a new value from within another
function, or even from within a `loop` or `if` statement; nor should you return
a function as a result value towards a higher scope than where it was bound.

(Note that none of this is enforced by the interpreter.)

## Workflow
Sgetti saves your input directly as bytecode, from which the source code is
reproduced, so your code will automatically be pretty-printed -- to a fashion.

Currently Sgetti keeps a full command log (type `hist` instead of `list`), but
it will only save toplevel `define` statements to file. This way, a program is
defined in terms of its global variable and function definitions.

Ideally you can simply edit or redefine a global function, and the old
definition is scratched; as this is not implemented yet, be careful when
you want to refactor a function.

A good strategy is to save individual program pieces, and reload and combine
them later. Reloading your program from disk also helps to declutter the
runtime environment.

We also still miss a way to save and load binary data.

## twist -n -SHOUT
Being text only, stored programs can also be edited from outside the C64
environment. (The `cc1541` tool can be used to get programs on and off a D64
disk image.) To get around the `\r` only line endings and switched case, use
the provided `twist` tool:

        ./twist -n -SHOUT < INFILE > outfile

The `-n` option converts the newline characters from Unix to "Mac" and back;
and the `-SHOUT` option reverses case. Additionally, `twist` always converts
the unicode characters near `{}` (which are missing on the C64) to the same
block near `[]`, so that it can also convert "standard" Pasta code to C64 form.
The latter conversion it is always applied, and never reversed.

## Exploring C64 Features
Sgetti on the C64 comes with all the features of the C64 itself. The commands
`getb` and `setb` are the equivalent of `peek` and `poke` (the 16-bit variants
`getw` and `setw` are not yet implemented).

In the future I hope to compile some sample programs onto the sgetti.d64 image.
For now, the sprite demo under `recipes/` is a lame first attempt.
