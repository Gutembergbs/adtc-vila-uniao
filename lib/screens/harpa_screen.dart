import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/bible_api_service.dart';
import '../services/hymn_catalog_service.dart';

/// Referências de hinos sem reproduzir letras protegidas por direitos autorais.
class _ReferenciaHino {
  final int numero;
  final String titulo;

  const _ReferenciaHino(this.numero, this.titulo);
}

class HarpaScreen extends StatefulWidget {
  const HarpaScreen({super.key});

  @override
  State<HarpaScreen> createState() => _HarpaScreenState();
}

class _HarpaScreenState extends State<HarpaScreen> {
  final _buscaController = TextEditingController();
  Set<int> _favoritos = {};
  List<_ReferenciaHino> _hinos = [];
  String? _hymnError;
  bool _mostrarFavoritos = false;
  bool _mostrarBiblia = false;
  final _bibleApi = BibleApiService();
  List<BibleBook> _books = [];
  BibleBook? _selectedBook;
  List<int> _chapters = [];
  BibleChapter? _currentChapter;
  bool _loadingBible = true;
  String? _bibleError;
  int _bibleRequestId = 0;

  @override
  void initState() {
    super.initState();
    _carregarFavoritos();
    _carregarCatalogoHinos();
    _loadBibleBooks();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _bibleApi.dispose();
    super.dispose();
  }

