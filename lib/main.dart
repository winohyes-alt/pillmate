import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart' as flags;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const PillMateApp());
}

class PillMateApp extends StatelessWidget {
  const PillMateApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PillMate',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4AC3CF),
        scaffoldBackgroundColor: const Color(0xFFF6FBFC),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const SplashPage(),
    );
  }
}


class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    HomePage(),        // หน้าเดิม
    _PlaceholderPage(title: 'ปฏิทิน (ยังไม่ทำ)'),
    _PlaceholderPage(title: 'ยา (ยังไม่ทำ)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check), label: 'งาน'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'ปฏิทิน'),
          NavigationDestination(icon: Icon(Icons.medication), label: 'ยา'),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
appBar: AppBar(
  backgroundColor: const Color(0xFF4AC3CF),
  foregroundColor: Colors.white,
  elevation: 0,
  centerTitle: true,
  title: const Text('PillMate', style: TextStyle(fontWeight: FontWeight.w900)),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(170),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ===== Banner ด้านบน =====
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.85),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Text('แบนเนอร์', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        // ===== แถบปฏิทิน 7 วันเดิม =====
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              physics: const BouncingScrollPhysics(),
              cacheExtent: 600,
              itemBuilder: (_, i) {
                final d = days[i];
                final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_weekdayShort(d.weekday), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.white : Colors.white.withOpacity(.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: isToday ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)] : null,
                      ),
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          color: isToday ? const Color(0xFF198D98) : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  ),
  actions: [
    IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings, color: Colors.white),
      onPressed: _openSettings,
    ),
    IconButton(
      tooltip: 'ทดสอบเด้งทันที',
      icon: const Icon(Icons.notifications_active_outlined, color: Colors.white),
      onPressed: () => NotificationService.instance.showNow('ทดสอบแจ้งเตือน', 'แบบเด้งทันที'),
    ),
    const SizedBox(width: 6),
  ],
),

        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: const Center(child: Text('เร็ว ๆ นี้')),
    );
  }
}

