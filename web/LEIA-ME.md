# Royale Cars — Sistema de Gestão de Locadora

Sistema web em PHP + MySQL (MariaDB) para gerenciar clientes, frota, aluguéis,
manutenção, financeiro e a equipe da locadora.

---

## 1. Como instalar (XAMPP)

1. **Apague a pasta antiga** `htdocs/royale-cars-web` (ou renomeie para guardar
   um backup). Vários arquivos antigos foram substituídos ou removidos, então não
   copie por cima.
2. Copie a pasta `royale-cars-web` deste zip para `C:\xampp\htdocs\`.
3. Ligue **Apache** e **MySQL** no painel do XAMPP.
4. Abra o phpMyAdmin → aba **Importar** → escolha `royale_cars.sql` → **Executar**.
   O script cria o banco `royale_cars` do zero, com dados de exemplo.
   *Atenção: ele apaga as tabelas antigas.*
5. Acesse **http://localhost/royale-cars-web/**

Se o MySQL tiver senha, ajuste em `config/database.php`.

### Logins de teste

Desde o pacote 3.2, o login é o do **Supabase**: as mesmas contas do desktop e
do celular (criadas pelo `banco/03_dados_demo.sql`). A senha é a que o grupo
definiu ao criar cada conta no painel do Supabase (Authentication → Users).

| Pessoa         | E-mail                      | Cargo                      |
|----------------|-----------------------------|----------------------------|
| Gabriel S      | gabriel@royalecars.com.br   | Chefe                      |
| Mariana Costa  | mariana@royalecars.com.br   | Gerente                    |
| Lucas Pereira  | lucas@royalecars.com.br     | Funcionário                |
| Pedro Alves    | pedro@royalecars.com.br     | Funcionário (desativado)   |

Enquanto a mudança para o Supabase não termina (pacote 3.8), as telas que ainda
usam o MySQL continuam lendo os dados de exemplo do `royale_cars.sql`.

As datas dos dados de exemplo são calculadas a partir do dia da importação, então
o sistema sempre tem um aluguel atrasado, um que vence amanhã e um carro na oficina
para demonstrar os alertas.

---

## 2. O que o sistema faz

### Clientes
- Validação de **CPF** e **CNH** com dígitos verificadores, **e-mail** e
  **telefone com DDD** (confere se o DDD existe no Brasil).
- Bloqueia **CPF, CNH e e-mail duplicados**. Se o documento for de um cliente
  arquivado, o sistema avisa para reativar em vez de duplicar.
- Validade da CNH: cliente com CNH vencida (ou que vence durante o aluguel) não aluga.
- **Arquivar** sem apagar o histórico; página exclusiva
  `clientes/clientes_arquivados.php`; **reativar** com os dados anteriores.
- Ficha do cliente com histórico de aluguéis e total já pago.

### Veículos
- Placa **antiga (ABC-1234)** e **Mercosul (ABC1D23)**, sem duplicidade
  (ABC-1234 e ABC1234 contam como a mesma placa).
- **Chassi** com 17 caracteres (sem I, O e Q), sem duplicidade.
- Marca, modelo, ano, diária, **foto** (JPG/PNG/WEBP até 2 MB, tipo real conferido).
- Status **Disponível / Alugado / Em manutenção** controlado pelo sistema
  (não dá mais para escolher "Alugado" à mão).
- Arquivar/reativar e ficha com faturamento e gasto de manutenção do carro.

### Aluguéis
- Retirada: só cliente ativo com CNH válida e carro disponível. O valor previsto
  aparece na tela enquanto você escolhe as datas.
- Devolução: calcula as diárias usadas e o **atraso** (cobrado pela diária combinada).
- Se o carro voltou com defeito, já vai direto para a manutenção.
- Cancelamento com motivo obrigatório.
- Tudo em **transação** com o veículo travado (`SELECT ... FOR UPDATE`): duas
  pessoas não conseguem alugar o mesmo carro ao mesmo tempo.
- Comprovante para imprimir.

### Manutenção
- Registro do defeito, oficina, data de entrada e previsão.
- Na liberação: serviço feito, custo e data. O carro em manutenção não pode ser alugado.

### Dashboard, alertas, financeiro e relatórios
- Dashboard: faturamento do mês (com variação), carros alugados, atrasos,
  clientes, situação da frota e gráfico mensal (feito em HTML/CSS, funciona sem internet).
- Alertas: atrasos, devoluções próximas, carros na oficina, CNH vencendo e
  tentativas suspeitas de login.
- Financeiro: faturamento x custo de manutenção mês a mês e rankings.
- Relatórios de clientes, veículos, aluguéis, manutenções e faturamento, com filtros
  (período, situação, cliente, veículo, funcionário), **impressão** e **CSV**
  (abre direto no Excel).

### Painel Administrativo (só o chefe)
- Cadastrar quantos **funcionários e gerentes** precisar, cada um com **login próprio**.
- **Permissões individuais** (13 permissões em 5 grupos), com sugestão por cargo.
- **Ativar/desativar** (a pessoa perde o acesso na hora) e **redefinir senha**
  (gera senha temporária; a pessoa é obrigada a trocar no próximo login).
- **Histórico de ações**: quem fez o quê, quando e de qual IP (ex.: "Alterou o
  Porsche 911: diária de R$ 1.600,00 para R$ 1.800,00").
- **Tentativas de login**, com destaque para IPs suspeitos.

---

## 3. Segurança

| Proteção | Como funciona |
|---|---|
| Validação em 3 camadas | JavaScript (aviso na hora) → PHP (regra que vale) → banco (`CHECK`, `UNIQUE`, chaves estrangeiras) |
| SQL Injection | Todas as consultas usam *prepared statements* |
| XSS | Tudo que vem do banco passa por `htmlspecialchars` |
| CSRF | Todo formulário tem um token secreto; ações como arquivar só aceitam POST |
| Senhas | Guardadas e conferidas pelo Supabase Auth (o PHP nunca vê o hash); mínimo de 8 caracteres com letras e números |
| Força bruta | 5 senhas erradas no mesmo e-mail → bloqueio de 15 minutos (regra do banco, igual nas 3 plataformas) |
| Sessão | Cookie `HttpOnly`, novo ID a cada login e saída automática após 30 minutos parado |
| Acesso direto | Toda página confere login e permissão; `config/` e `includes/` bloqueados pelo `.htaccess` |
| Uploads | Tipo real do arquivo conferido, nome aleatório e a pasta não executa PHP |
| Cadastro público | Removido: só o chefe cria contas |

---

## 4. Estrutura de pastas

```
royale-cars-web/
├── index.php              Login
├── dashboard.php          Painel inicial
├── alertas.php            Alertas automáticos
├── alterar_senha.php      Troca de senha (obrigatória após redefinição)
├── logout.php
├── config/database.php    Conexão com o banco
├── includes/              Funções, validações, permissões, layout (bloqueado no navegador)
├── css/style.css          Estilo único (o antigo dashboard.css foi incorporado)
├── js/app.js              Máscaras e validações da tela
├── uploads/veiculos/      Fotos dos carros
├── clientes/              index, cadastrar, editar, ver, arquivar, reativar, clientes_arquivados
├── veiculos/              index, cadastrar, editar, ver, arquivar, reativar, arquivados
├── locacoes/              index, cadastrar, ver, devolver, cancelar
├── manutencoes/           index, cadastrar, concluir
├── financeiro/            index
├── relatorios/            index (todos os relatórios + CSV)
├── configuracoes/         Minha conta
└── admin/                 Painel do chefe: usuários, permissões, histórico, tentativas
```

**Arquivos antigos que não existem mais:** `auth/cadastrar.php` (cadastro público),
`css/dashboard.css`, `locacoes/finalizar.php` (virou `devolver.php`) e
`veiculos/excluir.php` (virou `arquivar.php`).

---

## 5. Roteiro sugerido para a apresentação

1. Entrar como **Lucas (funcionário)** e mostrar que o menu dele é menor e que
   abrir `financeiro/index.php` direto pela barra de endereço dá "Acesso negado".
2. Tentar cadastrar um cliente com CPF `123.456.789-00` → recusado.
3. Registrar um aluguel e mostrar o carro mudando para **Alugado** na frota.
4. Entrar como **Gabriel (chefe)** → Alertas → devolver o aluguel atrasado,
   marcando "voltou com defeito" → o carro vai para a manutenção.
5. Liberar o carro na Manutenção, informando o custo → aparece no Financeiro.
6. Painel Administrativo → cadastrar um funcionário, escolher permissões,
   mostrar a senha temporária e o **Histórico de ações** com tudo que foi feito.
7. Errar a senha 5 vezes → bloqueio → aparece em **Tentativas de login**.

---

## 6. Problemas comuns

- **"Não foi possível conectar ao banco"**: o MySQL não está ligado no XAMPP ou a
  senha em `config/database.php` está diferente.
- **Página sem estilo**: confira se a pasta se chama `css` (minúsculo).
- **Erro ao enviar foto (finfo)**: no `php.ini` do XAMPP, tire o `;` da linha
  `extension=fileinfo` e reinicie o Apache.
- **Requisitos**: PHP 8.0 ou superior; MariaDB 10.4+ ou MySQL 8+.
