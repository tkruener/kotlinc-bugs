import lib.*

// The lambda returns non-locally before `x!!` runs, and x is null.
fun systemNull(b: Builder, x: String?) { uiNull(b, x) { return } }

fun main() {
    val b = Builder()
    systemNull(b, null)
    println(b.log)   // expected "begin abort"
}
