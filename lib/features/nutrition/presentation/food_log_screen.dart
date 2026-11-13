import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/food_log.dart';
import 'food_log_controller.dart';

/// Jason's simple, device-local calorie and protein diary.
class FoodLogScreen extends ConsumerStatefulWidget {
  /// Creates the diary screen.
  const FoodLogScreen({super.key});
  @override
  ConsumerState<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends ConsumerState<FoodLogScreen> {
  DateTime _date = DateTime.now();
  String _query = '';
  bool _busy = false;
  Future<bool> _save(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not save. Your previous entries are unchanged. Please retry.')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food log')),
      body: ref.watch(foodLogProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => Center(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const Text('Unable to load your food log. No data was changed.'),
              TextButton(
                  onPressed: () => ref.invalidate(foodLogProvider),
                  child: const Text('Retry')),
            ])),
            data: (FoodLog log) {
              final List<FoodEntry> entries = log.forDay(foodDay(_date));
              final double calories = entries.fold(
                  0, (double sum, FoodEntry e) => sum + e.calories);
              final double protein =
                  entries.fold(0, (double sum, FoodEntry e) => sum + e.protein);
              return SafeArea(
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: <Widget>[
                                Row(children: <Widget>[
                                  IconButton(
                                      tooltip: 'Previous day',
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() => _date =
                                              DateTime(_date.year, _date.month,
                                                  _date.day - 1)),
                                      icon: const Icon(Icons.chevron_left)),
                                  Expanded(
                                      child: TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () async {
                                                  final DateTime? selected =
                                                      await showDatePicker(
                                                          context: context,
                                                          initialDate: _date,
                                                          firstDate:
                                                              DateTime(2020),
                                                          lastDate:
                                                              DateTime.now());
                                                  if (selected != null &&
                                                      mounted) {
                                                    setState(
                                                        () => _date = selected);
                                                  }
                                                },
                                          child: Text(foodDay(_date)))),
                                  IconButton(
                                      tooltip: 'Next day',
                                      onPressed: _busy ||
                                              foodDay(_date) ==
                                                  foodDay(DateTime.now())
                                          ? null
                                          : () => setState(() => _date =
                                              DateTime(_date.year, _date.month,
                                                  _date.day + 1)),
                                      icon: const Icon(Icons.chevron_right)),
                                ]),
                                Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                            '${calories.round()} cal • ${protein.toStringAsFixed(1)} g protein',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge))),
                                const Text(
                                    'Food entries only. Separate from your existing manual protein tracker; totals are not added together. Saved on this browser only.'),
                                const SizedBox(height: 16),
                                Text('Meals logged',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                if (entries.isEmpty)
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16),
                                      child: Text(
                                          'Nothing logged yet. Choose a food below.')),
                                for (final FoodEntry entry in entries)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(entry.food.name),
                                    subtitle: Text(
                                        '${_number(entry.amount)} ${entry.byWeight ? 'g' : 'serving(s)'} • ${entry.calories.round()} cal • ${entry.protein.toStringAsFixed(1)} g protein'),
                                    onTap: _busy
                                        ? null
                                        : () =>
                                            _portion(entry.food, entry: entry),
                                    trailing: IconButton(
                                        tooltip: 'Delete entry',
                                        onPressed:
                                            _busy ? null : () => _delete(entry),
                                        icon: const Icon(Icons.delete_outline)),
                                  ),
                                const Divider(height: 32),
                                Text('Quick add',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const Text(
                                    'Favourites first, then recent foods. Check your package for the exact flavour and size.'),
                                const SizedBox(height: 8),
                                TextField(
                                    decoration: const InputDecoration(
                                        labelText: 'Search foods',
                                        prefixIcon: Icon(Icons.search)),
                                    onChanged: (String value) =>
                                        setState(() => _query = value)),
                                TextButton.icon(
                                    onPressed: _busy ? null : _customFood,
                                    icon: const Icon(Icons.add),
                                    label: const Text(
                                        'Create custom food or recipe')),
                                for (final Food food in log.search(_query))
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(food.name),
                                    subtitle: Text(
                                        '${food.serving} • ${food.calories.round()} cal • ${food.protein.toStringAsFixed(1)} g protein'),
                                    leading: IconButton(
                                        tooltip:
                                            log.favourites.contains(food.id)
                                                ? 'Remove favourite'
                                                : 'Add favourite',
                                        onPressed: _busy
                                            ? null
                                            : () => _save(() => ref
                                                .read(foodLogProvider.notifier)
                                                .toggleFavourite(food.id)),
                                        icon: Icon(
                                            log.favourites.contains(food.id)
                                                ? Icons.star
                                                : Icons.star_border)),
                                    trailing:
                                        const Icon(Icons.add_circle_outline),
                                    onTap: _busy ? null : () => _portion(food),
                                  ),
                                if (log.search(_query).isEmpty)
                                  const Text(
                                      'No matching foods. Create a custom food using its label.'),
                              ]))));
            },
          ),
    );
  }

  Future<void> _portion(Food food, {FoodEntry? entry}) async {
    final _Portion? portion = await showDialog<_Portion>(
        context: context,
        builder: (BuildContext context) =>
            _PortionDialog(food: food, entry: entry));
    if (portion == null || !mounted) return;
    await _save(() => ref.read(foodLogProvider.notifier).saveEntry(FoodEntry(
        id: entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        day: entry?.day ?? foodDay(_date),
        food: food,
        amount: portion.amount,
        byWeight: portion.byWeight)));
  }

  Future<void> _delete(FoodEntry entry) async {
    final bool confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
                    title: const Text('Delete this entry?'),
                    content: Text(entry.food.name),
                    actions: <Widget>[
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete')),
                    ])) ??
        false;
    if (confirmed && mounted) {
      await _save(
          () => ref.read(foodLogProvider.notifier).deleteEntry(entry.id));
    }
  }

  Future<void> _customFood() async {
    final Food? food = await showDialog<Food>(
        context: context,
        builder: (BuildContext context) => const _CustomFoodDialog());
    if (food == null || !mounted) return;
    final bool saved =
        await _save(() => ref.read(foodLogProvider.notifier).addFood(food));
    if (saved && mounted) await _portion(food);
  }
}

