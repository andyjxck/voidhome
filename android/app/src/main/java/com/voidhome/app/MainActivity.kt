package com.voidhome.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.voidhome.app.data.Repo
import com.voidhome.app.data.T
import com.voidhome.app.ui.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Repo.init(applicationContext)
        setContent { VoidTheme { VoidBackground { Root() } } }
    }
}

@Composable
fun Root() {
    val user = Repo.user
    when {
        !Repo.userLoaded -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        user == null -> SignInScreen()
        Repo.houseId == null -> HouseSetupScreen()
        Repo.house == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        else -> AppShell()
    }
    Repo.lastError?.let { msg ->
        AlertDialog(onDismissRequest = { Repo.lastError = null }, confirmButton = { TextButton(onClick = { Repo.lastError = null }) { Text("OK") } }, text = { Text(msg) })
    }
}

@Composable
fun AppShell() {
    BackHandler(enabled = Nav.stack.size > 1) { Nav.back() }
    LaunchedEffect(Repo.houseId) { Nav.reset() }
    val d = Nav.top
    Box(Modifier.fillMaxSize().systemBarsPadding()) {
        key(Nav.stack.size, d) {
            when (d.kind) {
                "launcher" -> LauncherScreen()
                "home" -> HomeDashboard()
                "todo" -> TodoScreen()
                "bills" -> BillsScreen()
                "rooms" -> RoomsScreen(d.id)
                "timeline" -> TimelineScreen()
                "search" -> SearchScreen()
                "house" -> HouseSettingsScreen()
                "list" -> ListScreen(d.type ?: T.ASSET)
                "detail" -> DetailScreen(d.id ?: "")
                "edit" -> EditScreen(d.type ?: T.ASSET, d.id, d.prefill)
                "room" -> RoomPage(d.id ?: "")
                "roomEdit", "roomShape" -> RoomShapeEditor(d.id ?: "")
                else -> LauncherScreen()
            }
        }
        Repo.storageProblem?.let { msg ->
            Snackbar(Modifier.align(Alignment.BottomCenter).padding(12.dp), action = { TextButton(onClick = { Repo.storageProblem = null }) { Text("OK") } }, containerColor = Color(0xFF2A2140)) { Text(msg) }
        }
    }
}
