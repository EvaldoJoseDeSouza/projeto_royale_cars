-- =====================================================================
--  ROYALE CARS - Testes automáticos do banco
--  Rodar depois do 01, 02 e 03, no SQL Editor do Supabase.
--
--  Tudo acontece dentro de uma transação que termina em ROLLBACK:
--  o teste aluga, devolve, cancela... e no final o banco volta a ser
--  exatamente o que era. Pode rodar quantas vezes quiser.
--
--  Resultado esperado: uma mensagem em vermelho dizendo
--  "TODOS OS TESTES PASSARAM". Ela aparece como erro de propósito
--  (é o erro que desfaz tudo). Se algum teste falhar, a mensagem
--  começa com "FALHOU" e diz qual foi.
--
--  Como simula cada pessoa: o Supabase descobre quem está logado
--  lendo o "crachá" (token JWT) de quem fez o pedido. Aqui a gente
--  escreve esse crachá à mão com set_config e troca de papel com
--  "set local role authenticated", igual a um app logado.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Ferramentas do teste (só existem durante este teste)
-- ---------------------------------------------------------------------

-- Faz o banco achar que a pessoa deste e-mail está logada
create function pg_temp.como(p_email text) returns void language plpgsql as $$
declare uid uuid;
begin
    execute 'reset role';
    select id into uid from auth.users where email = p_email;
    if uid is null then raise exception 'Conta % não existe. Rode o 03_dados_demo.sql antes.', p_email; end if;
    perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', uid::text, true);
    perform set_config('royale.rpc', '', true);   -- cada chamada começa fora do "modo função"
    execute 'set local role authenticated';
end $$;

-- Roda um comando que DEVE dar erro; se não der erro, o teste falha
create function pg_temp.espera_erro(p_nome text, p_sql text, p_trecho text) returns void language plpgsql as $$
begin
    begin
        execute p_sql;
    exception when others then
        if position(lower(p_trecho) in lower(sqlerrm)) > 0 then
            raise notice 'OK  %', p_nome;
            return;
        end if;
        raise exception 'FALHOU  % — deu outro erro: %', p_nome, sqlerrm;
    end;
    raise exception 'FALHOU  % — deveria ter dado erro e não deu', p_nome;
end $$;

-- Confere uma condição
create function pg_temp.confere(p_nome text, p_ok boolean) returns void language plpgsql as $$
begin
    if coalesce(p_ok, false) then raise notice 'OK  %', p_nome;
    else raise exception 'FALHOU  %', p_nome; end if;
end $$;

grant execute on function pg_temp.como(text), pg_temp.espera_erro(text, text, text), pg_temp.confere(text, boolean) to authenticated;


-- ---------------------------------------------------------------------
-- 1. Login e permissões
-- ---------------------------------------------------------------------

select pg_temp.como('lucas@royalecars.com.br');
select pg_temp.confere('Funcionário entra e recebe as permissões do modelo Vendedor',
    (select (iniciar_sessao('desktop') ->> 'cargo') = 'funcionario'
        and json_array_length(iniciar_sessao('desktop') -> 'permissoes') = 5));
select pg_temp.confere('Funcionário não vê o financeiro', (select count(*) = 0 from vw_faturamento_mensal));
select pg_temp.confere('Funcionário não vê o histórico de ações', (select count(*) = 0 from logs));
select pg_temp.confere('Funcionário vê os modelos de permissão', (select count(*) >= 3 from modelos_permissao));
select pg_temp.espera_erro('Funcionário não cria modelo de permissão',
    $$insert into modelos_permissao (nome, permissoes) values ('Teste', '{}')$$, 'row-level security');
select pg_temp.espera_erro('Funcionário não cancela aluguel (sem locacoes_cancelar)',
    $$select cancelar_aluguel(13, 'Teste de permissão')$$, 'não tem permissão');

select pg_temp.como('pedro@royalecars.com.br');
select pg_temp.espera_erro('Usuário desativado não consegue iniciar sessão',
    $$select iniciar_sessao('mobile')$$, 'desativado');
select pg_temp.confere('Usuário desativado não vê nenhum cliente', (select count(*) = 0 from clientes));

select pg_temp.como('gabriel@royalecars.com.br');
select pg_temp.confere('Chefe recebe as 13 permissões',
    (select json_array_length(iniciar_sessao('web') -> 'permissoes') = 13));


-- ---------------------------------------------------------------------
-- 2. Clientes: padronização, validação e endereço
-- ---------------------------------------------------------------------

select pg_temp.como('lucas@royalecars.com.br');
insert into clientes (nome, cpf, cnh, cnh_validade, email, telefone, endereco)
values ('Teste  Unificado', '529.982.247-25', '3141 5926 507', current_date + 400,
        ' Teste@Royale.COM ', '(19) 99876-5432', '  Rua   do Teste, 10 ');
