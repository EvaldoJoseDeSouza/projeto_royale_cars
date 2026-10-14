# Royale Cars — Desktop (Electron)

Versão desktop do Royale Cars, para Windows. Feita em Electron (JavaScript, HTML e CSS).

## Como rodar

```
npm install   (só na primeira vez)
npm start
```

## Como o código está organizado

O Electron tem duas partes que rodam separadas:

- **Processo principal** (`src/main/`): o "cérebro". Abre as janelas, fala com o banco
  (Supabase) e decide o que cada pessoa pode fazer.
- **Telas** (`src/renderer/`): o que a pessoa vê e clica. Cada tela pede as coisas ao
  processo principal pela "ponte" do `src/preload/preload.js`.

```
src/
├── main/                     processo principal
│   ├── index.js              abre as janelas e liga tudo
│   ├── supabase.js           a conexão com o banco
│   ├── sessao.js             quem está logado e o que pode fazer
│   ├── erros-banco.js        traduz os erros do banco para português
│   └── ipc/                  as "conversas" com as telas, por assunto
│       ├── sessao.js         login, troca de senha, Minha conta
│       ├── modelos.js        modelos de permissão
│       ├── colaboradores.js  a equipe (usa a Edge Function admin-usuarios)
│       └── clientes.js       clientes
├── preload/preload.js        a ponte entre as telas e o processo principal
├── imagens/                  ícone do sistema (bandeja e telas)
└── renderer/                 as telas, organizadas por tela
    ├── telas/
    │   ├── login/            login.html + login.js + login.css
    │   └── dashboard/        dashboard.html + dashboard.js + dashboard.css
    ├── modais/               as janelas que abrem por cima (cadastros, confirmações)
    │   ├── cliente/
    │   ├── veiculo/
    │   ├── locacao/
    │   ├── colaborador/
    │   ├── grupo-permissao/  (modelos de permissão)
    │   ├── confirmacao/
    │   ├── trocar-senha/
    │   └── senha-temporaria/ (mostra a senha gerada para um colaborador)
    ├── estilos/              CSS usado por várias telas (modal.css)
    └── compartilhado/        JavaScript usado por várias telas
        ├── permissoes.js     a lista das 13 permissões (um lugar só)
        └── formatos.js       máscaras e formatos (CPF, telefone, data)
```

A regra é simples: **tudo de uma tela fica na pasta dela** (HTML, JavaScript e o CSS só
dela). O que é usado por várias telas fica em `estilos/` (CSS) ou `compartilhado/` (JavaScript).
