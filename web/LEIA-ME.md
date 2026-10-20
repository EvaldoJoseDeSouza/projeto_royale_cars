# Royale Cars — Sistema web

Sistema web em PHP para gerenciar clientes, frota, aluguéis, manutenção,
financeiro e a equipe da locadora. Usa o **mesmo banco do desktop e do
celular**: o Supabase (PostgreSQL na nuvem). Não precisa de MySQL.

---

## 1. Como rodar (XAMPP)

1. No painel do XAMPP, ligue só o **Apache** (o MySQL não é mais usado).
2. Deixe a pasta `web` do repositório acessível pelo Apache. Jeito mais fácil, sem
   copiar arquivos (no Prompt de Comando, como administrador):

   ```
   mklink /J C:\xampp\htdocs\royale-cars "C:\caminho\do\repositorio\projeto_royale_cars\web"
   ```
3. Abra **http://localhost/royale-cars/diagnostico.php**: ele confere se o PHP
   consegue falar com o Supabase (extensão curl, certificado SSL e internet).
4. Tudo certo? Entre em **http://localhost/royale-cars/**

A configuração do Supabase fica em `config/config.exemplo.php` (só a chave
**pública**). Se um computador precisar de algo diferente, copie para
`config/config.local.php`, que não vai para o GitHub.

### Logins de teste

As mesmas contas do desktop e do celular (criadas pelo `banco/03_dados_demo.sql`).
A senha é a que o grupo definiu ao criar cada conta no Supabase (Authentication → Users).

| Pessoa         | E-mail                      | Cargo                      |
|----------------|-----------------------------|----------------------------|
| Gabriel S      | gabriel@royalecars.com.br   | Chefe                      |
| Mariana Costa  | mariana@royalecars.com.br   | Gerente                    |
| Lucas Pereira  | lucas@royalecars.com.br     | Funcionário                |
| Pedro Alves    | pedro@royalecars.com.br     | Funcionário (desativado)   |

---

## 2. O que o sistema faz

As **regras ficam no banco** (pasta `banco/`), não no PHP: validação de CPF e
placa, cálculo do aluguel, mudança de status dos carros, permissões e histórico.
Por isso a web, o desktop e o celular se comportam igual.

### Clientes
- Validação de **CPF** e **CNH** com dígitos verificadores, **e-mail** e
  **telefone com DDD**. Endereço opcional.
- **CPF, CNH e e-mail repetidos** são recusados, e a tela diz de quem é (ou sugere
  reativar, se o dono estiver arquivado).
- Cliente com CNH vencida (ou que vence durante o aluguel) não aluga.
- **Arquivar** sem apagar o histórico; **reativar** com os dados anteriores.

### Veículos
- Placa **antiga (ABC-1234)** e **Mercosul (ABC1D23)**, chassi de 17 caracteres,
  sem repetidos. Quilometragem atual.
- **Foto** guardada no Supabase Storage (aparece em qualquer computador).
- Status **Disponível / Alugado / Em manutenção** muda sozinho com os aluguéis e
  as manutenções (o banco não deixa mudar à mão).

### Locações
- Retirada, devolução e cancelamento pelas **funções do banco** (as mesmas do
  desktop e do celular): tudo ou nada, e duas pessoas não alugam o mesmo carro.
- Quilometragem de saída e de volta; **taxas extras com motivo** (combustível,
  limpeza, avaria); atraso calculado pelo banco; comprovante para imprimir.
- Mostra a **assinatura do contrato** colhida no celular.
- Carro que volta com defeito vai direto para a manutenção.

### Manutenção
- Envio à oficina com **vistoria opcional** (motor, freios, pneus, óleo — o mesmo
  checklist do celular) e liberação com serviço, custo e data.

### Painel, alertas, financeiro e relatórios
- Painel e alertas pelas **visões do banco** (os mesmos números do desktop).
- Financeiro: faturamento x manutenção mês a mês e rankings.
- Relatórios de clientes, veículos, aluguéis, manutenções e faturamento, com
  filtros, **impressão** e **CSV** (abre direto no Excel).

### Administração (só o chefe)
- Cadastrar funcionários e gerentes com **login próprio**, usando os **modelos
  de permissão** (Gerente, Vendedor, Financeiro) ou marcando uma a uma.
