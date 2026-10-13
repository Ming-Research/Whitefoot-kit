# Writing Whitefoot

This guide is for agents that write Whitefoot programs and is 2029 lines long. Read all of it before writing code. If a file reader shows only part, read the rest in numbered ranges until the final section is received. Before writing concurrent code, read all of Part 3, including child completion and its examples.

- Part 1, syntax, holds the forms every program needs. Most first rejections come from these forms; write them as shown, not as another language would.
- Parts 2 and 3 say how to design a sequential and a concurrent program: where data lives, who owns it, what the checker must be told, how contexts share state. Rejections cannot teach these.
- Throughout, "Silent" marks behavior the compiler accepts but that is wrong or slow, with the way to check for it.

After `make compiler`, the release's language directory, `build/whitefoot/<release>/language/`, holds the standard library's interfaces, `lib/std/<module>/module.wfm`, listed in `lib/std/modules.wfg`, and the specification, `spec/kernel-spec.md`, at the same commit as the compiler. For releases older than `wf-5dd90db143b1`, read these files at the compiler's commit as README.md describes. A rule id in brackets, such as [GRAM-9], names the specification rule that defines a form. Read an interface before calling anything in it; never guess a name.

Write the whole program from this guide, then compile it. Before repairing, identify the compiler input named by the task and diagnostic; edit that file, not a duplicate. After any rejection, identify its rule, apply a supplied `mechanical_fix`, and fix every violation of that rule in all compiler inputs before compiling again. For FORM-2, use the layout audit in §12. Part 1 ends with "When the compiler says…", for rejections whose text does not lead to the fix.

Before delivery, inspect requirements the output oracle cannot establish: actual required storage, mandatory consumption, in-place updates, published guarantees, and real shared state.

## Part 1. Syntax you will need in every program

### 1. What is the complete function header?

Write `fn name(parameter: Type) -> result_name: ResultType effects waits? contract? {`. The result binder and effect row are mandatory. Choose `pure` alone for the empty row or a nonempty `reads`/`writes` list; never append `pure` to that list. `waits` follows the row, and `contract` follows `waits` when present. Parameters use `T`, `&T` or `&[T]`, without `move` or `&mut`. Results are owned values, never references. [GRAM-2, GRAM-3, EFF-1, FN-1, REF-3]

Effect paths root at reference parameters, without `^`: `reads(source)`, `writes(counter.value)`. By-value parameters and locals add no enclosing row entry. Order reads before writes, each in parameter order; `writes(p)` covers reads below `p`. Declared paths and exhibited body accesses must cover each other. `pure` may allocate or wait. Audit each row before submission: only reference parameters can root entries; remove every read covered by a write and every narrower entry covered by an ancestor. [EFF-1, EFF-2, STOR-8]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn reset(counter: &u64) -> result: unit writes(counter) {
  set counter^ = 0_u64;
  return unit;
}

fn bounded_next(value: u64) -> result: u64 pure contract {
  requires value < 10_u64;
} {
  return value + 1_u64;
}

fn main() -> status: ExitStatus pure {
  let counter = bounded_next(value: 3_u64);
  reset(counter: &counter);
  return exit_status(code: 0_u8);
}
```

### 2. How does a program start and finish?

Put aliases first; there is no `use` import. Use `main(inputs: Inputs)` for startup handles or `main()` when none are needed. The invocation supplies declared arguments; main uses an ordinary function header. [MOD-4, PROG-3]

`Inputs` fields, in declaration order, are `args`, `drivers`, `cwd`, `stdout`, `stderr`, `handles`, `stdin`, `clock`, `wall_clock`, `stops`, `memory_meter`. Named fields retain declaration order even when fields are omitted: `stdout` precedes `handles`. Bind all fields, or a subset followed by `, ..`. The rest marker releases omitted droppable fields; it cannot discard a linear field. `cwd` owns two linear directory handles, so consume it and close both halves even when the program does not use its working directory. [GRAM-4, GRAM-10, PROV-6, WIN-3, PRE-2]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias Inputs = std::process::Inputs;
alias exit_status = std::process::exit_status;

fn main(inputs: Inputs) -> status: ExitStatus pure waits {
  let Inputs(cwd: directory, handles: factory, ..) = move inputs;
  let std::fs::Directory(read: directory_read, write: directory_write) = move directory;
  std::fs::close_directory_write(factory: &factory, directory: move directory_write);
  std::fs::close_directory(factory: &factory, directory: move directory_read);
  return exit_status(code: 0_u8);
}
```

The close calls return `Result<unit, IoError>`; this template discards their results. Match them if close failure must affect the exit status. Waiting calls require `waits`; local handles add no formal-path effect to `main`. Consume linear handles on every leaving path by closing or transferring them. [PRE-2, PROV-6, EFF-2, WAIT-1]

### 3. Where must I split an expression?

An executable expression is an atom, a call, or one infix over two atoms. Atoms are literals, places, `move place` and `&place`. No expression grouping, precedence or chaining exists. Inspect every argument, constructor field, infix operand, index and range endpoint in every compiler input: each must be an atom. Nullary `None<T>()` and `Variant()` are calls too. Extract every computed operand into a preceding `let`; audit constructors as well as ordinary functions. [GRAM-5, GRAM-6, GRAM-9]

```whitefoot
fn compose() -> result: u64 pure {
  let first = 1_u64 + 2_u64;
  let second = first + 3_u64;
  return second;
}
```

Rejected: these forms require an intermediate binding, or removal of parentheses.

```text
f(value: g(value: x))
a[i + 1_u64]
a + b + c
(a + b)
if (a < b) {
```

`if feq(a, b) {` and `match f(value: x) {` are valid because a condition or scrutinee is an expression, not an atom position. The call's operands still must be atoms. Contract and invariant expressions have their own affine grammar; do not apply those extra forms to executable expressions. [GRAM-4, GRAM-5, GRAM-6, GRAM-9, INV-1]

### 4. Which operation spelling and mode do I use?

Table operations use positional operands, such as `iand(a, b)` and `fmul.strict(a, b)`. Ordinary source and prelude functions use named arguments in declared order, such as `array_filled::<u8, 3>(value: byte)`. Operand types must agree exactly; operations do not widen them from an expected result type. [GRAM-11, OP-1, TYPE-5]

| Integer operation | Modes/forms |
| --- | --- |
| `+ - *` | Bare exact; `+defined +wrap +checked +sat`, likewise `-`/`*` |
| `/ %` | Bare exact; `/defined /checked %defined %checked` |
| `ishl ishr` | Bare exact; `.defined .wrap`; amount `u32` |
| `== !=` | Equality types; floats use `feq fne` |
| `< <= > >=` | Integers only |
| `iand ior ixor inot` | Bit calls |
| `irotl irotr` | Rotate; amount `u32` |

Bare integer arithmetic needs a proved domain: representable results for `+ - *`, nonzero divisor and no signed-minimum/`-1` pair for `/ %`, shift amount below the width. Exact left shift may discard high bits. Defined queries are total Bool operations; binding one proves nothing, but a true branch can establish its domain. [OP-2]

Wrap arithmetic is modulo the width; wrap shifts mask the amount. Checked forms return `Result`; saturating forms clamp to type endpoints. Preserve the intended semantics when repairing a proof. Division and remainder have no wrap or saturating mode: choose exact with a proved domain or checked with a handled `Result`. There is no `ishl.checked`. [OP-1, OP-2, OP-8]

Bit operations are calls: `ixor(a, b)`, never `a ixor b`. Bool calls are `band(a, b)`, `bor(a, b)`, `bxor(a, b)`, `bnot(a)`, with already evaluated operands; use control flow for conditional evaluation. No `&& || !`, infix bitwise `& |`, or `bitand` exists. [OP-1, GRAM-5]

Rounding float arithmetic uses `fadd.strict fsub.strict fmul.strict fdiv.strict fsqrt.strict ffma.strict`. Float comparisons are `feq flt fle fgt fge fne`; use `feq(a, b)`, not `a == b`. Conversions write both types: `cvt::<u8, u32>(byte)` needs a proved exact domain. For rounded float-to-integer conversion, bind `froundeven(x)`, then use `cvt.checked::<f64, i32>` for an f64 input and i32 destination. `cvt.nearest` requires a float destination. Compare floats with `fge`/`flt`, not ordering infix operators. [OP-1, OP-3, OP-6]

### 5. How do I spell a literal?

Literals need suffixes: `42_u64`, `-5_i64`, `0.125_f64`, `'+'_u8`. Integers are decimal without leading zeros; negative unsigned literals are forbidden. Floats need a decimal point and the canonical shortest spelling. Characters use `_u8` for ASCII or `_u32` for Unicode scalars. The unit value is `unit`. [FORM-5, FORM-6, FORM-7]

Bool values are `True()` and `False()`. Strings appear only in `doc`, package locations and eligible const initializers. Non-finite floats use `finf::<f64>()`/`fnan::<f64>()`. Numeric generics admit identity literals `0_T`/`1_T`. [FORM-5, PRE-1, CONST-2]

Rejected: no hexadecimal numeric literal, unsuffixed number/character, or executable string.

```text
0xFF_u8
42
'+'
let message = "hello";
```

### 6. How do I bind, name and replace a value?

Write `let name = expression;`; the initializer determines the exact type and mode. There is no local type annotation, `mut` or `_` discard binder. Bind an unused field to an ordinary name such as `unused_clock`, or use an admitted rest marker. Replace a live value with `set place = expression;`; `let` does not imply immutability. [GRAM-4, TYPE-5, SET-1]

Value names, including constants, match `[a-z][a-z0-9_]*`; type names `[A-Z][A-Za-z0-9]*`; labels `@[a-z][a-z0-9_]*`. Before choosing a binder, check the reserved inventory below: `checked`, `wrap` and operation names cannot be lets. Use a fresh nonreserved name; no local declaration still in scope, parameter, alias or competing module declaration may be shadowed. Audit every declaration: no `_` binder or uppercase value name, including constants. Initialize once with `let`, update with `set`. A moved value’s declaration still occupies its name until its block ends. [FORM-3, TYPE-6, OP-1]

Rejected: invalid binders or binding forms.

```text
let x: u64 = 1_u64;
let mut x = 1_u64;
let _ = f();
const MAX_SIZE: u64 = 8_u64;
fn done() -> unit: unit pure {
```

### 7. How do I construct an array, window or constant table?

A fixed array type is `Array<T, N>`, never `[T; N]`, including inside `Box` and other type arguments. [GRAM-3, TYPE-9]

There is no list literal in executable expression position. `array_filled::<T, N>(value: x)` initializes all N elements and requires copy T. `slots_new::<T, N>()` creates an empty constant-capacity window; `place_back(window: &s, value: x)` requires `s.len < s.cap` and adds an initialized element. Index only initialized elements. [OP-13, OP-10, OP-4, PRE-1]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

const digits: Array<u8, 4> =['0'_u8, '1'_u8, '2'_u8, '3'_u8];

