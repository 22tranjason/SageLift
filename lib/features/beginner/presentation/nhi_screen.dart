import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/storage/key_value_store.dart';
import '../data/beginner_repository.dart';
import '../domain/beginner_program.dart';
import 'training_profile.dart';

/// A gentle independent workout flow, with no charts.
class NhiScreen extends ConsumerStatefulWidget {
  /// Creates Nhi's home screen.
  const NhiScreen({super.key});
  @override
  ConsumerState<NhiScreen> createState() => _NhiScreenState();
}

class _NhiScreenState extends ConsumerState<NhiScreen> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  String? _error;
  BeginnerRepository get _repository =>
      BeginnerRepository(ref.read(keyValueStoreProvider));
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> data = await _repository.load();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load your session. Please retry.');
      }
    }
  }

  Future<void> _save(Map<String, dynamic> next) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository.save(next);
      if (mounted) {
        setState(() {
          _data = next;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save. Your previous session is safe. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final String? effort = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('How did that feel?'),
        children: <Widget>[
          for (final String label in <String>[
            'Comfortable',
            'About right',
            'Too much',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, label),
              child: Text(label),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep going'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (effort == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      final Map<String, dynamic> next = await _repository.complete(
        _data!,
        effort,
      );
      if (mounted) {
        setState(() {
          _data = next;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session saved. Showing up counts!')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save completion. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = _data ?? <String, dynamic>{};
    final bool active = data['active'] == true;
    final int rounds = data['rounds'] as int? ?? 1;
    final List<dynamic> done = data['done'] as List? ?? <dynamic>[];
    final List<dynamic> sessions = data['sessions'] as List? ?? <dynamic>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhi’s workouts'),
        actions: <Widget>[
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    try {
                      await selectTrainingProfile(ref, 'jason');
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error = 'Could not switch. Please retry.',
                        );
                      }
                    }
                  },
            child: const Text('Jason'),
          ),
          IconButton(
            tooltip: 'Settings and backup',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _busy
                ? null
                : () async {
                    await context.pushNamed(AppRoute.settings.name);
                    if (mounted) await _load();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_error != null) ...<Widget>[
              Text(_error!),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Retry'),
              ),
            ],
            if (_data == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_data != null) ...<Widget>[
              Text(
                'A little stronger for everyday life',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Aim for two sessions a week with a rest day between. Start easy. No failure sets or pressure to finish.',
              ),
              const SizedBox(height: 8),
              const Text(
                'About 20 minutes with two rounds, including warm-up and rests. Start with one round (about 10–15 minutes); add the second only when comfortable.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep several good reps in reserve. Rest 45–90 seconds or longer until ready. Stop for pain, dizziness or unusual symptoms.',
              ),
              const SizedBox(height: 16),
              if (!active) ...<Widget>[
                Text('${sessions.length} sessions completed'),
                if (sessions.isNotEmpty)
                  Text('Last session: ${(sessions.last as Map)['effort']}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _save(<String, dynamic>{
                            ...data,
                            'active': true,
                            'rounds': 1,
                            'done': <String>[],
                          }),
                  child: const Text('Start a gentle full-body session'),
                ),
              ] else ...<Widget>[
                const Text(
                  'Your session is saved on this device. You can pause and come back.',
                ),
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 1, label: Text('1 round')),
                    ButtonSegment<int>(value: 2, label: Text('2 rounds')),
                  ],
                  selected: <int>{rounds},
                  onSelectionChanged: _busy
                      ? null
                      : (Set<int> value) => _save(<String, dynamic>{
                            ...data,
                            'rounds': value.first,
                          }),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Warm up • 3 minutes\nEasy marching, gentle shoulder circles and a few slow sit-to-stands. Move within a comfortable range.',
                ),
                for (int round = 0; round < rounds; round++) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Round ${round + 1}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  for (int i = 0; i < beginnerExercises.length; i++)
                    Card(
                      child: CheckboxListTile(
                        value: done.contains('$round-$i'),
                        onChanged: _busy
                            ? null
                            : (bool? checked) {
                                final List<dynamic> next = List<dynamic>.from(
                                  done,
                                );
                                if (checked == true) {
                                  next.add('$round-$i');
                                } else {
                                  next.remove('$round-$i');
                                }
                                unawaited(
                                  _save(<String, dynamic>{
                                    ...data,
                                    'done': next,
                                  }),
                                );
                              },
                        title: Text(
                          '${beginnerExercises[i].name} • ${beginnerExercises[i].reps}',
                        ),
                        subtitle: Text(
                          '${beginnerExercises[i].cue}\nEasier: ${beginnerExercises[i].easier}',
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Finish • 2 minutes\nWalk slowly and let your breathing settle. Gentle stretches are optional.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _finish,
                  child: const Text('Finish session, even if shortened'),
                ),
              ],
              const SizedBox(height: 20),
              const ExpansionTile(
                title: Text('When it starts to feel easy'),
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Repeat the same moves to build confidence. Start at the lower rep count. After two comfortable sessions, try one or two extra reps. At the top of the range, add a second round OR a little weight, not both together. Keep the easier version whenever you need it.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Your workouts stay on this phone/browser. They do not sync with Jason’s phone. Use Settings to back up before clearing website data.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
