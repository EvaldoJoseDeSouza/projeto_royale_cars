-- =====================================================================
--  ROYALE CARS - Restaurar os dados de demonstração
--
--  PARA QUÊ: deixar o banco "bonito" para os prints da documentação e
--  para a apresentação (27/10). Pode rodar quantas vezes quiser.
--
--  O QUE FAZ:
--    APAGA  clientes, veículos, aluguéis, manutenções, o histórico de
--           ações e as tentativas de login.
--    CRIA   11 clientes, 14 veículos, 33 aluguéis (12 meses de
--           movimento) e 9 manutenções.
--    MANTÉM as contas da equipe (logins, cargos e permissões), os
--           modelos de permissão e as FOTOS dos carros (pela placa).
--
--  As datas são contadas a partir de HOJE ("current_date - 30" = 30 dias
--  atrás). Por isso rode de novo na manhã da apresentação: o aluguel
--  atrasado continua atrasado e o que vence amanhã continua vencendo
--  amanhã.
--
--  As assinaturas NÃO entram: elas são desenhadas à mão no celular.
--  Depois de rodar, faça 1 ou 2 aluguéis pelo celular, assinando.
--
--  COMO RODAR: Supabase → SQL Editor → colar tudo → Run.
-- =====================================================================

set search_path = public;

begin;

-- =====================================================================
-- 1. Guarda as fotos dos carros antes de apagar (a foto fica no
--    Storage; no banco só fica o caminho, na coluna "imagem")
-- =====================================================================

create temp table fotos_guardadas on commit drop as
    select placa, imagem from veiculos where imagem is not null;


-- =====================================================================
-- 2. Apaga os dados de movimento (a equipe NÃO é apagada)
--    "restart identity" faz os números (id) voltarem a começar do 1.
-- =====================================================================

truncate manutencoes, locacoes, clientes, veiculos restart identity;
delete from logs;
delete from login_tentativas;


-- =====================================================================
-- 3. Clientes
--    CPF e CNH com dígitos verificadores válidos (o banco confere).
--    Rafael tem a CNH vencendo em 20 dias: aparece nos alertas.
--    Juliana está arquivada, com a CNH vencida.
-- =====================================================================

insert into clientes (id, nome, cpf, cnh, cnh_validade, email, telefone, endereco, arquivado, arquivado_em, criado_em) values
(1,  'João da Silva',     '10433218100', '96001338941', current_date + 900,  'joao@gmail.com',            '19999999999', 'Rua Barão de Jaguara, 1200 - Centro, Campinas/SP',     false, null, now() - interval '360 days'),
(2,  'Evaldo José',       '08386379499', '02654235141', current_date + 600,  'evaldo@gmail.com',          '1940028922',  'Av. Brasil, 455 - Jardim Guanabara, Campinas/SP',      false, null, now() - interval '355 days'),
(3,  'Caio Andrade',      '16155940789', '81618495903', current_date + 1200, 'andrade@gmail.com',         '19989568439', 'Rua José Paulino, 88 - Centro, Limeira/SP',            false, null, now() - interval '350 days'),
(4,  'Ana Beatriz Souza', '31034131656', '47525534144', current_date + 1500, 'ana.souza@gmail.com',       '11987654321', 'Rua Augusta, 2100 - Consolação, São Paulo/SP',         false, null, now() - interval '300 days'),
(5,  'Marcos Oliveira',   '92832764851', '35030564106', current_date + 400,  'marcos.oli@hotmail.com',    '21998765432', null,                                                   false, null, now() - interval '280 days'),
(6,  'Fernanda Lima',     '39537672409', '23884969629', current_date + 800,  'fernanda.lima@gmail.com',   '19991234567', 'Av. Norte-Sul, 980 - Cambuí, Campinas/SP',             false, null, now() - interval '260 days'),
(7,  'Rafael Mendes',     '53287101269', '26916697875', current_date + 20,   'rafael.mendes@outlook.com', '19993456789', null,                                                   false, null, now() - interval '230 days'),
(8,  'Juliana Rocha',     '48018451427', '62704828170', current_date - 15,   'juliana.rocha@gmail.com',   '11976543210', null,                                                   true,  now() - interval '10 days', now() - interval '340 days'),
(9,  'Beatriz Nogueira',  '74431148507', '45623371922', current_date + 1100, 'bia.nogueira@gmail.com',    '19981112233', 'Rua Coronel Quirino, 410 - Cambuí, Campinas/SP',       false, null, now() - interval '210 days'),
(10, 'Thiago Martins',    '19660750730', '42959382101', current_date + 700,  'thiago.martins@gmail.com',  '19974445566', 'Av. Orosimbo Maia, 1500 - Vila Itapura, Campinas/SP',  false, null, now() - interval '190 days'),
(11, 'Larissa Campos',    '64081272409', '80207259967', current_date + 950,  'larissa.campos@yahoo.com',  '11965557788', 'Rua Oscar Freire, 300 - Jardins, São Paulo/SP',        false, null, now() - interval '160 days');