select pg_temp.confere('CPF, CNH, telefone e e-mail gravados sem máscara',
    (select cpf = '52998224725' and cnh = '31415926507' and telefone = '19998765432'
            and email = 'teste@royale.com' and endereco = 'Rua do Teste, 10'
     from clientes where email = 'teste@royale.com'));
select pg_temp.espera_erro('CPF com dígito errado é recusado',
    $$insert into clientes (nome, cpf, cnh, cnh_validade, email, telefone)
      values ('Fulano de Tal', '123.456.789-00', '27182818250', current_date + 400, 'f@t.com', '19998765432')$$,
    'clientes_cpf_check');
select pg_temp.espera_erro('CPF repetido é recusado',
    $$insert into clientes (nome, cpf, cnh, cnh_validade, email, telefone)
      values ('Outra Pessoa', '52998224725', '96001338941', current_date + 400, 'outra@t.com', '19998765432')$$,
    'duplicate key');
select pg_temp.espera_erro('Funcionário sem clientes_arquivar não arquiva',
    $$update clientes set arquivado = true where email = 'teste@royale.com'$$, 'não tem permissão');


-- ---------------------------------------------------------------------
-- 3. Veículos: placa, status automático e quilometragem
-- ---------------------------------------------------------------------

select pg_temp.como('mariana@royalecars.com.br');
insert into veiculos (marca, modelo, ano, placa, chassi, valor_diaria, quilometragem, status)
values ('Fiat', 'Pulse', 2025, 'tst-1a23', '9BD363A1RPYB12345', 200, 15000, 'Alugado');
select pg_temp.confere('Placa sem hífen, maiúscula, e veículo novo entra Disponível (mesmo pedindo Alugado)',
    (select placa = 'TST1A23' and status = 'Disponível' and quilometragem = 15000 from veiculos where placa = 'TST1A23'));
select pg_temp.espera_erro('Status não pode ser mudado à mão',
    $$update veiculos set status = 'Em manutenção' where placa = 'TST1A23'$$, 'muda sozinho');


-- ---------------------------------------------------------------------
-- 4. Locação completa: retirada com km e assinatura, devolução com
--    km, atraso e taxas extras
-- ---------------------------------------------------------------------

select pg_temp.como('lucas@royalecars.com.br');
select pg_temp.espera_erro('Km de saída menor que o do veículo é recusado',
    $$select registrar_aluguel((select id from clientes where email = 'teste@royale.com'),
        (select id from veiculos where placa = 'TST1A23'), current_date, current_date + 3, null, 14000, null)$$,
    'não pode ser menor');

select pg_temp.como('lucas@royalecars.com.br');
select registrar_aluguel((select id from clientes where email = 'teste@royale.com'),
    (select id from veiculos where placa = 'TST1A23'), current_date - 5, current_date,
    'Teste do roteiro', null, 'teste/assinatura.png');
select pg_temp.confere('Retirada: carro vira Alugado, km de saída = km do carro, assinatura gravada',
    (select v.status = 'Alugado' and l.km_saida = 15000 and l.assinatura_path = 'teste/assinatura.png'
            and l.assinada_em is not null and l.valor_previsto = 1000
     from locacoes l join veiculos v on v.id = l.veiculo_id
     where v.placa = 'TST1A23' and l.status = 'Em andamento'));
-- Simula que o tempo passou: a devolução prevista era 2 dias atrás
reset role;
update locacoes set data_prevista = current_date - 2
 where status = 'Em andamento' and veiculo_id = (select id from veiculos where placa = 'TST1A23');

select pg_temp.como('lucas@royalecars.com.br');
select pg_temp.confere('Visão de locações mostra "Atrasada"',
    (select status_exibicao = 'Atrasada' from vw_locacoes where placa = 'TST1A23' and status = 'Em andamento'));

select pg_temp.como('lucas@royalecars.com.br');
select pg_temp.espera_erro('Taxa extra sem motivo é recusada',
    $$select registrar_devolucao((select id from locacoes l where status = 'Em andamento'
        and veiculo_id = (select id from veiculos where placa = 'TST1A23')), current_date, null, null, null, 15500, 50, null)$$,
    'motivo das taxas');

select pg_temp.como('lucas@royalecars.com.br');
select pg_temp.espera_erro('Km de retorno menor que o de saída é recusado',
    $$select registrar_devolucao((select id from locacoes l where status = 'Em andamento'
        and veiculo_id = (select id from veiculos where placa = 'TST1A23')), current_date, null, null, null, 14000)$$,
    'não pode ser menor');

