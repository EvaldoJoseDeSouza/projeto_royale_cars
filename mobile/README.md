# Royale Cars — Mobile (Flutter)

Versão para celular (Android) do Royale Cars, feita em Flutter (Dart).
Usa o mesmo banco das versões web e desktop, no Supabase.

## Como rodar

```
flutter pub get              (só na primeira vez)
flutter run                  com o celular conectado no USB
flutter run -d chrome        no navegador, para testar rápido
flutter build apk --release  gera o APK em build/app/outputs/flutter-apk/app-release.apk
```

Para conferir o código: `flutter analyze` (o esperado é "No issues found!").

## O que só o celular faz

- **Assinatura do contrato**: na retirada, o cliente assina na tela
  (`widgets/assinatura_digital.dart`). A imagem vai para uma pasta privada do
  Supabase e o contrato sai em PDF já assinado (`utils/contrato_pdf.dart`).
- **Sobre nós**: a página institucional da locadora.

## Como o código está organizado

```
lib/
├── main.dart              liga o Supabase e abre o app
├── dependencies.dart      os controllers usados pelas telas
├── services/              conversa com o banco (supabase_service.dart) e
│                          tradução dos erros do banco para português
├── controllers/           guardam as listas (clientes, frota, aluguéis,
│                          manutenção, login) e avisam as telas quando mudam
├── models/                o formato de cada dado (Cliente, Veiculo, Locacao...)
├── pages/                 as telas, uma por arquivo
├── widgets/               peças usadas em várias telas (botões, selos, assinatura)
├── utils/                 validação de CPF/placa, permissões e o PDF do contrato
└── theme/                 cores e estilo do app
```

As regras (permissões, CNH válida, carro disponível, cálculo do aluguel) ficam
**no banco**: o app chama as mesmas funções que a web e o desktop
(`registrar_aluguel`, `registrar_devolucao`, `abrir_manutencao`...).