-- =====================================================================
-- 4. Veículos
--    Todos entram "Disponível"; o status certo (Alugado, Em manutenção)
--    é acertado no passo 8, depois dos aluguéis e manutenções.
--    A quilometragem também é calculada depois (passo 7).
-- =====================================================================

insert into veiculos (id, marca, modelo, ano, placa, chassi, valor_diaria, status, arquivado, arquivado_em, criado_em) values
(1,  'Toyota',        'Corolla XEi',        2025, 'FEG1A33', '9BRBDWHE5S0123451', 350,  'Disponível', true,  now() - interval '100 days', now() - interval '365 days'),
(2,  'BMW',           '320i',               2024, 'DEF2E34', 'WBA5R1C08RFS23456', 500,  'Disponível', true,  now() - interval '90 days',  now() - interval '365 days'),
(3,  'BMW',           'M3',                 2026, 'ABC1D23', 'WBS43AY05TFR12345', 500,  'Disponível', false, null, now() - interval '365 days'),
(4,  'Audi',          'A5 Sportback',       2024, 'AUD5E67', 'WAUZZZF54RA012345', 700,  'Disponível', false, null, now() - interval '365 days'),
(7,  'Volkswagen',    'Jetta GLI',          2023, 'GTR3R35', '3VW5T7BU2PM012345', 450,  'Disponível', false, null, now() - interval '360 days'),
(10, 'Porsche',       '911 Carrera',        2024, 'POR9A25', 'WP0AA2A93RS201234', 1800, 'Disponível', false, null, now() - interval '355 days'),
(11, 'Mercedes-Benz', 'C63 AMG',            2026, 'MER6B24', 'W1KAF8HB4TR012345', 2500, 'Disponível', false, null, now() - interval '350 days'),
(12, 'Toyota',        'Hilux SRX',          2023, 'HLX4521', '8AJBA3CD1P1654321', 380,  'Disponível', false, null, now() - interval '330 days'),
(13, 'Jeep',          'Compass Limited',    2024, 'JPC2F19', '988675139RKA12345', 320,  'Disponível', false, null, now() - interval '320 days'),
(14, 'Honda',         'Civic Touring',      2022, 'CVC8834', '93HFC2630NZ123456', 280,  'Disponível', false, null, now() - interval '310 days'),
(15, 'Land Rover',    'Range Rover Evoque', 2025, 'RRE7H40', 'SALZA2BX5SH123456', 1200, 'Disponível', false, null, now() - interval '300 days'),
(16, 'Chevrolet',     'Tracker Premier',    2025, 'TRK5C21', '9BGEP76H0SB123456', 260,  'Disponível', false, null, now() - interval '240 days'),
(17, 'Hyundai',       'HB20 Platinum',      2024, 'HBZ2D45', '9BHBG51CBRP123456', 180,  'Disponível', false, null, now() - interval '220 days'),
(18, 'Volvo',         'XC60 Recharge',      2025, 'VLV6G60', 'YV1UZL1V1S1234567', 900,  'Disponível', false, null, now() - interval '200 days');

-- Devolve as fotos que já estavam no Storage (mesma placa = mesmo carro)
update veiculos v set imagem = f.imagem from fotos_guardadas f where f.placa = v.placa;


-- =====================================================================
-- 5. Aluguéis
--    Aqui só vão os DADOS de cada aluguel. As CONTAS (valor previsto,
--    atraso, total) o próprio SQL faz logo abaixo, com a mesma regra da
--    função registrar_devolucao:
--      total = dias usados × diária + taxas
--      devolveu antes do previsto → cobra só os dias usados (decisão 10)
--
--    Colunas: id, cliente, veículo, retirada (dias atrás), diárias
--    previstas, dias usados (null = ainda não devolveu), taxa extra,
--    motivo da taxa, situação, observação.
-- =====================================================================