select pg_temp.como('lucas@royalecars.com.br');
select pg_temp.confere('Devolução: 5 diárias (2 de atraso) + R$ 80 de taxa = R$ 1.080, 620 km rodados',
    (select (r ->> 'valor_total')::numeric = 1080 and (r ->> 'dias_atraso')::int = 2
            and (r ->> 'km_rodados')::int = 620 and r ->> 'status_veiculo' = 'Disponível'
     from (select registrar_devolucao(
              (select id from locacoes where status = 'Em andamento'
                 and veiculo_id = (select id from veiculos where placa = 'TST1A23')),
              current_date, 'Tudo certo', null, null, 15620, 80, 'Limpeza') as r) x));
select pg_temp.confere('Veículo ficou com a quilometragem do retorno',
    (select quilometragem = 15620 from veiculos where placa = 'TST1A23'));


-- ---------------------------------------------------------------------
-- 5. Manutenção com checklist
-- ---------------------------------------------------------------------

select pg_temp.como('mariana@royalecars.com.br');
select abrir_manutencao((select id from veiculos where placa = 'TST1A23'), 'Revisão de teste do roteiro',
    'Oficina Teste', current_date, current_date + 2, true, true, false, true);
select pg_temp.confere('Manutenção aberta com checklist e carro Em manutenção',
    (select m.pneus_ok = false and m.motor_ok and v.status = 'Em manutenção'
     from manutencoes m join veiculos v on v.id = m.veiculo_id
     where v.placa = 'TST1A23' and m.status = 'Em andamento'));

select pg_temp.como('mariana@royalecars.com.br');
select concluir_manutencao((select id from manutencoes where status = 'Em andamento'
    and veiculo_id = (select id from veiculos where placa = 'TST1A23')), current_date, 'Troca dos pneus dianteiros', 900);
select pg_temp.confere('Manutenção concluída e carro volta a Disponível',
    (select status = 'Disponível' from veiculos where placa = 'TST1A23'));


-- ---------------------------------------------------------------------
-- 6. Histórico automático (o chefe vê tudo que foi feito acima)
-- ---------------------------------------------------------------------

select pg_temp.como('gabriel@royalecars.com.br');
select pg_temp.confere('Histórico registrou cadastro, aluguel, devolução e manutenção com o nome de quem fez',
    (select count(distinct modulo || acao) >= 5 and bool_and(usuario_id is not null)
     from logs where modulo in ('clientes', 'veiculos', 'locacoes', 'manutencoes')));

-- ---------------------------------------------------------------------
-- 7. Foto do veículo (correção de 15/10: trocar a foto dava erro)
-- ---------------------------------------------------------------------

-- A gerente troca e depois tira a foto; o chefe (só ele lê o histórico) confere
select pg_temp.como('mariana@royalecars.com.br');
update veiculos set imagem = 'teste-foto.jpg' where placa = 'TST1A23';
update veiculos set imagem = null where placa = 'TST1A23';

select pg_temp.como('gabriel@royalecars.com.br');
select pg_temp.confere('Trocar e tirar a foto ficam no histórico ("trocou a foto" e "removeu a foto")',
    (select bool_or(descricao like '%trocou a foto%') and bool_or(descricao like '%removeu a foto%')
     from logs where modulo = 'veiculos' and acao = 'editar' and descricao like '%TST1A23%'));

-- ---------------------------------------------------------------------
-- 8. Permissão "relatorios" lê tudo, mas não altera nada (06, de 16/10)
-- ---------------------------------------------------------------------

-- O chefe deixa o Lucas só com "relatorios" (dentro do teste: no fim, tudo é desfeito)
select pg_temp.como('gabriel@royalecars.com.br');
delete from usuario_permissoes where usuario_id = (select id from perfis where email = 'lucas@royalecars.com.br');
insert into usuario_permissoes select id, 'relatorios' from perfis where email = 'lucas@royalecars.com.br';

select pg_temp.como('lucas@royalecars.com.br');
select pg_temp.confere('Só com "relatorios" lê clientes, veículos, aluguéis e manutenções',
    (select count(*) > 0 from clientes) and (select count(*) > 0 from veiculos)
    and (select count(*) > 0 from locacoes) and (select count(*) > 0 from manutencoes));
select pg_temp.espera_erro('Só com "relatorios" não cadastra cliente',
    $$insert into clientes (nome, cpf, cnh, cnh_validade, email, telefone)
      values ('Teste Relatorio', '52998224725', '96001338941', current_date + 100, 'rel@teste.com', '19999998888')$$,
    'row-level security');
select pg_temp.espera_erro('Só com "relatorios" não registra aluguel',
    $$select registrar_aluguel(1, 4, current_date, current_date + 2)$$, 'não tem permissão');

-- ---------------------------------------------------------------------
-- Fim. A mensagem abaixo aparece em VERMELHO, como erro, de propósito:
-- é o erro que faz o banco desfazer tudo que o teste gravou.
-- ---------------------------------------------------------------------
reset role;
do $$ begin
    raise exception 'TODOS OS TESTES PASSARAM. (Esta mensagem aparece como erro de propósito: assim o banco desfaz tudo o que o teste gravou.)';
end $$;

rollback;