String _number(double n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();

class _Portion {
  const _Portion(this.amount, this.byWeight);
  final double amount;
  final bool byWeight;
}

class _PortionDialog extends StatefulWidget {
  const _PortionDialog({required this.food, this.entry});
  final Food food;
  final FoodEntry? entry;
  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _amount =
      TextEditingController(text: _number(widget.entry?.amount ?? 1));
  late bool _weight = widget.entry?.byWeight ?? false;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.entry == null ? 'Add food' : 'Edit portion'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(widget.food.name),
                  Text('1 serving = ${widget.food.serving}'),
                  if (widget.food.grams != null)
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Measure in grams'),
                        value: _weight,
                        onChanged: (bool value) => setState(() {
                              final double? amount =
                                  double.tryParse(_amount.text);
                              if (amount != null) {
                                _amount.text = _number(value
                                    ? amount * widget.food.grams!
                                    : amount / widget.food.grams!);
                              }
                              _weight = value;
                            })),
                  TextFormField(
                      controller: _amount,
                      autofocus: true,
                      decoration: InputDecoration(
                          labelText: _weight ? 'Grams' : 'Servings'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (String? value) =>
                          _numeric(value, positive: true)),
                ]))),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                      context, _Portion(double.parse(_amount.text), _weight));
                }
              },
              child: const Text('Save entry')),
        ],
      );
}

String? _numeric(String? value,
    {bool positive = false, bool optional = false}) {
  if (optional && (value == null || value.trim().isEmpty)) return null;
  final double? number = double.tryParse(value ?? '');
  return number == null ||
          !number.isFinite ||
          (positive ? number <= 0 : number < 0)
      ? (positive
          ? 'Enter a number above zero'
          : 'Enter zero or a positive number')
      : null;
}

class _CustomFoodDialog extends StatefulWidget {
  const _CustomFoodDialog();
  @override
  State<_CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends State<_CustomFoodDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final List<TextEditingController> _fields =
      List<TextEditingController>.generate(5, (_) => TextEditingController());
  @override
  void dispose() {
    for (final TextEditingController field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Custom food or recipe'),
          content: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    const Text(
                        'Saved for next time, including whole meals. Estimates are fine: add “estimate” to the name. Include oils and sauces, and match cooked weights to cooked nutrition values.'),
                    for (int i = 0; i < 5; i++)
                      TextFormField(
                          controller: _fields[i],
                          keyboardType: i < 2
                              ? TextInputType.text
                              : const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                              labelText: <String>[
                            'Food name',
                            'Serving label (e.g. 1 bowl)',
                            'Calories per serving (kcal)',
                            'Protein per serving (g)',
                            'Serving weight in grams (optional)'
                          ][i]),
                          validator: (String? value) => i < 2
                              ? (value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null)
                              : _numeric(value,
                                  positive: i == 4, optional: i == 4)),
                  ]))),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(
                        context,
                        Food(
                            id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                            name: _fields[0].text.trim(),
                            serving: _fields[1].text.trim(),
                            calories: double.parse(_fields[2].text),
                            protein: double.parse(_fields[3].text),
                            grams: double.tryParse(_fields[4].text)));
                  }
                },
                child: const Text('Save food')),
          ]);
}
