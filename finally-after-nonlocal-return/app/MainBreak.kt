import lib.*

// A non-local `break` out of the lambda: the `try` never finished, so `described` is still false.
fun loop(b: Builder) { for (i in 0 until 1) ui(b) { break } }

fun main() {
    val b = Builder()
    loop(b)
    println(b.log)   // expected "begin abort"
}
