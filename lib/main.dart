import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatefulWidget {
  const CalculatorApp({super.key});

  @override
  State<CalculatorApp> createState() => _CalculatorAppState();
}

class _CalculatorAppState extends State<CalculatorApp> {
  // Default rose/pink accent seed matching the screenshots
  Color _accentColor = const Color(0xFFE0B4C0);
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isDegreeMode = true;
  bool _hapticsEnabled = true;
  bool _saveHistory = true;
  int _precision = 12;

  void _updateAccent(Color color) {
    setState(() => _accentColor = color);
  }

  void _updateThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  void _updateDegreeMode(bool isDeg) {
    setState(() => _isDegreeMode = isDeg);
  }

  void _updateHaptics(bool enabled) {
    setState(() => _hapticsEnabled = enabled);
  }

  void _updateSaveHistory(bool enabled) {
    setState(() => _saveHistory = enabled);
  }

  void _updatePrecision(int precision) {
    setState(() => _precision = precision);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digito',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accentColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accentColor,
          brightness: Brightness.dark,
        ),
      ),
      home: CalculatorScreen(
        accentColor: _accentColor,
        themeMode: _themeMode,
        isDegreeMode: _isDegreeMode,
        hapticsEnabled: _hapticsEnabled,
        saveHistory: _saveHistory,
        precision: _precision,
        onAccentChanged: _updateAccent,
        onThemeModeChanged: _updateThemeMode,
        onDegreeModeChanged: _updateDegreeMode,
        onHapticsChanged: _updateHaptics,
        onSaveHistoryChanged: _updateSaveHistory,
        onPrecisionChanged: _updatePrecision,
      ),
    );
  }
}

class HistoryEntry {
  final String expression;
  final String result;
  final DateTime timestamp;

  HistoryEntry({
    required this.expression,
    required this.result,
    required this.timestamp,
  });
}

enum _LayoutMode {
  compactPortrait,
  compactLandscape,
  medium,
  expanded,
}

class CalculatorScreen extends StatefulWidget {
  final Color accentColor;
  final ThemeMode themeMode;
  final bool isDegreeMode;
  final bool hapticsEnabled;
  final bool saveHistory;
  final int precision;
  final ValueChanged<Color> onAccentChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onDegreeModeChanged;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onSaveHistoryChanged;
  final ValueChanged<int> onPrecisionChanged;