  /// Restaura os números favoritos deste aparelho.
  Future<void> _carregarFavoritos() async {
    final preferencias = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _favoritos =
          preferencias
              .getStringList('harpa_favoritos')
              ?.map(int.tryParse)
              .whereType<int>()
              .toSet() ??
          {},
    );
  }

  /// Alterna favorito e persiste a escolha localmente.
  Future<void> _alternarFavorito(int numero) async {
    final novosFavoritos = Set<int>.from(_favoritos);
    if (!novosFavoritos.add(numero)) novosFavoritos.remove(numero);
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setStringList(
      'harpa_favoritos',
      novosFavoritos.map((item) => item.toString()).toList(),
    );
    if (mounted) setState(() => _favoritos = novosFavoritos);
  }

  Future<void> _carregarCatalogoHinos() async {
    try {
      final entries = await HymnCatalogService.load();
      if (!mounted) return;
      setState(() {
        _hinos = entries
            .map((hymn) => _ReferenciaHino(hymn.number, hymn.title))
            .toList();
        _hymnError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _hymnError = 'Não foi possível carregar os hinos: $error');
    }
  }

  /// Abre uma busca externa para consultar uma edição autorizada do hino.
  Future<void> _abrirReferencia(_ReferenciaHino hino) async {
    final consulta = Uri.https('www.google.com', '/search', {
      'q': 'Harpa Cristã ${hino.numero} ${hino.titulo} fonte autorizada',
    });
    await launchUrl(consulta, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadBibleBooks() async {
    try {
      final books = await _bibleApi.listBooks();
      if (!mounted) return;
      setState(() {
        _books = books;
        _selectedBook = books.first;
        _loadingBible = false;
      });
      await _selectBibleBook(books.first);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBible = false;
        _bibleError = 'Não foi possível carregar os livros da Bíblia: $error';
      });
    }
  }

  Future<void> _selectBibleBook(BibleBook book) async {
    final requestId = ++_bibleRequestId;
    setState(() {
      _selectedBook = book;
      _loadingBible = true;
      _bibleError = null;
      _currentChapter = null;
    });
    try {
      final chapters = await _bibleApi.listChapters(book);
      final content = await _bibleApi.getChapter(book, chapters.first);
      if (!mounted || requestId != _bibleRequestId) return;
      setState(() {
        _chapters = chapters;
        _currentChapter = content;
        _loadingBible = false;
      });
    } catch (error) {
      if (!mounted || requestId != _bibleRequestId) return;
      setState(() {
        _loadingBible = false;
        _bibleError = 'Não foi possível carregar ${book.name}: $error';
      });
    }
  }

  Future<void> _loadBibleChapter(int chapter) async {
    final book = _selectedBook;
    if (book == null) return;
    final requestId = ++_bibleRequestId;
    setState(() {
      _loadingBible = true;
      _bibleError = null;
    });
    try {
      final content = await _bibleApi.getChapter(book, chapter);
      if (!mounted || requestId != _bibleRequestId) return;
      setState(() {
        _currentChapter = content;
        _loadingBible = false;
      });
    } catch (error) {
      if (!mounted || requestId != _bibleRequestId) return;
      setState(() {
        _loadingBible = false;
        _bibleError = 'Não foi possível carregar o capítulo: $error';
      });
    }
  }

  Future<void> _searchBiblePassage(String reference) async {
    final requestId = ++_bibleRequestId;
    setState(() {
      _loadingBible = true;
      _bibleError = null;
    });
    try {
      final result = await _bibleApi.searchPassage(reference);
      if (!mounted || requestId != _bibleRequestId) return;
      setState(() {
        _currentChapter = result;
        _loadingBible = false;
      });
    } catch (error) {
      if (!mounted || requestId != _bibleRequestId) return;
      setState(() {
        _loadingBible = false;
        _bibleError = 'Referência não encontrada: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final termo = _buscaController.text.trim().toLowerCase();
    final hinosFiltrados = _hinos.where((hino) {
      final correspondeBusca =
          termo.isEmpty ||
          hino.numero.toString().contains(termo) ||
          hino.titulo.toLowerCase().contains(termo);
      return correspondeBusca &&
          (!_mostrarFavoritos || _favoritos.contains(hino.numero));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Harpa Cristã e Bíblia')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Harpa Cristã'),
                  icon: Icon(Icons.library_music_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Bíblia'),
                  icon: Icon(Icons.menu_book_outlined),
                ),
              ],
              selected: {_mostrarBiblia},
              onSelectionChanged: (selecionado) =>
                  setState(() => _mostrarBiblia = selecionado.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _buscaController,
              textInputAction: _mostrarBiblia
                  ? TextInputAction.search
                  : TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: _mostrarBiblia ? _searchBiblePassage : null,
              decoration: InputDecoration(
                hintText: _mostrarBiblia
                    ? 'Buscar referência bíblica'
                    : 'Buscar por número, hino ou autor',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _buscaController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _buscaController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          if (!_mostrarBiblia)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Todos')),
                      ButtonSegment(value: true, label: Text('Favoritos')),
                    ],
                    selected: {_mostrarFavoritos},
                    onSelectionChanged: (selecionados) =>
                        setState(() => _mostrarFavoritos = selecionados.first),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'As letras são consultadas em fontes externas autorizadas; o app não armazena nem republica o hinário.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ),
              ],
            ),
          Expanded(
            child: _mostrarBiblia
                ? _construirLeitorBiblia()
                : _hymnError != null
                ? Center(child: Text(_hymnError!))
                : _hinos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : hinosFiltrados.isEmpty
                ? const Center(child: Text('Nenhuma referência encontrada.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: hinosFiltrados.length,
                    itemBuilder: (context, index) {
                      final hino = hinosFiltrados[index];
                      final favorito = _favoritos.contains(hino.numero);
                      return Card(
                        child: ListTile(
                          onTap: () => _abrirReferencia(hino),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEAF4F2),
                            child: Text(
                              hino.numero.toString(),
                              style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(hino.titulo),
                          subtitle: const Text('Harpa Cristã'),
                          trailing: IconButton(
                            tooltip: favorito
                                ? 'Remover dos favoritos'
                                : 'Adicionar aos favoritos',
                            onPressed: () => _alternarFavorito(hino.numero),
                            icon: Icon(
                              favorito
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: favorito
                                  ? const Color(0xFFD97706)
                                  : Colors.blueGrey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _construirLeitorBiblia() {
    if (_loadingBible && _books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bibleError != null && _books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_bibleError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadBibleBooks,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digite uma referência, por exemplo: João 3:16. Ou escolha um livro e capítulo.',
                style: TextStyle(color: Color(0xFF475569)),
              ),
              SizedBox(height: 4),
              Text(
                'Versão: Bíblia Portuguesa Mundial',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
        if (_books.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<BibleBook>(
                    key: ValueKey(_selectedBook?.id),
                    initialValue: _selectedBook,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Livro',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    items: _books
                        .map(
                          (book) => DropdownMenuItem(
                            value: book,
                            child: Text(
                              book.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (book) {
                      if (book != null) _selectBibleBook(book);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(
                      '${_selectedBook?.id}-${_chapters.length}-${_currentChapter?.chapter}',
                    ),
                    initialValue: _chapters.contains(_currentChapter?.chapter)
                        ? _currentChapter!.chapter
                        : (_chapters.isEmpty ? null : _chapters.first),
                    decoration: const InputDecoration(labelText: 'Capítulo'),
                    items: _chapters
                        .map(
                          (chapter) => DropdownMenuItem(
                            value: chapter,
                            child: Text('$chapter'),
                          ),
                        )
                        .toList(),
                    onChanged: (chapter) {
                      if (chapter != null) _loadBibleChapter(chapter);
                    },
                  ),
                ),
              ],
            ),
          ),
        if (_bibleError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _bibleError!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadingBible
                      ? null
                      : () {
                          final selectedBook = _selectedBook;
                          if (selectedBook == null) {
                            _loadBibleBooks();
                          } else if (_currentChapter == null) {
                            _selectBibleBook(selectedBook);
                          } else {
                            _loadBibleChapter(_currentChapter!.chapter);
                          }
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar'),
                ),
              ],
            ),
          ),
        if (_loadingBible)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: _currentChapter == null
              ? const Center(child: Text('Selecione um livro e capítulo.'))
              : ListView(
                  key: ValueKey(
                    '${_currentChapter!.bookName}:${_currentChapter!.chapter}:${_currentChapter!.verses.length}',
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      _currentChapter!.reference,
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._currentChapter!.verses.map(
                      (verse) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(
                              context,
                            ).style.copyWith(height: 1.55, fontSize: 16),
                            children: [
                              TextSpan(
                                text: '${verse.number} ',
                                style: const TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: verse.text),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bíblia Portuguesa Mundial (BSL) • domínio público. '
                      'Fonte: Bible.helloao.org.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
