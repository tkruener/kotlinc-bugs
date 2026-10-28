# kotlinc bugs

Minimal, self-contained reproducers for Kotlin compiler bugs. Each directory has a README and a `reproduce.sh` that
downloads the official `kotlinc` release(s) and shows the wrong behaviour next to the expected one.

| Directory | Bug | Status |
|---|---|---|
| [`finally-after-nonlocal-return/`](finally-after-nonlocal-return/) | JVM: an inline function's `finally` takes the wrong branch after a non-local `return`/`break` from a caller in another module | reproduced on 2.4.0 – 2.4.21, 2.5.0-Beta2 and 2.5.20-dev-2503; filed as [KT-90854](https://youtrack.jetbrains.com/issue/KT-90854) |