fn main() -> status: ExitStatus pure {
  let bytes = array_filled::<u8, 3>(value: 65_u8);
  set bytes[1_u64] = 66_u8;
  let window = slots_new::<u8, 3>();
  place_back(window: &window, value: bytes[1_u64]);
  let first = window[0_u64];
  let digit = digits[2_u64];
  return exit_status(code: 0_u8);
}
```

Array sizes and const type arguments use bare decimal counts, such as `3`, or an integer const name; one bare `+ - * / %` operation is permitted. Typed runtime numbers such as `3_u64` are not count spellings. A constant table is `const name: Array<T, N> =[...];`, with exactly N eligible values. An `Array<u8, N>` const may instead use a string of exactly N UTF-8 bytes. Constants are read-only: never `move` or `set` them. Enum, Box, Slots and Ring values are not const-eligible. [CONST-1, CONST-2]

### 8. How do I write conditions and loops?

An `if` condition is an owned Bool expression, without parentheses. The then-block may be empty; an explicit empty else-block is rejected. Write `} else if condition {` for a chain; an else-block containing only another `if` is rejected. [GRAM-4, GRAM-6, OP-5]

A value conditional initializes a `let` only. It requires else; every continuing branch ends in `give expression;` with one identical type and mode. Close with `}`, without `;`. Returning paths need no give. Do not write `give if ...` or `return if ...`. Bind the conditional with `let`, then give or return its binder. [GRAM-7, GIVE-1]

`for (i in lower..upper) {` captures two u64 endpoints once, increments its own u64 binder and visits the half-open range. `loop {` has no implied update; terminate or repeat with `break;` and `continue;`. Optional labels appear after `for`/`loop`, as `loop @scan {`; use `break @scan;` or `continue @scan;` for the named enclosing loop. [GRAM-4, FN-1, TYPE-6]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn main() -> status: ExitStatus pure {
  let count = 3_u64;
  let chosen = if count < 4_u64 {
    give 8_u64;
  } else {
    give 0_u64;
  }
  let sum = 0_u64;
  for (i in 0_u64..count) {
    set sum = sum +wrap i;
  }
  loop @check {
    if chosen == 8_u64 {
      break @check;
    }
    return exit_status(code: 1_u8);
  }
  return exit_status(code: 0_u8);
}
```

Header invariants are named clauses inside the parentheses. An invariant-bearing header must span lines, with a comma after every header component except the last: [FORM-2, INV-1]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn main() -> status: ExitStatus pure {
  let values = slots_new::<u64, 8>();
  for (
    i in 0_u64..8_u64,
    invariant length: values.len == i
  ) {
    place_back(window: &values, value: i);
  }
  return exit_status(code: 0_u8);
}
```

For an invariant-bearing uncounted loop, begin with `loop (` or `loop @scan (` and put each `invariant name: relation` on its own indented line before `) {`. `loop ()` is invalid: omit the parentheses when there are no invariants. [GRAM-4, FORM-2]

### 9. How do I match an enum?

List every declared variant exactly once, using unqualified variant names in arms. Each payload binding is `declared_field: fresh_binder`, in declaration order; the binder must differ from its field label and all competing names live on arm entry. A final `..` may cover omitted fields, but a consuming match cannot discard linear payloads. There is no wildcard arm. Use `if` for Bool. [ERR-2, GRAM-6, GRAM-10, OWN-13, WIN-3]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn main() -> status: ExitStatus pure {
  let outcome = 2_u64 +checked 3_u64;
  let number = match outcome {
    Ok(value: n) => {
      give n;
    }
    Err(error: problem) => {
      return exit_status(code: 1_u8);
    }
  }
  let optional = Some<u64>(value: number);
  let chosen = match optional {
    Some(value: selected) => {
      give selected;
    }
    None() => {
      give 0_u64;
    }
  }
  return exit_status(code: 0_u8);
}
```

A statement match produces no value. A let-initializer match has braced arms; every continuing arm ends with `give`. Close the enclosing match with `}`, without a semicolon; the same applies to a let-value if. Reference-derived scrutinees keep their owner and bind reference payloads. Affine/linear own scrutinees need `move`. [GRAM-7, GIVE-1, OWN-1, OWN-13]

### 10. How do I construct a struct or enum variant?

Write every field by its declared name in declared order. Struct type arguments attach directly: `Pair<u64>(left: a, right: b)`. A variant of a generic enum is `Choice<u64>::Present(value: a)`, without `::<...>` after the type name. A nullary variant still needs `()`. Bind nested construction values first. Opaque types have no usable source constructor. [GRAM-8, GRAM-9, TYPE-2, TYPE-5]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

struct Pair<T> {
  left: T;
  right: T;
}

enum Choice<T> {
  Absent();
  Present(value: T);
}

enum ParseError {
  Truncated();
}

fn main() -> status: ExitStatus pure {
  let pair = Pair<u64>(left: 1_u64, right: 2_u64);
  let choice = Choice<u64>::Present(value: pair.left);
  let problem = ParseError::Truncated();
  let missing = None<u64>();
  let present = Some<u64>(value: pair.right);
  let success = Ok<u64, ParseError>(value: pair.left);
  let failure = Err<u64, ParseError>(error: problem);
  match choice {
    Absent() => {
      return exit_status(code: 1_u8);
    }
    Present(value: selected) => {
    }
  }
  return exit_status(code: 0_u8);
}
```

Prelude forms are `None<T>()`, `Some<T>(value: x)`, `Ok<T, E>(value: x)`, `Err<T, E>(error: e)`, with named fields. [PRE-1, GRAM-8]

Tuple types and tuple values do not exist. Use a named struct for a multi-field `Result` payload. A function's ordered results use a result list and a destructuring `let`; they are not a stored tuple. [GRAM-2, GRAM-3, GRAM-4, GRAM-5, FN-1]

For a stored Slots value or payload, use `Slots<T, N>` or `Box<Slots<T>>`. Bare runtime `Slots<T>` is admitted only as Box content, not as a local, result or payload. [TYPE-9]

### 11. How do I spell references, slices, fields and moves?

`&place` forms a reference. A reference variable is not implicitly read as its value: use `r^`, `r^.field`, `r^[index]`, or `r^.len`. A half-open slice is `&array[lower..upper]`; a slice reference has `len`, not `cap`. A Box exposes its content as `cell.inner`. For an array `a`, `&a` is an array reference, not a slice reference. For a parameter `&[T]`, pass `&a[0_u64..length]` with a u64 endpoint. [GRAM-5, TYPE-5, TYPE-7, TYPE-9, REF-1, REF-4]

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

struct Counter {
  value: u64;
}

fn increment(counter: &Counter) -> result: unit writes(counter.value) {
  set counter^.value = counter^.value +wrap 1_u64;
  return unit;
}

fn fill(bytes: &[u8]) -> result: unit writes(bytes) {
  let length = bytes^.len;
  for (i in 0_u64..length) {
    set bytes^[i] = 65_u8;
  }
  return unit;
}

fn main() -> status: ExitStatus pure {
  let counter = Counter(value: 0_u64);
  increment(counter: &counter);
  let bytes = array_filled::<u8, 3>(value: 0_u8);
  let view = &bytes[0_u64..3_u64];
  fill(bytes: view);
  let cell = box_new::<u64>(value: counter.value);
  let seen = cell.inner;
  return exit_status(code: 0_u8);
}
```

Bare copy values copy; affine or linear values need explicit `move place` to transfer ownership. References pass by their own binding, such as `fill(bytes: view)`, without `move`. `&mut` does not exist; a reference's permitted uses follow ownership, overlap and effect checks. References cannot be stored in a field, array element or type argument, and cannot be returned. [OWN-1, REF-1, REF-3, STOR-5]

### 12. Which bytes are canonical?

Use UTF-8/LF and two spaces per brace depth. No tabs, trailing spaces or leading blank line. End the last line with one LF, without a trailing blank line. Noncanonical bytes are rejected. [FORM-1, FORM-2]

Audit three regions separately across every compiler input: alias runs and graph package/row runs have no blank separator; other top-level items have one; item bodies have none. Ordinary statements, including destructuring lets, stay on one physical line. Control-flow blocks and value arms use canonical multiline layout. Function headers through `{` each occupy one line. Empty blocks use two lines. Join else as `} else {` or `} else if ... {`, and contract/body as `} {`. Write `Array<u8, 3>`, `f(x: a, y: b)`, `=[...]`, `&a[lo..hi]`, `r^`. Follow the complete files' layout. [FORM-2]

No comments exist. `doc "...";` is declaration documentation, permitted at the start of a declaration body or as an interface declaration's documentation; do not insert it between executable statements. [FORM-4, GRAM-2]

### 13. How do I lay out a module program?

The package root has `modules.wfg`; each registered module directory has `module.wfm` and its direct `.wf` implementation files. Every module row lists its exact direct dependencies. A `pkg` dependency must be an earlier row; transitive dependencies grant no visibility. An entry names an ordinary public nongeneric function. [MOD-1, MOD-2, MOD-5, MOD-9]

`modules.wfg` is a graph record, not a standalone source file: [GRAM-2, FORM-2]

```wfg
pkg::geometry: [];
pkg::client: [pkg::geometry, std::process];

entry main = pkg::client::main;
```

Public declarations belong in `module.wfm`; interface functions end with `doc "...";`, never a plain `;`. Definitions repeat the header without `public`. Aliases bind public declarations in direct dependencies and grant no graph edge. These four files complete the graph above; check the graph as one module program, not each file as a source bundle. [MOD-4, MOD-5, MOD-6, MOD-7, MOD-8]

`geometry/module.wfm`:

```wfm
public struct Point {
  public x: i32;
}

public fn make(x: i32) -> result: Point pure doc "Makes a point.";
```

`geometry/make.wf`:

```wf-module
fn make(x: i32) -> result: Point pure {
  return Point(x: x);
}
```

`client/module.wfm`:

```wfm
alias ExitStatus = std::process::ExitStatus;

public fn main() -> status: ExitStatus pure doc "Runs the program.";
```

`client/main.wf`:

```wf-module
alias ExitStatus = std::process::ExitStatus;
alias make = pkg::geometry::make;

fn main() -> status: ExitStatus pure {
  let point = make(x: 3_i32);
  if point.x == 3_i32 {
    return std::process::exit_status(code: 0_u8);
  } else {
    return std::process::exit_status(code: 1_u8);
  }
}
```

### 14. Where do I discover the standard library API?

Read `lib/std/modules.wfg` for available module names, then `lib/std/<module>/module.wfm` for exact public types, functions, parameter order, effects, waiting markers and contracts. Do not guess API names or infer a callee's obligations from its implementation. The specification's [PRE-1] contains prelude functions, while [PRE-2] declares the host modules. [MOD-10, FN-1, FN-8, FN-9]

The startup names are `std::process::Inputs` and `std::process::ExitStatus`. Streams and their factory are `std::io::InputStream`, `std::io::OutputStream`, `std::io::HandleFactory`. The `std::io` interface declares: [PRE-2, GRAM-11]

`write_once(factory: &HandleFactory, output: &OutputStream, source: &[u8], start: u64, end: u64, deadline: Option<Instant>, cancel: &CancelWatch) -> result: Result<u64, IoError> reads(cancel), reads(source), writes(factory), writes(output) waits`

It requires `start <= end` and `end <= source^.len`. `Ok` carries the index after the last byte written, which can be below `end`; complete output needs continuation from that index. Deadline and cancellation are explicit arguments.

### Reserved words

Grammar tokens cannot be identifiers: [FORM-3]

`alias apart atomic binding break const continue contract copy define doc drop else ensures entry enum f32 f64 fn for forall give i16 i32 i64 i8 if in interface invariant is let loop match move musttail no_heap nocopy nodrop not opaque package pkg program propagate public pure readonly reads requires return set spawn std struct times u16 u32 u64 u8 unchanged unit use waits when writes`

Mode words: `wrap defined checked sat strict nearest`.

Dotless operation names: `band bnot bor bxor cvt fabs fceil fcopysign feq ffloor fge fgt finf fle flt fmax fmin fnan fne fneg frem froundeven ftrunc iabs iand ibswap iclz ictz imax imin imulhi ineg inot ior ipopcount irotl irotr ishl ishr ixor reinterpret`.

Modes and operation names are prohibited for source function names, constants, value parameters, result binders, lets, loop binders, atomic binders, contract definitions, fields and payload binders. They remain legal for aliases, const generics, labels, invariant names and interface member signature names; calls use the operation names. [OP-1, FORM-3]

### When the compiler says…

Use the opening repair workflow; use §3 for atom positions and §12 for layout.

| Diagnostic symptom | Form to check |
| --- | --- |
| `GRAM-3`: header expected list includes `pure`, `reads`, `writes`; found `{` or `waits` | Put `waits` after a required effect row. [GRAM-2, EFF-1] |
| `GRAM-4`: found `[` after `let name =` | Use `array_filled`/`slots_new`, not a list literal. [GRAM-4, OP-13] |
| `GRAM-4/5`: found `(` around an expression, `+` inside an argument/subscript, or a nested call | Remove grouping or bind the computed operand first. [GRAM-5, GRAM-6, GRAM-9] |
| Found `&`, `\|`, `&&`, `\|\|`, `!`, or `%wrap` as an operation | Use the admitted table operation; division/remainder have no wrap mode. [OP-1, GRAM-5] |
| `FORM-1` or `FORM-3` at an uppercase constant, `_` binder or reserved name | Use a fresh lowercase nonreserved name. [FORM-3, TYPE-6, OP-1] |
| Error at `loop ()` | Use `loop {`, or a nonempty named invariant header. [GRAM-4] |
| `GRAM-4`: found `;` after a value match/if's `}` | Remove that semicolon. [GRAM-4, GRAM-7] |
| `GRAM-2`: expected end of source, found top-level `use` | Imports are aliases in the file's alias header. [GRAM-2, MOD-4] |
| Error at `Choice::<T>::Present` | Write `Choice<T>::Present(...)`. [TYPE-5] |
| Error at `Some(x)` or a repeated payload binder | Write `Some(value: fresh_name)` in a match arm. [GRAM-10] |
| Graph file errors | Use section 13's complete graph layout and direct dependencies; entries are `entry name = pkg::module::function;`. [GRAM-2, MOD-1] |
| `FORM-2` expects an indented LF but finds an extra blank line | Remove the blank line inside the item; follow canonical layout. [FORM-2] |
| `MOD-5 QualifiedNameNotFound` | Use a listed public declaration from that module's interface; check its direct graph edge. [MOD-5, MOD-6] |
| `FORM-5 UnclassifiedToken` on a quoted character such as unsuffixed `'+'`, or hex | Add `_u8`/`_u32` to the character; use decimal numeric literals. [FORM-5, FORM-7] |
| `OP-2` on bare arithmetic or `OP-6` on `cvt` | Establish the operation's domain; preserve the intended numeric semantics. [OP-2, OP-6] |

## Part 2. Designing a sequential program

### Where should each piece of data live?

Choose occupancy, residence and required views together: they determine initialized positions, ownership and legal consumers [TYPE-9, WIN-1].

| Need | Choose | Cost or limitation to plan for |
|---|---|---|
| Small parent-owned record | Inline fields | Inline representation travels with its parent. |
| Full fixed extent | `Array<T, N>` | N initialized elements; inline storage. |
| Fixed prefix window | `Slots<T, N>` | Unused inline capacity occupies storage. |
| Fixed queue | `Ring<T, N>` | Wrapped indexing; no range borrow. |
| One independently owned heap value or recursive link | `Box<T>` | Owns a cell; content may avoid/add allocations. Access `cell.inner`. |
| Runtime full extent | `Box<Array<T>>` | Contiguous; initialized from a copy value. |
| Growable contiguous prefix | `Box<Slots<T>>` | `grow` may relocate every initialized element. |
| Runtime queue | `Box<Ring<T>>` | Resize by rebasing; no native grow. |
| Variable-length outputs per item | `Box<Segments<T>>` | Count first; joined contiguous run. |
| Growth without later payload moves | `Box<Paged<T>>` | Directory access; ranges use `&Run<T>`. |
| Read-only fixed lookup data | Named const `Array<T, N>` | Immutable static storage; see the immutable-table section. |

Runtime-capacity shapes, `Segments` and `Paged` live only inside Box; store/return the Box or borrow its content [TYPE-9]. Wrap it only for additional policy or state.

For bulk records that loops scan field by field, keep one window or array per field, all indexed by the same record index, instead of one window of records. A scan then reads only the fields it uses, contiguously, and a field update writes only that field's storage. Pair fields in one record only when every access uses them together, such as a hash table's key and value slots. Keep the shared length in one place and append to every field window together, so one index names the same record in each.

Inline and boxed prefix windows:

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn main() -> status: ExitStatus pure {
  let local = slots_new::<u8, 4>();
  place_back(window: &local, value: 7_u8);
  let heap = box_slots_new::<u8>(capacity: 4_u64);
  place_back(window: &heap.inner, value: 9_u8);
  let first = local[0_u64];
  let second = heap.inner[0_u64];
  let total = first +wrap second;
  return exit_status(code: total);
}
```

Readonly measures are `len`, `cap`, and Ring's `head`; Array has `len` only. There is no `room`. Append needs `len < cap`; a subscript needs `index < len`, not merely capacity [MSR-1, OP-4].

**Cost and check.** A fixed empty window reserves its full inline capacity; boxing a fixed array does not promise elimination of a large constructor temporary. Current compiler: inspect frames/chains/cycles with `--stack-ledger`; acceptance does not prove stack capacity [STOR-1, STOR-6]. `std::process::heap_in_use` observes heap holding; `resident_bytes` observes residency, a different quantity [PRE-2].

Require heap independence with first-item `program no_heap;` or graph entry `no_heap`; neither proves stack capacity or promotes inline values to heap [STOR-8, MOD-9].

#### Do consumers need contiguous data or just a logical run?

Choose `&[T]` for contiguous consumers and `&Run<T>` for possibly paged logical access: the kind states the representation promise. `Run` is not an owned value type [TYPE-8, REF-4].

`&a[lo..hi]` requires `lo <= hi <= a.len`; length is captured `hi - lo`, indexing is relative to lo. Alias with `let other = part;`; reslice with `&part^[a..b]`, preserving its kind [REF-1, REF-4].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn first(run: &[u8]) -> result: u8 reads(run) contract {
  requires run^.len > 0_u64;
} {
  return run^[0_u64];
}

fn main() -> status: ExitStatus pure {
  let bytes = array_filled::<u8, 4>(value: 7_u8);
  set bytes[1_u64] = 9_u8;
  let part = &bytes[1_u64..3_u64];
  let alias_part = part;
  let prefix = &alias_part^[0_u64..1_u64];
  let selected = first(run: prefix);
  return exit_status(code: selected);
}
```

**Failure and check.** Captured ranges do not extend after append or retarget after endpoint rebinding. Read `part^.len` and borrow anew for a new extent. Ring ranges are refused even after a non-wrap test; visit logical elements [REF-4].

#### Are variable-length outputs known before filling them?

Use Segments for known per-item counts and one contiguous result: its fixed boundaries avoid a backing allocation per item [TYPE-9, OP-13].

Outer `len` counts segments; `&out.inner[i]` has its own element length. `&out.inner.all` borrows the joined run; neither selection is an owned value [OP-4, REF-4].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn main() -> status: ExitStatus pure {
  let counts = array_filled::<u64, 2>(value: 2_u64);
  set counts[1_u64] = 1_u64;
  let out = box_segments_filled::<u8>(lengths: &counts[0_u64..2_u64], value: 0_u8);
  let segment = &out.inner[0_u64];
  if segment^.len > 0_u64 {
    set segment^[0_u64] = 7_u8;
  }
  let joined = &out.inner.all;
  if joined^.len > 0_u64 {
    return exit_status(code: joined^[0_u64]);
  }
  return exit_status(code: 0_u8);
}
```

**Cost and check.** Construction initializes all elements from a copy value and stores boundaries. If counting requires expensive production, compare retaining per-item buffers against producing twice. Use a segment's own length for element bounds. The runtime sum/size may exhaust allocation; it gives no Result [OP-9, OP-13, STOR-8].

#### Must growth preserve payload addresses?

Choose Paged for repeated growth with bounded initial copying; choose Slots for one contiguous run, because its growth can relocate the full prefix [OP-10, OP-13].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn first(run: &Run<u8>) -> result: u8 reads(run) contract {
  requires run^.len > 0_u64;
} {
  return run^[0_u64];
}

fn main() -> status: ExitStatus pure {
  let pool = box_paged_new::<u8>(capacity: 1_u64);
  place_back(window: &pool.inner, value: 7_u8);
  grow_paged(cell: &pool, capacity: 8_u64);
  let run = &pool.inner[0_u64..pool.inner.len];
  let selected = first(run: run);
  return exit_status(code: selected);
}
```

`paged_page_len::<T>()` returns page length B. Growing page zero below B copies at most B - 1 initialized elements in total over an owner's growth. Once page zero reaches B, growth keeps element addresses but may replace the directory cell [OP-10, OP-13].

For contiguous access, prove `k < pool.inner.pages.len` and borrow `&pool.inner.pages[k]`. Pages count initialized extents only; the borrow captures that extent and never extends [REF-4, MSR-1].

**Cost and check.** Directory access, page allocations and directory capacity cost space/time. Whole-cell growth rows invalidate references despite retained addresses; keep indices and borrow again [REF-2, OP-10]. Measure heap holding and access time separately.

#### Does the standard library already own the required policy?

Read the collection's `module.wfm`: wrappers publish policy, bounds and ownership transitions beyond native windows [MOD-8].

| Requirement | Module to inspect | Behavior affecting design |
|---|---|---|
| Growing prefix | `lib/std/collections/vector/module.wfm` | Doubles within ceiling; remove shifts, swap-remove moves a constant number. |
| Runtime queue | `lib/std/collections/deque/module.wfm` | Endpoints need room/nonemptiness; rebase replaces backing; visit per element. |
| Sparse reusable slots | `lib/std/collections/slab/module.wfm` | Index/generation handles; full insert returns owner; exhausted generations retire. |
| Owning key/value lookup | `lib/std/collections/hash_map/module.wfm` | Inline buckets; replacement/full insert return complete pairs; reserve/rehash relocate. |

For next-item ordering inspect priority_queue; for sorted keys/ranges inspect ordered_map, also under lib/std/collections. Neither promises stable physical indices.

Observation/edit callbacks return owned results; drain callbacks consume `nodrop` elements. Environment must be disjoint from backing [EFF-5]. Read measures: the vector constructor has no result postcondition [FN-9].

**Check.** Hash/equality laws grant no ownership authority. Test returned-owner consumption. Callback rows remain authoritative even if a body touches less.

### Who owns each value, and how does ownership end?

Choose copy, transfer or borrow: ownership follows fields, payloads, Box content and elements, so wrapping a resource preserves its obligation [OWN-1, PROV-6].

Copy values are used bare; affine values transfer with `move` or take derived release; linear values must be consumed. `nocopy` removes copy; `nodrop` removes copy and drop. Neither attaches a finalizer. `Result` inherits its payload capabilities: match `Result<u64, IoError>` bare; move a Result owning `HostString`. Do not add `move` to every Result [OWN-1, STOR-3, PRE-2].

Move is forbidden for concrete copy values. `Array<u8, N>`, `Option<u8>` and an unmarked `Pair<u8>` with copy fields are copy; `Box<Pair<u8>>` is not. After `MoveOfCopy`, inspect every move, including returns, using the instantiated type for concrete uses. Keep the generic template's move spelling under its written bounds, as the generic section explains. [OWN-1, FN-2]

`cell.inner` reaches Box content; moving it consumes/frees the cell. `^` is for references only. Runtime-capacity shapes, Segments and Paged cannot move out of Box [TYPE-7, TYPE-9].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

nocopy struct Record {
  id: u8;
  scratch: Box<u8>;
}

fn main() -> status: ExitStatus pure {
  let scratch = box_new::<u8>(value: 9_u8);
  let record = Record(id: 7_u8, scratch: move scratch);
  let cell = box_new::<Record>(value: move record);
  let taken = move cell.inner;
  let Record(id: selected, ..) = move taken;
  return exit_status(code: selected);
}
```

Final `..` releases omitted droppable fields in a consuming destructure; copy destructuring leaves its source live. Fields are in declaration order. Partial moves kill the whole root and cannot strand linear residual fields; destructure whole to give them distinct consumers [WIN-3, PROV-6].

End ownership early with `release::<T>(value: move owner)` for `T: drop`; concrete copy values pass bare. A reference argument never consumes the resource [PRE-1, OWN-1].

Release the owner unconditionally before observing heap use after disposal. Moving it into a helper transfers ownership; a return expression is evaluated before automatic exit release of bindings still live in that helper. An owner moved into the returned value is transferred, not released there. [OWN-1, STOR-3]

**Cost and check.** Release visits owned elements/links: bindings in reverse declaration order, fields in declaration order, active enum payloads only, content before Box. Recursive release depth follows the value [PROV-6, STOR-3]. Check `--stack-ledger` and deepest intended structures; loop or `musttail` traversal does not guarantee constant-depth cleanup.

#### How can owned state change without leaving a hole?

Use swap, window operations or atomic owned update: each preserves complete occupied places without a hole [WIN-3, OP-11, OP-12].

Set releases an old affine value and refuses a linear overwrite. Swap exchanges noncopy values without consuming roots; equal targets are allowed, possible proper ancestry is not [OP-11].

Atomic update takes its target as first value argument, returns its type, has no failure exit and cannot write/free a target prefix. Failure lives in the replacement state enum [OP-12].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

nocopy struct State {
  value: u8;
}

fn advance(state: State) -> result: State pure {
  let State(value: previous) = move state;
  let next = previous +wrap 1_u8;
  return State(value: next);
}

fn main() -> status: ExitStatus pure {
  let state = State(value: 7_u8);
  set state = advance(state: move state);
  return exit_status(code: state.value);
}
```

A consume kills its root; only a whole-binding assignment revives it. Joins require identical live/dead status on the structural control graph, even for `if True()`: its false edge remains, including when there is no written else. [SET-1, LIV-1, FN-1]

**Failure and check.** Loop ownership checks the structural backedge even after `break`/`return`. Rebuild consumed outer bindings, or consume iteration-local owners [OWN-11]. Read diagnostics for the root/predecessors/residual part and repair the complete transition.

#### How do must-use elements and their backing get consumed?

Consume elements, prove empty, then `free_empty`: zero length never changes linearity [PROV-6, OP-14].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

nodrop enum Ticket {
  Ready();
}

fn spend(ticket: Ticket) -> result: unit pure {
  match move ticket {
    Ready() => {
      return unit;
    }
  }
}

fn main() -> status: ExitStatus pure {
  let tickets = box_slots_new::<Ticket>(capacity: 1_u64);
  let ticket = Ticket::Ready();
  place_back(window: &tickets.inner, value: move ticket);
  let removed = take_back(window: &tickets.inner);
  spend(ticket: move removed);
  free_empty(window: move tickets);
  return exit_status(code: 0_u8);
}
```

`free_empty` admits Slots/Ring and boxed runtime Slots/Ring/Paged. For Box, prove `owner.inner.len == 0` and pass the Box. Drain helpers can publish emptiness after consuming elements [OP-14].

**Failure and check.** Every exit, including propagate error returns, must discharge linear owners. Release cannot close nodrop handles; move cannot leave a window hole. Remove with take operations or whole-state exchange, and account for every early exit.

### How long can a reference remain valid?

Borrow near use: a reference is a local path witness, not durable identity [REF-1, REF-3].

References never escape into fields/elements/results/type arguments. Return an index/decision; the caller borrows [TYPE-8, REF-3]. `let q = p;` aliases; `set cursor = &place;` rebinds; `set cursor^ = value;` writes [REF-1].

Borrowed matches keep the enum live and bind references: read with `^`, pass bare as references. Consuming matches bind owners and kill the root [OWN-13].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

struct Link {
  value: u64;
  next: Option<Box<Link>>;
}

fn sum(head: &Option<Box<Link>>) -> result: u64 reads(head) {
  let cursor = head;
  let total = 0_u64;
  loop {
    match cursor^ {
      Some(value: node) => {
        set total = total +wrap node^.inner.value;
        set cursor = &node^.inner.next;
      }
      None() => {
        return total;
      }
    }
  }
}

fn main() -> status: ExitStatus pure {
  let empty = None<Box<Link>>();
  let node = Link(value: 7_u64, next: move empty);
  let cell = box_new::<Link>(value: move node);
  let head = Some<Box<Link>>(value: move cell);
  let total = sum(head: &head);
  if total == 7_u64 {
    return exit_status(code: 0_u8);
  }
  return exit_status(code: 1_u8);
}
```

Writing a proper path prefix, moving/releasing the path or prefix, scope exit and window invalidation end validity. Content writes at/below the selected place preserve the reference but kill old value facts. Moves never re-root references [REF-2, ENT-5].

Payload references survive their selecting arm but not enum replacement; a fresh selection needs refinement. Loop cursors may descend owned links. Structural writes preserve the current cursor/proved aliases but may invalidate other cursors in the subtree; re-form them [REF-1, REF-2].

#### Which window changes move values or invalidate selection?

A safe slot can acquire a different occupant [OP-10].

| Operation | Preconditions to establish | Movement and reference consequence |
|---|---|---|
| `place_back(window:, value:)` | `len < cap` | Fill next slot, increment length. Existing filled-slot/range bounds survive; captured ranges do not extend. |
| `take_back(window:)` | `len > 0` | Return last owner, decrement length. Earlier selection bounds are not published across the call; re-form references. |
| `insert_at(window:, index:, value:)` | `index <= len`, `len < cap` | Shift filled run and increment length. Surviving references name slots whose occupants may change. |
| `remove_at(window:, index:)` | `index < len` | Return owner, shift filled run, decrement length. Re-form references after the lost bounds. |
| `append(destination:, source:)` | `source.len <= destination.cap - destination.len` | Transfer source's run and empty source. Its owners move; references into source cease to select filled elements. |
| `split_off(source:, index:, destination:)` | `index <= source.len`, suffix fits destination | Transfer suffix, reduce source to index. Re-form views of either resulting run. |
| `grow(cell:, capacity:)` | New capacity at least old capacity | Boxed runtime Slots only; whole-cell row, possibly relocate all payloads; re-form references. |
| `grow_paged(cell:, capacity:)` | New capacity at least old capacity | Boxed Paged only; possible initial-page/directory replacement; whole-cell row invalidates references. |
| `place_front(window:, value:)`, `take_front(window:)` | Room or nonemptiness | Ring only; shift every logical index and invalidate every reference into it. |

**Cost and check.** Repeated middle insertion can be quadratic. Profile representative use. Append publishes destination lower bounds/source emptiness, not exact summed length [PRE-1].

### What survives longer than one borrow?

Keep indices; add generations for reuse, because bounds prove slot existence, not object identity [OP-13].

Append-only Slots/Paged pools preserve logical indices across growth; prove bounds and borrow at access. Shifting removal changes identity at indices; use stable sparse slots for long-lived identity.

Represent vacancy as Option; swap complete owners instead of leaving subscript holes [OP-11, WIN-3].

```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

fn main() -> status: ExitStatus pure {
  let pool = slots_new::<Option<Box<u8>>, 2>();
  let cell = box_new::<u8>(value: 7_u8);
  let occupied = Some<Box<u8>>(value: move cell);
  place_back(window: &pool, value: move occupied);
  let handle = 0_u64;
  let removed = None<Box<u8>>();
  if handle < pool.len {
    swap(first: &pool[handle], second: &removed);
  }
  match move removed {
    Some(value: selected) => {
      return exit_status(code: selected.inner);
    }
    None() => {
      return exit_status(code: 0_u8);
    }
  }
}
```

Carry index/generation and reject mismatches/vacancy. Prevent wrap accepting ancient handles; std slab retires at its generation limit. Handles are pool-relative: another pool's same index/generation proves no identity.

**Failure and check.** Stale in-bounds handles can target the wrong object. Test reuse, wrong-pool use and generation exhaustion against identity. Required retention by another index needs a preserved membership protocol; public counters alone prove none.

### How will expected failures leave this operation?

Return `Result<T, E>` for an expected failure and `Option<T>` for absence; use a domain enum when the alternatives carry different information. Use `propagate` when the current function returns `Result<U, E>` with the same exact error type. Reason: a failure value gives the caller an ordinary branch and keeps cleanup visible [ERR-1, ERR-3].

```whitefoot
fn add_byte(left: u8, right: u8) -> result: Result<u8, Overflow> pure {
  return left +checked right;
}

fn twice(value: u8) -> result: Result<u8, Overflow> pure {
  let doubled = propagate add_byte(left: value, right: value);
  return Ok<u8, Overflow>(value: doubled);
}
```

`propagate` evaluates once, binds `Ok`, or returns `Err`; it performs no error conversion and has no `Option` counterpart. Match explicitly to translate, retry, or close a live linear resource. Its error edge owes ordinary cleanup and reference postconditions. The checked program attaches automatic `(function, node_path)` context [ERR-3].

Silent failure and check: a `requires` clause removes the runtime failure alternative. Use it only for a real API obligation. Exercise both variants and the boundary between them; `--check` proves obligations, not application error policy.

### Which evidence must travel with a successful result?

Put a reusable success relation in a routed `ensures when Ok(value: ...)` or `ensures when Some(value: ...)`, then keep the outcome as an ordinary value until selection. Reason: the caller checks a signature and does not inspect the callee's body to rediscover why its payload is safe. Any own result whose concrete type is an enum takes routed clauses: `ensures when V(f: r): ...`, or `ensures when b is V(f: r): ...`, where `b` names the result, which picks one of several results. One clause binds one declared field whose type supplies integer data; write another clause for another field, and no clause relates two fields of one variant. A return of `V`, constructed or forwarded with `V`'s evidence, proves the clause; a return of another variant owes nothing. The caller gets the fact only in that variant's match arm. An interface member's implementation repeats the interface's routed clauses exactly [FN-4]. Current compiler: a routed clause in a generic template whose type parameter is bounded only by `copy` is rejected even for an integer instance; bound it by `Int`. Report a needed unsupported boundary; do not hide it with a redundant runtime guard [FN-9, CALL-4, CALL-6, ENT-5].

A lookup that reports where it found a key publishes each location's bound, and its caller indexes without another bounds check:

```whitefoot
enum Slot {
  Array(value: u64);
  Node(value: u64);
  Missing();
}

fn find_slot(array: &Box<Slots<u64>>, nodes: &Box<Slots<u64>>, key: u64) -> r: Slot reads(array), reads(nodes) contract {
  ensures when Array(value: i): i < array^.inner.len;
  ensures when Node(value: i): i < nodes^.inner.len;
} {
  for (i in 0_u64..array^.inner.len) {
    if array^.inner[i] == key {
      return Slot::Array(value: i);
    }
  }
  for (j in 0_u64..nodes^.inner.len) {
    if nodes^.inner[j] == key {
      return Slot::Node(value: j);
    }
  }
  return Slot::Missing();
}

fn store(array: &Box<Slots<u64>>, nodes: &Box<Slots<u64>>, key: u64, value: u64) -> r: Bool writes(array), writes(nodes) {
  let slot = find_slot(array: array, nodes: nodes, key: key);
  match slot {
    Array(value: i) => {
      set array^.inner[i] = value;
      return True();
    }
    Node(value: j) => {
      set nodes^.inner[j] = value;
      return True();
    }
    Missing() => {
      return False();
    }
  }
}
```

The same form on Result and Option:

```whitefoot
fn selected(value: i32, fail: Bool) -> result: Result<i32, Overflow> pure contract {
  ensures when Ok(value: payload): payload == value;
} {
  if fail {
    let problem = Overflow();
    return Err<i32, Overflow>(error: problem);
  }
  return Ok<i32, Overflow>(value: value);
}

fn relay(value: i32, fail: Bool) -> result: Result<i32, Overflow> pure contract {
  ensures when Ok(value: payload): payload == value;
} {
  let outcome = selected(value: value, fail: fail);
  let saved = outcome;
  let payload = propagate saved;
  return Ok<i32, Overflow>(value: payload);
}
```

Named, copied, moved, assigned and `give`-delivered local outcomes retain verified conditional numeric relations. The match success binder or successful propagation exposes them; an unknown tag does not. Supported struct payload fields/measures can carry relations [FN-9, ENT-5].

Evidence names the evaluated value: reassignment does not change an earlier copy, while writes to supporting storage kill affected relations. Array-element storage does not preserve ordinary local numeric evidence. Joins keep common consequences; continuing backedges cannot reuse an outcome’s old evidence after changing it [ENT-5, MSR-3].

Silent failure and check: a wrapper must republish its routed contract. Integer `cvt.checked` supplies conditional equality to the evaluated input; float-involving conversion supplies no numeric relation. On rejection, find the write that killed support before adding checks.

### What does arithmetic mean when it exceeds its ordinary domain?

Choose the mode from the algorithm: bare exact arithmetic for a proved domain, `checked` for expected numeric failure, `wrap` for modular arithmetic, `sat` for intentional clamping, and `defined` for a domain query. Reason: these spellings choose different results, and a compiler repair cannot decide the algorithm's intended result [OP-2].

```whitefoot
fn next(value: u8) -> result: Result<u8, Overflow> pure {
  let valid = value +defined 1_u8;
  if valid {
    let incremented = value + 1_u8;
    return Ok<u8, Overflow>(value: incremented);
  }
  let problem = Overflow();
  return Err<u8, Overflow>(error: problem);
}
```

Exact operations owe a static domain proof and emit no synthesized guard/trap. Computing a `defined` Bool alone establishes nothing; its selected true edge proves the corresponding domain. Test a domain when input rejection is required; do not add runtime tests solely to hide a checker gap.

Division/remainder exclude zero and signed minimum/`-1`, return `DivError` when checked, and have no wrap mode. Division truncates toward zero; remainder has the dividend’s sign. Exact negation/absolute exclude signed minimum. Exact shifts only prove amount < width: left shift may discard high bits. Wrap shifts mask their `u32` amount; rotates use it modulo width.

Silent failure and check: using wrap to silence an exact-operation rejection changes results. Test overflow, signed minimum, zero divisor and shift-by-width where relevant. Read the residual OP-2 obligation; publish a valid missing relation through an invariant/certificate.

Float rounding operations use `.strict`, with no reassociation/contraction; `ffma.strict` explicitly fuses. The active table has no `.fast`. Use float comparisons such as `feq`. `reinterpret` bitcasts admitted equal-width primitives, preserving NaN/sign bits [OP-3, OP-8]. Test exceptional values and accuracy separately from proof.

### Is a conversion exact, checked, modular, or rounded?

Use `cvt` when exact representability is guaranteed, `cvt.checked` when failure is an outcome, `cvt.wrap` for the destination-width integer residue, and `cvt.nearest` when the destination float should round. Reason: the type pair alone does not decide whether lost information is an error, a residue, or rounding [OP-6].

```whitefoot
fn byte(value: u32) -> result: u8 pure contract {
  requires value <= 255_u32;
} {
  return cvt::<u32, u8>(value);
}

fn high_half(word: u64) -> result: u32 pure {
  let high = ishr(word, 32_u32);
  return cvt::<u64, u32>(high);
}

fn channel(component: u8) -> result: f32 pure {
  let wide = cvt::<u8, f64>(component);
  let ratio = fdiv.strict(wide, 255.0_f64);
  return cvt.nearest::<f64, f32>(ratio);
}
```

`cvt.checked` always returns `Result<Dst, NarrowError>`, even for identity/widening. A selected true `cvt.defined` proves exact conversion of the same value and pair. Operation result intervals can prove narrowing directly: avoid extra masks/checked conversions solely for bounds already carried [ENT-3].

Integer-to-float requires representability, not just finite range; −2^24..2^24 suffices for f32. Float-to-integer additionally requires integrality. Identity conversion preserves representation; cross-format NaN uses the destination’s canonical quiet NaN.

`cvt.wrap` applies destination modulus to the mathematical input: −1_i8 to u32 yields 4294967295. Its output has destination bounds, not input equality. `cvt.nearest` has a float destination, rounds ties to even, yields signed infinity on overflow and preserves sign when rounding to zero; it supplies no proof about the input.

Silent failure and check: an exactness guard with fallback usually selects the fallback for computed fractions. Use `cvt.nearest` for rounded storage. Check loss boundaries and exceptional values; an OP-6 rejection names the domain, so distinguish missing proof from genuinely invalid input.

### Should classifier state be control flow or Boolean data?

Keep predicates and scanner flags in `Bool`; combine them with `band`, `bor`, `bxor`, and `bnot`, and select a numeric contribution with value-producing `if`. Reason: Boolean dataflow preserves its meaning and leaves branch lowering to the compiler [OP-5, ENT-3, GIVE-1].

```whitefoot
fn decimal(byte: u8) -> result: Option<u8> pure {
  let low = byte >= 48_u8;
  let high = byte <= 57_u8;
  let valid = band(low, high);
  if valid {
    let digit = byte - 48_u8;
    return Some<u8>(value: digit);
  }
  return None<u8>();
}

fn contribution(starts_word: Bool) -> result: u64 pure {
  let increment = if starts_word {
    give 1_u64;
  } else {
    give 0_u64;
  }
  return increment;
}
```

A true retained `band` provides both facts; a true `bor` generally proves neither particular operand. These operations are not short-circuit control flow. Branch before a partial subscript; computing it before combining an in-bounds Bool is too early [ENT-3].

Silent cost and check: Bool dataflow does not promise branchless machine code; inspect emitted LLVM and measure the hot workload through CI. Both `give` branches preserve common bounds, so this contribution lies in 0..1. Use `--check` to identify missing origin facts.

### What belongs in a function boundary?

Declare the narrowest truthful reference effect row and state only genuine caller requirements and proved result/state relations. Reason: a call invalidates facts from its declared writes and publishes its declared guarantees, rather than reading its implementation [EFF-1, EFF-2, FN-8, FN-9].

When a long call chain decides changes to state reached through reference parameters, compute the changes as owned values in `pure` or read-only helpers, and apply them in one shallow writer near the state's owner. The deciding helpers then carry no `writes` for that state, so the facts and independence their callers rely on survive the calls, and the mutation boundary stays visible in signatures; callers of the writer still inherit its projected writes. [EFF-1, EFF-2] This concerns ordinary state only: a shared object's state is outside the row, a `pure waits` function can change it, and its accesses follow the atomic-statement rules of Part 3. [SHARE-2]

```whitefoot
struct Counter {
  value: u64;
}

fn store(counter: &Counter, next: u64) -> result: unit writes(counter.value) contract {
  ensures counter^.value == next;
} {
  set counter^.value = next;
  return unit;
}

fn pop<T, const n: u64>(window: &Slots<T, n>) -> value: T writes(window.last), writes(window.len) contract {
  requires window^.len > 0_u64;
  ensures window^.len + 1_u64 == entry(window)^.len;
} {
  let value = take_back(window: window);
  return move value;
}
```

Effect paths begin at the formal without `^`. Write covers reads/writes below it; read covers reads below it; do not repeat covered entries. Owned parameters have no effect entry. `pure` promises neither no allocation, no waiting nor termination; local mutation can remain pure [EFF-3]. Overlapping reads are allowed; read/write or write/write actuals must be proved disjoint [EFF-1, EFF-5].

`next`, `last`, `filled` and `free` are effect-only window parts, never readable fields or borrow targets. `last` covers successive rear removals, not just one entry slot [WIN-2].

`entry(window)` denotes entry storage; bare written-reference terms denote exit storage. Requirements permit larger arithmetic than published `ensures`, whose relation sides admit one supported datum displaced by a constant, plus at most one bare integer parameter with coefficient one on one side, as in `ensures after <= base + limit;`. Pass a scalar final total when publishing a relation to a larger sum [FN-9, MSR-3].

A call inside a recursive cycle, to the function itself or to another function of the same call-graph cycle, receives the callee's postconditions, written `ensures` included, as induction hypotheses. A body never assumes its own `ensures` at entry, every exit still proves them, and writes to a reference argument after the call kill its facts as for any call. Split recursion can therefore bound its combination directly instead of using a loop or `+sat`: [DIAG-2, FN-9]

```whitefoot
fn halves(n: u64) -> total: u64 pure contract {
  ensures total <= n;
} {
  if n <= 1_u64 {
    return n;
  }
  let half = n / 2_u64;
  let rest = n - half;
  let a = halves(n: half);
  let b = halves(n: rest);
  let total = a + b;
  return total;
}
```

Contract `define` abbreviates proof expressions, expands recursively, executes/snapshots nothing and is unavailable in the body. Contract +/−/* are mathematical arithmetic; they do not prove body-operation domains. Calls/allocation/partial division, remainder and shifts are inadmissible; use total queries or relations [FN-8].

An ordinary mutable integer field below a subscript is not a proof term: copy it to a local first. A `public readonly` integer field can participate directly, but replacement, storage writes or index changes can kill its facts [ENT-2].

Silent cost and check: broad writes kill caller facts and independence; omitted real accesses are rejected. Unused declared effects also reject: rows must cover all body accesses and exhibit every entry, including syntactically unreachable accesses [EFF-2]. Audit the formal boundary at each call. `--check` verifies rows and contracts; no runtime checks are inserted. A callback’s formal row governs callers even if the actual writes less.

### Which relation should the checker carry around a loop?

Choose the maintained relation before writing the loop. For an empty append window, use `output.len == index` with a counted index starting at zero. For a byte decoder that does not expand input, maintain `produced <= consumed` and `input_length <= output_length`. Put the relation in the loop header; use a local invariant for a fact needed at one point. The header is the induction boundary where the checker proves the base and every continuing backedge. [INV-1]

```whitefoot
fn filled<const n: u64>() -> result: Slots<u8, n> pure contract {
  ensures result.len == n;
} {
  let output = slots_new::<u8, n>();
  for (
    at in 0_u64..n,
    invariant filled_prefix: output.len == at
  ) {
    place_back(window: &output, value: 0_u8);
  }
  return move output;
}
```

The counted binder supplies its half-open range. Header invariants prove simultaneously; none proves another’s base. Headers have no proof blocks: establish complex base/backedge facts locally. Affine targets admit supported integer values/fields/measures and literal-scaled expressions, not arbitrary runtime products or `!=` [INV-1].

A break exports only conclusions with surviving support. The header’s proof name expires, while its conclusion may survive. A write before break can invalidate it. Exact exhaustion conclusions survive only if every reaching continuation edge independently has them [ENT-5].

Silent failure and check: prove every next header, including the terminal next counted index, and every continuing path that skips work; inspect each exit separately. [INV-1, FN-1] Wrapping can reorder lookahead indices; establish a separate bound for each before indexing. [OP-2, OP-4] The checker rejects failed induction and inserts no runtime tests. Reduce an unproved valid step before weakening arithmetic or adding a redundant guard.

### What should be written when automatic proof is insufficient?

For a valid local affine consequence outside automatic proof, attach a finite `use` certificate to its local invariant. Reason: the checker verifies the chosen premises and combination and then erases the proof, keeping the algorithm's execution unchanged [PRF-1].

```whitefoot
fn bounded_sum(first: u8, first_limit: u8, second: u8, second_limit: u8, third: u8, third_limit: u8) -> result: u8 pure contract {
  requires first <= first_limit;
  requires second <= second_limit;
  requires third <= third_limit;
  requires first_limit <= 80_u8;
  requires second_limit <= 80_u8;
  requires third_limit <= 93_u8;
  ensures result <= 254_u8;
} {
  invariant component_sum: first + second + third <= first_limit + second_limit + third_limit + 1_u8 {
    use (first <= first_limit);
    use (second <= second_limit);
    use (third <= third_limit);
  }
  invariant limit_sum: first_limit + second_limit + third_limit <= 253_u8;
  invariant total_bound: first + second + third <= 254_u8;
  let first_two = first + second;
  let result = first_two + third;
  return result;
}
```

Use a dominating named invariant or parenthesized inequality; written equality is not one premise. Literal multiplicities are untyped proof decimals, e.g. `use 3 times bound;`. Runtime unsigned multipliers require earlier admitted exact-product records; arbitrary nonlinear terms/signed multipliers reject [PRF-1].

All uses are proved in the same entering snapshot; earlier uses cannot help later ones. Duplicates reject; a block whose target AUTO already proves rejects as redundant. Only the target is published. Named theorems keep immutable value identities [PRF-1].

Silent failure and check: certificates direct valid derivations, never assert facts. Read the residual and PRF-1 disposition; remove redundant blocks. If the natural relation cannot be expressed/proved, report a minimal semantic witness as a language/checker gap instead of changing the algorithm to conceal it.

### Does the proof concern an entire processed prefix?

Use a named `forall` range fact for a relation about collection contents, with a loop invariant over the processed prefix and a postcondition for consumers. Reason: scalar length facts alone say nothing about what the elements contain [RANGE-1, RANGE-3].

```whitefoot
fn ramp(n: u64) -> result: Box<Array<u64>> pure contract {
  requires n <= 1000_u64;
  ensures result.inner.len == n;
  ensures forall up(k in 0_u64..result.inner.len): result.inner[k] == k;
} {
  let cells = box_array_filled::<u64>(count: n, value: 0_u64);
  for (
    k in 0_u64..n,
    invariant forall built(q in 0_u64..k): cells.inner[q] == q
  ) {
    set cells.inner[k] = k;
  }
  return move cells;
}

fn at_index(cells: &[u64]) -> result: u64 reads(cells) contract {
  requires forall up(k in 0_u64..cells^.len): cells^[k] == k;
} {
  if 0_u64 < cells^.len {
    let last = cells^.len - 1_u64;
    return cells^[last];
  }
  return 0_u64;
}
```

Range clauses have one/two binders, half-open ranges, optional guards and conclusions over supported element projections. They execute nothing; an instance claims conclusions only where its element/payload reads are defined. A payload projection alone proves no tag. Ring projections are excluded [RANGE-1].

Explicit instantiation is `use fact(index);` in binder order, without `times`: after copying `targets^[i]` to t, a local `invariant bounded: t < 4_u64 { use valid(i); }` can use `forall valid(j in 0_u64..4_u64): targets^[j] < 4_u64;`. Use range-postcondition `P unchanged` to preserve untouched elements across a writer without equality capability [RANGE-4].

Silent failure and check: length-only guarantees cannot restore contents killed by a helper write. Audit preservation/tag conditions. `--check` proves quantified entry/backedge/return obligations. Range clauses cannot be stated in `fn_sig` contracts, including interface members [RANGE-1].

### Is the relation part of every valid value of a type?

Declare a type invariant when a struct is valid only while its fields satisfy a relation. Reason: each constructor and function boundary then owes that relation, so clients do not have to repeat it on every API [TYPE-11].

```whitefoot
struct Table {
  slots: Slots<u64, 8>;
  next: u64;
  invariant cursor(table): table.next < table.slots.len;
}

fn advance(t: &Table) -> result: u64 reads(t.slots), writes(t.next) {
  let at = t^.next;
  let got = t^.slots[at];
  let after = at + 1_u64;
  if after == t^.slots.len {
    set t^.next = 0_u64;
  } else {
    set t^.next = after;
  }
  return got;
}
```

Affine type invariants require a nongeneric, nonopaque struct with private or `public readonly` fields and an admitted binder field/measure relation. Construction, parameter entry, written-reference exits (including propagation), results and calls carry their obligations. Temporary internal violations must be restored before a boundary [TYPE-11].

`public readonly` restricts outside modules only; internally it is an ordinary field. Range type invariants use the admitted binder/forall form for contents relations true of every valid value [TYPE-11, RANGE-1].

Silent failure and check: an invariant imposes obligations on all constructors, callers and error exits; use it for genuine validity. `--check` verifies boundaries; TYPE-11 construction failure is static. Generic/opaque affine invariants are a language restriction. A direct generic instance at this struct receives its invariant at a parameter/result boundary; a stored element does not automatically carry it. A container can therefore fail when it extracts or compares that element. Treat a required unsupported container use as a language/checker gap [TYPE-11].

### What can a generic body assume, and how is behavior supplied?

Choose the minimum capability the body uses; supply compile-time behavior through a raw function parameter or an `interface`/`binding`. Reason: capabilities authorize copy/drop/operations, while explicit function bindings authorize behavior and specialize to ordinary direct calls [FN-2, FN-3, FN-5, PROV-6].

```whitefoot
fn forward<T>(value: T) -> result: T pure {
  return move value;
}

fn discard<T: drop>(value: T) -> result: unit pure {
  return unit;
}

fn duplicate<T: copy>(value: T) -> (left: T, right: T) pure {
  return value, value;
}

interface Identity<T> {
  fn same(value: T) -> result: T pure;
}

fn same_u8(value: u8) -> result: u8 pure {
  return value;
}

binding ByteIdentity : Identity<u8> {
  same = same_u8;
}

fn apply<interface Identity<T>>(value: T) -> result: T pure {
  return Identity<T>::same(value: move value);
}

fn relay<interface Identity<T>>(value: T) -> result: T pure {
  return apply::<Identity<T>>(value: move value);
}

fn raw<T, fn pass(value: T) -> result: T pure>(value: T) -> result: T pure {
  return pass(value: move value);
}

fn example() -> result: u8 pure {
  let grouped = relay::<ByteIdentity>(value: 9_u8);
  return raw::<u8, fn same_u8>(value: grouped);
}
```

`<T>` grants no capability; `<T: drop>` permits derived release; `<T: copy>` permits repeated bare use. `Int`/`Float` authorize numeric domains and imply copy; `Eq` authorizes equality and implies copy. Each parameter has at most one bound; interface behavior occupies separate argument positions.

The template decides move spelling: unconstrained/drop T consumes with `move` even for copy instantiations. Arguments are explicit and references cannot be type arguments. Monomorphization rechecks concrete instances; recursive cycles forward each argument unchanged in its position or use closed terms [FN-2, FN-6].

Interfaces order signatures; bindings supply all members in order. Introduce `interface Identity<T>`, forward `Identity<T>`, instantiate `ByteIdentity`. Raw fn arguments name fully instantiated ordinary functions/parameters. They capture no environment: pass one explicitly. Runtime choice uses enum/match [FN-3, FN-5].

Binding modes/types must match; actual effects may be a subset, requirements weaker and ensures stronger under the finite refinement checker. Waiting actuals need waiting formals. Calls use formal labels/boundaries. Binding proves no algebraic or hash/equality law [FN-4].

Silent cost and check: monomorphization can multiply code/build work despite direct calls. Inspect combinations and output size; `--report` reports build/graph phase reuse, not proof or speed. `--check` verifies capabilities, refinement and instances. Runtime capture/quantified callback contracts/unexpressed algebraic laws are interface gaps.

### Which data should be immutable tables?

Use `const` for lookup tables, fixed messages and fixed records; borrow the needed range instead of creating a mutable array and filling it at startup. A const is program-lifetime read-only storage with no allocation or release [CONST-2].

```whitefoot
const digits: Array<u8, 4> =['0'_u8, '1'_u8, '2'_u8, '3'_u8];

const usage: Array<u8, 12> = "usage: tool\n";

fn digit(index: u64) -> result: u8 pure contract {
  requires index < 4_u64;
} {
  return digits[index];
}

fn message() -> count: u64 pure {
  let bytes = &usage[0_u64..12_u64];
  return bytes^.len;
}
```

A static value may contain primitives, fixed `Array` values and non-opaque source structs whose fields are const-eligible. It cannot contain an enum, `Box`, `Slots`, `Ring` or runtime-capacity array. Dependencies between consts must be acyclic. A struct const uses its ordinary field labels and declaration order; for example, a `Dimensions` with `width: u64` and `height: u64` takes
`Dimensions(width: 3_u64, height: 2_u64)` as its const initializer.

Text has exactly its UTF-8 byte length, with no implicit trailing zero. A STRING is a const initializer, not a runtime string expression. Use `\n`, `\t`, `\r` and canonical `\u{...}` escapes where required [FORM-5, FORM-7]. The compiler reports the actual byte length when `Array<u8, N>` disagrees.

**Cost and check.** A bare use of a copy array copies its value; `&table` or a range borrows it. Choosing `const` does not remove index bounds obligations. Check the program with `--check`, and test every table boundary and every externally required byte sequence against the format being implemented. When a large table appears in a stack frame, inspect value passing and `--stack-ledger`;
static storage itself is not a per-call local array.

### Which module owns this boundary, and where do I find its API?

Read `module.wfm` before calling across a module boundary: acceptance depends on the interface [MOD-8].

The distributed library inventory is `lib/std/modules.wfg`; declarations are at `lib/std/<module>/module.wfm`. Inside those files `pkg` names the library itself: an interface's `pkg::io::IoError` is `std::io::IoError` in your program [MOD-10]. Bundles name std modules directly; module programs list direct dependencies. Aliases are record-local and grant no dependency edge [MOD-4, MOD-5].

Read ownership capabilities, ordered parameters, effects, `waits`, contracts and `doc`. `opaque` denies ordinary construction and destructuring; accessible fields can remain visible. References retain caller ownership. `pure waits` is possible: effects describe reference-parameter changes; `waits` describes suspension [WAIT-1]. The result type alone does not state transfer completeness.

Each registered module contains `module.wfm` and direct `.wf` files; registration includes no children. Dependencies precede clients. Named entries select public ordinary nongeneric functions [MOD-1, MOD-2, MOD-9]. This complete module program has three records:

`modules.wfg`:
```text
pkg::client: [std::process];

entry main = pkg::client::main;
```

`client/module.wfm`:
```text
alias ExitStatus = std::process::ExitStatus;

public fn main() -> status: ExitStatus pure doc "Returns a successful invocation status.";
```

`client/main.wf`:
```text
alias ExitStatus = std::process::ExitStatus;

fn main() -> status: ExitStatus pure {
  return std::process::exit_status(code: 0_u8);
}
```

Repeat the public function's complete signature and contract in its definition, without `public`; other declarations in `module.wfm` are their definitions [MOD-7]. Public boundaries expose only client-accessible names and fields [MOD-6].

**Failure and check:** list directly used dependencies even if already transitive. Private fields remain inaccessible in bodies, effects and contracts. Current compiler: `whitefootc --graph modules.wfg --check-modules --report` checks modules and entries. `whitefootc --graph modules.wfg --check-interface pkg::client` checks only the interface; composition still requires definitions. `--report` supports graph checks/builds, not bundle-only `--check`.

### What does startup own, and what must be closed?

Accept and destructure `Inputs` for host capabilities: startup is an ordinary call with ordinary ownership [PROG-3].

`Inputs` is optional: a computation-only entry may take another admitted signature. The heap is ambient.

Consume both linear cwd halves. Streams/factory are affine capabilities without close APIs; files, directories and directory-listing sources are `nodrop` with explicit close functions [PRE-2, PROV-6].
```whitefoot
alias ExitStatus = std::process::ExitStatus;
alias Inputs = std::process::Inputs;

fn main(inputs: Inputs) -> status: ExitStatus pure waits {
  let Inputs(args: unused_args, drivers: unused_drivers, cwd: cwd_directory, stdout: unused_stdout, stderr: unused_stderr, handles: factory, stdin: unused_stdin, clock: unused_clock, wall_clock: unused_wall_clock, stops: unused_stops, memory_meter: unused_memory_meter) = move inputs;
  let std::fs::Directory(read: cwd, write: cwd_write) = move cwd_directory;
  let write_closed = std::fs::close_directory_write(factory: &factory, directory: move cwd_write);
  let read_closed = std::fs::close_directory(factory: &factory, directory: move cwd);
  let code = 0_u8;
  match write_closed {
    Ok(value: unused_write_closed) => {
    }
    Err(error: unused_write_error) => {
      set code = 1_u8;
    }
  }
  match read_closed {
    Ok(value: unused_read_closed) => {
    }
    Err(error: unused_read_error) => {
      set code = 1_u8;
    }
  }
  return std::process::exit_status(code: code);
}
```

Both closes run before either result is interpreted; returning on the first error would still owe the other handle. Close consumes its argument even on error.

**Failure and check:** acceptance catches unconsumed linear owners, including exits through `propagate`, but an ignored drop-capable close result can silently report success. Test acquisition, operation and close failure paths. Shared factories draw on one handle budget [PRE-2]. Read `waits` from the declaration: `cancel_source` and `close_cancel_watch` do not wait.

### How do I transfer bytes without losing a short read or write?

Pass a reference to initialized buffer storage, and track the endpoint returned by each host call. One host transfer may cover only part of the requested range, so successful transfer is not a whole-buffer guarantee [PRE-2].

`read_next` uses `Result<u64, ReadStop>`: `ReadEnd` is normal end of input; `ReadFailed(error)` carries an `IoError`. `write_once` uses `Result<u64, IoError>`. The byte count is `next - start`, not `next`. A read requires initialized destination elements, not merely capacity.

These helpers borrow streams and the factory.
```whitefoot
alias HandleFactory = std::io::HandleFactory;
alias InputStream = std::io::InputStream;
alias IoError = std::io::IoError;
alias OutputStream = std::io::OutputStream;
alias ReadStop = std::io::ReadStop;

fn publish_all(factory: &HandleFactory, output: &OutputStream, source: &[u8], length: u64) -> result: Result<unit, IoError> reads(source), writes(factory), writes(output) waits contract {
  define source_length = source^.len;
  requires length <= source_length;
} {
  let sent = 0_u64;
  loop @publish {
    let pending = sent < length;
    if pending {
    } else {
      break @publish;
    }
    let no_deadline = None<std::time::Instant>();
    let cancel = std::time::cancel_never();
    let outcome = std::io::write_once(factory: factory, output: output, source: source, start: sent, end: length, deadline: no_deadline, cancel: &cancel);
    std::time::close_cancel_watch(watch: move cancel);
    match outcome {
      Ok(value: next) => {
        set sent = next;
      }
      Err(error: problem) => {
        return Err<unit, IoError>(error: problem);
      }
    }
  }
  return Ok<unit, IoError>(value: unit);
}

fn read_chunk(factory: &HandleFactory, input: &InputStream, destination: &[u8]) -> result: Result<u64, ReadStop> writes(factory), writes(input), writes(destination) waits contract {
  ensures when Ok(value: next): next <= destination^.len;
} {
  let end = destination^.len;
  let no_deadline = None<std::time::Instant>();
  let cancel = std::time::cancel_never();
  let outcome = std::io::read_next(factory: factory, input: input, destination: destination, start: 0_u64, end: end, deadline: no_deadline, cancel: &cancel);
  std::time::close_cancel_watch(watch: move cancel);
  match outcome {
    Ok(value: next) => {
      return Ok<u64, ReadStop>(value: next);
    }
    Err(error: stop) => {
      match stop {
        ReadEnd() => {
          let ended = ReadStop::ReadEnd();
          return Err<u64, ReadStop>(error: ended);
        }
        ReadFailed(error: problem) => {
          let failed = ReadStop::ReadFailed(error: problem);
          return Err<u64, ReadStop>(error: failed);
        }
      }
    }
  }
}
```

Publish only the successful prefix, then repeat until `ReadEnd` to process all input. The untouched suffix holds old data.

`None<Instant>()` plus `cancel_never()` permits an unbounded wait. Deadline/cancellation errors transfer no bytes; an already produced host outcome wins. Read errors wrap them in `ReadFailed`. File-system calls have no deadline or cancel parameters [PRE-2].

**Failure and check:** one successful write can leave a suffix, and a short read leaves stale buffer content. Test empty ranges, nonzero starts, short transfers, EOF and errors after progress with byte-for-byte output checks. The checker proves bounds, not completeness or termination: `write_once` permits `next == start` in its contract. Inspect inline-buffer frame cost with `--stack-ledger`.

### How do file helpers preserve ownership on errors?

Choose whether a helper borrows a file or consumes it, and put cleanup outside any error propagation that would bypass it. A linear handle must be closed or returned on every path; a reference does not transfer that obligation [PRE-2, PROV-6].

`arg_get` in `lib/std/text/module.wfm` yields a `HostString`; `relative_path` consumes it into a `RelativePath` for `open_read` below a `DirectoryRead`. Byte-name APIs such as `open_file` and `open_append` require one direct child name, neither `.` nor `..` [PRE-2].

This file reader gives a close failure precedence over the read outcome.
```whitefoot
alias HandleFactory = std::io::HandleFactory;
alias ReadFile = std::fs::ReadFile;
alias ReadStop = std::io::ReadStop;

fn read_prefix(factory: &HandleFactory, file: ReadFile) -> result: Result<u64, ReadStop> writes(factory) waits {
  let bytes = array_filled::<u8, 64>(value: 0_u8);
  let window = &bytes[0_u64..64_u64];
  let outcome = std::fs::read_at(factory: factory, file: &file, destination: window, file_offset: 0_u64, start: 0_u64, end: 64_u64);
  let closed = std::fs::close_read(factory: factory, file: move file);
  match closed {
    Ok(value: unused_closed) => {
    }
    Err(error: problem) => {
      let stop = ReadStop::ReadFailed(error: problem);
      return Err<u64, ReadStop>(error: stop);
    }
  }
  return outcome;
}
```

Advance `read_at`'s file offset by the byte count independently of the buffer endpoint. Repeat `append_once` like `write_once` for a whole range. Renaming or removing the name leaves an open file usable [PRE-2].

**Failure and check:** append success does not mean durability. `sync_file` and `sync_directory` hand changes to the host durability mechanism; survival of host failure is outside the guarantee [PRE-2, SCOPE-3]. Test short transfers, exact offsets and cleanup on every outcome, including simultaneous operation/close errors.

### How should an interpreter dispatch each operation?

Use a loop whose header ends in one exhaustive `match` over the current operation, and make every looping arm finish with `continue`. This keeps each state transition and its next-header proof visible to the checker and the dispatcher [INV-1].
```whitefoot
enum Op {
  Add(k: u64);
  Halt();
}

fn run(code: &Box<Slots<Op>>) -> result: u64 reads(code) {
  let n = code^.inner.len;
  if n == 0_u64 {
    return 0_u64;
  }
  let pc = 0_u64;
  let acc = 0_u64;
  loop (
    invariant inb: pc < n
  ) {
    match code^.inner[pc] {
      Add(k: value) => {
        let next = pc + 1_u64;
        if next < n {
          set acc = acc +wrap value^;
          set pc = next;
          continue;
        } else {
          return 0_u64;
        }
      }
      Halt() => {
        return acc;
      }
    }
  }
}
```

Each `continue` proves `pc < n` again. Guard a decoded jump target unless a verified boundary proves its bounds. This reference match binds payload references, hence `value^`; use wrapping arithmetic only when the interpreted machine wraps.

**Cost and check:** Current compiler: eligible dispatch loops split into one function per arm with guaranteed tail transfers and no source `musttail`. Excess register demand or unsupported control flow keeps the loop whole. Inspect `whitefootc --dispatch-ledger program.wf` for the decision and `--stack-ledger` for frame/growth costs. Keep carried state compact. Invariants prove safety, not eventual `Halt` or instruction semantics; test results against the interpreted instruction specification.

Use `return musttail` for a direct self call whose stack must remain bounded [FN-10]. Reference arguments must descend from reference parameters, not owned locals or owned parameters whose activation disappears. Unreferenced affine locals are released before transfer; a live reference into a local with nonempty release prevents it. Current compiler also optimizes eligible unmarked self calls; the marker requires a compile-time error if the transfer cannot be guaranteed. It adds no termination proof.
```whitefoot
fn countdown(n: u64) -> result: u64 pure {
  if n == 0_u64 {
    return 0_u64;
  }
  let next = n - 1_u64;
  return musttail countdown(n: next);
}
```

**Check:** inspect `--stack-ledger` for recursive growth; `musttail` preserves the ordinary call's ownership and proof obligations.

### What evidence says the chosen design works?

Check source obligations and generated code separately; neither substitutes for output tests. Keep compiler, interfaces and specification at one revision. Run these commands in CI with the actual source, graph and entry.

| Question | Current compiler: evidence |
|---|---|
| Source acceptance | `whitefootc --check program.wf`; add `--diagnostic-format json` for structured diagnostics. |
| All module bodies and entries | `whitefootc --graph modules.wfg --check-modules --report`. |
| Machine frames and recursive cycles | `whitefootc --stack-ledger program.wf -o program`. |
| Interpreter arm splitting | `whitefootc --dispatch-ledger program.wf -o program`. |
| Build phases and cache reuse | `whitefootc --report program.wf -o program`. For a module build use `--graph modules.wfg --entry main` instead of the source path. |
| Owned heap versus residency | Read `lib/std/process/module.wfm`: `heap_in_use` and `resident_bytes` measure different quantities. |

The stack ledger is target/build-specific and includes machine spills. An inlined callee has no separate row. Displayed recursive levels divide stack size by per-level cost; other frames and runtime code still need space, and linked runtime translation units are outside the ledger. It is not a proof of maximum input depth. A source-only `--check` supplies no machine frames.

`--report` measures compilation, not runtime memory, speed or proof traces. `--report --check program.wf` is refused for a source bundle. Source rejection, compiler capability limits, target/build failure and denied optimization are distinct outcomes [DIAG-1, DIAG-2, STOR-6].

## Part 3. Designing a concurrent program

### Which work needs its own context?

Spawn activities that must run while others wait; split by ownership and lifetime. Use `--par` for independent computation that preserves the source-order result [WAIT-2, PAR-1, PAR-2].

A waiting call pauses its caller; `spawn` lets it continue. The callee must be declared `waits` and take only value parameters. Move resources and separate shared handles into it [WAIT-1, WAIT-3]. Contexts are not core or thread assignments.

```whitefoot
alias ExitStatus = std::process::ExitStatus;

fn bump(counter: Shared<u64>) -> result: unit pure waits {
  atomic count = &counter {
    set count^ = count^ +wrap 1_u64;
  }
  return unit;
}

fn launch(counter: &Shared<u64>) -> result: unit reads(counter) waits {
  for (index in 0_u64..2_u64) {
    let handle = shared_share::<u64>(shared: counter);
    spawn bump(counter: move handle);
  }
  return unit;
}

fn main() -> status: ExitStatus pure waits {
  let counter = shared_new::<u64>(value: 0_u64);
  launch(counter: &counter);
  let seen = 0_u64;
  atomic count = &counter {
    set seen = count^;
  }
  if seen != 2_u64 {
    return std::process::exit_status(code: 1_u8);
  }
  return std::process::exit_status(code: 0_u8);
}
```

The expression-statement spawns join when `launch` exits, after both children start. A bound spawn delivers its result directly at its implicit join; no shared result slot is needed solely to cross a context boundary.

**Silent failure:** an ordinary connection-handler call serializes acceptance; unlimited spawns can exhaust retained buffers and handles. `pure waits` can mutate shared state: target-state paths are excluded from atomic statements’ ordinary effect footprints [SHARE-2].

**Check:** locate an actual `spawn` for every activity that must overlap a wait. Waiting calls have no PAR permission: `--par-ledger` cannot demonstrate concurrent I/O.

### Where should shared state split?

Keep request-local data owned by its context. Partition mutable shared state by what must change together. Use `Frozen<T>` for retained immutable values and `SharedRead<T>` to grant only read authority [SHARE-1].

`SharedRead` requires atomic access; `Frozen.inner` does not. Shared state lives until its last handle is gone and no atomic statement on it is executing.

**Current compiler:** an ordinary shared object is one lock unit. Maps also admit entry and key-set holds: use them for known keys. Use a whole-map target for whole-map operations or keys computed inside the block [SHARE-2].

```whitefoot
alias ExitStatus = std::process::ExitStatus;

fn main() -> status: ExitStatus pure waits {
  let map = shared_map_new::<u8>(capacity: 8_u64);
  let key = array_filled::<u8, 1>(value: 97_u8);
  let bytes = &key[0_u64..1_u64];
  atomic slot = &map[bytes] {
    set slot^ = Some<u8>(value: 7_u8);
  }
  let got = 0_u8;
  atomic slot = &map[bytes] {
    match slot^ {
      Some(value: stored) => {
        set got = stored^;
      }
      None() => {
      }
    }
  }
  if got != 7_u8 {
    return std::process::exit_status(code: 1_u8);
  }
  return std::process::exit_status(code: 0_u8);
}
```

For known keys, put their entry targets or a `KeySet` target in one statement. A key-set binding is an `&Entries<V>` indexed in key-set order. A whole-map target holds the map even when a helper accesses just one entry.

**Silent failure:** adding one global counter to every request can serialize otherwise independent keys. When every context updates the same `Shared<u64>`, total throughput falls as contexts are added, instead of rising; giving each context its own object restores scaling. Nothing in the compiler reports this; measure with the counter and without it.

`Shards<T>` is **not yet available** in this release. For a final aggregate, keep counts local and return them from bound spawns, then combine them after joining. If independently observed partitions fit the requirement, use separate `Shared<T>` objects. For one exact shared observation, retain the transaction and measure it; delayed aggregation changes the requirement. Report a missing
facility if required semantics and throughput cannot both be met.

**Check:** list the shared objects each hot operation reaches through direct accesses and helpers. Distinguish entry and whole-map holds; compare throughput across context counts in CI.

### What must take effect together?

Put a transition that observers must never see halfway through in one atomic statement. Its target-state reads and writes take effect at one point; consecutive statements have separate points and can interleave [SHARE-3].

Here taking an item and accounting for it are one transition. The guard proves that `take_front` has an item.

```whitefoot
alias ExitStatus = std::process::ExitStatus;

fn take_and_count(queue: Shared<Ring<u64, 8>>, total: Shared<u64>) -> result: u64 pure waits {
  let got = 0_u64;
  atomic items = &queue, sum = &total when items^.len > 0_u64 {
    set got = take_front(window: items);
    set sum^ = sum^ +wrap got;
  }
  return got;
}

fn main() -> status: ExitStatus pure waits {
  let initial = ring_new::<u64, 8>();
  place_back(window: &initial, value: 9_u64);
  let queue = shared_new::<Ring<u64, 8>>(value: move initial);
  let total = shared_new::<u64>(value: 0_u64);
  let consumed = shared_share::<Ring<u64, 8>>(shared: &queue);
  let counted = shared_share::<u64>(shared: &total);
  let got = take_and_count(queue: move consumed, total: move counted);
  let left = 1_u64;
  let sum = 0_u64;
  atomic items = &queue, count = &total {
    set left = items^.len;
    set sum = count^;
  }
  if got != 9_u64 {
    return std::process::exit_status(code: 1_u8);
  }
  if left != 0_u64 {
    return std::process::exit_status(code: 2_u8);
  }
  if sum != 9_u64 {
    return std::process::exit_status(code: 3_u8);
  }
  return std::process::exit_status(code: 0_u8);
}
```

An observer comparing queue state with its total must read both in one statement too. The total deliberately uses modulo arithmetic.

Prepare independent inputs first; validate current state and apply the transition inside. Copy or move results to locals: atomic bindings, their references and shared-state facts end with the block [REF-2, SHARE-2]. Receive before and send afterward. The guard and block cannot wait or contain nested atomic statements [SHARE-2].

**Silent failure:** separate atomic reads and writes can lose intervening updates. Splitting removal from accounting can expose an impossible state even though every access is race-free.

**Check:** enumerate what another statement can observe between your atomic statements, including error exits. The checker cannot choose the application's transaction boundary.

### How do I lock an object only on paths that use it?

Keep all uses of conditional metadata inside its condition, while retaining all targets needed for the transition in one atomic statement. Header order does not set lock order.

**Current compiler:** first use of a state-type group acquires it and all earlier untaken groups until block end. [SHARE-3] permits this policy without requiring its acquisition points in every implementation.

Before: metadata is read before the branch, so writes with neither logging nor timing acquire it.

```whitefoot
alias ExitStatus = std::process::ExitStatus;

struct Entry {
  value: u8;
}

struct Meta {
  commit_sequence: u64;
  commits: u64;
}

fn put(keys: Shared<ConcurrentHashMap<Entry>>, meta: Shared<Meta>, record: Entry, logged: Bool, timed: Bool) -> result: unit pure waits {
  let key_bytes = array_filled::<u8, 1>(value: 97_u8);
  let key = &key_bytes[0_u64..1_u64];
  let tracked = bor(logged, timed);
  atomic slot = &keys[key], m = &meta {
    let previous = m^.commit_sequence;
    set slot^ = Some<Entry>(value: record);
    if tracked {
      let next = previous +wrap 1_u64;
      set m^.commit_sequence = next;
      set m^.commits = m^.commits +wrap 1_u64;
    }
  }
  return unit;
}

fn main() -> status: ExitStatus pure waits {
  let keys = shared_map_new::<Entry>(capacity: 8_u64);
  let initial = Meta(commit_sequence: 0_u64, commits: 0_u64);
  let meta = shared_new::<Meta>(value: initial);
  let record = Entry(value: 7_u8);
  let off = False();
  put(keys: move keys, meta: move meta, record: record, logged: off, timed: off);
  return std::process::exit_status(code: 0_u8);
}
```

After: move the read under `if tracked`. The map group precedes `Meta`, so the false path avoids `meta` while all changes remain one transition.

```whitefoot
alias ExitStatus = std::process::ExitStatus;

struct Entry {
  value: u8;
}

struct Meta {
  commit_sequence: u64;
  commits: u64;
}

fn put(keys: Shared<ConcurrentHashMap<Entry>>, meta: Shared<Meta>, record: Entry, logged: Bool, timed: Bool) -> result: unit pure waits {
  let key_bytes = array_filled::<u8, 1>(value: 97_u8);
  let key = &key_bytes[0_u64..1_u64];
  let tracked = bor(logged, timed);
  atomic slot = &keys[key], m = &meta {
    set slot^ = Some<Entry>(value: record);
    if tracked {
      let next = m^.commit_sequence +wrap 1_u64;
      set m^.commit_sequence = next;
      set m^.commits = m^.commits +wrap 1_u64;
    }
  }
  return unit;
}

fn main() -> status: ExitStatus pure waits {
  let keys = shared_map_new::<Entry>(capacity: 8_u64);
  let initial = Meta(commit_sequence: 0_u64, commits: 0_u64);
  let meta = shared_new::<Meta>(value: initial);
  let record = Entry(value: 7_u8);
  let off = False();
  put(keys: move keys, meta: move meta, record: record, logged: off, timed: off);
  return std::process::exit_status(code: 0_u8);
}
```

The four limits of this compiler policy are:

1. **One type is one group.** Using any target of a type takes every target of that type, including targets used only on other paths.
2. **Later groups take earlier groups along.** Primitive types come first, then prelude nominal types such as `ConcurrentHashMap<Entry>`, then source and host-module nominal types ordered by module path and name, with type arguments breaking ties. Using a later group acquires every earlier group not yet taken, even when the path does not use it.
3. **Entries, key sets and guard reads acquire early.** Their groups acquire before the guard, with all earlier untaken groups. Moving a block use into a branch does not defer them. A guard that reads **no target** acquires **every group** before evaluation. Omit an unnecessary guard; when the program needs a guard, retain its meaning and inspect what it reads.
4. **A primitive counter beside a map is already early.** A `Shared<u64>` counter acquires with the entry even if its use is conditional. A separate source struct such as `Meta` orders after the map and can remain untaken on the path that does not use it.

**Silent failure:** a statistics read before the branch, a helper that reads metadata, or a target-free `when tracked` can make an optional object a lock on every request. Finishing with an object early does not release it early.

**Check:** compile with `whitefootc --lock-ledger main.wf -o main`. It prints one line per target group of every atomic statement:

```text
LOCK <function>  <file:line:col of the atomic>  targets(<names>): <state type>  <when>[; first use <sites>][; taken with targets(<names>) at <site>]
```

`<when>` is `before the guard`, `on every path`, `on some paths` or `never`. An object you meant to take only on some requests must read `on some paths`; `on every path` or `before the guard` means a use, a helper's footprint, a guard or a later-ordered group takes it on every execution, and `taken with` names the later group whose first use pulled it in. Result checks establish state
transitions, not lock timing, and `--par-ledger` is not a substitute.

### Where must children finish, and what lets them finish?

Mark every implicit join before arranging control flow. Put an action that enables a child before the statement that joins it [WAIT-3].

A bound spawn joins before the first later statement **in its binding’s block** that names the binding **or contains an edge leaving that block**, otherwise at block end. An expression-statement spawn joins when its activation leaves by any edge. Bound results cannot be polled. A bound spawn inside a for-body joins no later than that iteration’s end. Launch dependent producers and consumers with expression-statement spawns in one synchronous helper before it returns. Separate synchronous launchers may join producers before consumers start. Counted launch loops remain valid: expression-statement spawns join at activation exit, not iteration end. Observe final results after the shared helper returns. [WAIT-3]

```whitefoot
alias ExitStatus = std::process::ExitStatus;

fn consume(cell: Shared<u8>) -> result: u8 pure waits {
  let seen = 0_u8;
  atomic value = &cell when value^ >= 6_u8 {
    set seen = value^;
  }
  return seen;
}

fn main() -> status: ExitStatus pure waits {
  let cell = shared_new::<u8>(value: 0_u8);
  let watched = shared_share::<u8>(shared: &cell);
  let seen = spawn consume(cell: move watched);
  atomic value = &cell {
    set value^ = 6_u8;
  }
  if seen != 6_u8 {
    return std::process::exit_status(code: 1_u8);
  }
  return std::process::exit_status(code: 0_u8);
}
```

The enabling write runs before the `if`, which joins before evaluating its condition. If the write were inside an `if` containing a `return` from this block, the join would precede the whole `if` and the write could never run. A `propagate` error edge can similarly bring a join forward. To gather independent answers, place their bound spawns before the first statement that mentions
either result or can leave their block.

Use guards for state waits; identify a reachable producer for each false guard. [WAIT-2] gives conditional progress: contexts can still deadlock on false guards or each other.

**Silent failure:** coherent reads can observe intermediate results. A guarded publication flag can deliver data before cleanup finishes; join when child completion is required.

**Check:** draw the wait dependencies, including implicit joins before exit-containing statements. In CI, exercise one-driver and multiple-driver execution and record `Inputs.drivers`, the actual count [PRE-2]. No ledger proves termination.

### Who owns I/O, and what does an I/O result mean?

Give each ordered stream one owner with local buffers. Both ordered host operations must reach that owner’s state; one context alone does not order unrelated handles [HOST-1]. Receive, change state, then send. Spawn transfers owned handles, not parent references [WAIT-3].

A successful send can be partial. This helper advances to the returned endpoint and carries the same deadline and cancellation watch across retries. Its `main` supplies an entry point; callers supply a live send handle.

```whitefoot
alias TcpSend = std::net::TcpSend;
alias IoError = std::io::IoError;
alias Instant = std::time::Instant;
alias CancelWatch = std::time::CancelWatch;
alias ExitStatus = std::process::ExitStatus;

fn send_all(send: &TcpSend, source: &[u8], length: u64, deadline: Option<Instant>, cancel: &CancelWatch) -> result: Result<unit, IoError> reads(source), reads(cancel), writes(send) waits contract {
  requires length <= source^.len;
} {
  let sent = 0_u64;
  loop @sending {
    if sent < length {
    } else {
      break @sending;
    }
    match std::net::send_once(send: send, source: source, start: sent, end: length, deadline: deadline, cancel: cancel) {
      Ok(value: next) => {
        set sent = next;
      }
      Err(error: problem) => {
        return Err<unit, IoError>(error: problem);
      }
    }
  }
  return Ok<unit, IoError>(value: unit);
}

fn main() -> status: ExitStatus pure {
  return std::process::exit_status(code: 0_u8);
}
```

`Cancelled` or `DeadlinePassed` transfers nothing **in that invocation** [PRE-2]. Earlier iterations may already have sent a prefix. This helper does not report that prefix on error, so do not restart it from zero unless the application protocol permits duplicate bytes. The `send_once` contract permits `next == start`; the loop alone proves neither eventual completion nor a bound on
return time.

**Silent failure:** treating one successful send as the whole response truncates it. Retrying a request after a failed response can repeat a state mutation: a send error does not undo the transaction that preceded it.

**Check:** follow handles to their explicit closes, inspect partial transfers and define the retry rule. The checker cannot decide whether a retry duplicates an application operation.

### How do cancellation and deadlines end every wait?

For shutdown, request stop, wake waits, clean up, then join. Guards cannot read clocks or other self-changing host handles. For state-or-time waiting, spawn a timer that fires a cancellation source; read its shared state in the guard [SHARE-2, PRE-2].

Make that timer cancellable too, so early readiness does not leave the parent joining a timer with a distant deadline.

```whitefoot
alias Instant = std::time::Instant;
alias CancelSource = std::time::CancelSource;
alias CancelWatch = std::time::CancelWatch;
alias Inputs = std::process::Inputs;
alias ExitStatus = std::process::ExitStatus;

fn timer(deadline: Instant, source: CancelSource, disarm: CancelWatch) -> result: unit pure waits {
  let outcome = std::time::sleep_until(deadline: deadline, cancel: &disarm);
  match outcome {
    Ok(value: slept) => {
      std::time::cancel_fire(source: &source);
    }
    Err(error: stopped) => {
    }
  }
  return unit;
}

fn wait_ready(work: Shared<Bool>, deadline: Instant) -> result: Bool pure waits {
  let source = std::time::cancel_source();
  let watch = std::time::cancel_watch(source: &source);
  let timeout = std::time::cancel_state(watch: &watch);
  let disarm_source = std::time::cancel_source();
  let disarm_watch = std::time::cancel_watch(source: &disarm_source);
  let finished = spawn timer(deadline: deadline, source: move source, disarm: move disarm_watch);
  let ready = False();
  atomic item = &work, expired = &timeout when bor(item^, expired^.fired) {
    set ready = item^;
  }
  std::time::cancel_fire(source: &disarm_source);
  let joined = finished;
  return ready;
}

fn main(inputs: Inputs) -> status: ExitStatus pure waits {
  let Inputs(args: unused_args, drivers: unused_drivers, cwd: cwd, stdout: unused_stdout, stderr: unused_stderr, handles: handles, stdin: unused_stdin, clock: clock, wall_clock: unused_wall_clock, stops: unused_stops, memory_meter: unused_memory_meter) = move inputs;
  let std::fs::Directory(read: directory, write: writable) = move cwd;
  std::fs::close_directory_write(factory: &handles, directory: move writable);
  std::fs::close_directory(factory: &handles, directory: move directory);
  let begin = std::time::now(clock: &clock);
  let deadline = std::time::instant_after(instant: begin, nanoseconds: 10000000_u64);
  let not_ready = False();
  let work = shared_new::<Bool>(value: not_ready);
  let ready = wait_ready(work: move work, deadline: deadline);
  if ready {
    return std::process::exit_status(code: 1_u8);
  }
  return std::process::exit_status(code: 0_u8);
}
```

The example chooses readiness when readiness and timeout are both observed. It waits for state or **timer notification**: the timer must run after sleep completion to publish timeout. It does not prove that readiness occurred before the clock deadline. Cancellation handles release their retained shared handles on leaving scope; dropping a source does not fire it.

For host I/O, pass a deadline directly. An already-produced host outcome wins over later cancellation or deadline expiry; a race between cancellation and deadline may choose either [PRE-2]. If one deadline bounds a whole request, carry that absolute deadline through successive waits instead of granting a fresh interval on every retry.

**Silent failure:** firing a source does not mean host calls returned, children joined or cleanup finished. A host cancellation watch does not interrupt arbitrary computation or an unrelated guarded wait. Filesystem calls have no deadline or cancellation parameters [PRE-2]. Joining a still-armed timer can delay a request that already has its answer.

**Check:** list every wait's normal wake condition and shutdown path. In CI, exercise work-first, timeout-first, already-cancelled and racing outcomes. Check resource cleanup after joining, not merely after observing `fired`.

### How do I expose computation to `--par`?

Write the correct source-order program first. Express independence through precise effects, disjoint storage and counted loops. A PAR permission allows parallel execution; it does not require it [PAR-1, PAR-2].

Adjacent statements may overlap when each one’s writes are disjoint from the other’s reads and writes, including arguments, moves and new bindings. Reads may overlap reads. Waiting calls, including atomic statements, never qualify.

```whitefoot
alias ExitStatus = std::process::ExitStatus;

fn folded(lo: u64, hi: u64) -> result: u64 pure {
  let total = 0_u64;
  for (i in lo..hi) {
    set total = total +wrap i;
  }
  return total;
}

fn main() -> status: ExitStatus pure {
  let a = folded(lo: 0_u64, hi: 8_u64);
  let b = folded(lo: 8_u64, hi: 16_u64);
  let total = a +wrap b;
  if total != 120_u64 {
    return std::process::exit_status(code: 1_u8);
  }
  return std::process::exit_status(code: 0_u8);
}
```

The calls are independent and the loop admits reduction; this tiny workload is not a speedup claim.

For an element map, keep iteration `i` within element `i` and its owned parts: fields, payloads, `Box` content and nested storage. A helper taking `&items^[i]` keeps that shape when its effect row stays within that argument. Alternatively partition an origin into proved-disjoint ranges. Reading a neighbor while writing the current element, or passing the whole mutable run beside the
element, can introduce interference and keep the loop sequential. Do not add an atomic accumulator per iteration to obtain parallel computation.

For a scalar reduction, keep at most one outer whole-binding accumulator and use it only in its admitted updates. The operations are integer `+wrap`, `*wrap`, `iand`, `ior`, `ixor`, `imin`, `imax`; unsigned `+sat`; and Boolean `band`, `bor`, `bxor`. Indexed accumulator families have their own restricted update and occurrence rules [PAR-2]. Ordinary exact addition, floating addition and
signed saturating addition are not interchangeable with the admitted operations. Never change numerical meaning to obtain permission.

#### What if each iteration writes an index read from storage?

For a scatter, put `apart(i, j) { }` last in the counted loop's header. It asks the checker to prove that different iterations touch disjoint elements [RANGE-5]. Supply the relationship that makes stored indices distinct; the certificate is not a runtime alias test.

This program builds a permutation and its left inverse, establishing range invariants that become the scatter's range requirement.

```whitefoot
fn scatter(order: &[u64], pos: &[u64], out: &[u64]) -> result: unit reads(order), writes(out) contract {
  requires pos^.len == out^.len;
  requires forall inv(k in 0_u64..order^.len) when order^[k] < out^.len: pos^[order^[k]] == k;
} {
  let count = order^.len;
  for (
    k in 0_u64..count,
    apart(i, j) {
    }
  ) {
    let e = order^[k];
    if e < out^.len {
      set out^[e] = k;
    }
  }
  return unit;
}

fn reversed(n: u64) -> result: u64 pure contract {
  requires n <= 1000_u64;
  requires n >= 1_u64;
} {
  let order = box_array_filled::<u64>(count: n, value: 0_u64);
  let pos = box_array_filled::<u64>(count: n, value: 0_u64);
  let out = box_array_filled::<u64>(count: n, value: 0_u64);
  let last = n - 1_u64;
  for (
    k in 0_u64..n,
    invariant forall vals(q in 0_u64..k): order.inner[q] == last - q,
    invariant forall inv(q in 0_u64..k): pos.inner[order.inner[q]] == q
  ) {
    let back = last - k;
    set order.inner[k] = back;
    set pos.inner[back] = k;
  }
  scatter(order: &order.inner[0_u64..n], pos: &pos.inner[0_u64..n], out: &out.inner[0_u64..n]);
  let first = out.inner[0_u64];
  return first;
}

fn main() -> status: std::process::ExitStatus pure {
  let got = reversed(n: 5_u64);
  if got != 4_u64 {
    return std::process::exit_status(code: 1_u8);
  }
  return std::process::exit_status(code: 0_u8);
}
```

A left inverse `pos[order[k]] == k` makes distinct iterations’ valid output indices distinct. Another useful relation makes each new index exceed all earlier ones. Establish these relations where the arrays are built. Builders can return range postconditions, including routed success postconditions; a struct whose writers preserve a relationship between its stores can carry it as a range
type invariant [RANGE-1, RANGE-3, TYPE-11]. Facts describe the storage versions over which they were proved and survive only the writes the rules permit.

An `apart` certificate that fails is a compile error naming the accesses it could not separate. A holding certificate still needs the loop's other PAR-2 conditions, including its exits and accumulator restrictions. Without such an explicit failed obligation, lack of parallel permission keeps otherwise accepted code sequential.

**Silent failure:** a broad effect row or a read of partially accumulated state can suppress permission without rejecting the program. Permission alone does not establish that the compiler emitted parallel work.

**Current compiler:** cost selection can omit an offer for permitted work that is too small. Inspect `omitted offer` messages rather than assuming adjacent independent calls run on different workers. A statement binding an ordered result list also has a PAR-1 planning limitation; retain the natural interface and report the compiler gap rather than replacing it with a record solely to
bypass that limitation.

**Check in CI:** use `--par-ledger` to inspect permission and refused conditions; use `--par --par-ledger` to inspect actualization, including omitted offers. Retain ledger expectations for critical loops. Check sequential and parallel results against an independent oracle, then measure speedup. Permission, emitted offers and performance are separate evidence.

### What must I check before accepting the design?

- Context ownership and admission bound retained resources.
- Shared objects and atomic boundaries preserve application invariants.
- Guards have reachable producers; enabling actions precede implicit joins.
- Lock order preserves conditional access, including through helpers.
- Publication, cancellation, cleanup and child completion remain distinct.
- Retry rules and deadline scope match the protocol.
- CI checks results, driver counts, cancellation races, PAR permissions and measured contention.
