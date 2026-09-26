# Sgetti

Sgetti Is a Threaded Pasta intepreter for the 6502 processor. It is developed
against the Commodore 64 and Neo6502 (by means of their emulators).

Sgetti depends on the `tas64` assembler, and on `cc1541` for making disk images.
A number of Makefile targets will directly run Pasta on `kernalemu`, `tmce64` or
`neo65` if these projects are found in adjacent directories.

To get started on the C64 version, read the [C64 Sgetting Started Guide](doc/c64-guide.md).

## Pasta
[Pasta](https://github.com/stefanrieken/pasta) is a programming langauge I
developed with fantasy consoles in mind. It effectively offers LISP-level
expressiveness on BASIC-like system constraints.

Here's a "Hello, World" in Pasta:

        define "greet" (bind {
          args "who";
          print "Hello, " who "!"
        })
        greet "world"

## Threaded code
Pasta's original interpreter runs on a minimalistic 4-instruction code engine,
partially designed to evoke the spirit of a simple 8-bit machine.

As it turns out, a real 8-bit machine has a much worse code density, and could do
with a little byte code of its own, but with different design constraints:
while the 6502 cannot afford to decode individual instruction and argument bits,
it can easily support a wider range of instructions by way of a jump table.

This technique of interpreting bytecode by way of a jump table is known as
token threaded code.

### Instruction density
With a full byte at our disposal, we can afford more instructions, including
typed `PUSH` variants (all pointing to one implementation) that help us to
decompile the bytecode back to source code, BASIC style.

Even then there's less than a nybblesworth of core instructions (and yes, I
just invented that word, and trademarked it), so the higher bytecodes are used
to directly reference expression level primitives, using the same lookup table.

### Example
In pseudo-mnemonics, an expression like `print "hello " x` would now translate
to something like:

        print STR "hello" REF x EVAL 3

Where `print` is a primitive reference, `STR`, `REF` and `EVAL` are core engine
instructions, and the values `"hello"` and `x` are actually a string pointer
and an index.

### Primitive-first approach
As all expressions must start with an expression level primitive, the compiler
prepends native function calls with a `funcall` primitive. This is notably
different from the original Pasta interpreter, where only through variable and
function code resolution one may eventually stumble upon a primitive reference.

Ultimately it should make little difference apart from overriding primitives;
this now requires var stack analysis to properly detect and allow at compile
time.

## Hardware specific challenges
### The 6502
The 6502 is essentially the BASIC language of processors: simple, but often
lacking the essential constructs required to be anything close to elegant or
efficient.

Even with the period appropriate solution of threaded code, we still face very
basic challenges, like the 6502 not supporting the required indexed jumps.

Instead, we need to copy over the target address to a fixed address first, then
jump from the latter. This alone takes up between 13-15 bytes. An alternative
construct called the 'RTS Trick' pushes the target address _minus one_ to the
stack, and then calls `rts`, reducing the code to 9 bytes.

### Character sets
The C64 uses the PETSCII character set, which is based on early ASCII. Most
notably, it has upper- and lowercase reversed and it doesn't know curly braces.

I have mapped the whole range of absent symbols near `{}` to the similar range
near `[]`, so that the C64 build of Sgetti now expects square brackets for
blocks.

We also lose the backslash (but string escape sequences weren't yet implemented
anyway) and `~`, the latter falling back to `^` (or `arrow up` on the C64). I
have resolved this by unifying the XOR and NOT functions so that their
single-argument invocation is interpreted as `^ arg1 0xFFFF`, i.e.: `~ arg1`.

It may not be intuitive to represent either function by `arrow up`, but keeping
a near match with ASCII helps towards code comprehension and interoperability.

### Kernalemu / tmce4
[Kernalemu](https://github.com/mist64/kernalemu) is a cool project that can run
all kinds of CBM software on the command line by emulating a 6502 together with
the KERNAL routines.

It only does some ASCII adaptation on its (screen) output, leaving the input
reverse-case and requiring you to SHOUT your commands. (I have patched it
locally to flip the case back, and to extend the lower-to-upper reversal to
the `{}` area, so that for these symbols both alternatives are accepted as
input.)

Equally cool is the
[Terminal Mode Commodore Emulator](https://github.com/kobolt/tmce64),
which approximates PETSCII art using ASCII. This emulator accepts regular input
as lowercase, and displays it in the C64 with the appropriate case shift; but
it simply refuses the symbols near '{}'.

(On main.c:314 it produces a double carriage return on autorun. Remove one of
these to successfully parse Sgetti's first line of input.)

### Twist & shout
So whenever we cannot change the input constraints of these emulators, we can
just change the input text itself.  The tool `twist` moves the wider `{}` ASCII
area to the wider `[]` area. If called with `-n` it also switches newlines and
carriage returns; and if called with `-SHOUT`, it also reverses case. As it only
reads from stdin and writes to stdout, typical usage may look like:

        ./twist -n -SHOUT < OUTPUT > converted.txt
        cat test.txt | ./twist -SHOUT | ../kernalemu/build/kernalemu sgetti64.prg

Note that `kernalemu` doesn't echo its piped input. As for `tmce64`, it will not
sync well with the piped in data, and there's the first-input bug; so here it
is easier to just copy / paste your (converted) program.

## Current state
Sgetti compiles and runs on both the neo6502 emulator and the c64, as well as
on Kernalemu and tmce64. (See the `run` Makefile target for details).

We are slowly getting to the point of running a test suite. Meanwhile, here are
a few different Pasta expressions to try:

        print "hello"; print "world"
        print "Hello, " (return "world") "!"
        + (* 3 4) (* 5 6)
        * (+ 1 2) (+ 3 4) 2
        / 0x2a 2 3
        % 44 3

Functions now fully work with lexical scoping, and conditionals and blocks with
regular block scoping:

        define "f" (bind {
          args "x";
          if (= x 0x2a) { print "correct!" };
          loop {
            print "hello";
            set "x" (- x 1)
          }
        })
        f 6

