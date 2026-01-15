import 'package:flutter/material.dart';

class LogoHelper {
  static const Map<String, String> _logoMap = {
    'bkash': 'assets/icons/bkash.png',
    'nagad': 'assets/icons/nagad.png',
    'rocket': 'assets/icons/rocket.png', 
    'upay': 'assets/icons/upay.png',
    'cellfin': 'assets/icons/cellfin.png',
    'tap': 'assets/icons/tap.png',
    
    // Telcos (Flexiload)
    'grameenphone': 'assets/icons/flexiload.png', // Or specific operator logo if available
    'gp info': 'assets/icons/flexiload.png',
    'banglalink': 'assets/icons/flexiload.png',
    'robi': 'assets/icons/flexiload.png',
    'airtel': 'assets/icons/flexiload.png',
    'teletalk': 'assets/icons/flexiload.png',
    
    // Utilities
    'desco': 'assets/icons/utility_bill.png',
    'dpdc': 'assets/icons/utility_bill.png',
    'wasa': 'assets/icons/utility_bill.png',
    'titas': 'assets/icons/utility_bill.png',
    'bpdb': 'assets/icons/utility_bill.png',
    'polli bidyut': 'assets/icons/utility_bill.png',
  };

  static const String _defaultLogo = 'assets/icons/other.png';

  /// Get logo asset path for a given sender/type
  static String getLogoPath(String type) {
    if (type.isEmpty) return _defaultLogo;
    
    final normalizedType = type.toLowerCase();
    
    // Direct match
    if (_logoMap.containsKey(normalizedType)) {
      return _logoMap[normalizedType]!;
    }
    
    // Partial match (e.g. "bKash Payment" -> "bkash")
    for (final key in _logoMap.keys) {
      if (normalizedType.contains(key)) {
        return _logoMap[key]!;
      }
    }
    
    return _defaultLogo;
  }

  /// Get color for a given type (optional, if we want to retain some color coding)
  static Color getColor(String type) {
    final normalizedType = type.toLowerCase();
    
    if (normalizedType.contains('bkash')) return Colors.pink;
    if (normalizedType.contains('nagad')) return Colors.redAccent;
    if (normalizedType.contains('rocket')) return Colors.purple;
    if (normalizedType.contains('flexi') || 
        normalizedType.contains('gp') || 
        normalizedType.contains('load')) return Colors.blue;
        
    return Colors.grey;
  }
}
