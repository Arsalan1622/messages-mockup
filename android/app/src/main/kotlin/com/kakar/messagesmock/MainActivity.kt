package com.kakar.messagesmock

import android.content.ContentResolver
import android.net.Uri
import android.provider.ContactsContract
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Read-only SMS access for the Messages mockup.
 *
 * Reads the SMS provider (content://sms) and the phonebook display names.
 * This app never writes to the SMS provider and never sends anything.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.kakar.messagesmock/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllSms" -> {
                    try {
                        result.success(getAllSms())
                    } catch (e: Exception) {
                        result.error("SMS_READ_FAILED", e.message, null)
                    }
                }
                "getContactNames" -> {
                    try {
                        val addresses =
                            call.argument<List<String>>("addresses") ?: emptyList()
                        result.success(getContactNames(addresses))
                    } catch (e: Exception) {
                        result.error("CONTACTS_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** All SMS (received + sent), newest first, capped for memory safety. */
    private fun getAllSms(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val uri: Uri = Telephony.Sms.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )
        val cr: ContentResolver = contentResolver
        // NOTE: no "LIMIT" in the sort order — some OEM SMS providers reject
        // it and throw. Cap the rows in code instead.
        cr.query(uri, projection, null, null, "${Telephony.Sms.DATE} DESC")
            ?.use { cursor ->
                val iAddress = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
                val iBody = cursor.getColumnIndex(Telephony.Sms.BODY)
                val iDate = cursor.getColumnIndex(Telephony.Sms.DATE)
                val iType = cursor.getColumnIndex(Telephony.Sms.TYPE)
                val iRead = cursor.getColumnIndex(Telephony.Sms.READ)
                while (cursor.moveToNext() && out.size < 5000) {
                    out.add(
                        mapOf(
                            "address" to if (iAddress >= 0) cursor.getString(iAddress) else null,
                            "body" to if (iBody >= 0) cursor.getString(iBody) else null,
                            "date" to if (iDate >= 0) cursor.getLong(iDate) else 0L,
                            "type" to if (iType >= 0) cursor.getInt(iType) else 1,
                            "read" to if (iRead >= 0) cursor.getInt(iRead) else 1
                        )
                    )
                }
            }
        return out
    }

    /** Phonebook display name per address (short codes have none). */
    private fun getContactNames(addresses: List<String>): Map<String, String> {
        val out = HashMap<String, String>()
        val cr: ContentResolver = contentResolver
        for (address in addresses) {
            val lookupUri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(address)
            )
            cr.query(
                lookupUri,
                arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(
                        ContactsContract.PhoneLookup.DISPLAY_NAME
                    )
                    if (idx >= 0) {
                        val name = cursor.getString(idx)
                        if (!name.isNullOrBlank()) out[address] = name
                    }
                }
            }
        }
        return out
    }
}
