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
