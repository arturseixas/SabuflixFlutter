import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/watched_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/media_card.dart';

class WatchedHistoryScreen extends StatelessWidget {
  const WatchedHistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
            'Os títulos marcados como assistidos serão removidos deste perfil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Limpar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (clear == true && context.mounted) {
      await context.read<WatchedProvider>().clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatchedProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final columns = (width / 180).floor().clamp(2, 7);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      appBar: AppBar(
        title: Text('Já assistidos', style: SabuflixTheme.title(fontSize: 20)),
        actions: [
          if (provider.items.isNotEmpty)
            TextButton(
                onPressed: () => _confirmClear(context),
                child: const Text('Limpar')),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 52, color: SabuflixTheme.textMuted),
                      const SizedBox(height: 16),
                      Text('Nenhum título marcado',
                          style: SabuflixTheme.title(fontSize: 17)),
                      const SizedBox(height: 7),
                      Text('Use a ação “Marcar como assistido” nos detalhes.',
                          style: SabuflixTheme.body(fontSize: 13)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: provider.items.length,
                  itemBuilder: (context, index) =>
                      MediaCard(media: provider.items[index]),
                ),
    );
  }
}
