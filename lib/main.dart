import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const App());
}

class Geet {
  String title;
  String lyrics;
  String category;
  String videoUrl;
  bool favorite;

  Geet({
    required this.title,
    required this.lyrics,
    required this.category,
    required this.videoUrl,
    this.favorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'lyrics': lyrics,
      'category': category,
      'videoUrl': videoUrl,
      'favorite': favorite,
    };
  }

  factory Geet.fromJson(Map<String, dynamic> json) {
    return Geet(
      title: json['title'] ?? '',
      lyrics: json['lyrics'] ?? '',
      category: json['category'] ?? 'Christian Geet',
      videoUrl: json['videoUrl'] ?? '',
      favorite: json['favorite'] ?? false,
    );
  }
}

class Store {
  static const String key = 'geets';

  static Future<List<Geet>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    final data = jsonDecode(raw) as List;

    return data
        .map((item) => Geet.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<Geet> geets) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      key,
      jsonEncode(
        geets.map((geet) => geet.toJson()).toList(),
      ),
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Christian Geet & Zaboor',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Geet> items = [];
  String query = '';
  bool favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    loadGeets();
  }

  Future<void> loadGeets() async {
    final loaded = await Store.load();

    if (!mounted) return;

    setState(() {
      items = loaded;
    });
  }

  Future<void> editGeet([Geet? old]) async {
    final result = await Navigator.push<Geet>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPage(old: old),
      ),
    );

    if (result == null) return;

    setState(() {
      if (old == null) {
        items.add(result);
      } else {
        final index = items.indexOf(old);
        if (index >= 0) {
          items[index] = result;
        }
      }
    });

    await Store.save(items);
  }

  Future<void> deleteGeet(Geet geet) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('Delete / حذف'),
              content: Text(geet.title),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      items.remove(geet);
    });

    await Store.save(items);
  }

  Future<void> searchGeets() async {
    final controller = TextEditingController(text: query);

    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Search / تلاش'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Geet ka naam likhein',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result != null) {
      setState(() {
        query = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((geet) {
      final matchesFavorite =
          !favoritesOnly || geet.favorite;

      final text =
          '${geet.title} ${geet.category}'.toLowerCase();

      final matchesSearch =
          text.contains(query.toLowerCase());

      return matchesFavorite && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('✝️ Christian Geet & Zaboor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: searchGeets,
          ),
        ],
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Text(
                'ابھی کوئی Geet نہیں ہے\n'
                '+ دباکر نیا Geet شامل کریں',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final geet = filtered[index];

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        geet.category == 'Zaboor'
                            ? Icons.menu_book
                            : Icons.music_note,
                      ),
                    ),
                    title: Text(geet.title),
                    subtitle: Text(geet.category),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GeetPage(
                            geet,
                            onChanged: () {
                              setState(() {});
                              Store.save(items);
                            },
                          ),
                        ),
                      );
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          editGeet(geet);
                        }

                        if (value == 'delete') {
                          deleteGeet(geet);
                        }

                        if (value == 'favorite') {
                          setState(() {
                            geet.favorite = !geet.favorite;
                          });

                          Store.save(items);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'favorite',
                          child: Text(
                            geet.favorite
                                ? 'Remove Favorite'
                                : 'Favorite / پسندیدہ',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit / ترمیم'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete / حذف'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          editGeet();
        },
        icon: const Icon(Icons.add),
        label: const Text('Naya Geet'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: favoritesOnly ? 1 : 0,
        onDestinationSelected: (index) {
          setState(() {
            favoritesOnly = index == 1;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.music_note),
            label: 'Christian Geet',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}

class EditPage extends StatefulWidget {
  final Geet? old;

  const EditPage({
    super.key,
    this.old,
  });

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late TextEditingController titleController;
  late TextEditingController lyricsController;
  late TextEditingController videoController;

  String category = 'Christian Geet';

  @override
  void initState() {
    super.initState();

    final geet = widget.old;

    titleController = TextEditingController(
      text: geet?.title ?? '',
    );

    lyricsController = TextEditingController(
      text: geet?.lyrics ?? '',
    );

    videoController = TextEditingController(
      text: geet?.videoUrl ?? '',
    );

    category = geet?.category ?? 'Christian Geet';
  }

  @override
  void dispose() {
    titleController.dispose();
    lyricsController.dispose();
    videoController.dispose();
    super.dispose();
  }

  void saveGeet() {
    if (titleController.text.trim().isEmpty) {
      return;
    }

    final geet = Geet(
      title: titleController.text.trim(),
      lyrics: lyricsController.text,
      category: category,
      videoUrl: videoController.text.trim(),
      favorite: widget.old?.favorite ?? false,
    );

    Navigator.pop(context, geet);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.old == null
              ? 'Naya Geet / نیا Geet'
              : 'Edit / ترمیم',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Geet ka Naam / گیت کا نام',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(
              labelText: 'Category / قسم',
              border: OutlineInputBorder(),
            ),
            items: const [
              'Christian Geet',
              'Zaboor',
              'Worship',
              'Christmas',
              'Easter',
              'Sunday School',
            ].map(
              (value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              },
            ).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                category = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lyricsController,
            minLines: 10,
            maxLines: 20,
            decoration: const InputDecoration(
              labelText: 'Geet ke Bol / گیت کے بول',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: videoController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'YouTube / Video Link',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saveGeet,
            icon: const Icon(Icons.save),
            label: const Text('Save / محفوظ کریں'),
          ),
        ],
      ),
    );
  }
}

class GeetPage extends StatelessWidget {
  final Geet geet;
  final VoidCallback onChanged;

  const GeetPage(
    this.geet, {
    super.key,
    required this.onChanged,
  });

  Future<void> openVideo(BuildContext context) async {
    if (geet.videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video link محفوظ نہیں ہے'),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(geet.videoUrl);

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video link درست نہیں ہے'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.play_circle_fill),
          onPressed: () {
            openVideo(context);
          },
        ),
        title: Text(geet.title),
        actions: [
          IconButton(
            icon: Icon(
              geet.favorite
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            onPressed: () {
              geet.favorite = !geet.favorite;
              onChanged();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              label: Text(geet.category),
            ),
            const SizedBox(height: 18),
            Text(
              geet.lyrics,
              style: const TextStyle(
                fontSize: 20,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 25),
            if (geet.videoUrl.isNotEmpty)
              FilledButton.icon(
                onPressed: () {
                  openVideo(context);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Geet ki Video چلائیں'),
              ),
          ],
        ),
      ),
    );
  }
}