create temp table aluguel_demo on commit drop as
select * from (values
--   id cli vei  atrás prev usados taxa  motivo                              situação        observação
    ( 1,  1,  3, 350,  3,   3,    0, null,                                 'Finalizada',   null),
    ( 2,  3,  7, 330,  6,   6,    0, null,                                 'Finalizada',   null),
    ( 3,  2, 10, 310,  3,   5,    0, null,                                 'Finalizada',   'Devolvido com 2 dias de atraso.'),
    ( 4,  4,  4, 290,  5,   5,    0, null,                                 'Finalizada',   null),
    ( 5,  5, 12, 270,  7,   7,    0, null,                                 'Finalizada',   'Viagem para o litoral.'),
    ( 6,  6,  3, 250,  4,   4,    0, null,                                 'Finalizada',   null),
    ( 7,  1, 15, 235,  3,   3,    0, null,                                 'Finalizada',   null),
    ( 8,  7,  7, 220,  5,   5,    0, null,                                 'Finalizada',   null),
    ( 9,  9, 17, 200,  4,   4,    0, null,                                 'Finalizada',   null),
    (10, 10, 18, 185,  3,   3,  150, 'Limpeza interna (areia de praia)',   'Finalizada',   null),
    (11,  4, 10, 170,  2,   2,    0, null,                                 'Finalizada',   'Ensaio fotográfico de casamento.'),
    (12, 11, 11, 150,  4,   4,    0, null,                                 'Finalizada',   null),
    (13,  3, 12, 140,  6,   5,    0, null,                                 'Finalizada',   'Devolveu um dia antes: cobradas só as diárias usadas.'),
    (14,  2,  4, 120,  5,   5,    0, null,                                 'Finalizada',   null),
    (15,  5, 14, 105,  3,   3,    0, null,                                 'Finalizada',   null),
    (16,  9,  3,  95,  7,   7,    0, null,                                 'Finalizada',   null),
    (17,  6, 17,  80,  3,   4,    0, null,                                 'Finalizada',   'Devolvido com 1 dia de atraso.'),
    (18, 10, 15,  70,  5,   5,    0, null,                                 'Finalizada',   null),
    (19,  1, 18,  60,  4,   4,    0, null,                                 'Finalizada',   null),
    (20, 11, 10,  50,  2,   2,    0, null,                                 'Finalizada',   null),
    (21,  7, 12,  40,  3,   3,  120, 'Tanque devolvido na reserva',        'Finalizada',   null),
    (22,  4, 16,  32,  4,   4,    0, null,                                 'Finalizada',   null),
    (23,  3, 13,  25,  5,   5,    0, null,                                 'Finalizada',   'Cliente relatou barulho na suspensão.'),
    (24,  9,  4,  15,  2,   2,    0, null,                                 'Finalizada',   null),
    (25,  2, 18,  10,  2, null,   0, null,                                 'Cancelada',    'Cancelado: cliente desistiu antes da retirada.'),
    (26,  5, 17,   6,  3,   3,   80, 'Lavagem completa',                   'Finalizada',   null),
    -- Devolvidos nas últimas 2 semanas: o "Faturamento do mês" não fica vazio
    (27, 11, 10,  18,  2,   2,    0, null,                                 'Finalizada',   'Evento corporativo.'),
    (28,  7, 12,  12,  3,   3,    0, null,                                 'Finalizada',   null),
    (29,  9,  3,   8,  2,   2,    0, null,                                 'Finalizada',   null),
    -- Em andamento (o carro está com o cliente agora)
    (30,  6, 14,   9,  7, null,   0, null,                                 'Em andamento', null),  -- ATRASADO 2 dias
    (31,  2, 11,   3,  8, null,   0, null,                                 'Em andamento', null),
    (32,  1, 15,   2,  3, null,   0, null,                                 'Em andamento', null),  -- vence AMANHÃ
    (33, 10, 16,   1,  7, null,   0, null,                                 'Em andamento', 'Viagem a trabalho para Ribeirão Preto.')
) as t (id, cliente_id, veiculo_id, dias_atras, dias_previstos, dias_usados, taxa, motivo, situacao, obs);

-- Quem atendeu: reveza entre a equipe (se a conta existir)
create temp table equipe on commit drop as
select row_number() over (order by email) - 1 as vez, id
from perfis
where email in ('gabriel@royalecars.com.br', 'mariana@royalecars.com.br', 'lucas@royalecars.com.br');

insert into locacoes (id, cliente_id, veiculo_id, usuario_id, data_retirada, data_prevista, data_devolucao,
                      valor_diaria, dias_previstos, valor_previsto, dias_atraso, valor_atraso,
                      taxas_extras, taxas_motivo, valor_total, status, observacoes,
                      finalizado_por, finalizado_em, criado_em)
