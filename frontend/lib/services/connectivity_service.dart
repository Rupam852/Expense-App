import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'expense_provider.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  bool _wasOffline = false;
  bool get wasOffline => _wasOffline;

  ExpenseProvider? _expenseProvider;

  void initialize(ExpenseProvider provider) {
    _expenseProvider = provider;
    _checkInitialConnectivity();
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChanged);
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (_) {}
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final previouslyOffline = _isOffline;
    _updateStatus(results);

    // If we just came back online after being offline, trigger quiet sync automatically!
    if (previouslyOffline && !_isOffline) {
      _expenseProvider?.triggerQuietSync();
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.contains(ConnectivityResult.none) ||
        (results.length == 1 && results.first == ConnectivityResult.none);

    if (_isOffline != offline) {
      if (offline) {
        _wasOffline = true;
      }
      _isOffline = offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
