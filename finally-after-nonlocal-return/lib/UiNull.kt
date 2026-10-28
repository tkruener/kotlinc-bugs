package lib

// The `finally` reads no local the `try` assigns, only a fact the `try` established: `x!!` makes x non-null.
inline fun uiNull(builder: Builder, x: String?, content: Builder.() -> Unit) {
    builder.beginRoot()
    try {
        builder.content()
        x!!.length
    } finally {
        if (x == null) builder.abortRoot() else builder.endRoot()
    }
}
