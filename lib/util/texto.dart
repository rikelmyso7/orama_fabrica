/// Comparação de texto sem acento e sem diferenciar maiúsculas, para a busca de itens.
class Texto {
  const Texto._();

  static const _de = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  static const _para = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

  static String normalizar(String texto) {
    final b = StringBuffer();
    for (final r in texto.runes) {
      final c = String.fromCharCode(r);
      final i = _de.indexOf(c);
      b.write(i >= 0 ? _para[i] : c);
    }
    return b.toString().toLowerCase().trim();
  }

  static bool contem(String texto, String busca) =>
      normalizar(texto).contains(normalizar(busca));
}
