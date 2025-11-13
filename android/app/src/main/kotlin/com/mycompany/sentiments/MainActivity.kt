package com.mycompany.sentiments

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_icon_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "changeIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    val currentAlias = call.argument<String>("currentAlias")
                    val aliases = call.argument<List<String>>("aliases")
                    
                    if (packageName != null && currentAlias != null && aliases != null) {
                        try {
                            changeAppIcon(packageName, currentAlias, aliases)
                            result.success("Icon changed successfully")
                        } catch (e: Exception) {
                            result.error("CHANGE_ICON_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun changeAppIcon(packageName: String, targetAlias: String, allAliases: List<String>) {
        val packageManager = packageManager
        
        try {
            android.util.Log.d("IconChange", "=== INICIANDO TROCA DE ÍCONE ===")
            android.util.Log.d("IconChange", "Target: $targetAlias")
            
            // Lista completa de TODOS os aliases (incluindo MainActivity para controle)
            val allPossibleAliases = listOf(
                "$packageName.MainActivity",
                "$packageName.MainActivityLogo2",
                "$packageName.MainActivityLogo3", 
                "$packageName.MainActivityLogo4"
            )
            
            android.util.Log.d("IconChange", "Aliases disponíveis: $allPossibleAliases")
            
            // PASSO 1: Desabilitar TODOS os aliases primeiro (exceto o target)
            for (alias in allPossibleAliases) {
                if (alias != targetAlias) {
                    try {
                        val component = ComponentName(this, alias)
                        packageManager.setComponentEnabledSetting(
                            component,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        android.util.Log.d("IconChange", "❌ DESABILITADO: $alias")
                    } catch (e: Exception) {
                        android.util.Log.w("IconChange", "Erro ao desabilitar $alias: ${e.message}")
                    }
                }
            }
            
            // PASSO 2: Esperar um momento para propagação
            Thread.sleep(100)
            
            // PASSO 3: Habilitar APENAS o target
            try {
                val targetComponent = ComponentName(this, targetAlias)
                packageManager.setComponentEnabledSetting(
                    targetComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                android.util.Log.d("IconChange", "✅ HABILITADO: $targetAlias")
            } catch (e: Exception) {
                android.util.Log.e("IconChange", "Erro ao habilitar $targetAlias: ${e.message}")
                throw e
            }
            
            // Try multiple methods to force launcher refresh
            try {
                // Method 1: Send broadcast to refresh launcher
                val refreshIntent = android.content.Intent("android.intent.action.MAIN")
                refreshIntent.addCategory("android.intent.category.LAUNCHER")
                sendBroadcast(refreshIntent)
                android.util.Log.d("IconChange", "📡 Broadcast sent")
                
                // Method 2: Query activities to trigger refresh
                val homeIntent = android.content.Intent(android.content.Intent.ACTION_MAIN)
                homeIntent.addCategory(android.content.Intent.CATEGORY_HOME)
                packageManager.queryIntentActivities(homeIntent, 0)
                android.util.Log.d("IconChange", "🔍 Home activities queried")
                
                // Method 3: Force package info refresh
                try {
                    packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
                    android.util.Log.d("IconChange", "📦 Package info refreshed")
                } catch (e: Exception) {
                    android.util.Log.w("IconChange", "Package info refresh failed: ${e.message}")
                }
                
                android.util.Log.d("IconChange", "🔄 All refresh methods attempted")
            } catch (e: Exception) {
                android.util.Log.w("IconChange", "Launcher refresh failed: ${e.message}")
            }
            
            android.util.Log.d("IconChange", "=== TROCA DE ÍCONE CONCLUÍDA COM SUCESSO! ===")
            android.util.Log.d("IconChange", "Ativo agora: $targetAlias")
            
        } catch (e: Exception) {
            android.util.Log.e("IconChange", "💥 Error changing icon: ${e.message}")
        }
    }
}
