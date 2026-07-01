import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/search_provider.dart';
import '../../Widgets/state/empty_state.dart';
import '../../Widgets/user_info_sheet.dart';
import '../../core/haptics.dart';
import '../Deatiled_Screens/program_chat_screen.dart';

/// Full-screen global search overlay (UX appendix §14). 300ms debounce, recent
/// searches on empty query, results grouped by scope. People → info sheet,
/// messages → program chat; other types display inline.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  static const _scopes = ['all', 'courses', 'materials', 'users', 'assignments', 'messages'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().loadRecent();
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SearchProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: context.read<SearchProvider>().onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Search courses, people, materials…',
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      context.read<SearchProvider>().onQueryChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _scopes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _scopes[i];
                return ChoiceChip(
                  label: Text(s[0].toUpperCase() + s.substring(1)),
                  selected: p.scope == s,
                  onSelected: (_) {
                    Haptics.light();
                    context.read<SearchProvider>().setScope(s);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(p, cs)),
        ],
      ),
    );
  }

  Widget _body(SearchProvider p, ColorScheme cs) {
    if (p.query.trim().length < 2) {
      // Recent searches / hint
      if (p.recent.isEmpty) {
        return const EmptyState(
          icon: Icons.search,
          title: 'Search everything',
          message: 'Find courses, materials, people, assignments, and messages.',
        );
      }
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Recent', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const Spacer(),
                TextButton(
                  onPressed: context.read<SearchProvider>().clearRecent,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          ...p.recent.map((r) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(r),
                onTap: () {
                  _controller.text = r;
                  context.read<SearchProvider>().onQueryChanged(r);
                },
              )),
        ],
      );
    }

    if (p.loading && p.results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = p.results;
    if (r == null || r.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        message: 'Nothing matched "${p.query}".',
      );
    }

    return ListView(
      children: [
        _group(cs, 'People', r.users, (u) => _userTile(u)),
        _group(cs, 'Courses', r.courses, (c) => _simpleTile(Icons.menu_book, c['name'], c['type'])),
        _group(cs, 'Assignments', r.assignments, (a) => _simpleTile(Icons.assignment, a['title'], a['type'])),
        _group(cs, 'Materials', r.materials, (m) => _simpleTile(Icons.insert_drive_file, m['title'], m['fileType'])),
        _group(cs, 'Messages', r.messages, (m) => _messageTile(m)),
      ],
    );
  }

  Widget _group(ColorScheme cs, String title, List<Map<String, dynamic>> items,
      Widget Function(Map<String, dynamic>) tile) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text('$title (${items.length})',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, fontSize: 13)),
        ),
        ...items.map(tile),
        const Divider(height: 1),
      ],
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
      title: Text('${u['name'] ?? 'User'}'),
      subtitle: Text('${u['email'] ?? ''}${u['role'] != null ? ' · ${u['role']}' : ''}'),
      onTap: () => showUserInfoSheet(
        context,
        name: '${u['name'] ?? 'User'}',
        userId: u['id']?.toString(),
        avatar: u['avatar']?.toString(),
        role: u['role']?.toString(),
      ),
    );
  }

  Widget _messageTile(Map<String, dynamic> m) {
    return ListTile(
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text('${m['content'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('from ${m['senderName'] ?? 'someone'}'),
      onTap: () {
        final pid = m['programId']?.toString();
        if (pid != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProgramChatScreen(programId: pid, programName: 'Chat'),
            ),
          );
        }
      },
    );
  }

  Widget _simpleTile(IconData icon, dynamic title, dynamic subtitle) {
    return ListTile(
      leading: Icon(icon),
      title: Text('${title ?? ''}'),
      subtitle: subtitle == null ? null : Text('$subtitle'),
    );
  }
}
