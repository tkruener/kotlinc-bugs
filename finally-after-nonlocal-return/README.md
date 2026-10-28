# JVM: a `finally` takes the wrong branch after a non-local exit from an inline function of another module

**Filed as [KT-90854](https://youtrack.jetbrains.com/issue/KT-90854)** (YouTrack, project KT).

**Backend:** JVM (K2, JVM IR) · **Reproduced with:** 2.4.0, 2.4.10, 2.4.20, 2.4.21 (latest stable), 2.5.0-Beta2 (latest
pre-release), 2.5.20-dev-2503 (dev build with the KT-90245 fix) · **Not affected:** the same code in one module; `-Xno-optimize` on the library

## Not a duplicate of KT-90245

[KT-90245](https://youtrack.jetbrains.com/issue/KT-90245) (code after a nested inline call in an inline function's
`finally` is skipped on non-local return) is in the same area, but it's a different bug: it needs a nested inline call
in the `finally` and happens in one module; this one needs no nested call and happens only across modules. Kotlin
**2.5.20-dev-2503**, which contains the KT-90245 fix (2.5.20-dev-1842), fixes KT-90245's sample
(`foo;bar;barFinally;afterBar;`) but **still** prints `begin end` here.

## Summary

An `inline` function whose `finally` branches on a local that its `try` assigns runs the wrong branch when a caller
compiled in **another module** leaves the lambda with a non-local `return` or `break`. The library module's bytecode
optimizer folds the branch in the normal-exit copy of the `finally`, where the local is known. The bytecode inliner
then copies that normal-exit copy (found between the `finallyStart`/`finallyEnd` markers) in front of the non-local
exit. In one module, the same code runs the right branch.

## Reproducer

`lib/Ui.kt` (module 1):

```kotlin
package lib

class Builder {
    var log = ""
    fun beginRoot() { log += "begin " }
    fun endRoot() { log += "end" }
    fun abortRoot() { log += "abort" }
}

inline fun ui(builder: Builder, content: Builder.() -> Unit) {
    builder.beginRoot()
    var described = false
    try {
        builder.content()
        described = true
    } finally {
        if (described) builder.endRoot() else builder.abortRoot()
    }
}
```

`app/Main.kt` (module 2):

```kotlin
import lib.*

fun system(b: Builder, quit: Boolean) { ui(b) { if (quit) return } }

fun main() {
    val b = Builder()
    system(b, true)
    println(b.log)   // expected "begin abort"
}
```

```sh
kotlinc lib/*.kt -d lib.jar
kotlinc -cp lib.jar app/Main.kt -d app.jar
kotlin -cp lib.jar:app.jar MainKt
```

**Expected:** `begin abort` (`described` is still `false` when the lambda returns). **Actual:** `begin end`.

`./reproduce.sh [VERSION ...]` downloads the official compiler release(s) and runs all cases:

```
kotlinc      case              two modules (default)    lib -Xno-optimize        one module
2.4.21       Main              begin end                begin abort              begin abort
2.4.21       MainBreak         begin end                begin abort              begin abort
2.4.21       MainNull          begin end                begin abort              begin abort
2.5.0-Beta2  Main              begin end                begin abort              begin abort
2.5.0-Beta2  MainBreak         begin end                begin abort              begin abort
2.5.0-Beta2  MainNull          begin end                begin abort              begin abort

Expected in every column: begin abort
```

| Case | File | What exits early |
|---|---|---|
| `Main` | `app/Main.kt` | non-local `return` from the lambda |
| `MainBreak` | `app/MainBreak.kt` | non-local `break` from the lambda (`for (i in 0 until 1) ui(b) { break }`) |
| `MainNull` | `lib/UiNull.kt`, `app/MainNull.kt` | the `finally` reads no assigned local, only a null fact: `try { content(); x!!.length } finally { if (x == null) abort() else end() }`, with `x == null` and a non-local `return` |

## Bytecode

`javap -c` on `lib.jar`'s `ui`:
- The normal-exit copy of the `finally` (between `InlineMarker.finallyStart(1)` and `finallyEnd(1)`) is just
  `endRoot()`. The `if` is folded away because `described = true` precedes it.
- The exceptional copy is just `abortRoot()`.

In `app.jar`, the code in front of the non-local `return` is the normal-exit copy, `endRoot()`.

## Impact

Silent wrong control flow on the JVM. It hits any library inline function that decides in its `finally` from a flag
set at the end of its `try`: a "commit or roll back" shape such as transactions, builders, or locks with a success
flag. It shows when a caller in another module returns or breaks out of the lambda.

## Suggested fix

Either don't run the constant-condition / dead-code passes over `finally` copies between the
`finallyStart`/`finallyEnd` markers of an inline function's bytecode. Or have the inliner copy a `finally` body that
was not specialised to one exit, for example the exceptional copy's code before folding.
