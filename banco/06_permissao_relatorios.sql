-- =====================================================================
--  ROYALE CARS - Permissão "Relatórios" passa a ler o que o relatório mostra
--  Rodar UMA vez no SQL Editor do Supabase, depois do 05.
--  (Quem montar o banco do zero também roda, na ordem: 01, 02, 03, 05, 06, 04.)
--  Pode rodar de novo sem problema: apaga e recria só as 4 regras de leitura.
--
--  Decisão do grupo (16/10, opção A): quem tem a permissão "relatorios"
--  (ou "relatorios_financeiros") consegue LER clientes, veículos, aluguéis
--  e manutenções, para gerar os relatórios. Só LER: cadastrar, editar,
--  arquivar, alugar e devolver continuam exigindo as outras permissões.
--
--  Antes: quem tinha só "relatorios" abria o relatório de clientes e via
--  a lista vazia, porque o banco não deixava ler a tabela clientes.
-- =====================================================================

set search_path = public;

drop policy if exists clientes_ver on clientes;
create policy clientes_ver on clientes for select to authenticated
    using (tem_permissao('clientes_ver') or tem_permissao('locacoes_gerenciar')
           or tem_permissao('relatorios') or tem_permissao('relatorios_financeiros'));

drop policy if exists veiculos_ver on veiculos;
create policy veiculos_ver on veiculos for select to authenticated
    using (tem_permissao('veiculos_ver') or tem_permissao('locacoes_gerenciar')
           or tem_permissao('relatorios') or tem_permissao('relatorios_financeiros'));

drop policy if exists locacoes_ver on locacoes;
create policy locacoes_ver on locacoes for select to authenticated
    using (tem_permissao('locacoes_ver') or tem_permissao('financeiro')
           or tem_permissao('relatorios') or tem_permissao('relatorios_financeiros'));

drop policy if exists manutencoes_ver on manutencoes;
create policy manutencoes_ver on manutencoes for select to authenticated
    using (tem_permissao('manutencoes') or tem_permissao('veiculos_ver') or tem_permissao('financeiro')
           or tem_permissao('relatorios') or tem_permissao('relatorios_financeiros'));