class Medicine {
  final int id;
  String name;
  int hour;
  int minute;
  bool enabled;
  // 1=Mon..7=Sun (ตาม Dart DateTime.weekday)
  List<int> days;
  Medicine({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    this.enabled = true,
    List<int>? days,
  }) : days = days ?? [1,2,3,4,5,6,7];

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'days': days,
      };
  static Medicine fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'],
        name: j['name'],
        hour: j['hour'],
        minute: j['minute'],
        enabled: j['enabled'] ?? true,
        days: (j['days'] as List?)?.map((e) => e as int).toList() ?? [1,2,3,4,5,6,7],
      );
}


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    () async {
      await NotificationService.instance.init();
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4AC3CF),
      body: Center(
        child: Image.asset('assets/logo.png', width: 150, height: 150),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Medicine> _meds = [];
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    () async {
      await NotificationService.instance.init();
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }();
    _loadMeds().then((_) => _ensureSchedules());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPaused());
  }

  Future<void> _refreshPaused() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _paused = prefs.getBool('pause_all') ?? false);
  }

  Future<void> _ensureSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final paused = prefs.getBool('pause_all') ?? false;
    if (paused) {
      await NotificationService.instance.cancelAll();
      return;
    }
    for (final m in _meds) {
      // ล้างซีรีส์เก่า (ถ้าเคยตั้งแบบรายสัปดาห์)
      await NotificationService.instance.cancelSeries(m.id);
      if (m.enabled) {
        // ตั้งแบบ "ทุกวัน"
        await NotificationService.instance.scheduleDaily(
          id: m.id,
          title: 'ถึงเวลายา',
          body: 'อย่าลืมทาน: ${m.name}',
          hour: m.hour,
          minute: m.minute,
        );
      }
    }
  }

  Future<void> _loadMeds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('meds_v3_weekdays') ?? prefs.getStringList('meds_v2') ?? [];
    final items = raw.map((s) => Medicine.fromJson(jsonDecode(s))).toList();
    setState(() {
      _meds
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _saveMeds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _meds.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('meds_v3_weekdays', raw);
  }

  void _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
    await _refreshPaused();
    await _ensureSchedules();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 3));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4AC3CF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('PillMate', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(170),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner ด้านบน (แก้น้อยสุด แค่ใส่ Container ไว้ให้ใช้งานต่อ)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Text('แบนเนอร์', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final d = days[i];
                  final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_weekdayShort(d.weekday), style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday ? Colors.white : Colors.white.withOpacity(.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: isToday ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)] : null,
                        ),
                        child: Text('${d.day}',
                            style: TextStyle(
                              color: isToday ? const Color(0xFF198D98) : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            )
            ],
          ),
        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'ทดสอบเด้งทันที',
            icon: const Icon(Icons.notifications_active_outlined, color: Colors.white),
            onPressed: () => NotificationService.instance.showNow('ทดสอบแจ้งเตือน', 'แบบเด้งทันที'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _paused
          ? FloatingActionButton.extended(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('pause_all', false);
                await _ensureSchedules();
                setState(() => _paused = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เปิดแจ้งเตือนทั้งหมดแล้ว')));
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume all'),
              backgroundColor: Colors.orange,
            )
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.of(context).push<Medicine>(
                  MaterialPageRoute(builder: (_) => const EditMedicinePage()),
                );
                if (result != null) {
                  setState(() => _meds.add(result));
                  await _saveMeds();
                  if (result.enabled) {
                    await NotificationService.instance.scheduleDaily(
                      id: result.id,
                      title: 'ถึงเวลายา',
                      body: 'อย่าลืมทาน: ${result.name}',
                      hour: result.hour,
                      minute: result.minute,
                    );
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เพิ่ม ${result.name} ${result.time.format(context)}')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มยา'),
            ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        child: _meds.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 8),
                  Text('วันนี้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SizedBox(height: 12),
                  _EmptyState(),
                ],
              )
            : ListView.builder(
                itemCount: _meds.length,
                itemBuilder: (_, i) {
                  final m = _meds[i];
                  return Dismissible(
                    key: ValueKey(m.id),
                    background: Container(
                      decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      final removed = m;
                      setState(() => _meds.removeAt(i));
                      await _saveMeds();
                      await NotificationService.instance.cancelSeries(removed.id);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('ลบ ${removed.name} แล้ว'),
                        action: SnackBarAction(
                          label: 'ยกเลิก',
                          onPressed: () async {
                            setState(() => _meds.insert(i, removed));
                            await _saveMeds();
                            if (removed.enabled) {
                              await NotificationService.instance.scheduleDaily(
                                id: removed.id,
                                title: 'ถึงเวลายา',
                                body: 'อย่าลืมทาน: ${removed.name}',
                                hour: removed.hour,
                                minute: removed.minute,
                              );
                            }
                          },
                        ),
                      ));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4AC3CF).withOpacity(.15),
                          foregroundColor: const Color(0xFF198D98),
                          child: const Icon(Icons.medication_liquid_rounded),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${m.time.format(context)}  •  ทุกวัน'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: m.enabled && !_paused,
                              onChanged: _paused
                                  ? null
                                  : (val) async {
                                      setState(() => m.enabled = val);
                                      await _saveMeds();
                                      await NotificationService.instance.cancelSeries(m.id);
                                      if (val) {
                                        await NotificationService.instance.scheduleDaily(
                                          id: m.id,
                                          title: 'ถึงเวลายา',
                                          body: 'อย่าลืมทาน: ${m.name}',
                                          hour: m.hour,
                                          minute: m.minute,
                                        );
                                      }
                                    },
                            ),
                            IconButton(
                              tooltip: 'แก้ไข',
                              icon: const Icon(Icons.edit),
                              onPressed: _paused
                                  ? null
                                  : () async {
                                      final edited = await Navigator.of(context).push<Medicine>(
                                        MaterialPageRoute(builder: (_) => EditMedicinePage(existing: m)),
                                      );
                                      if (edited != null) {
                                        setState(() {
                                          m.name = edited.name;
                                          m.hour = edited.hour;
                                          m.minute = edited.minute;
                                          m.enabled = edited.enabled;
                                          m.days = edited.days; // not used but kept for data compatibility
                                        });
                                        await _saveMeds();
                                        await NotificationService.instance.cancelSeries(m.id);
                                        if (m.enabled) {
                                          await NotificationService.instance.scheduleDaily(
                                            id: m.id,
                                            title: 'ถึงเวลายา',
                                            body: 'อย่าลืมทาน: ${m.name}',
                                            hour: m.hour,
                                            minute: m.minute,
                                          );
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _weekdayShort(int w) {
    const map = {1: 'จ.', 2: 'อ.', 3: 'พ.', 4: 'พฤ.', 5: 'ศ.', 6: 'ส.', 7: 'อา.'};
    return map[w] ?? '';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_rounded, size: 96, color: Colors.black.withOpacity(.15)),
            const SizedBox(height: 12),
            Text('ยังไม่มียา เพิ่มรายการด้วยปุ่มด้านล่างขวา', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

class EditMedicinePage extends StatefulWidget {
  final Medicine? existing;
  const EditMedicinePage({super.key, this.existing});
  @override
  State<EditMedicinePage> createState() => _EditMedicinePageState();
}

class _EditMedicinePageState extends State<EditMedicinePage> {
  late TextEditingController _nameCtrl;
  TimeOfDay? _selectedTime;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    () async {
      await NotificationService.instance.init();
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    if (widget.existing != null) {
      _selectedTime = widget.existing!.time;
      _enabled = widget.existing!.enabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขยา' : 'เพิ่มยา'),
        backgroundColor: const Color(0xFF4AC3CF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ชื่อยา',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime == null ? 'เลือกเวลา' : _selectedTime!.format(context)),
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (t != null) setState(() => _selectedTime = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const Text('เปิดการแจ้งเตือนรายการนี้'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty || _selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรอกข้อมูลให้ครบ')));
                  return;
                }
                final t = _selectedTime!;
                final id = widget.existing?.id ?? (DateTime.now().millisecondsSinceEpoch & 0x7fffffff);
                Navigator.of(context).pop(Medicine(
                  id: id,
                  name: _nameCtrl.text.trim(),
                  hour: t.hour,
                  minute: t.minute,
                  enabled: _enabled,
                  days: const [1,2,3,4,5,6,7], // keep persisted shape; not used
                ));
              },
              child: Text(isEdit ? 'บันทึกการแก้ไข' : 'เพิ่ม'),
            )
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _paused = false;
  int _snooze = 10;

  @override
  void initState() {
    super.initState();
    () async {
      await NotificationService.instance.init();
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paused = prefs.getBool('pause_all') ?? false;
      _snooze = prefs.getInt('default_snooze_minutes') ?? 10;
    });
  }

  Future<void> _saveSnooze(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_snooze_minutes', minutes);
    setState(() => _snooze = minutes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ตั้งค่าการเลื่อนแจ้งเตือน $_snooze นาที')));
    }
  }

  Future<void> _setPaused(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pause_all', value);
    setState(() => _paused = value);
    if (_paused) {
      await NotificationService.instance.cancelAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('หยุดแจ้งเตือนทั้งหมดแล้ว')));
      }
    } else {
      final raw = prefs.getStringList('meds_v3_weekdays') ?? [];
      final meds = raw.map((s) => Medicine.fromJson(jsonDecode(s))).toList();
      for (final m in meds) {
        if (m.enabled) {
          await NotificationService.instance.scheduleDaily(
            id: m.id,
            title: 'ถึงเวลายา',
            body: 'อย่าลืมทาน: ${m.name}',
            hour: m.hour,
            minute: m.minute,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เปิดแจ้งเตือนทั้งหมดแล้ว')));
      }
    }
  }

  void _openNotifSettings() {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: <String, dynamic>{'android.provider.extra.APP_PACKAGE': 'com.example.pillmate'},
      flags: <int>[flags.Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    intent.launch();
  }

  void _openExactAlarm() {
    if (!Platform.isAndroid) return;
    const action = 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM';
    final intent = AndroidIntent(action: action, flags: <int>[flags.Flag.FLAG_ACTIVITY_NEW_TASK]);
    intent.launch();
  }

  void _openBattery() {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      flags: <int>[flags.Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    intent.launch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF4AC3CF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _paused,
            onChanged: (v) => _setPaused(v),
            title: const Text('Pause all reminders'),
            subtitle: const Text('หยุดการแจ้งเตือนทั้งหมดชั่วคราว'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Default Snooze time'),
            subtitle: Text('เลื่อนแจ้งเตือน: $_snooze นาที'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ChoiceChip(
                label: const Text('5 นาที'),
                selected: _snooze == 5,
                onSelected: (_) => _saveSnooze(5),
              ),
              ChoiceChip(
                label: const Text('10 นาที'),
                selected: _snooze == 10,
                onSelected: (_) => _saveSnooze(10),
              ),
              ChoiceChip(
                label: const Text('15 นาที'),
                selected: _snooze == 15,
                onSelected: (_) => _saveSnooze(15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const ListTile(
            title: Text('Quick Settings'),
            subtitle: Text('ตั้งค่าสิทธิในระบบให้แจ้งเตือนได้แน่นอน'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notification settings'),
            onTap: _openNotifSettings,
          ),
          ListTile(
            leading: const Icon(Icons.alarm_on_rounded),
            title: const Text('Alarms & reminders (Exact alarm)'),
            onTap: _openExactAlarm,
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Battery optimization'),
            subtitle: const Text('แนะนำเป็น Unrestricted'),
            onTap: _openBattery,
          ),
        ],
      ),
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (NotificationResponse resp) async {
        if (resp.actionId == 'SNOOZE') {
          final minutes = await _getDefaultSnoozeMinutes();
          final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
          await scheduleOneShot(
            id: 800000 + DateTime.now().millisecondsSinceEpoch % 100000,
            title: 'เตือนอีกครั้ง',
            body: 'เลื่อนแจ้งเตือน $minutes นาที',
            when: when,
          );
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'pillmate_daily',
      'PillMate Daily',
      description: 'แจ้งเตือนกินยาประจำวัน',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>() 
        ?.requestNotificationsPermission();
  }

  static const _androidActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      'SNOOZE',
      'เลื่อน',
      showsUserInterface: true,
    ),
  ];

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'pillmate_daily',
          'PillMate Daily',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: _androidActions,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> showNow(String title, String body) async {
    await _plugin.show(9999, title, body, _details());
  }

  // NEW: แจ้งเตือนทุกวันตามเวลา
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (at.isBefore(now)) {
      at = at.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // สร้างซีรีส์แจ้งเตือนรายสัปดาห์ตามวันในสัปดาห์ (เก็บไว้เพื่อเคลียร์ของเก่าได้)
  Future<void> scheduleWeeklySeries({
    required int baseId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays, // 1..7
  }) async {
    for (final w in weekdays) {
      final id = _seriesId(baseId, w);
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, minute);
      // เลื่อนไปให้ตรงวัน w ที่จะถึง
      while (at.weekday != w || at.isBefore(now)) {
        at = at.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  int _seriesId(int base, int weekday) => base % 1000000 * 10 + weekday; // map เป็น id ไม่ชน

  Future<void> cancelSeries(int baseId) async {
    for (int w = 1; w <= 7; w++) {
      await _plugin.cancel(_seriesId(baseId, w));
    }
    // เผื่อเคยตั้งแบบ daily มาก่อน
    await _plugin.cancel(baseId);
  }

  Future<void> scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();

  Future<int> _getDefaultSnoozeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('default_snooze_minutes') ?? 10;
  }
}
