import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'boulder_detail_page_offline.dart'; // We'll create this next

class SavedBouldersPage extends StatefulWidget {
  const SavedBouldersPage({Key? key}) : super(key: key);

  @override
  _SavedBouldersPageState createState() => _SavedBouldersPageState();
}

class _SavedBouldersPageState extends State<SavedBouldersPage> {
  Future<List<Map<String, dynamic>>>? _savedBouldersFuture;

  @override
  void initState() {
    super.initState();
    _loadSavedBoulders();
  }

  Future<void> _loadSavedBoulders() async {
    setState(() {
      _savedBouldersFuture = _getSavedBoulders();
    });
  }

  Future<List<Map<String, dynamic>>> _getSavedBoulders() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBouldersStrings = prefs.getStringList('saved_boulders') ?? [];
    return savedBouldersStrings
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _removeBoulder(String boulderId) async {
      final prefs = await SharedPreferences.getInstance();
      final savedBoulders = prefs.getStringList('saved_boulders') ?? [];
      
      savedBoulders.removeWhere((b) => (jsonDecode(b) as Map)['id'] == boulderId);

      await prefs.setStringList('saved_boulders', savedBoulders);
      _loadSavedBoulders(); // Refresh the list

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boulder removed from offline list.'), backgroundColor: Colors.redAccent),
        );
      }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Saved Boulders'),
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedBoulders,
            tooltip: 'Refresh List',
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _savedBouldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading saved boulders: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have no boulders saved for offline use.\nFind a boulder and tap "Save for Offline".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final boulders = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: boulders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final b = boulders[index];
              final name = b['name'] as String? ?? 'Unnamed Boulder';
              final grade = b['grade'] as String? ?? '—';
              final id = b['id'] as String? ?? '';

              return Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                color: Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  title: Text(name,
                      style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          grade,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _removeBoulder(id),
                        tooltip: 'Remove from Offline',
                      ),
                    ],
                  ),
                  onTap: () async {
                    // Navigate to an offline detail page
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BoulderDetailPageOffline(boulderData: b),
                      ),
                    );
                    // Refresh the list in case the saved status changes on the detail page
                    _loadSavedBoulders();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}