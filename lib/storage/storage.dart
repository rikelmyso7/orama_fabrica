import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

/// Guarda dados comuns do app (catálogo em cache, fila de entradas). Texto simples, sem segredo.
abstract class KeyValueStore {
  String? ler(String chave);
  Future<void> gravar(String chave, String valor);
  Future<void> remover(String chave);
}

/// Guarda segredos (o token de login), no armazenamento seguro do aparelho.
abstract class SecureStore {
  Future<String?> ler(String chave);
  Future<void> gravar(String chave, String valor);
  Future<void> remover(String chave);
}

class GetStorageKeyValueStore implements KeyValueStore {
  GetStorageKeyValueStore([GetStorage? box]) : _box = box ?? GetStorage();

  final GetStorage _box;

  @override
  String? ler(String chave) => _box.read<String>(chave);

  @override
  Future<void> gravar(String chave, String valor) => _box.write(chave, valor);

  @override
  Future<void> remover(String chave) => _box.remove(chave);
}

class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  @override
  Future<String?> ler(String chave) => _storage.read(key: chave);

  @override
  Future<void> gravar(String chave, String valor) => _storage.write(key: chave, value: valor);

  @override
  Future<void> remover(String chave) => _storage.delete(key: chave);
}

/// Implementações em memória, para testes.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> dados = {};

  @override
  String? ler(String chave) => dados[chave];

  @override
  Future<void> gravar(String chave, String valor) async => dados[chave] = valor;

  @override
  Future<void> remover(String chave) async => dados.remove(chave);
}

class MemorySecureStore implements SecureStore {
  final Map<String, String> dados = {};

  @override
  Future<String?> ler(String chave) async => dados[chave];

  @override
  Future<void> gravar(String chave, String valor) async => dados[chave] = valor;

  @override
  Future<void> remover(String chave) async => dados.remove(chave);
}
