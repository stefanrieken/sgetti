# Sgetti

Sgetti Is a Threaded Pasta intepreter for the 6502 processor.

Sgetti can be thought of as:
- A _core engine_ that executes core instructions one at the time, to form:
- The _primitive engine_ that evaluates primitive expressions; and
- The _emergent language_ in which primitives and native functions can be mixed

## The Core Engine
Affectionally known as the Little Engine, it evaluates byte sized token
threaded code.

The byte codes come in several categories. Unlike with the Pasta interpreter, we
can afford several forms of each category:
- `PUSH v` pushes a literal value. May come in shortcut and typed forms
- `REF n` resolves a variable. May have several (un)optimized variants
- `SKIP n` jumps over a block while pushing its pointer (probably just the one)
- `EVAL n` evaluates `n` items on the argstack together as an expression (also one)

Other instructions (may) include:
- `CLEAR` to clear the stack between expressions
- `DONE` allows the interpreter to stop
- Other still: see discussion below

Rather than being called as a subroutine, threaded code simply returns by
jumping back to the main thread loop, leaving the stack largely unbothered.

### As Compact Source Code
Having a little more room for specific variants allows us to specify the type
of `PUSH`ed values, which may greatly help with reproducing the source code
from byte code, as compiled Pasta code already closely matches its source.

## The Primitive Engine
Even with all variants, there are far less core instructions than different
bytes. So even though it is not strictly necessary to mix both types, Sgetti
simply lets byte codes greater than (e.g.) `DONE` refer to so-called expression
level primitives.

These primitives are resolved and then pushed, but only evaluated by `EVAL`
after their expression arguments have been evaluated and pushed to the argument
stack. Typical expression level primitives are things like `define` and `+`,
but within Pasta may also include control structures like `if` and `loop`.

## The Emergent Language
All expressions run by `EVAL` must start with an expression level primitive.
Source code expressions, however, may freely mix primitive and native function
calls. The compiler irons out this difference by prefixing a `funcall`
primitive to the latter.

The compiler may detect that a function reference is not primitive either by
doing var stack analysis, or simply by comparing against the static list of
primitives. Only the former allows for overriding primitives at runtime.

### Variables
Pasta's emergent environment centers around its variable system. In theory
variables are all higher level constructs, and any Core Engine level `REF`
commands may simply be considered a practical convenience. (In the current C
interpreter, `REF` actually is a required core instruction, because its
primitives are resolved through the variable system.)

### Examples
NOTE: no compiler yet!

## 6502 Specific Challenges
The 6502 is essentially the BASIC language of processors: simple, but often
lacking the basic constructs to also be even near to elegant.

Even with the period appropriate solution of threaded code, we still face very
basic challenges, like the 6502 not having the required indexed jumps.

Instead, we need to copy over the target address to a fixed address first, then
jump from the latter. This alone takes up between 13-15 bytes. An alternative
construct called the 'RTS Trick' pushes the target address _minus one_ to the
stack, and then calls `rts`, reducing the code to 9 bytes.

A hack known as the 'RTS Trick'
 (11-15 bytes)
- Better still: push address, then rts from it (7-9 bytes depending on zp use)
  - Note: RTS requires address-1


## Current state
Sgetti can currently evaluate primitive-based expressions and compiles with the
neo6502 emulator as a target (see the `run` Makefile target for details).

Once running in the emulator, you can type `print "Hello, World!"` and even
expect the outcome to be as predictable. It is even possible to write some
early variations:

        print "hello"; print "world"
        print "hello " "world"

That's it for now.
