package com.voidhome.app.ui

import android.content.ClipData
import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.voidhome.app.R
import com.voidhome.app.data.Repo
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

@Composable
fun VoidHeader(sub: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Text("VOID", fontSize = 44.sp, fontWeight = FontWeight.ExtraLight, letterSpacing = 6.sp, color = Color.White)
        Text(sub, color = P.muted, fontSize = 14.sp, textAlign = TextAlign.Center)
    }
}

@Composable
fun SignInScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    Column(Modifier.fillMaxSize().systemBarsPadding().padding(28.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        VoidHeader("Your home, shared with the people you live with.")
        Spacer(Modifier.height(48.dp))
        Button(
            enabled = !busy, modifier = Modifier.fillMaxWidth().height(52.dp),
            onClick = {
                busy = true; error = null
                scope.launch {
                    try {
                        val option = GetSignInWithGoogleOption.Builder(context.getString(R.string.default_web_client_id)).build()
                        val result = CredentialManager.create(context).getCredential(context, GetCredentialRequest.Builder().addCredentialOption(option).build())
                        val cred = result.credential
                        if (cred is CustomCredential && cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                            val token = GoogleIdTokenCredential.createFrom(cred.data).idToken
                            FirebaseAuth.getInstance().signInWithCredential(GoogleAuthProvider.getCredential(token, null)).await()
                        } else error = "That sign-in type isn't supported."
                    } catch (_: GetCredentialCancellationException) {
                    } catch (e: Exception) {
                        error = e.message ?: "Sign-in failed."
                    } finally { busy = false }
                }
            },
        ) { Icon(Icons.Filled.AccountCircle, null); Spacer(Modifier.width(10.dp)); Text(if (busy) "Signing in…" else "Sign in with Google") }
        error?.let { Spacer(Modifier.height(16.dp)); Text(it, color = P.billOverdue, textAlign = TextAlign.Center) }
    }
}

