# Banco de dados unificado (Supabase)

As três versões do Royale Cars (web, desktop e mobile) usam este mesmo banco.
As **regras ficam aqui**, não em cada aplicativo: validação de CPF e placa,
permissões, cálculo do aluguel e histórico de ações. Assim as três plataformas
não conseguem se comportar diferente.

## Ordem dos scripts

Rodar no **SQL Editor** do Supabase, um de cada vez, nesta ordem:

| Arquivo | O que faz |
|---|---|
| `01_royale_cars_supabase.sql` | Cria tabelas, validações, permissões (RLS), funções de aluguel e manutenção, visões e dados de exemplo. **Apaga e recria as tabelas.** |
| `02_complemento.sql` | Acrescenta o que veio do desktop e do celular: endereço do cliente, quilometragem, assinatura, taxas extras, checklist da manutenção e modelos de permissão. |
| `03_dados_demo.sql` | Liga as contas de login aos perfis (chefe, gerente, funcionários) e completa os dados de exemplo. Antes, criar as 4 contas em *Authentication → Users*. |
| `04_testes.sql` | Testa o banco inteiro simulando cada pessoa logada. Não grava nada: no final desfaz tudo. |

A função que roda no servidor (criar e desativar contas, gerar senha temporária)
está em `supabase/functions/admin-usuarios/`.

## Contas de demonstração

| Pessoa | E-mail | Cargo |
|---|---|---|
| Gabriel S | gabriel@royalecars.com.br | Chefe (acesso a tudo) |
| Mariana Costa | mariana@royalecars.com.br | Gerente (modelo Gerente) |
| Lucas Pereira | lucas@royalecars.com.br | Funcionário (modelo Vendedor) |
| Pedro Alves | pedro@royalecars.com.br | Funcionário desativado |