- **Ativar/desativar** (a pessoa perde o acesso na hora), **redefinir senha**
  (senha temporária, troca obrigatória no próximo login) e trocar o e-mail de login.
  Essas ações passam pela **Edge Function `admin-usuarios`** (pasta `supabase/`),
  porque precisam da chave de serviço, que nunca fica no PHP.
- **Histórico de ações** escrito pelo próprio banco: quem fez o quê e quando,
  nas três plataformas.
- **Tentativas de login** (web, desktop e celular), com destaque para IPs suspeitos.

---

## 3. Segurança

| Proteção | Como funciona |
|---|---|
| Regras no banco | Validações (`CHECK`, `UNIQUE`), funções de aluguel e permissões por linha (RLS): nenhuma plataforma consegue burlar |
| Chaves | Só a chave **pública** fica no projeto; a chave de serviço fica na Edge Function |
| Senhas | Guardadas e conferidas pelo Supabase Auth (o PHP nunca vê a senha); mínimo de 8 caracteres com letras e números |
| Força bruta | 5 senhas erradas no mesmo e-mail → bloqueio de 15 minutos (regra do banco, igual nas 3 plataformas) |
| Sessão | Cookie `HttpOnly`, novo ID a cada login e saída automática após 30 minutos parado |
| XSS | Tudo que vem do banco passa por `htmlspecialchars` |
| CSRF | Todo formulário tem um token secreto; ações como arquivar só aceitam POST |
| Filtros | O que a pessoa digita na busca nunca vira comando (a "pontuação de comando" é retirada) |
| Fotos | Tipo real do arquivo conferido e nome aleatório |
| Acesso direto | Toda página confere login e permissão; `config/` e `includes/` bloqueados pelo `.htaccess` |

Avisos que só a web percebe (acesso negado, formulário inválido) vão para o log
do Apache (`C:\xampp\apache\logs\error.log`).

---

## 4. Estrutura de pastas

```
web/
├── index.php              Login
├── dashboard.php          Painel inicial
├── alertas.php            Alertas automáticos
├── alterar_senha.php      Troca de senha (obrigatória com senha temporária)
├── diagnostico.php        Confere a ligação com o Supabase
├── logout.php
├── config/                Endereço e chave pública do Supabase
├── includes/              supabase.php (a ponte com o banco), regras de cada tela, layout
├── css/style.css          Estilo
├── js/app.js              Máscaras, cálculos de prévia e validações da tela
├── clientes/              index, cadastrar, editar, ver, arquivar, reativar, clientes_arquivados
├── veiculos/              index, cadastrar, editar, ver, arquivar, reativar, arquivados
├── locacoes/              index, cadastrar, ver, devolver, cancelar
├── manutencoes/           index, cadastrar, concluir
├── financeiro/            index
├── relatorios/            index (todos os relatórios + CSV)
├── configuracoes/         Minha conta
└── admin/                 Painel do chefe: equipe, permissões, histórico, tentativas
```

---

## 5. Roteiro sugerido para a apresentação

1. Entrar como **Lucas (funcionário)** e mostrar que o menu dele é menor e que
   abrir `financeiro/index.php` direto pela barra de endereço dá "Acesso negado".
2. Tentar cadastrar um cliente com CPF `123.456.789-00` → recusado.
3. Registrar um aluguel na **web** e mostrar o carro como **Alugado** no **desktop**.
4. Entrar como **Gabriel (chefe)** → Alertas → devolver o aluguel atrasado com uma
   taxa extra, marcando "voltou com defeito" → o carro vai para a manutenção.
5. Liberar o carro na Manutenção, informando o custo → aparece no Financeiro
   (na web e no desktop, com os mesmos números).
6. Administração → cadastrar um funcionário com o modelo "Vendedor",
   mostrar a senha temporária e o **Histórico de ações**.
7. Errar a senha 5 vezes → bloqueio → aparece em **Tentativas de login**.

---

## 6. Problemas comuns

- **"Sem conexão com o servidor"**: o computador está sem internet, ou o PHP não
  confia no certificado do Supabase. Abra `diagnostico.php`: ele diz o que fazer.
- **Página sem estilo**: confira se a pasta se chama `css` (minúsculo).
- **Erro ao enviar foto (finfo)**: no `php.ini` do XAMPP, tire o `;` da linha
  `extension=fileinfo` e reinicie o Apache.
- **"A função admin-usuarios não está publicada"**: publique a Edge Function
  (ver `supabase/functions/admin-usuarios`).
- **Requisitos**: PHP 8.0 ou superior, com as extensões `curl` e `fileinfo`.
