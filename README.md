# Royale Cars

Sistema de gestão para locadoras de veículos, feito como TCC no Cotil (Unicamp).
É um sistema só, com três versões que usam o mesmo banco de dados no Supabase:

| Versão  | Tecnologia                  | Responsável | Pasta       |
|---------|-----------------------------|-------------|-------------|
| Desktop | Electron (JavaScript, HTML, CSS) | Caio   | `desktop/`  |
| Web     | PHP, HTML, CSS              | Gabriel     | `web/`      |
| Mobile  | Flutter (Dart)              | Evaldo      | `mobile/`   |

Com ele a locadora cadastra clientes e a frota, registra a retirada e a devolução
dos carros, controla a manutenção, acompanha o financeiro e define o que cada
funcionário pode acessar.

## Como o projeto está organizado

```
projeto_royale_cars/
├── banco/                 scripts SQL do banco unificado, na ordem em que rodam
├── supabase/functions/    funções que rodam no servidor do Supabase
├── desktop/               versão desktop (Electron)
├── web/                   versão web (PHP)
├── mobile/                versão mobile (Flutter)
└── docs/                  documentação das plataformas e plano de unificação
```

## Como rodar cada parte

**Desktop**: na pasta `desktop/`, rodar `npm install` (só na primeira vez) e depois `npm start`.

**Web**: copiar a pasta `web/` para `C:\xampp\htdocs\royale-cars-web`, ligar o Apache no XAMPP e
abrir `http://localhost/royale-cars-web/`.

**Mobile**: na pasta `mobile/`, rodar `flutter pub get` (só na primeira vez) e depois
`flutter run` (celular conectado) ou `flutter run -d chrome` (no navegador).

## Situação atual

O grupo está unificando as três versões no mesmo banco (Supabase), com as mesmas
regras e funcionalidades. O plano completo está em `docs/plano-unificacao.pdf`.
