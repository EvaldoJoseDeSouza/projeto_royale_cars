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
│   └── index.js
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
    │   ├── grupo-permissao/
    │   ├── confirmacao/
    │   ├── trocar-senha/
    │   ├── redefinir-senha-colaborador/
    │   └── ver-colaboradores/
    └── estilos/              CSS usado por várias telas (modal.css)
```

A regra é simples: **tudo de uma tela fica na pasta dela** (HTML, JavaScript e o CSS só
dela). O que é usado por várias telas fica em `estilos/`.
