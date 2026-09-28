package com.example.clinical_assistant

import androidx.activity.result.ActivityResultLauncher
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.feature.ExperimentalPersonalHealthRecordApi
import androidx.health.connect.client.permission.HealthPermission.Companion.PERMISSION_READ_MEDICAL_DATA_LABORATORY_RESULTS
import androidx.health.connect.client.records.MedicalResource
import androidx.health.connect.client.request.ReadMedicalResourcesInitialRequest
import androidx.health.connect.client.request.ReadMedicalResourcesPageRequest
import androidx.health.connect.client.request.ReadMedicalResourcesRequest
import androidx.lifecycle.lifecycleScope
import java.io.File
import kotlinx.coroutines.launch

@OptIn(ExperimentalPersonalHealthRecordApi::class)
class MainActivity : FlutterFragmentActivity() {
    private lateinit var labPermissionLauncher: ActivityResultLauncher<Set<String>>
    private var pendingLabPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        labPermissionLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            pendingLabPermissionResult?.success(
                PERMISSION_READ_MEDICAL_DATA_LABORATORY_RESULTS in granted
            )
            pendingLabPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "clinical_assistant/local_data"
        ).setMethodCallHandler { call, result ->
            if (call.method != "vaultDirectory") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val directory = File(noBackupFilesDir, "clinical_assistant").apply {
                if (!exists() && !mkdirs()) {
                    result.error("vault_directory", "Could not create the local vault directory.", null)
                    return@setMethodCallHandler
                }
            }
            result.success(directory.absolutePath)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "clinical_assistant/health_connect_medical_records"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isMedicalRecordsAvailable" -> runMedicalRecordsCall(result) {
                    val client = healthConnectClientOrNull()
                    client != null && hasMedicalRecordsFeature(client)
                }
                "requestLabReadPermission" -> requestLabReadPermission(result)
                "readLabRecords" -> runMedicalRecordsCall(result) {
                    readLabRecords()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun runMedicalRecordsCall(
        result: MethodChannel.Result,
        operation: suspend () -> Any?
    ) {
        lifecycleScope.launch {
            try {
                result.success(operation())
            } catch (error: Exception) {
                result.error(
                    "health_connect_medical_records",
                    error.message ?: "Health Connect medical records could not be read.",
                    null
                )
            }
        }
    }

    private fun requestLabReadPermission(result: MethodChannel.Result) {
        lifecycleScope.launch {
            try {
                val client = healthConnectClientOrNull()
                if (client == null || !hasMedicalRecordsFeature(client)) {
                    result.success(false)
                    return@launch
                }

                val permission =
                    PERMISSION_READ_MEDICAL_DATA_LABORATORY_RESULTS
                if (permission in client.permissionController.getGrantedPermissions()) {
                    result.success(true)
                    return@launch
                }
                if (pendingLabPermissionResult != null) {
                    result.error(
                        "health_connect_medical_records",
                        "A laboratory permission request is already in progress.",
                        null
                    )
                    return@launch
                }
                pendingLabPermissionResult = result
                labPermissionLauncher.launch(setOf(permission))
            } catch (error: Exception) {
                result.error(
                    "health_connect_medical_records",
                    error.message ?: "Health Connect laboratory permission could not be checked.",
                    null
                )
            }
        }
    }

    private fun healthConnectClientOrNull(): HealthConnectClient? {
        if (
            HealthConnectClient.getSdkStatus(this) !=
                HealthConnectClient.SDK_AVAILABLE
        ) {
            return null
        }
        return HealthConnectClient.getOrCreate(this)
    }

    private fun hasMedicalRecordsFeature(client: HealthConnectClient): Boolean {
        return try {
            client.features.getFeatureStatus(
                HealthConnectFeatures.FEATURE_PERSONAL_HEALTH_RECORD
            ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        } catch (_: UnsupportedOperationException) {
            false
        }
    }

    private suspend fun readLabRecords(): List<Map<String, String>> {
        val client = healthConnectClientOrNull()
            ?.takeIf(::hasMedicalRecordsFeature)
            ?: throw IllegalStateException(
                "Health Connect Medical Records is unavailable on this device."
            )
        if (
            PERMISSION_READ_MEDICAL_DATA_LABORATORY_RESULTS !in
            client.permissionController.getGrantedPermissions()
        ) {
            throw SecurityException(
                "Health Connect laboratory access is not currently granted."
            )
        }

        val pageSize = 100
        val initialRequest: ReadMedicalResourcesRequest =
            ReadMedicalResourcesInitialRequest(
                MedicalResource.MEDICAL_RESOURCE_TYPE_LABORATORY_RESULTS,
                medicalDataSourceIds = emptySet(),
                pageSize = pageSize
            )
        val resources = mutableListOf<MedicalResource>()
        val seenPageTokens = mutableSetOf<String>()
        var pageToken: String? = null
        do {
            val request = if (pageToken == null) {
                initialRequest
            } else {
                ReadMedicalResourcesPageRequest(pageToken, pageSize = pageSize)
            }
            val response = client.readMedicalResources(request)
            resources.addAll(response.medicalResources)
            pageToken = response.nextPageToken
            if (pageToken != null && !seenPageTokens.add(pageToken)) {
                throw IllegalStateException(
                    "Health Connect repeated a medical-record page token."
                )
            }
        } while (pageToken != null)

        val sourceNames = if (resources.isEmpty()) {
            emptyMap()
        } else {
            client.getMedicalDataSources(
                resources.map { it.dataSourceId }.distinct()
            ).associate { source -> source.id to source.displayName }
        }
        return resources.map { resource ->
            mapOf(
                "sourceId" to resource.dataSourceId,
                "sourceName" to (sourceNames[resource.dataSourceId] ?: "Health Connect"),
                "resourceId" to resource.fhirResource.id,
                "resource" to resource.fhirResource.data
            )
        }
    }
}
