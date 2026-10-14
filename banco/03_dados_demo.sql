-- =====================================================================
--  ROYALE CARS - Dados de demonstração e contas da equipe
--  Rodar DEPOIS do 01 e do 02.
--
--  ANTES DE RODAR: criar as 4 contas de login no painel do Supabase
--  (Authentication → Users → Add user → Create new user), marcando
--  "Auto Confirm User":
--
--     gabriel@royalecars.com.br   (vai ser o chefe)
--     mariana@royalecars.com.br   (gerente)
--     lucas@royalecars.com.br     (funcionário, modelo Vendedor)
--     pedro@royalecars.com.br     (funcionário desativado, para testes)
--
--  O Supabase Auth guarda só o login (e-mail e senha). Este script cria o
--  "perfil" de cada um no Royale Cars: nome, cargo e permissões.
-- =====================================================================

set search_path = public;


-- =====================================================================
-- 1. Confere se as 4 contas existem antes de continuar
-- =====================================================================

do $$
declare
    faltando text;
begin
    select string_agg(e, ', ') into faltando
    from unnest(array['gabriel@royalecars.com.br', 'mariana@royalecars.com.br',
                      'lucas@royalecars.com.br', 'pedro@royalecars.com.br']) e
    where not exists (select 1 from auth.users u where u.email = e);

    if faltando is not null then
        raise exception 'Crie primeiro estas contas em Authentication → Users: %', faltando;
    end if;
end $$;


-- =====================================================================
-- 2. Perfis e permissões
-- =====================================================================

-- O chefe tem acesso a tudo, sem precisar marcar permissões
select criar_chefe('gabriel@royalecars.com.br', 'Gabriel S');

insert into perfis (id, nome, email, cargo, ativo)
select u.id, x.nome, u.email, x.cargo::cargo_usuario, x.ativo
from (values
    ('mariana@royalecars.com.br', 'Mariana Costa', 'gerente',     true),
    ('lucas@royalecars.com.br',   'Lucas Pereira', 'funcionario', true),
    ('pedro@royalecars.com.br',   'Pedro Alves',   'funcionario', false)
) as x (email, nome, cargo, ativo)
join auth.users u on u.email = x.email
on conflict (id) do update set nome = excluded.nome, cargo = excluded.cargo, ativo = excluded.ativo;

-- Permissões tiradas dos modelos (o mesmo que o botão "usar modelo" faz nas telas)
insert into usuario_permissoes (usuario_id, permissao)
select p.id, unnest(m.permissoes)
from perfis p
join modelos_permissao m on m.nome = case p.email
        when 'mariana@royalecars.com.br' then 'Gerente'
        when 'lucas@royalecars.com.br'   then 'Vendedor'
        when 'pedro@royalecars.com.br'   then 'Vendedor'
     end
on conflict do nothing;


-- =====================================================================
-- 3. Completa os dados de exemplo do script 01 com os campos novos
-- =====================================================================

-- Endereços (opcionais: alguns clientes ficam sem, de propósito)
update clientes set endereco = x.endereco
from (values
    (1, 'Rua Barão de Jaguara, 1200 - Centro, Campinas/SP'),
    (2, 'Av. Brasil, 455 - Jardim Guanabara, Campinas/SP'),
    (3, 'Rua José Paulino, 88 - Centro, Limeira/SP'),
    (4, 'Rua Augusta, 2100 - Consolação, São Paulo/SP'),
    (6, 'Av. Norte-Sul, 980 - Cambuí, Campinas/SP')
) as x (id, endereco)
where clientes.id = x.id;

-- Quilometragem de cada locação, em ordem, carro por carro:
-- cada saída começa onde a anterior terminou
with ordem as (
    select l.id, l.veiculo_id, l.status, l.dias_previstos,
           coalesce(l.data_devolucao, l.data_prevista) - l.data_retirada as dias_usados,
           row_number() over (partition by l.veiculo_id order by l.data_retirada) as n
    from locacoes l
),
km as (
    select o.*,
           8000 + o.veiculo_id * 1500
             + sum(greatest(1, o.dias_usados) * 180) over (partition by o.veiculo_id order by o.n
                                                            rows between unbounded preceding and 1 preceding) as saida
    from ordem o
)
update locacoes l
   set km_saida   = coalesce(k.saida, 8000 + k.veiculo_id * 1500),
       km_retorno = case when k.status = 'Finalizada'
                         then coalesce(k.saida, 8000 + k.veiculo_id * 1500) + greatest(1, k.dias_usados) * 180 end
  from km k
 where l.id = k.id;

-- Quilometragem atual do veículo = último retorno (ou última saída, se está alugado)
update veiculos v
   set quilometragem = coalesce(
        (select max(greatest(l.km_saida, coalesce(l.km_retorno, 0))) from locacoes l where l.veiculo_id = v.id),
        8000 + v.id * 1500);

-- Uma taxa extra de exemplo, para o financeiro mostrar
update locacoes
   set taxas_extras = 120, taxas_motivo = 'Tanque devolvido na reserva', valor_total = valor_total + 120
 where id = 12;

-- Checklist da manutenção que está aberta (o Jeep na oficina)
update manutencoes set motor_ok = true, freios_ok = true, pneus_ok = true, oleo_ok = false where id = 4;

-- Os updates acima geraram histórico "sem usuário"; não interessa
delete from logs where usuario_id is null;
