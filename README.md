# Sgetti

Sgetti Is a Threaded Pasta intepreter for the 6502 processor.

Sgetti can be thought of as:
- A _core engine_ that executes core instructions one at the time, to form:
- The _primitive engine_ that evaluates primitive expressions; and
- The _emergent language_ in which primitives and native functions can be mixed

## The Core Engine
Affectionally known as the Little Engine, it evaluates byte sized token
threaded code.

This is considerably more compact than directly compiling to 6502 machine code,
but easier to decode (on the 6502) than Pasta's original 4-instruction code.

The engine still centers around the instructions PUSH, REF, EVAL, and SKIP,
but (typed) variants and housekeeping instructions can now freely be added.
For one thing, this means that the bytecode can be made descriptive enough to
reproduce its own source code, similar to BASIC.

Even then, the amount of core instructions is limited, so the higher bytecodes
are used to directly reference expression level primitives, which the core
engine simply pushes un-evaluated.

## The Primitive Engine
The core instructions mainly collect argument values on the stack, until
finally the 'eval n' core instruction evaluates the last n stack values as an
expression by invoking its first argument, which must be an expression level
primitive.

A relatively large number of expression level primitives represent all built-in
functionality, from integer maths to conditionals and more.

## The Emergent Language
As all expressions must start with an expression level primitive, the compiler
prepends native function calls with a `funcall` primitive.

This literal "primitives first" approach is notably opposite from the original
Pasta interpreter, where only through variable and function resolution one may
eventually stumble upon a primitive.

Ultimately it should make little difference apart from overriding primitives;
this now requires var stack analysis to properly detect at compile time.

## 6502 Specific Challenges
The 6502 is essentially the BASIC language of processors: simple, but often
lacking the essential constructs required to be anything close to elegant or
efficient.

Even with the period appropriate solution of threaded code, we still face very
basic challenges, like the 6502 not supporting the required indexed jumps.

Instead, we need to copy over the target address to a fixed address first, then
jump from the latter. This alone takes up between 13-15 bytes. An alternative
construct called the 'RTS Trick' pushes the target address _minus one_ to the
stack, and then calls `rts`, reducing the code to 9 bytes.

## Current state
Sgetti can currently evaluate primitive-based expressions and compiles with the
neo6502 emulator as a target (see the `run` Makefile target for details).

Here are a few expressions to try:

        print "hello"; print "world"
        print "Hello, " (return "world") "!"
        + (* 3 4) (* 5 6)
        * (+ 1 2) (+ 3 4) 2
        / 0x2a 2 3
        % 44 3
        if (= (* 6 7) 0x2a) { print "yes"; return 42 }

Support for variables and functions is slowly maturing:

        define "f" (bind { args "x"; return x })
        f 42

Presently we miss variables defined by `args` when cleaning up scope.