@Composable
fun HouseSetupScreen() {
    val scope = rememberCoroutineScope()
    var code by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("My Home") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    fun run(block: suspend () -> Unit) { busy = true; error = null; scope.launch { try { block() } catch (e: Exception) { error = e.message ?: "Something went wrong." } finally { busy = false } } }
    Column(Modifier.fillMaxSize().systemBarsPadding().padding(24.dp), verticalArrangement = Arrangement.Center) {
        VoidHeader("Signed in as ${Repo.user?.email ?: ""}")
        Spacer(Modifier.height(32.dp))
        Glass(tint = P.accent) {
            Text("Join a house", fontSize = 18.sp)
            Text("Ask the owner for the 6-character code in their Void Home.", color = P.muted, fontSize = 13.sp)
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(code, { code = it.uppercase().take(6) }, label = { Text("Invite code") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace, letterSpacing = 4.sp))
            Spacer(Modifier.height(10.dp))
            Button(onClick = { run { Repo.joinHouse(code) } }, enabled = !busy && code.length == 6, modifier = Modifier.fillMaxWidth()) { Text("Join") }
        }
        Spacer(Modifier.height(16.dp))
        Glass {
            Text("Or start your own house", fontSize = 18.sp)
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(name, { name = it }, label = { Text("House name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(10.dp))
            OutlinedButton(onClick = { run { Repo.createHouse(name.ifBlank { "My Home" }) } }, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Text("Create house") }
        }
        error?.let { Spacer(Modifier.height(12.dp)); Text(it, color = P.billOverdue) }
        Spacer(Modifier.height(20.dp))
        TextButton(onClick = { Repo.signOut() }, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text("Sign out") }
    }
}

@Composable
fun HouseSettingsScreen() {
    val h = Repo.house ?: return
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var error by remember { mutableStateOf<String?>(null) }
    var confirm by remember { mutableStateOf<Pair<String, suspend () -> Unit>?>(null) }
    var rename by remember { mutableStateOf(h.name) }
    fun run(block: suspend () -> Unit) { scope.launch { try { block(); error = null } catch (e: Exception) { error = e.message } } }
    Page("House", onBack = Nav::back) {
        item {
            Glass(tint = P.accent) {
                Text(h.name, fontSize = 22.sp, fontWeight = FontWeight.Light)
                Text(if (Repo.isOwner) "You own this house" else "Owner: ${Repo.memberName(h.ownerId)}", color = P.muted)
            }
        }
        item {
            SectionTitle("Invite code")
            Glass {
                Text(h.inviteCode.ifBlank { "No code" }, fontSize = 34.sp, fontFamily = FontFamily.Monospace, letterSpacing = 6.sp, modifier = Modifier.align(Alignment.CenterHorizontally))
                Text("Anyone with this code can join after signing in.", color = P.muted, fontSize = 13.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                    OutlinedButton(onClick = {
                        val cm = context.getSystemService(android.content.ClipboardManager::class.java)
                        cm.setPrimaryClip(ClipData.newPlainText("Void Home code", h.inviteCode))
                    }) { Text("Copy") }
                    OutlinedButton(onClick = {
                        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain")
                            .putExtra(Intent.EXTRA_TEXT, "Join our house on Void Home with code ${h.inviteCode}"), "Share code"))
                    }) { Text("Share") }
                    if (Repo.isOwner) OutlinedButton(onClick = { confirm = "Make a new code? The old one stops working." to { Repo.newInviteCode() } }) { Text("New code") }
                }
            }
        }
        item { SectionTitle("Members (${h.members.size})") }
        items(h.members.size) { i ->
            val m = h.members[i]
            ItemRow(m.name + if (m.uid == Repo.uid) " (you)" else "", if (m.uid == h.ownerId) "Owner" else "Member", P.people, Icons.Filled.Person,
                trailing = if (Repo.isOwner && m.uid != Repo.uid) { {
                    Row {
                        TextButton(onClick = { confirm = "Make ${m.name} the owner?" to { Repo.handOver(m.uid) } }) { Text("Make owner") }
                        TextButton(onClick = { confirm = "Remove ${m.name} from the house?" to { Repo.removeMember(m.uid) } }) { Text("Remove", color = P.billOverdue) }
                    }
                } } else null)
        }
        item {
            SectionTitle("House name")
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(rename, { rename = it }, singleLine = true, modifier = Modifier.weight(1f))
                TextButton(onClick = { run { Repo.renameHouse(rename.trim()) } }, enabled = rename.isNotBlank() && rename != h.name) { Text("Save") }
            }
        }
        item {
            SectionTitle("Account")
            Text("Signed in as ${Repo.user?.email ?: ""}", color = P.muted)
            Spacer(Modifier.height(8.dp))
            if (!Repo.isOwner) OutlinedButton(onClick = { confirm = "Leave ${h.name}? Your Just me items stay saved but you won't see the house." to { Repo.leaveHouse() } }, modifier = Modifier.fillMaxWidth()) { Text("Leave house") }
            if (Repo.isOwner && h.members.size == 1) OutlinedButton(onClick = { confirm = "Close ${h.name}? This deletes the house and its invite code." to { Repo.closeHouse() } }, modifier = Modifier.fillMaxWidth()) { Text("Close house", color = P.billOverdue) }
            if (Repo.isOwner && h.members.size > 1) Text("To leave, make someone else the owner first.", color = P.faint, fontSize = 13.sp)
            Spacer(Modifier.height(8.dp))
            TextButton(onClick = { Repo.signOut() }) { Text("Sign out") }
            error?.let { Text(it, color = P.billOverdue) }
        }
    }
    confirm?.let { (msg, action) ->
        AlertDialog(onDismissRequest = { confirm = null }, text = { Text(msg) },
            confirmButton = { TextButton(onClick = { confirm = null; run(action) }) { Text("Yes") } },
            dismissButton = { TextButton(onClick = { confirm = null }) { Text("Cancel") } })
    }
}