select a.id, a.cliente_id, a.veiculo_id,
       (select id from equipe where vez = a.id % 3),
       current_date - a.dias_atras,
       current_date - a.dias_atras + a.dias_previstos,
       case when a.situacao = 'Finalizada' then current_date - a.dias_atras + a.dias_usados end,
       v.valor_diaria,
       a.dias_previstos,
       a.dias_previstos * v.valor_diaria,
       -- atraso: só quando usou MAIS dias que o previsto
       greatest(0, coalesce(a.dias_usados, 0) - a.dias_previstos),
       greatest(0, coalesce(a.dias_usados, 0) - a.dias_previstos) * v.valor_diaria,
       a.taxa, a.motivo,
       -- total: cobra os dias usados (+ taxas). Em andamento e cancelado: 0
       case when a.situacao = 'Finalizada' then a.dias_usados * v.valor_diaria + a.taxa
            when a.situacao = 'Em andamento' then a.dias_previstos * v.valor_diaria
            else 0 end,
       a.situacao::status_locacao,
       a.obs,
       case when a.situacao <> 'Em andamento' then (select id from equipe where vez = (a.id + 1) % 3) end,
       case when a.situacao = 'Finalizada' then (current_date - a.dias_atras + a.dias_usados) + time '17:30'
            when a.situacao = 'Cancelada' then (current_date - a.dias_atras) + time '10:15' end,
       (current_date - a.dias_atras) + time '09:00'
from aluguel_demo a
join veiculos v on v.id = a.veiculo_id;


-- =====================================================================
-- 6. Manutenções
--    7 concluídas (o custo entra no gráfico do Financeiro) e 2 na
--    oficina agora:
--      - o Jeep, que voltou do aluguel 23 com barulho (previsão já
--        passou: aparece em vermelho, "atrasada")
--      - o Jetta, numa revisão com a vistoria feita
-- =====================================================================

insert into manutencoes (id, veiculo_id, locacao_id, defeito, oficina, data_entrada, previsao_liberacao, data_liberacao,
                         servico_realizado, custo, status, motor_ok, freios_ok, pneus_ok, oleo_ok,
                         usuario_id, concluido_por, criado_em) values
(1, 3,  null, 'Pastilhas de freio no limite de desgaste.', 'Auto Center Campinas',
    current_date - 240, current_date - 237, current_date - 237,
    'Troca de pastilhas e discos de freio dianteiros.', 850, 'Concluída', true, false, true, true,
    (select id from equipe where vez = 0), (select id from equipe where vez = 1), now() - interval '240 days'),
(2, 17, null, 'Revisão programada de 20.000 km.', 'Hyundai Prime',
    current_date - 130, current_date - 128, current_date - 127,
    'Troca de óleo e filtros, revisão dos freios.', 540, 'Concluída', null, null, null, null,
    (select id from equipe where vez = 1), (select id from equipe where vez = 2), now() - interval '130 days'),
(3, 12, null, 'Volante puxando para a direita.', 'Pneus & Cia',
    current_date - 160, current_date - 158, current_date - 158,
    'Alinhamento, balanceamento e rodízio de pneus.', 420, 'Concluída', true, true, false, true,
    (select id from equipe where vez = 2), (select id from equipe where vez = 0), now() - interval '160 days'),
(4, 10, null, 'Revisão programada de 30.000 km.', 'Porsche Center Campinas',
    current_date - 100, current_date - 98, current_date - 98,
    'Troca de óleo, filtros e velas.', 2300, 'Concluída', null, null, null, null,
    (select id from equipe where vez = 0), (select id from equipe where vez = 0), now() - interval '100 days'),
(5, 18, null, 'Ar-condicionado não está gelando.', 'Auto Frio Refrigeração',
    current_date - 45, current_date - 42, current_date - 41,
    'Recarga de gás e troca do filtro de cabine.', 680, 'Concluída', true, true, true, true,
    (select id from equipe where vez = 1), (select id from equipe where vez = 2), now() - interval '45 days'),
(6, 4,  null, 'Pneus dianteiros com desgaste irregular.', 'Pneus & Cia',
    current_date - 30, current_date - 29, current_date - 28,
    'Troca dos 4 pneus e alinhamento.', 1960, 'Concluída', true, true, false, true,
    (select id from equipe where vez = 2), (select id from equipe where vez = 1), now() - interval '30 days'),
(7, 14, null, 'Troca de óleo e filtros (revisão de 40.000 km).', 'Honda Sumaré',
    current_date - 16, current_date - 15, current_date - 15,
    'Troca de óleo, filtro de óleo e filtro de ar.', 390, 'Concluída', true, true, true, true,
    (select id from equipe where vez = 1), (select id from equipe where vez = 0), now() - interval '16 days'),
