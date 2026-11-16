package com.voidhome.app.ui

import androidx.compose.runtime.mutableStateListOf

/** One screen on the back stack. */
data class Dest(val kind: String, val id: String? = null, val type: String? = null, val prefill: Map<String, Any?> = emptyMap())

object Nav {
    val stack = mutableStateListOf(Dest("launcher"))
    val top get() = stack.last()
    fun go(d: Dest) { stack.add(d) }
    fun go(kind: String) = go(Dest(kind))
    fun open(id: String) = go(Dest("detail", id = id))
    fun edit(type: String, id: String? = null, prefill: Map<String, Any?> = emptyMap()) = go(Dest("edit", id = id, type = type, prefill = prefill))
    fun back() { if (stack.size > 1) stack.removeAt(stack.lastIndex) }
    fun reset() { stack.clear(); stack.add(Dest("launcher")) }
}