  const CalculatorScreen({
    super.key,
    required this.accentColor,
    required this.themeMode,
    required this.isDegreeMode,
    required this.hapticsEnabled,
    required this.saveHistory,
    required this.precision,
    required this.onAccentChanged,
    required this.onThemeModeChanged,
    required this.onDegreeModeChanged,
    required this.onHapticsChanged,
    required this.onSaveHistoryChanged,
    required this.onPrecisionChanged,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  String _preview = '';
  String? _errorText;
  bool _justEvaluated = false;
  bool _isInvMode = false;
  bool _showSideHistory = true;

  final List<HistoryEntry> _history = [];

  static const List<Color> _presetAccents = [
    Color(0xFFE0B4C0), // Soft Rose Pink (Default)
    Color(0xFFD49B8B), // Warm Peach
    Color(0xFFE57373), // Coral Red
    Color(0xFFFFB74D), // Amber Gold
    Color(0xFF81C784), // Sage Green
    Color(0xFF4DB6AC), // Teal
    Color(0xFF4FC3F7), // Sky Blue
    Color(0xFF7986CB), // Indigo
    Color(0xFFBA68C8), // Orchid Purple
    Color(0xFFF06292), // Flamingo Pink
    Color(0xFF90A4AE), // Cool Slate
    Color(0xFFDCE775), // Lime
  ];

  bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant CalculatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDegreeMode != widget.isDegreeMode ||
        oldWidget.precision != widget.precision) {
      _updatePreview();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _errorText = null;
      _updatePreview();
    });
  }

  void _insertText(String text, {bool clearIfEvaluated = false}) {
    setState(() {
      _errorText = null;
      if (_justEvaluated && clearIfEvaluated) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
        _justEvaluated = false;
        _updatePreview();
        return;
      }
      _justEvaluated = false;

      final value = _controller.value;
      final selection = value.selection;
      final start = selection.isValid ? selection.start : value.text.length;
      final end = selection.isValid ? selection.end : value.text.length;

      final newText = value.text.replaceRange(start, end, text);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + text.length),
      );
      _updatePreview();
    });
  }

  void _onDigitOrDot(String char) {
    if (char == '.') {
      final text = _controller.text;
      final match = RegExp(r'[0-9.]+$').firstMatch(text);
      if (match != null && match.group(0)!.contains('.')) return;
      if (match == null && (text.isEmpty || _justEvaluated)) {
        _insertText('0.', clearIfEvaluated: true);
        return;
      }
    }
    _insertText(char, clearIfEvaluated: true);
  }

  void _onOperator(String op) {
    final text = _controller.text;
    if (text.isEmpty && op != '-') return;
    _justEvaluated = false;
    if (text.isNotEmpty) {
      final last = text[text.length - 1];
      if (_isOperator(last) && !(op == '-' && (last == '×' || last == '÷'))) {
        setState(() {
          _controller.text = text.substring(0, text.length - 1) + op;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
        return;
      }
    }
    _insertText(op);
  }

  void _onFunction(String fn) {
    final text = _controller.text;
    if (_justEvaluated && text.isNotEmpty) {
      setState(() {
        _justEvaluated = false;
        _controller.text = '$fn$text)';
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      });
      return;
    }
    _insertText(fn);
  }

  void _onReciprocal() {
    final text = _controller.text;
    if (text.isEmpty) {
      _insertText('1/(');
      return;
    }
    setState(() {
      _justEvaluated = false;
      _errorText = null;
      final match = RegExp(r'([0-9.]+)$').firstMatch(text);
      if (match != null) {
        final numStr = match.group(1)!;
        final replaced = '${text.substring(0, match.start)}1/$numStr';
        _controller.text = replaced;
        _controller.selection = TextSelection.collapsed(offset: replaced.length);
      } else {
        _insertText('1/(');
      }
      _updatePreview();
    });
  }

  void _onToggleSign() {
    final text = _controller.text;
    if (text.isEmpty) {
      _insertText('-');
      return;
    }
    setState(() {
      _justEvaluated = false;
      _errorText = null;
      final match = RegExp(r'(\(-?[0-9.]+\)|-?[0-9.]+)$').firstMatch(text);
      if (match != null) {
        final token = match.group(1)!;
        String replacement;
        if (token.startsWith('(-') && token.endsWith(')')) {
          replacement = token.substring(2, token.length - 1);
        } else if (token.startsWith('-')) {
          replacement = token.substring(1);
        } else {
          replacement = '(-$token)';
        }
        final updated = text.substring(0, match.start) + replacement;
        _controller.text = updated;
        _controller.selection = TextSelection.collapsed(offset: updated.length);
      } else {
        _insertText('(-');
      }
      _updatePreview();
    });
  }

  void _onAllClear() {
    setState(() {
      _controller.clear();
      _preview = '';
      _errorText = null;
      _justEvaluated = false;
    });
  }

  void _onBackspace() {
    final value = _controller.value;
    final text = value.text;
    if (text.isEmpty) return;

    setState(() {
      _errorText = null;
      _justEvaluated = false;

      final sel = value.selection;
      final cursor = sel.isValid ? sel.start : text.length;
      if (sel.isValid && sel.start != sel.end) {
        final updated = text.replaceRange(sel.start, sel.end, '');
        _controller.value = TextEditingValue(
          text: updated,
          selection: TextSelection.collapsed(offset: sel.start),
        );
        _updatePreview();
        return;
      }

      if (cursor == 0) return;
      final before = text.substring(0, cursor);
      const tokens = [
        'Log10(',
        'Cbrt(',
        'Sqrt(',
        'Asin(',
        'Acos(',
        'Atan(',
        'Pow(',
        'Exp(',
        'Sin(',
        'Cos(',
        'Tan(',
        'Ln(',
        'Pi',
      ];
      int removeLen = 1;
      for (final t in tokens) {
        if (before.endsWith(t)) {
          removeLen = t.length;
          break;
        }
      }
      final updated =
          text.substring(0, cursor - removeLen) + text.substring(cursor);
      _controller.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: cursor - removeLen),
      );
      _updatePreview();
    });
  }

  void _onEquals() {
    final expr = _controller.text.trim();
    if (expr.isEmpty) return;
    try {
      final value = _evaluateExpression(expr);
      final formatted = _formatNumber(value);
      setState(() {
        if (widget.saveHistory && expr != formatted) {
          _history.insert(
            0,
            HistoryEntry(
              expression: expr,
              result: formatted,
              timestamp: DateTime.now(),
            ),
          );
        }
        _controller.text = formatted;
        _controller.selection = TextSelection.collapsed(
          offset: formatted.length,
        );
        _preview = '';
        _errorText = null;
        _justEvaluated = true;
      });
    } on _MathException catch (e) {
      setState(() {
        _errorText = e.message;
        _preview = '';
      });
    } catch (_) {
      setState(() {
        _errorText = 'Syntax Error';
        _preview = '';
      });
    }
  }

  void _updatePreview() {
    final expr = _controller.text.trim();
    if (expr.isEmpty) {
      _preview = '';
      return;
    }
    try {
      final value = _evaluateExpression(expr);
      final formatted = _formatNumber(value);
      _preview = formatted == expr ? '' : formatted;
    } catch (_) {
      _preview = '';
    }
  }

  bool _isOperator(String ch) {
    return ch == '+' || ch == '-' || ch == '−' || ch == '×' || ch == '÷';
  }

  double _evaluateExpression(String raw) {
    final parser = _ExpressionParser(raw, isDegreeMode: widget.isDegreeMode);
    return parser.parse();
  }

  String _formatNumber(double value) {
    if (value.isNaN) throw const _MathException('Undefined');
    if (value.isInfinite) throw const _MathException('Div By Zero Not Defined');
    if (value == -0.0) value = 0.0;

    if (value.abs() >= 1e12 || (value != 0 && value.abs() < 1e-9)) {
      return value
          .toStringAsExponential(6)
          .replaceAll(RegExp(r'\.?0+e'), 'e');
    }

    final fixed = double.parse(value.toStringAsPrecision(widget.precision));
    if (fixed == fixed.truncateToDouble() && fixed.abs() < 1e12) {
      return fixed.toInt().toString();
    }
    return fixed.toString();
  }

  void _copyResultToClipboard() {
    final textToCopy = _preview.isNotEmpty
        ? _preview
        : (_controller.text.isNotEmpty ? _controller.text : '');
    if (textToCopy.isEmpty) return;
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$textToCopy"'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openKeymapsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _KeymapsDialog(),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final char = event.character;
    final ctrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Global modifier shortcuts
    if (ctrlOrMeta) {
      if (key == LogicalKeyboardKey.keyC &&
          !_inputFocusNode.hasFocus) {
        _copyResultToClipboard();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyH) {
        if (MediaQuery.sizeOf(context).width >= 900) {
          setState(() => _showSideHistory = !_showSideHistory);
        } else {
          _openHistorySheet();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.comma) {
        _openSettingsPage();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyD) {
        widget.onDegreeModeChanged(!widget.isDegreeMode);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyI) {
        setState(() => _isInvMode = !_isInvMode);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.f1) {
      _openKeymapsDialog();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        char == '=') {
      _onEquals();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _onAllClear();
      return KeyEventResult.handled;
    }

    // If the expression field is already focused, let it accept any typed text
    if (_inputFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }

    // If not focused yet (e.g., after clicking a keypad button on PC),
    // focus the expression field and accept the typed character directly
    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      _onAllClear();
      return KeyEventResult.handled;
    }
    if (char != null && char.isNotEmpty && !ctrlOrMeta) {
      _inputFocusNode.requestFocus();
      _insertText(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  _LayoutMode _resolveLayoutMode(BoxConstraints c) {
    final w = c.maxWidth;
    final h = c.maxHeight;
    if (h < 560 || (w > h * 1.25 && w < 900)) {
      return _LayoutMode.compactLandscape;
    }
    if (w >= 900) {
      return _LayoutMode.expanded;
    }
    if (w >= 600) {
      return _LayoutMode.medium;
    }
    return _LayoutMode.compactPortrait;
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => SettingsPage(
          accentColor: widget.accentColor,
          themeMode: widget.themeMode,
          isDegreeMode: widget.isDegreeMode,
          hapticsEnabled: widget.hapticsEnabled,
          saveHistory: widget.saveHistory,
          precision: widget.precision,
          presets: _presetAccents,
          historyCount: _history.length,
          onAccentChanged: widget.onAccentChanged,
          onThemeModeChanged: widget.onThemeModeChanged,
          onDegreeModeChanged: widget.onDegreeModeChanged,
          onHapticsChanged: widget.onHapticsChanged,
          onSaveHistoryChanged: widget.onSaveHistoryChanged,
          onPrecisionChanged: widget.onPrecisionChanged,
          onClearHistory: () => setState(() => _history.clear()),
        ),
      ),
    );
  }

  void _openHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: 420,
        child: _HistoryPanel(
          history: _history,
          onUse: (entry) {
            setState(() {
              _controller.text = entry.expression;
              _controller.selection = TextSelection.collapsed(
                offset: entry.expression.length,
              );
              _justEvaluated = false;
              _errorText = null;
              _updatePreview();
            });
            Navigator.pop(ctx);
          },
          onClear: () {
            setState(() => _history.clear());
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mode = _resolveLayoutMode(constraints);

              switch (mode) {
                case _LayoutMode.compactPortrait:
                  return _buildVerticalCalculator(
                    hasSideHistory: false,
                    isCompact: true,
                  );

                case _LayoutMode.compactLandscape:
                  return _buildLandscapeCalculator();

                case _LayoutMode.medium:
                  return _buildVerticalCalculator(
                    hasSideHistory: false,
                    isCompact: false,
                  );

                case _LayoutMode.expanded:
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildVerticalCalculator(
                              hasSideHistory: true,
                              isCompact: false,
                            ),
                          ),
                        ),
                        if (_showSideHistory) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _HistoryPanel(
                                      history: _history,
                                      onUse: (entry) {
                                        setState(() {
                                          _controller.text = entry.expression;
                                          _controller.selection =
                                              TextSelection.collapsed(
                                            offset: entry.expression.length,
                                          );
                                          _justEvaluated = false;
                                          _errorText = null;
                                          _updatePreview();
                                        });
                                      },
                                      onClear: () {
                                        setState(() => _history.clear());
                                      },
                                    ),
                                  ),
                                  if (kIsWeb) ...[
                                    Divider(
                                      height: 1,
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    _DesktopQuickAccentBar(
                                      presets: _presetAccents.take(6).toList(),
                                      currentAccent: widget.accentColor,
                                      onSelect: widget.onAccentChanged,
                                      onOpenSettings: _openSettingsPage,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar({required bool hasSideHistory}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'History',
                icon: Icon(Icons.history_rounded, color: cs.onSurfaceVariant),
                onPressed: hasSideHistory
                    ? () => setState(
                          () => _showSideHistory = !_showSideHistory,
                        )
                    : _openHistorySheet,
              ),
              IconButton(
                tooltip: 'Copy result',
                icon: Icon(
                  Icons.copy_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: _copyResultToClipboard,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Settings',
                icon: Icon(
                  Icons.settings_outlined,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: _openSettingsPage,
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: cs.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'settings') {
                    _openSettingsPage();
                  } else if (value == 'keymaps') {
                    _openKeymapsDialog();
                  } else if (value == 'clear_history') {
                    setState(() => _history.clear());
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'keymaps',
                    child: ListTile(
                      leading: Icon(Icons.keyboard_outlined),
                      title: Text('Keymaps'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (_history.isNotEmpty)
                    const PopupMenuItem(
                      value: 'clear_history',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Clear history'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisplay({required bool compact}) {
    final cs = Theme.of(context).colorScheme;
    final exprFontSize =
        compact ? 26.0 : (_controller.text.length > 14 ? 30.0 : 40.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_errorText != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    _errorText!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: compact ? 18 : 22,
                      fontWeight: FontWeight.w600,
                      color: cs.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.close_rounded, color: cs.error, size: 22),
              ],
            )
          else
            TextField(
              controller: _controller,
              focusNode: _inputFocusNode,
              autofocus: _isDesktopPlatform,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.text,
              showCursor: true,
              style: TextStyle(
                fontSize: exprFontSize,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _onEquals(),
            ),
          SizedBox(height: compact ? 2 : 6),
          SizedBox(
            height: compact ? 22 : 30,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _preview,
                style: TextStyle(
                  fontSize: compact ? 17 : 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
        ],
      ),
    );
  }

  Widget _buildVerticalCalculator({
    required bool hasSideHistory,
    required bool isCompact,
  }) {
    final cs = Theme.of(context).colorScheme;
    final rows = [..._scientificRows(cs), ..._standardRows(cs)];

    return Column(
      children: [
        _buildToolbar(hasSideHistory: hasSideHistory),
        Expanded(
          flex: 3,
          child: _buildDisplay(compact: false),
        ),
        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Column(
              children: rows.map((r) => _buildRow(r)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeCalculator() {
    final cs = Theme.of(context).colorScheme;
    final sciRows = _scientificRows(cs);
    final stdRows = _standardRows(cs);

    return Column(
      children: [
        _buildToolbar(hasSideHistory: false),
        _buildDisplay(compact: true),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    children: sciRows.map((r) => _buildRow(r)).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: stdRows.map((r) => _buildRow(r)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<List<_CalcBtnData>> _scientificRows(ColorScheme cs) {
    return [
      [
        _sciBtn(
          _isInvMode ? 'Sqr' : 'Sqrt(',
          cs,
          () => _onFunction(_isInvMode ? '^2' : 'Sqrt('),
        ),
        _sciBtn('Pi', cs, () => _insertText('Pi', clearIfEvaluated: true)),
        _sciBtn('!', cs, () => _insertText('!')),
        _sciBtn('e', cs, () => _insertText('e', clearIfEvaluated: true)),
      ],
      [
        _CalcBtnData(
          label: widget.isDegreeMode ? 'DEG' : 'RAD',
          bg: cs.secondaryContainer,
          fg: cs.onSecondaryContainer,
          fontSize: 15,
          onTap: () => widget.onDegreeModeChanged(!widget.isDegreeMode),
        ),
        _sciBtn(
          _isInvMode ? 'Asin(' : 'Sin(',
          cs,
          () => _onFunction(_isInvMode ? 'Asin(' : 'Sin('),
        ),
        _sciBtn(
          _isInvMode ? 'Acos(' : 'Cos(',
          cs,
          () => _onFunction(_isInvMode ? 'Acos(' : 'Cos('),
        ),
        _sciBtn(
          _isInvMode ? 'Atan(' : 'Tan(',
          cs,
          () => _onFunction(_isInvMode ? 'Atan(' : 'Tan('),
        ),
      ],
      [
        _CalcBtnData(
          label: 'Inv',
          bg: _isInvMode ? cs.primaryContainer : cs.surfaceContainerHigh,
          fg: _isInvMode ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontSize: 15,
          onTap: () => setState(() => _isInvMode = !_isInvMode),
        ),
        _sciBtn(
          _isInvMode ? 'Exp(' : 'Ln(',
          cs,
          () => _onFunction(_isInvMode ? 'Exp(' : 'Ln('),
        ),
        _sciBtn(
          _isInvMode ? '10^(' : 'Log10(',
          cs,
          () => _onFunction(_isInvMode ? '10^(' : 'Log10('),
        ),
        _sciBtn('Pow(', cs, () => _onFunction('Pow(')),
      ],
      [
        _sciBtn('1/x', cs, _onReciprocal),
        _sciBtn('+/-', cs, _onToggleSign),
        _sciBtn('Cbrt(', cs, () => _onFunction('Cbrt(')),
        _CalcBtnData(
          icon: Icons.backspace_outlined,
          bg: cs.surfaceContainerHigh,
          fg: cs.onSurface,
          onTap: _onBackspace,
          onLongPress: _onAllClear,
        ),
      ],
    ];
  }

  List<List<_CalcBtnData>> _standardRows(ColorScheme cs) {
    return [
      [
        _CalcBtnData(
          label: 'AC',
          bg: cs.tertiaryContainer,
          fg: cs.onTertiaryContainer,
          fontSize: 18,
          onTap: _onAllClear,
        ),
        _opBtn('(', cs, () => _insertText('(')),
        _opBtn(')', cs, () => _insertText(')')),
        _opBtn('÷', cs, () => _onOperator('÷'), fontSize: 24),
      ],
      [
        _digitBtn('7', cs),
        _digitBtn('8', cs),
        _digitBtn('9', cs),
        _opBtn('×', cs, () => _onOperator('×'), fontSize: 22),
      ],
      [
        _digitBtn('4', cs),
        _digitBtn('5', cs),
        _digitBtn('6', cs),
        _opBtn('-', cs, () => _onOperator('-'), fontSize: 24),
      ],
      [
        _digitBtn('1', cs),
        _digitBtn('2', cs),
        _digitBtn('3', cs),
        _opBtn('+', cs, () => _onOperator('+'), fontSize: 24),
      ],
      [
        _digitBtn('0', cs),
        _digitBtn('.', cs),
        _digitBtn(',', cs),
        _CalcBtnData(
          label: '=',
          bg: cs.primary,
          fg: cs.onPrimary,
          fontSize: 26,
          onTap: _onEquals,
        ),
      ],
    ];
  }

  _CalcBtnData _sciBtn(String label, ColorScheme cs, VoidCallback onTap) {
    return _CalcBtnData(
      label: label,
      bg: cs.surfaceContainerHigh,
      fg: cs.onSurfaceVariant,
      fontSize: 15,
      onTap: onTap,
    );
  }

  _CalcBtnData _digitBtn(String digit, ColorScheme cs) {
    return _CalcBtnData(
      label: digit,
      bg: cs.surfaceContainerHighest,
      fg: cs.onSurface,
      fontSize: 20,
      onTap: () => _onDigitOrDot(digit),
    );
  }

  _CalcBtnData _opBtn(
    String op,
    ColorScheme cs,
    VoidCallback onTap, {
    double fontSize = 18,
  }) {
    return _CalcBtnData(
      label: op,
      bg: cs.secondaryContainer,
      fg: cs.onSecondaryContainer,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  Widget _buildRow(List<_CalcBtnData> items) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3.5),
                  child: _CalcButton(
                    data: item,
                    hapticsEnabled: widget.hapticsEnabled,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CalcBtnData {
  final String? label;
  final IconData? icon;
  final Color bg;
  final Color fg;
  final double fontSize;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CalcBtnData({
    this.label,
    this.icon,
    required this.bg,
    required this.fg,
    this.fontSize = 18,
    required this.onTap,
    this.onLongPress,
  });
}

class _CalcButton extends StatefulWidget {
  final _CalcBtnData data;
  final bool hapticsEnabled;

  const _CalcButton({required this.data, required this.hapticsEnabled});

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: Material(
        color: widget.data.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_pressed ? 10 : 14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (widget.hapticsEnabled) {
              HapticFeedback.lightImpact();
            }
            widget.data.onTap();
          },
          onLongPress: widget.data.onLongPress,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          mouseCursor: SystemMouseCursors.click,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: widget.data.icon != null
                    ? Icon(
                        widget.data.icon,
                        color: widget.data.fg,
                        size: 20,
                        semanticLabel:
                            widget.data.icon == Icons.backspace_outlined
                                ? 'Backspace'
                                : null,
                      )
                    : Text(
                        widget.data.label ?? '',
                        maxLines: 1,
                        style: TextStyle(
                          color: widget.data.fg,
                          fontSize: widget.data.fontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  final List<HistoryEntry> history;
  final ValueChanged<HistoryEntry> onUse;
  final VoidCallback onClear;

  const _HistoryPanel({
    required this.history,
    required this.onUse,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (history.isNotEmpty)
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
            ],
          ),
        ),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 38,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No calculations yet',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.expression} =',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.result,
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => onUse(item),
                            child: const Text(
                              'Use',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DesktopQuickAccentBar extends StatelessWidget {
  final List<Color> presets;
  final Color currentAccent;
  final ValueChanged<Color> onSelect;
  final VoidCallback onOpenSettings;

  const _DesktopQuickAccentBar({
    required this.presets,
    required this.currentAccent,
    required this.onSelect,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Accent',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((c) {
                final selected = c.toARGB32() == currentAccent.toARGB32();
                return InkWell(
                  onTap: () => onSelect(c),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: cs.onSurface, width: 2.5)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          IconButton(
            tooltip: 'Open Settings',
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final Color accentColor;
  final ThemeMode themeMode;
  final bool isDegreeMode;
  final bool hapticsEnabled;
  final bool saveHistory;
  final int precision;
  final List<Color> presets;
  final int historyCount;
  final ValueChanged<Color> onAccentChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onDegreeModeChanged;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onSaveHistoryChanged;
  final ValueChanged<int> onPrecisionChanged;
  final VoidCallback onClearHistory;

  const SettingsPage({
    super.key,
    required this.accentColor,
    required this.themeMode,
    required this.isDegreeMode,
    required this.hapticsEnabled,
    required this.saveHistory,
    required this.precision,
    required this.presets,
    required this.historyCount,
    required this.onAccentChanged,
    required this.onThemeModeChanged,
    required this.onDegreeModeChanged,
    required this.onHapticsChanged,
    required this.onSaveHistoryChanged,
    required this.onPrecisionChanged,
    required this.onClearHistory,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _repositoryUrl =
      'https://github.com/Chill-Astro/Digito-Calculator';
  static const _licenseText = '''
MIT License

Copyright (c) 2026 Chill-Astro Software

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

  late HSLColor _hsl;
  late ThemeMode _themeMode;
  late bool _isDegreeMode;
  late bool _hapticsEnabled;
  late bool _saveHistory;
  late int _precision;
  late int _historyCount;

  @override
  void initState() {
    super.initState();
    _hsl = HSLColor.fromColor(widget.accentColor);
    _themeMode = widget.themeMode;
    _isDegreeMode = widget.isDegreeMode;
    _hapticsEnabled = widget.hapticsEnabled;
    _saveHistory = widget.saveHistory;
    _precision = widget.precision;
    _historyCount = widget.historyCount;
  }

  void _applyHsl(HSLColor hsl) {
    setState(() => _hsl = hsl);
    widget.onAccentChanged(hsl.toColor());
  }

  Future<void> _showRepository() async {
    try {
      final opened = await launchUrl(
        Uri.parse(_repositoryUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the Digito repository'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the Digito repository'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showLicense() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('MIT License'),
        content: const SizedBox(
          width: 480,
          child: SingleChildScrollView(child: Text(_licenseText)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = _hsl.toColor();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primaryContainer,
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.28),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.calculate_rounded,
                        size: 56,
                        color: cs.onPrimaryContainer,
                        semanticLabel: 'Digito calculator logo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Digito',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Developer: Chill-Astro Software',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _showRepository,
                          icon: const Icon(Icons.code_rounded),
                          label: const Text('Repository'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _showLicense,
                          icon: const Icon(Icons.info_outline_rounded),
                          label: const Text('License'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(),
              ),
              _sectionHeader(context, 'Appearance'),
              Card(
                color: cs.surfaceContainerLow,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Mode',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('System'),
                            ),
                          ],
                          selected: {_themeMode},
                          onSelectionChanged: (s) {
                            setState(() => _themeMode = s.first);
                            widget.onThemeModeChanged(s.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Accent Color',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: widget.presets.map((c) {
                          final selected =
                              c.toARGB32() == activeColor.toARGB32();
                          return GestureDetector(
                            onTap: () => _applyHsl(HSLColor.fromColor(c)),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(color: cs.onSurface, width: 3)
                                    : Border.all(
                                        color: cs.outlineVariant
                                            .withValues(alpha: 0.4),
                                      ),
                              ),
                              child: selected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: ThemeData
                                                  .estimateBrightnessForColor(
                                                      c) ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const SizedBox(width: 44, child: Text('Hue')),
                          Expanded(
                            child: Slider(
                              value: _hsl.hue,
                              min: 0,
                              max: 360,
                              activeColor: activeColor,
                              onChanged: (v) => _applyHsl(_hsl.withHue(v)),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 44, child: Text('Sat')),
                          Expanded(
                            child: Slider(
                              value: _hsl.saturation,
                              min: 0.1,
                              max: 1.0,
                              activeColor: activeColor,
                              onChanged: (v) =>
                                  _applyHsl(_hsl.withSaturation(v)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _sectionHeader(context, 'Calculator'),
              Card(
                color: cs.surfaceContainerLow,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Angle Unit: Degrees'),
                      subtitle: Text(
                        _isDegreeMode
                            ? 'Trigonometry uses Degrees (DEG)'
                            : 'Trigonometry uses Radians (RAD)',
                      ),
                      value: _isDegreeMode,
                      onChanged: (v) {
                        setState(() => _isDegreeMode = v);
                        widget.onDegreeModeChanged(v);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decimal Precision',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text('$_precision significant digits'),
                          Slider(
                            value: _precision.toDouble(),
                            min: 4,
                            max: 15,
                            divisions: 11,
                            label: '$_precision',
                            onChanged: (v) {
                              final p = v.round();
                              setState(() => _precision = p);
                              widget.onPrecisionChanged(p);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Haptic Feedback'),
                      subtitle: const Text('Vibrate on button tap on mobile'),
                      value: _hapticsEnabled,
                      onChanged: (v) {
                        setState(() => _hapticsEnabled = v);
                        widget.onHapticsChanged(v);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Save Calculation History'),
                      subtitle:
                          const Text('Record evaluated expressions in history'),
                      value: _saveHistory,
                      onChanged: (v) {
                        setState(() => _saveHistory = v);
                        widget.onSaveHistoryChanged(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionHeader(context, 'Data & About'),
              Card(
                color: cs.surfaceContainerLow,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: const Text('Clear History'),
                      subtitle: Text('$_historyCount saved entries'),
                      enabled: _historyCount > 0,
                      onTap: () {
                        widget.onClearHistory();
                        setState(() => _historyCount = 0);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('History cleared'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.keyboard_outlined),
                      title: const Text('Keymaps & Shortcuts'),
                      subtitle: const Text('View PC keyboard shortcuts (F1)'),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => const _KeymapsDialog(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _KeymapsDialog extends StatelessWidget {
  const _KeymapsDialog();

  static const List<MapEntry<String, String>> _shortcuts = [
    MapEntry('Type anything', 'Expression field accepts full text & functions'),
    MapEntry('Enter / =', 'Evaluate expression'),
    MapEntry('Backspace', 'Delete character or function'),
    MapEntry('Esc', 'All Clear (AC)'),
    MapEntry('Ctrl/Cmd + C', 'Copy result or selected text'),
    MapEntry('Ctrl/Cmd + H', 'Toggle History panel'),
    MapEntry('Ctrl/Cmd + D', 'Toggle DEG / RAD'),
    MapEntry('Ctrl/Cmd + I', 'Toggle Inv mode'),
    MapEntry('Ctrl/Cmd + ,', 'Open Settings'),
    MapEntry('F1', 'Show this Keymaps dialog'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Keymaps & Shortcuts'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _shortcuts
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            e.key,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _MathException implements Exception {
  final String message;
  const _MathException(this.message);
}

class _ExpressionParser {
  final String input;
  final bool isDegreeMode;
  int _pos = 0;

  _ExpressionParser(String raw, {required this.isDegreeMode})
      : input = _balanceParentheses(raw.replaceAll(' ', ''));

  static String _balanceParentheses(String s) {
    final open = '('.allMatches(s).length;
    final close = ')'.allMatches(s).length;
    if (open > close) {
      return s + (')' * (open - close));
    }
    return s;
  }

  double parse() {
    if (input.isEmpty) return 0;
    final result = _parseAddSub();
    if (_pos < input.length) {
      throw const _MathException('Syntax Error');
    }
    return result;
  }

  double _parseAddSub() {
    var left = _parseMulDiv();
    while (_pos < input.length) {
      final ch = input[_pos];
      if (ch == '+' || ch == '-' || ch == '−') {
        _pos++;
        final right = _parseMulDiv();
        left = (ch == '+') ? left + right : left - right;
      } else {
        break;
      }
    }
    return left;
  }

  double _parseMulDiv() {
    var left = _parsePower();
    while (_pos < input.length) {
      final ch = input[_pos];
      if (ch == '×' || ch == '*' || ch == '÷' || ch == '/') {
        _pos++;
        final right = _parsePower();
        if (ch == '×' || ch == '*') {
          left *= right;
        } else {
          if (right == 0) throw const _MathException('Div By Zero Not Defined');
          left /= right;
        }
      } else {
        break;
      }
    }
    return left;
  }

  double _parsePower() {
    var base = _parseUnary();
    if (_pos < input.length && input[_pos] == '^') {
      _pos++;
      final exp = _parsePower();
      return math.pow(base, exp).toDouble();
    }
    return base;
  }

  double _parseUnary() {
    if (_pos < input.length) {
      final ch = input[_pos];
      if (ch == '+') {
        _pos++;
        return _parseUnary();
      }
      if (ch == '-' || ch == '−') {
        _pos++;
        return -_parseUnary();
      }
    }
    return _parsePostfix();
  }

  double _parsePostfix() {
    var value = _parsePrimary();
    while (_pos < input.length) {
      if (input[_pos] == '!') {
        _pos++;
        value = _factorial(value);
      } else {
        break;
      }
    }
    return value;
  }

  double _parsePrimary() {
    if (_pos >= input.length) {
      throw const _MathException('Syntax Error');
    }

    final ch = input[_pos];

    if (ch == '(') {
      _pos++;
      final val = _parseAddSub();
      if (_pos < input.length && input[_pos] == ')') {
        _pos++;
      } else {
        throw const _MathException('Syntax Error');
      }
      return val;
    }

    if (input.startsWith('Pi', _pos) || input.startsWith('pi', _pos)) {
      _pos += 2;
      return math.pi;
    }
    if (ch == 'e') {
      _pos++;
      return math.e;
    }

    if (input.startsWith('Pow(', _pos) || input.startsWith('pow(', _pos)) {
      _pos += 4;
      final base = _parseAddSub();
      if (_pos >= input.length || input[_pos] != ',') {
        throw const _MathException('Syntax Error');
      }
      _pos++;
      final exp = _parseAddSub();
      if (_pos >= input.length || input[_pos] != ')') {
        throw const _MathException('Syntax Error');
      }
      _pos++;
      return math.pow(base, exp).toDouble();
    }

    const singleArgFuncs = [
      'Log10(',
      'log10(',
      'Log(',
      'log(',
      'Sqrt(',
      'sqrt(',
      'Cbrt(',
      'cbrt(',
      'Asin(',
      'asin(',
      'Acos(',
      'acos(',
      'Atan(',
      'atan(',
      'Sin(',
      'sin(',
      'Cos(',
      'cos(',
      'Tan(',
      'tan(',
      'Exp(',
      'exp(',
      'Ln(',
      'ln(',
    ];

    for (final fn in singleArgFuncs) {
      if (input.startsWith(fn, _pos)) {
        _pos += fn.length;
        final arg = _parseAddSub();
        if (_pos >= input.length || input[_pos] != ')') {
          throw const _MathException('Syntax Error');
        }
        _pos++;
        final name = fn.substring(0, fn.length - 1).toLowerCase();
        switch (name) {
          case 'sqrt':
            if (arg < 0) throw const _MathException('Syntax Error');
            return math.sqrt(arg);
          case 'cbrt':
            return arg < 0
                ? -math.pow(-arg, 1 / 3).toDouble()
                : math.pow(arg, 1 / 3).toDouble();
          case 'sin':
            return math.sin(_toRad(arg));
          case 'cos':
            return math.cos(_toRad(arg));
          case 'tan':
            return math.tan(_toRad(arg));
          case 'asin':
            if (arg < -1 || arg > 1) throw const _MathException('Syntax Error');
            return _fromRad(math.asin(arg));
          case 'acos':
            if (arg < -1 || arg > 1) throw const _MathException('Syntax Error');
            return _fromRad(math.acos(arg));
          case 'atan':
            return _fromRad(math.atan(arg));
          case 'ln':
            if (arg <= 0) throw const _MathException('Syntax Error');
            return math.log(arg);
          case 'log10':
          case 'log':
            if (arg <= 0) throw const _MathException('Syntax Error');
            return math.log(arg) / math.ln10;
          case 'exp':
            return math.exp(arg);
        }
      }
    }

    final start = _pos;
    while (_pos < input.length && RegExp(r'[0-9.]').hasMatch(input[_pos])) {
      _pos++;
    }
    if (_pos == start) {
      throw const _MathException('Syntax Error');
    }
    final parsed = double.tryParse(input.substring(start, _pos));
    if (parsed == null) throw const _MathException('Syntax Error');
    return parsed;
  }

  double _toRad(double val) => isDegreeMode ? val * math.pi / 180.0 : val;
  double _fromRad(double rad) => isDegreeMode ? rad * 180.0 / math.pi : rad;

  double _factorial(double n) {
    if (n < 0 || n != n.truncateToDouble() || n > 170) {
      throw const _MathException('Syntax Error');
    }
    double res = 1;
    for (int i = 2; i <= n.toInt(); i++) {
      res *= i;
    }
    return res;
  }
}