-- Na oficina agora
(8, 13, 23,   'Ruído na suspensão dianteira relatado pelo cliente na devolução.', 'Auto Center Campinas',
    current_date - 20, current_date - 2, null,
    null, null, 'Em andamento', true, true, true, false,
    (select id from equipe where vez = 2), null, now() - interval '20 days'),
(9, 7,  null, 'Revisão preventiva e troca da correia dentada.', 'VW Center Campinas',
    current_date - 1, current_date + 2, null,
    null, null, 'Em andamento', true, true, true, true,
    (select id from equipe where vez = 0), null, now() - interval '1 day');


-- =====================================================================
-- 7. Quilometragem
--    Carro por carro, em ordem de data: cada saída começa onde a volta
--    anterior terminou (uns 180 km por dia de aluguel).
-- =====================================================================

with ordem as (
    select l.id, l.veiculo_id, l.status,
           greatest(1, coalesce(l.data_devolucao, current_date) - l.data_retirada) as dias,
           row_number() over (partition by l.veiculo_id order by l.data_retirada) as n
    from locacoes l
    where l.status <> 'Cancelada'
),
km as (
    select o.*,
           8000 + o.veiculo_id * 1500
             + coalesce(sum(o.dias * 180) over (partition by o.veiculo_id order by o.n
                                                rows between unbounded preceding and 1 preceding), 0) as saida
    from ordem o
)
update locacoes l
   set km_saida   = k.saida,
       km_retorno = case when k.status = 'Finalizada' then k.saida + k.dias * 180 end
  from km k
 where l.id = k.id;

-- O cancelado sai com a quilometragem do carro naquele dia
update locacoes l set km_saida = 8000 + l.veiculo_id * 1500 + 1260 where l.status = 'Cancelada';

-- Quilometragem atual = a maior marcada (volta, ou saída se está alugado)
update veiculos v
   set quilometragem = coalesce(
        (select max(greatest(l.km_saida, coalesce(l.km_retorno, 0))) from locacoes l
          where l.veiculo_id = v.id and l.status <> 'Cancelada'),
        8000 + v.id * 1500);


-- =====================================================================
-- 8. Status de cada carro, de acordo com os aluguéis e manutenções
-- =====================================================================

update veiculos set status = 'Alugado'
 where id in (select veiculo_id from locacoes where status = 'Em andamento');

update veiculos set status = 'Em manutenção'
 where id in (select veiculo_id from manutencoes where status = 'Em andamento');


-- =====================================================================
-- 9. Os contadores (id) continuam depois dos dados de exemplo, e o
--    histórico começa limpo (os comandos acima geraram linhas "sem
--    usuário", que não interessam)
-- =====================================================================

select setval(pg_get_serial_sequence('clientes', 'id'),    (select max(id) from clientes));
select setval(pg_get_serial_sequence('veiculos', 'id'),    (select max(id) from veiculos));
select setval(pg_get_serial_sequence('locacoes', 'id'),    (select max(id) from locacoes));
select setval(pg_get_serial_sequence('manutencoes', 'id'), (select max(id) from manutencoes));

delete from logs;

commit;


-- =====================================================================
-- 10. Conferência: o resultado aparece embaixo, no Supabase
-- =====================================================================

select 'Clientes ativos'         as item, count(*)::text as total from clientes where not arquivado
union all select 'Veículos na frota',      count(*)::text from veiculos where not arquivado
union all select '  disponíveis',          count(*)::text from veiculos where not arquivado and status = 'Disponível'
union all select '  alugados',             count(*)::text from veiculos where status = 'Alugado'
union all select '  na oficina',           count(*)::text from veiculos where status = 'Em manutenção'
union all select 'Aluguéis em andamento',  count(*)::text from locacoes where status = 'Em andamento'
union all select '  atrasados',            count(*)::text from locacoes where status = 'Em andamento' and data_prevista < current_date
union all select 'Aluguéis finalizados',   count(*)::text from locacoes where status = 'Finalizada'
union all select 'Faturamento (12 meses)', 'R$ ' || replace(to_char(sum(valor_total), 'FM9999990.00'), '.', ',') from locacoes where status = 'Finalizada'
union all select 'Gasto com manutenção',   'R$ ' || replace(to_char(sum(custo), 'FM9999990.00'), '.', ',') from manutencoes where status = 'Concluída'
union all select 'Fotos de carro mantidas', count(*)::text from veiculos where imagem is not null;
