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
lacking the essential constructs required to be anything close to elegant.

Even with the period appropriate solution of threaded code, we still face very
basic challenges, like the 6502 not having the required indexed jumps.

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

There is initial support for variables, but only through primitives:

        define "x" 6
        define "y" (* (get "x") 7)
        get "y"

That's it for now.
