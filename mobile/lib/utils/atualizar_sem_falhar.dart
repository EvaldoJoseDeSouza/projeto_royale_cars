import 'package:flutter/foundation.dart';

/// Recarrega uma lista DEPOIS que o banco já gravou.
/// Se a internet falhar só nessa hora, a gravação deu certo: o erro vai
/// para o console em vez de aparecer na tela como se nada tivesse sido salvo.
Future<void> atualizarSemFalhar(Future<void> Function() atualizar) async {
  try {
    await atualizar();
  } catch (erro) {
    debugPrint('[ATUALIZAR] Gravou, mas a lista não recarregou: $erro');
  }
}
