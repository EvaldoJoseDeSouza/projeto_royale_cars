# Royale Cars

Sistema de gestão para locadoras de veículos, feito como TCC no Cotil (Unicamp).
É **um sistema só, com três versões** (web, desktop e celular) que usam o
**mesmo banco de dados** no Supabase. O que é feito numa plataforma aparece na
hora nas outras.

| Versão  | Tecnologia                       | Responsável          | Pasta      |
|---------|----------------------------------|----------------------|------------|
| Desktop | Electron (JavaScript, HTML, CSS) | Caio Andrade Campos  | `desktop/` |
| Web     | PHP, HTML, CSS, JavaScript       | Gabriel dos Santos   | `web/`     |
| Mobile  | Flutter (Dart)                   | Evaldo José          | `mobile/`  |
| Banco   | Supabase (PostgreSQL)            | o grupo              | `banco/`   |

## O que o sistema faz

- **Clientes**: cadastro com CPF e CNH conferidos; avisa CNH vencida ou perto de vencer.
- **Frota**: cadastro dos carros com foto; status Disponível, Alugado ou Em manutenção.
- **Aluguel**: retirada com contrato; no celular, o cliente **assina na tela** e o
  contrato sai em PDF com a assinatura (a web e o desktop mostram e imprimem o mesmo contrato).
- **Devolução**: o banco calcula diárias, atraso, taxas e quilometragem; se o carro
  voltou com defeito, já vai para a oficina.
- **Manutenção**: envio para a oficina com vistoria, liberação com serviço e custo.
- **Financeiro e relatórios**: faturamento, gastos com manutenção e relatórios
  (a web exporta em CSV).
- **Equipe e permissões**: cada funcionário tem a própria conta e só vê o que pode
  (13 permissões, com modelos prontos: Gerente, Vendedor...). O chefe cria as contas,
  redefine senhas e acompanha o histórico de ações e as tentativas de login.

## Como o projeto está organizado

```
projeto_royale_cars/
├── banco/                 scripts SQL do banco unificado, na ordem em que rodam
├── supabase/functions/    função que roda no servidor do Supabase (contas da equipe)
├── desktop/               versão desktop (Electron)
├── web/                   versão web (PHP)
├── mobile/                versão mobile (Flutter)
└── docs/                  documentação, plano de unificação e roteiro da apresentação
```

## Como rodar

O banco já está no ar, no Supabase. As três versões só precisam de **internet**.
Para entrar, use uma conta da equipe (a lista está em `banco/README.md`; a senha
é passada pelo grupo, ela não fica no GitHub).

### Desktop (Windows)

**Pelo instalador:** abrir `Royale Cars Setup 1.0.0.exe` e seguir os passos.

**Pelo código** (precisa do [Node.js](https://nodejs.org) 20 ou mais novo), na pasta `desktop/`:

```
npm install            (só na primeira vez)
npm start              abre o sistema
npm run instalador     gera o instalador em desktop/dist/
```

### Web

Precisa do XAMPP (PHP 8 ou mais novo, com as extensões `curl` e `fileinfo`).

1. Copiar a pasta `web/` para `C:\xampp\htdocs\royale-cars-web`.
2. Ligar só o **Apache** no painel do XAMPP (o MySQL não é usado).
3. Abrir `http://localhost/royale-cars-web/`.

Os detalhes e a solução de problemas comuns estão em `web/LEIA-ME.md`.

### Mobile (Android)

**Pelo APK:** passar o `app-release.apk` para o celular e abrir
(pode ser preciso permitir "instalar apps desconhecidos").

**Pelo código** (precisa do [Flutter](https://docs.flutter.dev/get-started/install)), na pasta `mobile/`:

```
flutter pub get              (só na primeira vez)
flutter run                  com o celular conectado no USB
flutter build apk --release  gera o APK em build/app/outputs/flutter-apk/
```

### Banco de dados

Os scripts ficam em `banco/` e rodam no **SQL Editor** do Supabase, na ordem
explicada em `banco/README.md`. Para deixar os dados de demonstração limpos
(por exemplo, antes de apresentar), basta rodar o `07_restaurar_demo.sql`.

## Segurança, em resumo

- A senha é conferida pelo Supabase Auth; nenhum aplicativo guarda ou vê a senha.
- As regras (permissões, validações, cálculo do aluguel) ficam **no banco**: cada
  tabela tem RLS, então mesmo chamando o banco direto a pessoa só vê o que pode.
- Login bloqueado por 15 minutos depois de 5 senhas erradas, nas três plataformas.
- Na web: proteção contra XSS (`e()`), CSRF (código secreto em cada formulário) e
  roubo de sessão (`session_regenerate_id`).
- No desktop: a tela é isolada do computador (`contextIsolation`); ela só usa os
  comandos que o `preload.js` libera.
- Só a chave **pública** do Supabase fica no código. A chave secreta fica apenas
  dentro da função `admin-usuarios`, no servidor.

## Documentação

Na pasta `docs/`: a documentação de cada plataforma, o plano de unificação do banco
e o roteiro do vídeo de apresentação.
