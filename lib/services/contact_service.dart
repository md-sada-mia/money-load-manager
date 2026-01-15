import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();

  factory ContactService() {
    return _instance;
  }

  ContactService._internal();

  List<String>? _cachedNormalizedNumbers;

  /// Pre-load contacts into memory for faster checking
  Future<void> loadContacts() async {
    try {
      // Use permission_handler to avoid request code collision with other plugins
      if (!await Permission.contacts.isGranted) {
        final status = await Permission.contacts.request();
        if (!status.isGranted) {
          _cachedNormalizedNumbers = [];
          return;
        }
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      _cachedNormalizedNumbers = contacts
          .expand((c) => c.phones)
          .map((p) => p.number.replaceAll(RegExp(r'\D'), ''))
          .where((n) => n.isNotEmpty)
          .toList();
      
      print('Loaded ${_cachedNormalizedNumbers?.length} contact numbers into cache.');
    } catch (e) {
      print('Error loading contacts: $e');
      _cachedNormalizedNumbers = [];
    }
  }

  /// Check if a phone number exists in contacts
  /// Uses cached list if available, otherwise fetches (and caches)
  Future<bool> isContactExists(String phoneNumber) async {
    try {
      if (_cachedNormalizedNumbers == null) {
        await loadContacts();
      }

      final normalizedInput = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (normalizedInput.length < 6) return false;

      // Check against cache
      // End-with matching to handle country codes
      // Trying exact match first for speed, then suffix match
      if (_cachedNormalizedNumbers!.contains(normalizedInput)) return true;

      for (final contactNum in _cachedNormalizedNumbers!) {
        // Check if one ends with the other (e.g. 017... vs 88017...)
        // We assume last 10 digits should match at least
        if (contactNum.length >= 10 && normalizedInput.length >= 10) {
           if (contactNum.endsWith(normalizedInput) || normalizedInput.endsWith(contactNum)) {
             return true;
           }
        }
      }

      return false;
    } catch (e) {
      print('Error checking contacts: $e');
      return false;
    }
  }

  void clearCache() {
    _cachedNormalizedNumbers = null;
  }
}

