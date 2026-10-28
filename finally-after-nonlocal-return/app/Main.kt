import lib.*

fun system(b: Builder, quit: Boolean) { ui(b) { if (quit) return } }

fun main() {
    val b = Builder()
    system(b, true)
    println(b.log)   // expected "begin abort"
}
