-- =====================================================================
--  ROYALE CARS - Banco unificado no Supabase (PostgreSQL)
--  Usado pelas 3 plataformas: Web (PHP), Desktop (Electron), Mobile (Flutter)
--
--  Como rodar: Supabase → SQL Editor → New query → cole tudo → Run.
--  ATENÇÃO: apaga e recria as tabelas do Royale Cars (não mexe em
--  auth.users, ou seja, as contas de login continuam existindo).
--
--  Ideia principal: as REGRAS ficam no banco, não em cada aplicativo.
--   - CHECK valida CPF, CNH, telefone, placa e chassi (com dígitos!)
--   - Gatilhos (triggers) padronizam formatos e gravam o histórico
--   - RLS (Row Level Security) aplica as permissões de cada pessoa
--   - Aluguel, devolução, cancelamento e manutenção são FUNÇÕES (RPC):
--     o app chama a função e o banco faz tudo numa transação.
--  Assim, web, desktop e celular se comportam exatamente igual.
-- =====================================================================

set search_path = public;

drop view if exists vw_alertas, vw_locacoes, vw_faturamento_mensal, vw_situacao_frota cascade;
drop table if exists logs, login_tentativas, manutencoes, locacoes, veiculos, clientes, usuario_permissoes, perfis cascade;
drop type if exists cargo_usuario, status_veiculo, status_locacao, status_manutencao cascade;


-- =====================================================================
-- 1. TIPOS (os textos de status são exatamente estes nas 3 plataformas)
-- =====================================================================

create type cargo_usuario     as enum ('chefe', 'gerente', 'funcionario');
create type status_veiculo    as enum ('Disponível', 'Alugado', 'Em manutenção');
create type status_locacao    as enum ('Em andamento', 'Finalizada', 'Cancelada');
create type status_manutencao as enum ('Em andamento', 'Concluída');


-- =====================================================================
-- 2. FUNÇÕES DE VALIDAÇÃO (mesmo algoritmo do PHP, do JS e do Dart)
-- =====================================================================

create or replace function so_digitos(valor text)
returns text language sql immutable as $$
    select regexp_replace(coalesce(valor, ''), '\D', '', 'g')
$$;

create or replace function validar_cpf(cpf text)
returns boolean language plpgsql immutable as $$
declare
    pos int; i int; soma int; dv int;
begin
    if cpf !~ '^\d{11}$' or cpf ~ '^(\d)\1{10}$' then
        return false;
    end if;

    for pos in 9..10 loop
        soma := 0;
        for i in 0..pos - 1 loop
            soma := soma + substr(cpf, i + 1, 1)::int * (pos + 1 - i);
        end loop;
        dv := (soma * 10) % 11;
        if dv = 10 then dv := 0; end if;
        if dv <> substr(cpf, pos + 1, 1)::int then
            return false;
        end if;
    end loop;

    return true;
end $$;

-- Aceita se passar em qualquer uma das 2 versões do cálculo em uso.
create or replace function validar_cnh(cnh text)
returns boolean language plpgsql immutable as $$
declare
    d int[]; i int; s int; r int; dv1 int; dv2 int; desconto int := 0;
begin
    if cnh !~ '^\d{11}$' or cnh ~ '^(\d)\1{10}$' then
        return false;
    end if;

    for i in 1..11 loop
        d[i] := substr(cnh, i, 1)::int;
    end loop;

    -- Versão 1
    s := 0;
    for i in 1..9 loop s := s + d[i] * (10 - i); end loop;
    dv1 := s % 11;
    if dv1 >= 10 then dv1 := 0; desconto := 2; end if;

    s := 0;
    for i in 1..9 loop s := s + d[i] * i; end loop;
    r := s % 11;
    dv2 := case when r >= 10 then 0 else r - desconto end;

    if dv1 = d[10] and dv2 = d[11] then
        return true;
    end if;

    -- Versão 2 (Detran-PR)
    s := 0;
    for i in 1..9 loop s := s + d[i] * (i + 1); end loop;
    r := s % 11;
    dv1 := case when r <= 1 then 0 else 11 - r end;

    s := dv1 * 2;
    for i in 1..9 loop s := s + d[i] * (i + 2); end loop;
    r := s % 11;
    dv2 := case when r <= 1 then 0 else 11 - r end;

    return dv1 = d[10] and dv2 = d[11];
end $$;

create or replace function validar_telefone(tel text)
returns boolean language sql immutable as $$
    select tel ~ '^\d{10,11}$'
       and substr(tel, 1, 2)::int = any (array[
            11,12,13,14,15,16,17,18,19,21,22,24,27,28,31,32,33,34,35,37,38,
            41,42,43,44,45,46,47,48,49,51,53,54,55,61,62,63,64,65,66,67,68,69,
            71,73,74,75,77,79,81,82,83,84,85,86,87,88,89,91,92,93,94,95,96,97,98,99])
       and case when length(tel) = 11 then substr(tel, 3, 1) = '9'
                else substr(tel, 3, 1) in ('2', '3', '4', '5') end
$$;


-- =====================================================================
-- 3. TABELAS
-- =====================================================================

-- Perfil de cada pessoa que usa o sistema (o login fica no Supabase Auth).
create table perfis (
    id            uuid primary key references auth.users (id) on delete cascade,
    nome          text not null check (char_length(trim(nome)) between 3 and 100),
    email         text not null unique check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    cargo         cargo_usuario not null default 'funcionario',
    ativo         boolean not null default true,
    trocar_senha  boolean not null default false,
    ultimo_acesso timestamptz,
    criado_em     timestamptz not null default now(),
    atualizado_em timestamptz
);

create table usuario_permissoes (
    usuario_id uuid not null references perfis (id) on delete cascade,
    permissao  text not null check (permissao in (
        'clientes_ver', 'clientes_gerenciar', 'clientes_arquivar',
        'veiculos_ver', 'veiculos_gerenciar', 'veiculos_arquivar',
        'locacoes_ver', 'locacoes_gerenciar', 'locacoes_cancelar',
        'manutencoes', 'financeiro', 'relatorios', 'relatorios_financeiros')),
    primary key (usuario_id, permissao)
);

create table clientes (
    id            bigint generated by default as identity primary key,
    nome          text not null check (char_length(nome) between 5 and 150 and nome ~ '\S+\s+\S+'),
    cpf           text not null unique check (validar_cpf(cpf)),
    cnh           text not null unique check (validar_cnh(cnh)),
    cnh_validade  date not null,
    email         text not null unique check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    telefone      text not null check (validar_telefone(telefone)),
    arquivado     boolean not null default false,
    arquivado_em  timestamptz,
    criado_em     timestamptz not null default now(),
    atualizado_em timestamptz
);

create table veiculos (
    id            bigint generated by default as identity primary key,
    marca         text not null check (char_length(trim(marca)) between 2 and 100),
    modelo        text not null check (char_length(trim(modelo)) between 1 and 100),
    ano           smallint not null check (ano between 1950 and 2100),
    placa         text not null unique check (placa ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
    chassi        text not null unique check (chassi ~ '^[A-HJ-NPR-Z0-9]{17}$' and chassi !~ '^(.)\1{16}$'),
    valor_diaria  numeric(10, 2) not null check (valor_diaria > 0),
    imagem        text,   -- caminho no Storage, bucket "veiculos"
    status        status_veiculo not null default 'Disponível',
    arquivado     boolean not null default false,
    arquivado_em  timestamptz,
    criado_em     timestamptz not null default now(),
    atualizado_em timestamptz
);

create table locacoes (
    id              bigint generated by default as identity primary key,
    cliente_id      bigint not null references clientes (id),
    veiculo_id      bigint not null references veiculos (id),
    usuario_id      uuid references perfis (id) on delete set null,
    data_retirada   date not null,
    data_prevista   date not null,
    data_devolucao  date,
    valor_diaria    numeric(10, 2) not null check (valor_diaria > 0),
    dias_previstos  int not null check (dias_previstos >= 1),
    valor_previsto  numeric(10, 2) not null check (valor_previsto >= 0),
    dias_atraso     int not null default 0 check (dias_atraso >= 0),
    valor_atraso    numeric(10, 2) not null default 0 check (valor_atraso >= 0),
    valor_total     numeric(10, 2) not null default 0 check (valor_total >= 0),
    status          status_locacao not null default 'Em andamento',
    observacoes     text,
    finalizado_por  uuid references perfis (id) on delete set null,
    finalizado_em   timestamptz,
    criado_em       timestamptz not null default now(),

    check (data_prevista >= data_retirada),
    check (data_devolucao is null or data_devolucao >= data_retirada)
);

-- Garantia extra: um carro só pode ter UM aluguel em andamento.
create unique index uk_locacao_ativa_por_veiculo on locacoes (veiculo_id) where status = 'Em andamento';
create index idx_locacoes_status on locacoes (status, data_prevista);
create index idx_locacoes_devolucao on locacoes (data_devolucao);

create table manutencoes (
    id                 bigint generated by default as identity primary key,
    veiculo_id         bigint not null references veiculos (id),
    locacao_id         bigint references locacoes (id) on delete set null,
    defeito            text not null check (char_length(defeito) between 5 and 1000),
    oficina            text check (oficina is null or char_length(oficina) <= 150),
    data_entrada       date not null,
    previsao_liberacao date check (previsao_liberacao is null or previsao_liberacao >= data_entrada),
    data_liberacao     date check (data_liberacao is null or data_liberacao >= data_entrada),
    servico_realizado  text,
    custo              numeric(10, 2) check (custo is null or custo >= 0),
    status             status_manutencao not null default 'Em andamento',
    usuario_id         uuid references perfis (id) on delete set null,
    concluido_por      uuid references perfis (id) on delete set null,
    criado_em          timestamptz not null default now()
);

-- Um carro só pode ter UMA manutenção aberta por vez.
create unique index uk_manutencao_aberta_por_veiculo on manutencoes (veiculo_id) where status = 'Em andamento';

create table logs (
    id          bigint generated always as identity primary key,
    usuario_id  uuid references perfis (id) on delete set null,
    modulo      text not null,
    acao        text not null,
    registro_id bigint,
    descricao   text not null,
    ip          text,
    criado_em   timestamptz not null default now()
);

create index idx_logs_data on logs (criado_em desc);

create table login_tentativas (
    id        bigint generated always as identity primary key,
    email     text not null,
    sucesso   boolean not null default false,
    motivo    text,
    ip        text,
    plataforma text check (plataforma in ('web', 'desktop', 'mobile')),
    criado_em timestamptz not null default now()
);

create index idx_tentativas_email on login_tentativas (email, criado_em desc);


-- =====================================================================
-- 4. QUEM ESTÁ LOGADO E O QUE PODE FAZER
-- =====================================================================

create or replace function usuario_ativo()
returns boolean language sql stable security definer set search_path = public as $$
    select exists (select 1 from perfis where id = auth.uid() and ativo)
$$;

create or replace function eh_chefe()
returns boolean language sql stable security definer set search_path = public as $$
    select exists (select 1 from perfis where id = auth.uid() and ativo and cargo = 'chefe')
$$;

create or replace function tem_permissao(p text)
returns boolean language sql stable security definer set search_path = public as $$
    select eh_chefe() or exists (
        select 1 from usuario_permissoes up
        join perfis pf on pf.id = up.usuario_id
        where up.usuario_id = auth.uid() and pf.ativo and up.permissao = p)
$$;

create or replace function exigir_permissao(p text)
returns void language plpgsql stable security definer set search_path = public as $$
begin
    if not tem_permissao(p) then
        raise exception 'Você não tem permissão para esta ação.' using errcode = '42501';
    end if;
end $$;

-- IP de quem fez a requisição (o Supabase repassa no cabeçalho)
create or replace function ip_requisicao()
returns text language sql stable as $$
    select split_part(coalesce(nullif(current_setting('request.headers', true), '')::json ->> 'x-forwarded-for', ''), ',', 1)
$$;

create or replace function registrar_log(p_modulo text, p_acao text, p_registro_id bigint, p_descricao text)
returns void language sql security definer set search_path = public as $$
    insert into logs (usuario_id, modulo, acao, registro_id, descricao, ip)
    values (auth.uid(), p_modulo, p_acao, p_registro_id, p_descricao, nullif(ip_requisicao(), ''))
$$;

-- Funções de formatação para textos do histórico
create or replace function fmt_moeda(v numeric)
returns text language sql immutable as $$
    select 'R$ ' || translate(to_char(v, 'FM999,999,990.00'), ',.', '.,')
$$;

create or replace function fmt_placa(p text)
returns text language sql immutable as $$
    select case when p ~ '^[A-Z]{3}\d{4}$' then substr(p, 1, 3) || '-' || substr(p, 4) else p end
$$;

create or replace function fmt_cpf(c text)
returns text language sql immutable as $$
    select substr(c, 1, 3) || '.' || substr(c, 4, 3) || '.' || substr(c, 7, 3) || '-' || substr(c, 10, 2)
$$;

-- Liga o "modo função" dentro de uma transação: só as funções oficiais
-- (aluguel, devolução, manutenção) podem mudar o status de um veículo.
create or replace function _modo_rpc()
returns void language sql as $$
    select set_config('royale.rpc', '1', true)
$$;

create or replace function _em_modo_rpc()
returns boolean language sql stable as $$
    select coalesce(current_setting('royale.rpc', true), '') = '1'
$$;


-- =====================================================================
-- 5. GATILHOS: padronizam dados, aplicam regras e gravam o histórico
-- =====================================================================

-- ---------- CLIENTES ----------

create or replace function tg_clientes_antes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    -- Formatos padrão, venha de onde vier (web, desktop ou celular)
    new.nome     := regexp_replace(trim(new.nome), '\s+', ' ', 'g');
    new.cpf      := so_digitos(new.cpf);
    new.cnh      := so_digitos(new.cnh);
    new.telefone := so_digitos(new.telefone);
    new.email    := lower(trim(new.email));

    if tg_op = 'UPDATE' then
        new.atualizado_em := now();

        if new.arquivado is distinct from old.arquivado then
            if auth.uid() is not null then
                perform exigir_permissao('clientes_arquivar');
            end if;

            if new.arquivado and exists (
                select 1 from locacoes where cliente_id = new.id and status = 'Em andamento') then
                raise exception 'O cliente % tem aluguel em andamento. Registre a devolução antes de arquivar.', new.nome;
            end if;

            new.arquivado_em := case when new.arquivado then now() else null end;
        end if;

        if auth.uid() is not null and (new.nome, new.cpf, new.cnh, new.cnh_validade, new.email, new.telefone)
            is distinct from (old.nome, old.cpf, old.cnh, old.cnh_validade, old.email, old.telefone) then
            perform exigir_permissao('clientes_gerenciar');

            if old.arquivado then
                raise exception 'Cliente arquivado. Reative o cadastro para poder editar.';
            end if;
        end if;
    end if;

    return new;
end $$;

create or replace function tg_clientes_depois()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    mudancas text[] := '{}';
begin
    if tg_op = 'INSERT' then
        perform registrar_log('clientes', 'cadastrar', new.id,
            format('Cadastrou o cliente %s (CPF %s).', new.nome, fmt_cpf(new.cpf)));
        return null;
    end if;

    if new.arquivado and not old.arquivado then
        perform registrar_log('clientes', 'arquivar', new.id, format('Arquivou o cliente %s (CPF %s).', new.nome, fmt_cpf(new.cpf)));
    elsif old.arquivado and not new.arquivado then
        perform registrar_log('clientes', 'reativar', new.id, format('Reativou o cliente %s.', new.nome));
    end if;

    if new.nome is distinct from old.nome then mudancas := mudancas || format('nome: %s → %s', old.nome, new.nome); end if;
    if new.cpf is distinct from old.cpf then mudancas := mudancas || format('CPF: %s → %s', fmt_cpf(old.cpf), fmt_cpf(new.cpf)); end if;
    if new.cnh is distinct from old.cnh then mudancas := mudancas || format('CNH: %s → %s', old.cnh, new.cnh); end if;
    if new.cnh_validade is distinct from old.cnh_validade then
        mudancas := mudancas || format('validade da CNH: %s → %s', to_char(old.cnh_validade, 'DD/MM/YYYY'), to_char(new.cnh_validade, 'DD/MM/YYYY'));
    end if;
    if new.email is distinct from old.email then mudancas := mudancas || format('e-mail: %s → %s', old.email, new.email); end if;
    if new.telefone is distinct from old.telefone then mudancas := mudancas || format('telefone: %s → %s', old.telefone, new.telefone); end if;

    if array_length(mudancas, 1) > 0 then
        perform registrar_log('clientes', 'editar', new.id,
            format('Editou o cliente %s: %s.', new.nome, array_to_string(mudancas, '; ')));
    end if;

    return null;
end $$;

create trigger clientes_antes before insert or update on clientes
    for each row execute function tg_clientes_antes();
create trigger clientes_depois after insert or update on clientes
    for each row execute function tg_clientes_depois();


-- ---------- VEÍCULOS ----------

create or replace function tg_veiculos_antes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    new.marca  := regexp_replace(trim(new.marca), '\s+', ' ', 'g');
    new.modelo := regexp_replace(trim(new.modelo), '\s+', ' ', 'g');
    new.placa  := upper(regexp_replace(new.placa, '[\s-]', '', 'g'));
    new.chassi := upper(regexp_replace(new.chassi, '\s', '', 'g'));

    if tg_op = 'INSERT' then
        if not _em_modo_rpc() and auth.uid() is not null then
            new.status := 'Disponível';   -- todo veículo novo entra disponível
        end if;
        return new;
    end if;

    new.atualizado_em := now();

    if new.arquivado is distinct from old.arquivado then
        if auth.uid() is not null then
            perform exigir_permissao('veiculos_arquivar');
        end if;

        if new.arquivado and old.status <> 'Disponível' then
            raise exception 'Só é possível arquivar veículos disponíveis. Este está: %.', old.status;
        end if;

        new.arquivado_em := case when new.arquivado then now() else null end;

        if not new.arquivado then
            new.status := 'Disponível';
        end if;
    elsif new.status is distinct from old.status and not _em_modo_rpc() and auth.uid() is not null then
        raise exception 'O status do veículo muda sozinho com aluguéis e manutenções; não pode ser alterado à mão.';
    end if;

    if auth.uid() is not null and (new.marca, new.modelo, new.ano, new.placa, new.chassi, new.valor_diaria, new.imagem)
        is distinct from (old.marca, old.modelo, old.ano, old.placa, old.chassi, old.valor_diaria, old.imagem) then
        perform exigir_permissao('veiculos_gerenciar');

        if old.arquivado then
            raise exception 'Veículo arquivado. Reative para poder editar.';
        end if;
    end if;

    return new;
end $$;

create or replace function tg_veiculos_depois()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    mudancas text[] := '{}';
    nome text := new.marca || ' ' || new.modelo || ' (' || fmt_placa(new.placa) || ')';
begin
    if tg_op = 'INSERT' then
        perform registrar_log('veiculos', 'cadastrar', new.id,
            format('Cadastrou o veículo %s, diária de %s.', nome, fmt_moeda(new.valor_diaria)));
        return null;
    end if;

    if new.arquivado and not old.arquivado then
        perform registrar_log('veiculos', 'arquivar', new.id, format('Arquivou o veículo %s.', nome));
    elsif old.arquivado and not new.arquivado then
        perform registrar_log('veiculos', 'reativar', new.id, format('Reativou o veículo %s.', nome));
    end if;

    if new.marca is distinct from old.marca then mudancas := mudancas || format('marca: %s → %s', old.marca, new.marca); end if;
    if new.modelo is distinct from old.modelo then mudancas := mudancas || format('modelo: %s → %s', old.modelo, new.modelo); end if;
    if new.ano is distinct from old.ano then mudancas := mudancas || format('ano: %s → %s', old.ano, new.ano); end if;
    if new.placa is distinct from old.placa then mudancas := mudancas || format('placa: %s → %s', fmt_placa(old.placa), fmt_placa(new.placa)); end if;
    if new.chassi is distinct from old.chassi then mudancas := mudancas || format('chassi: %s → %s', old.chassi, new.chassi); end if;
    if new.valor_diaria is distinct from old.valor_diaria then
        mudancas := mudancas || format('diária de %s para %s', fmt_moeda(old.valor_diaria), fmt_moeda(new.valor_diaria));
    end if;
    if new.imagem is distinct from old.imagem then mudancas := mudancas || 'trocou a foto'; end if;

    if array_length(mudancas, 1) > 0 then
        perform registrar_log('veiculos', 'editar', new.id, format('Editou o %s: %s.', nome, array_to_string(mudancas, '; ')));
    end if;

    return null;
end $$;

create trigger veiculos_antes before insert or update on veiculos
    for each row execute function tg_veiculos_antes();
create trigger veiculos_depois after insert or update on veiculos
    for each row execute function tg_veiculos_depois();


-- ---------- PERFIS (usuários) ----------

create or replace function tg_perfis_antes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    new.nome  := regexp_replace(trim(new.nome), '\s+', ' ', 'g');
    new.email := lower(trim(new.email));

    if tg_op = 'UPDATE' then
        new.atualizado_em := now();

        -- Cargo, situação e e-mail só o chefe muda (ou o servidor/Edge Function)
        if auth.uid() is not null and not eh_chefe()
           and (new.cargo, new.ativo, new.email) is distinct from (old.cargo, old.ativo, old.email) then
            raise exception 'Só o chefe pode alterar cargo, situação ou e-mail de acesso.';
        end if;

        if auth.uid() is not null and new.trocar_senha and not old.trocar_senha and not eh_chefe() then
            raise exception 'Operação não permitida.';
        end if;

        -- Ninguém tira o próprio acesso de chefe
        if auth.uid() = old.id and old.cargo = 'chefe' and (new.cargo <> 'chefe' or not new.ativo) then
            raise exception 'O chefe não pode desativar a si mesmo nem mudar o próprio cargo.';
        end if;

        if auth.uid() is not null and new.cargo = 'chefe' and old.cargo <> 'chefe' then
            raise exception 'O cargo de chefe não pode ser dado pelo sistema.';
        end if;
    end if;

    return new;
end $$;

create or replace function tg_perfis_depois()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if tg_op = 'INSERT' then
        perform registrar_log('usuarios', 'cadastrar', null,
            format('Cadastrou %s %s (%s).',
                case new.cargo when 'chefe' then 'o chefe' when 'gerente' then 'o gerente' else 'o funcionário' end,
                new.nome, new.email));
    else
        if new.ativo is distinct from old.ativo then
            perform registrar_log('usuarios', case when new.ativo then 'ativar' else 'desativar' end, null,
                format('%s o acesso de %s.', case when new.ativo then 'Reativou' else 'Desativou' end, new.nome));
        end if;
        if new.cargo is distinct from old.cargo then
            perform registrar_log('usuarios', 'editar', null, format('Mudou o cargo de %s: %s → %s.', new.nome, old.cargo, new.cargo));
        end if;
    end if;
    return null;
end $$;

create trigger perfis_antes before insert or update on perfis
    for each row execute function tg_perfis_antes();
create trigger perfis_depois after insert or update on perfis
    for each row execute function tg_perfis_depois();


-- ---------- PERMISSÕES ----------

create or replace function tg_permissoes_depois()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    alvo text;
begin
    select nome into alvo from perfis where id = coalesce(new.usuario_id, old.usuario_id);

    if tg_op = 'INSERT' then
        perform registrar_log('usuarios', 'permissao', null, format('Liberou "%s" para %s.', new.permissao, alvo));
    else
        perform registrar_log('usuarios', 'permissao', null, format('Retirou "%s" de %s.', old.permissao, alvo));
    end if;

    return null;
end $$;

create trigger permissoes_depois after insert or delete on usuario_permissoes
    for each row execute function tg_permissoes_depois();


-- =====================================================================
-- 6. FUNÇÕES DE NEGÓCIO (chamadas pelos apps via RPC)
--    Web (PHP):   POST /rest/v1/rpc/registrar_aluguel
--    Electron:    supabase.rpc('registrar_aluguel', { ... })
--    Flutter:     supabase.rpc('registrar_aluguel', params: { ... })
-- =====================================================================

-- ---------- Registrar aluguel (retirada) ----------
create or replace function registrar_aluguel(
    p_cliente_id    bigint,
    p_veiculo_id    bigint,
    p_data_retirada date,
    p_data_prevista date,
    p_observacoes   text default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
    c clientes; v veiculos; dias int; novo_id bigint; hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
    perform exigir_permissao('locacoes_gerenciar');
    perform _modo_rpc();

    select * into c from clientes where id = p_cliente_id and not arquivado;
    if not found then raise exception 'Selecione um cliente ativo.'; end if;

    if p_data_retirada > hoje then
        raise exception 'A retirada não pode ser no futuro.';
    elsif p_data_retirada < hoje - 30 then
        raise exception 'A retirada não pode ser de mais de 30 dias atrás.';
    elsif p_data_prevista < p_data_retirada then
        raise exception 'A devolução não pode ser antes da retirada.';
    elsif p_data_prevista < hoje then
        raise exception 'A devolução prevista não pode ser antes de hoje.';
    elsif p_data_prevista - p_data_retirada > 365 then
        raise exception 'O aluguel pode ter no máximo 365 dias.';
    end if;

    if c.cnh_validade < hoje then
        raise exception 'A CNH de % venceu em %. Atualize o cadastro antes de alugar.', c.nome, to_char(c.cnh_validade, 'DD/MM/YYYY');
    elsif c.cnh_validade < p_data_prevista then
        raise exception 'A CNH de % vence em %, antes do fim do aluguel.', c.nome, to_char(c.cnh_validade, 'DD/MM/YYYY');
    end if;

    -- Trava o veículo até o fim da transação
    select * into v from veiculos where id = p_veiculo_id for update;
    if not found or v.arquivado then raise exception 'Veículo não encontrado.'; end if;
    if v.status <> 'Disponível' then
        raise exception '% % não está disponível (status: %).', v.marca, v.modelo, v.status;
    end if;

    dias := greatest(1, p_data_prevista - p_data_retirada);

    insert into locacoes (cliente_id, veiculo_id, usuario_id, data_retirada, data_prevista,
                          valor_diaria, dias_previstos, valor_previsto, valor_total, observacoes)
    values (c.id, v.id, auth.uid(), p_data_retirada, p_data_prevista,
            v.valor_diaria, dias, dias * v.valor_diaria, dias * v.valor_diaria, nullif(trim(p_observacoes), ''))
    returning id into novo_id;

    update veiculos set status = 'Alugado' where id = v.id;

    perform registrar_log('locacoes', 'cadastrar', novo_id,
        format('Registrou o aluguel #%s: %s %s (%s) para %s, %s a %s, %s diária(s), previsto %s.',
            novo_id, v.marca, v.modelo, fmt_placa(v.placa), c.nome,
            to_char(p_data_retirada, 'DD/MM/YYYY'), to_char(p_data_prevista, 'DD/MM/YYYY'), dias, fmt_moeda(dias * v.valor_diaria)));

    return novo_id;
end $$;


-- ---------- Registrar devolução ----------
-- p_defeito preenchido = o carro voltou com defeito e vai direto para a manutenção.
create or replace function registrar_devolucao(
    p_locacao_id     bigint,
    p_data_devolucao date,
    p_observacoes    text default null,
    p_defeito        text default null,
    p_oficina        text default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
    l locacoes; v veiculos; dias int; atraso int; total numeric; obs text; novo_status status_veiculo;
    hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
    perform exigir_permissao('locacoes_gerenciar');
    perform _modo_rpc();

    select * into l from locacoes where id = p_locacao_id for update;
    if not found or l.status <> 'Em andamento' then
        raise exception 'Aluguel não encontrado ou já encerrado.';
    end if;

    if p_data_devolucao < l.data_retirada then
        raise exception 'A devolução não pode ser antes da retirada (%).', to_char(l.data_retirada, 'DD/MM/YYYY');
    elsif p_data_devolucao > hoje then
        raise exception 'A devolução não pode ser registrada com data futura.';
    end if;

    if p_defeito is not null and char_length(trim(p_defeito)) < 5 then
        raise exception 'Descreva o defeito encontrado.';
    end if;

    select * into v from veiculos where id = l.veiculo_id for update;

    dias   := greatest(1, p_data_devolucao - l.data_retirada);
    atraso := greatest(0, p_data_devolucao - l.data_prevista);
    total  := dias * l.valor_diaria;
    obs    := nullif(trim(concat_ws(E'\n', l.observacoes,
                case when nullif(trim(p_observacoes), '') is not null then 'Na devolução: ' || trim(p_observacoes) end)), '');

    update locacoes
       set status = 'Finalizada', data_devolucao = p_data_devolucao,
           dias_atraso = atraso, valor_atraso = atraso * l.valor_diaria, valor_total = total,
           observacoes = obs, finalizado_por = auth.uid(), finalizado_em = now()
     where id = l.id;

    perform registrar_log('locacoes', 'finalizar', l.id,
        format('Registrou a devolução do aluguel #%s: %s %s (%s). %s diária(s), total %s%s.',
            l.id, v.marca, v.modelo, fmt_placa(v.placa), dias, fmt_moeda(total),
            case when atraso > 0 then format(', com %s dia(s) de atraso', atraso) else '' end));

    if nullif(trim(p_defeito), '') is not null then
        insert into manutencoes (veiculo_id, locacao_id, defeito, oficina, data_entrada, usuario_id)
        values (v.id, l.id, trim(p_defeito), nullif(trim(p_oficina), ''), p_data_devolucao, auth.uid());

        perform registrar_log('manutencoes', 'abrir', currval(pg_get_serial_sequence('manutencoes', 'id')),
            format('Enviou o %s %s (%s) para manutenção na devolução: %s.', v.marca, v.modelo, fmt_placa(v.placa), trim(p_defeito)));
    end if;

    novo_status := case when exists (select 1 from manutencoes where veiculo_id = v.id and status = 'Em andamento')
                        then 'Em manutenção' else 'Disponível' end;

    update veiculos set status = novo_status where id = v.id;

    return json_build_object('dias', dias, 'dias_atraso', atraso, 'valor_atraso', atraso * l.valor_diaria,
                             'valor_total', total, 'status_veiculo', novo_status);
end $$;


-- ---------- Cancelar aluguel ----------
create or replace function cancelar_aluguel(p_locacao_id bigint, p_motivo text)
returns void
language plpgsql security definer set search_path = public as $$
declare
    l locacoes; v veiculos;
begin
    perform exigir_permissao('locacoes_cancelar');
    perform _modo_rpc();

    if char_length(trim(coalesce(p_motivo, ''))) < 5 then
        raise exception 'Informe o motivo do cancelamento.';
    end if;

    select * into l from locacoes where id = p_locacao_id for update;
    if not found or l.status <> 'Em andamento' then
        raise exception 'Só é possível cancelar aluguéis em andamento.';
    end if;

    select * into v from veiculos where id = l.veiculo_id for update;

    update locacoes
       set status = 'Cancelada', valor_total = 0,
           observacoes = trim(concat_ws(E'\n', l.observacoes, 'Cancelado: ' || trim(p_motivo))),
           finalizado_por = auth.uid(), finalizado_em = now()
     where id = l.id;

    update veiculos
       set status = case when exists (select 1 from manutencoes where veiculo_id = v.id and status = 'Em andamento')
                         then 'Em manutenção'::status_veiculo else 'Disponível'::status_veiculo end
     where id = v.id;

    perform registrar_log('locacoes', 'cancelar', l.id,
        format('Cancelou o aluguel #%s (%s %s). Motivo: %s', l.id, v.marca, v.modelo, trim(p_motivo)));
end $$;


-- ---------- Enviar para manutenção ----------
create or replace function abrir_manutencao(
    p_veiculo_id   bigint,
    p_defeito      text,
    p_oficina      text default null,
    p_data_entrada date default null,
    p_previsao     date default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
    v veiculos; novo_id bigint; hoje date := (now() at time zone 'America/Sao_Paulo')::date;
    entrada date := coalesce(p_data_entrada, (now() at time zone 'America/Sao_Paulo')::date);
begin
    perform exigir_permissao('manutencoes');
    perform _modo_rpc();

    if entrada > hoje or entrada < hoje - 30 then
        raise exception 'Data de entrada inválida (até hoje e no máximo 30 dias atrás).';
    end if;

    select * into v from veiculos where id = p_veiculo_id for update;
    if not found or v.arquivado then raise exception 'Veículo não encontrado.'; end if;
    if v.status <> 'Disponível' then
        raise exception '% % está "%". Só veículos disponíveis podem ir para a oficina por aqui.', v.marca, v.modelo, v.status;
    end if;

    insert into manutencoes (veiculo_id, defeito, oficina, data_entrada, previsao_liberacao, usuario_id)
    values (v.id, trim(p_defeito), nullif(trim(p_oficina), ''), entrada, p_previsao, auth.uid())
    returning id into novo_id;

    update veiculos set status = 'Em manutenção' where id = v.id;

    perform registrar_log('manutencoes', 'abrir', novo_id,
        format('Enviou o %s %s (%s) para manutenção: %s.', v.marca, v.modelo, fmt_placa(v.placa), trim(p_defeito)));

    return novo_id;
end $$;


-- ---------- Liberar da manutenção ----------
create or replace function concluir_manutencao(
    p_manutencao_id  bigint,
    p_data_liberacao date,
    p_servico        text,
    p_custo          numeric
) returns void
language plpgsql security definer set search_path = public as $$
declare
    m manutencoes; v veiculos; hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
    perform exigir_permissao('manutencoes');
    perform _modo_rpc();

    select * into m from manutencoes where id = p_manutencao_id for update;
    if not found or m.status <> 'Em andamento' then
        raise exception 'Manutenção não encontrada ou já concluída.';
    end if;

    if p_data_liberacao < m.data_entrada or p_data_liberacao > hoje then
        raise exception 'A liberação deve ser entre a entrada (%) e hoje.', to_char(m.data_entrada, 'DD/MM/YYYY');
    end if;

    if char_length(trim(coalesce(p_servico, ''))) < 5 then
        raise exception 'Descreva o serviço realizado.';
    end if;

    if p_custo is null or p_custo < 0 then
        raise exception 'Informe o custo do reparo (use 0 se foi na garantia).';
    end if;

    select * into v from veiculos where id = m.veiculo_id for update;

    update manutencoes
       set status = 'Concluída', data_liberacao = p_data_liberacao, servico_realizado = trim(p_servico),
           custo = round(p_custo, 2), concluido_por = auth.uid()
     where id = m.id;

    if v.status = 'Em manutenção' and not exists (
        select 1 from manutencoes where veiculo_id = v.id and status = 'Em andamento') then
        update veiculos set status = 'Disponível' where id = v.id;
    end if;

    perform registrar_log('manutencoes', 'concluir', m.id,
        format('Liberou o %s %s (%s) da manutenção. Serviço: %s. Custo: %s.',
            v.marca, v.modelo, fmt_placa(v.placa), trim(p_servico), fmt_moeda(p_custo)));
end $$;


-- ---------- Login: tentativas, bloqueio e último acesso ----------
-- O Supabase Auth já limita tentativas por IP. Estas funções dão o
-- bloqueio por e-mail (5 erros em 15 min) e o painel do chefe.

create or replace function login_bloqueado(p_email text)
returns boolean language sql stable security definer set search_path = public as $$
    select count(*) >= 5 from login_tentativas
    where email = lower(trim(p_email)) and not sucesso and criado_em > now() - interval '15 minutes'
$$;

create or replace function registrar_tentativa_login(p_email text, p_sucesso boolean, p_motivo text default null, p_plataforma text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
    insert into login_tentativas (email, sucesso, motivo, ip, plataforma)
    values (left(lower(trim(p_email)), 150), p_sucesso, left(p_motivo, 100), nullif(ip_requisicao(), ''),
            case when p_plataforma in ('web', 'desktop', 'mobile') then p_plataforma end);
end $$;

-- Chamar logo depois do login: devolve o perfil e as permissões.
-- Se o usuário estiver desativado, dá erro (o app deve fazer signOut).
create or replace function iniciar_sessao(p_plataforma text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
    p perfis;
begin
    select * into p from perfis where id = auth.uid();

    if not found then
        raise exception 'Usuário sem perfil no Royale Cars. Fale com o chefe.';
    end if;

    if not p.ativo then
        raise exception 'Seu acesso está desativado. Fale com o responsável pela locadora.';
    end if;

    update perfis set ultimo_acesso = now() where id = p.id;
    perform registrar_log('seguranca', 'login', null, format('Entrou no sistema (%s).', coalesce(p_plataforma, '?')));

    return json_build_object(
        'id', p.id, 'nome', p.nome, 'email', p.email, 'cargo', p.cargo, 'trocar_senha', p.trocar_senha,
        'permissoes', case when p.cargo = 'chefe' then
                          array['clientes_ver','clientes_gerenciar','clientes_arquivar','veiculos_ver','veiculos_gerenciar',
                                'veiculos_arquivar','locacoes_ver','locacoes_gerenciar','locacoes_cancelar','manutencoes',
                                'financeiro','relatorios','relatorios_financeiros']
                      else coalesce((select array_agg(permissao order by permissao) from usuario_permissoes where usuario_id = p.id), '{}') end);
end $$;

-- Chamada pela Edge Function depois de gerar a senha temporária
create or replace function marcar_senha_redefinida(p_usuario_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
    alvo perfis;
begin
    if not eh_chefe() then
        raise exception 'Só o chefe pode redefinir senhas.' using errcode = '42501';
    end if;

    select * into alvo from perfis where id = p_usuario_id;
    if not found or alvo.cargo = 'chefe' then
        raise exception 'Não é possível redefinir a senha deste usuário.';
    end if;

    update perfis set trocar_senha = true where id = alvo.id;
    delete from login_tentativas where email = alvo.email and not sucesso and criado_em > now() - interval '15 minutes';
    perform registrar_log('usuarios', 'redefinir_senha', null, format('Redefiniu a senha de %s (senha temporária gerada).', alvo.nome));
end $$;

-- Chamar depois de supabase.auth.updateUser({ password }) na troca obrigatória
create or replace function senha_trocada()
returns void language sql security definer set search_path = public as $$
    update perfis set trocar_senha = false where id = auth.uid();
    select registrar_log('usuarios', 'alterar_senha', null, 'Alterou a própria senha.');
$$;

-- Para o PRIMEIRO chefe: crie o usuário em Authentication → Add user e
-- rode no SQL Editor:  select criar_chefe('gabriel@gmail.com', 'Gabriel S');
create or replace function criar_chefe(p_email text, p_nome text)
returns void language plpgsql security definer set search_path = public as $$
declare
    uid uuid;
begin
    select id into uid from auth.users where email = lower(trim(p_email));
    if uid is null then
        raise exception 'Crie primeiro o usuário % em Authentication → Users.', p_email;
    end if;

    insert into perfis (id, nome, email, cargo, ativo)
    values (uid, p_nome, lower(trim(p_email)), 'chefe', true)
    on conflict (id) do update set cargo = 'chefe', ativo = true, nome = excluded.nome;
end $$;


-- =====================================================================
-- 7. VISÕES PRONTAS (as 3 plataformas leem daqui, com as mesmas contas)
--    security_invoker = as permissões (RLS) de quem consulta continuam valendo
-- =====================================================================

create view vw_locacoes with (security_invoker = true) as
select l.*,
       case when l.status = 'Em andamento' and l.data_prevista < current_date then 'Atrasada'
            else l.status::text end                                   as status_exibicao,
       greatest(0, current_date - l.data_prevista)
           * (l.status = 'Em andamento')::int                         as dias_atraso_atual,
       c.nome as cliente_nome, c.telefone as cliente_telefone, c.cpf as cliente_cpf,
       v.marca, v.modelo, v.placa,
       u.nome as registrado_por, f.nome as encerrado_por
from locacoes l
join clientes c on c.id = l.cliente_id
join veiculos v on v.id = l.veiculo_id
left join perfis u on u.id = l.usuario_id
left join perfis f on f.id = l.finalizado_por;

create view vw_situacao_frota with (security_invoker = true) as
select count(*) filter (where status = 'Disponível')    as disponiveis,
       count(*) filter (where status = 'Alugado')       as alugados,
       count(*) filter (where status = 'Em manutenção') as em_manutencao,
       count(*)                                         as total
from veiculos where not arquivado;

create view vw_faturamento_mensal with (security_invoker = true) as
with meses as (
    select generate_series(date_trunc('month', current_date) - interval '11 months',
                           date_trunc('month', current_date), interval '1 month')::date as mes
)
select m.mes,
       coalesce((select sum(valor_total) from locacoes
                 where status = 'Finalizada' and date_trunc('month', data_devolucao) = m.mes), 0) as faturamento,
       coalesce((select count(*) from locacoes
                 where status = 'Finalizada' and date_trunc('month', data_devolucao) = m.mes), 0) as alugueis,
       coalesce((select sum(custo) from manutencoes
                 where status = 'Concluída' and date_trunc('month', data_liberacao) = m.mes), 0) as manutencao
from meses m
where tem_permissao('financeiro')
order by m.mes;

create view vw_alertas with (security_invoker = true) as
select 'atraso' as tipo, l.id as referencia_id,
       format('%s %s (%s) com %s', v.marca, v.modelo, v.placa, c.nome) as titulo,
       format('%s dia(s) de atraso — devolução era %s', current_date - l.data_prevista, to_char(l.data_prevista, 'DD/MM/YYYY')) as detalhe,
       l.data_prevista as data
from locacoes l join clientes c on c.id = l.cliente_id join veiculos v on v.id = l.veiculo_id
where l.status = 'Em andamento' and l.data_prevista < current_date
union all
select 'devolucao_proxima', l.id,
       format('%s %s (%s) com %s', v.marca, v.modelo, v.placa, c.nome),
       format('Devolução em %s', to_char(l.data_prevista, 'DD/MM/YYYY')), l.data_prevista
from locacoes l join clientes c on c.id = l.cliente_id join veiculos v on v.id = l.veiculo_id
where l.status = 'Em andamento' and l.data_prevista between current_date and current_date + 2
union all
select 'manutencao', m.id,
       format('%s %s (%s) na oficina', v.marca, v.modelo, v.placa),
       format('Há %s dia(s)%s', current_date - m.data_entrada,
              case when m.previsao_liberacao < current_date then ' — previsão vencida' else '' end),
       m.data_entrada
from manutencoes m join veiculos v on v.id = m.veiculo_id
where m.status = 'Em andamento'
union all
select 'cnh', c.id, c.nome,
       case when c.cnh_validade < current_date then 'CNH venceu em ' else 'CNH vence em ' end || to_char(c.cnh_validade, 'DD/MM/YYYY'),
       c.cnh_validade
from clientes c
where not c.arquivado and c.cnh_validade <= current_date + 30
union all
select 'login_suspeito', null, t.email,
       format('%s tentativa(s) erradas nas últimas 24 h', count(*)), max(t.criado_em)::date
from login_tentativas t
where not t.sucesso and t.criado_em > now() - interval '24 hours'
group by t.email having count(*) >= 3;


-- =====================================================================
-- 8. SEGURANÇA POR LINHA (RLS)
--    Sem uma política que permita, ninguém lê nem grava nada.
-- =====================================================================

alter table perfis             enable row level security;
alter table usuario_permissoes enable row level security;
alter table clientes           enable row level security;
alter table veiculos           enable row level security;
alter table locacoes           enable row level security;
alter table manutencoes        enable row level security;
alter table logs               enable row level security;
alter table login_tentativas   enable row level security;

-- Perfis: quem está ativo vê a equipe (nomes nos aluguéis e no histórico);
-- cada um altera só o próprio nome; o chefe altera todos
create policy perfis_ver on perfis for select to authenticated
    using (id = auth.uid() or usuario_ativo());
create policy perfis_cadastrar on perfis for insert to authenticated
    with check (eh_chefe() and cargo <> 'chefe');
create policy perfis_editar_proprio on perfis for update to authenticated
    using (id = auth.uid() and ativo) with check (id = auth.uid());
create policy perfis_chefe on perfis for update to authenticated
    using (eh_chefe()) with check (eh_chefe());

-- Permissões: cada um vê as suas; só o chefe dá e tira
create policy permissoes_ver on usuario_permissoes for select to authenticated
    using (usuario_id = auth.uid() or eh_chefe());
create policy permissoes_dar on usuario_permissoes for insert to authenticated
    with check (eh_chefe());
create policy permissoes_tirar on usuario_permissoes for delete to authenticated
    using (eh_chefe());

-- Clientes (nunca se apaga: arquiva)
create policy clientes_ver on clientes for select to authenticated
    using (tem_permissao('clientes_ver') or tem_permissao('locacoes_gerenciar'));
create policy clientes_cadastrar on clientes for insert to authenticated
    with check (tem_permissao('clientes_gerenciar'));
create policy clientes_editar on clientes for update to authenticated
    using (tem_permissao('clientes_gerenciar') or tem_permissao('clientes_arquivar'));

-- Veículos (nunca se apaga: arquiva)
create policy veiculos_ver on veiculos for select to authenticated
    using (tem_permissao('veiculos_ver') or tem_permissao('locacoes_gerenciar'));
create policy veiculos_cadastrar on veiculos for insert to authenticated
    with check (tem_permissao('veiculos_gerenciar'));
create policy veiculos_editar on veiculos for update to authenticated
    using (tem_permissao('veiculos_gerenciar') or tem_permissao('veiculos_arquivar'));

-- Aluguéis e manutenções: só leitura direta; gravação só pelas funções da seção 6
create policy locacoes_ver on locacoes for select to authenticated
    using (tem_permissao('locacoes_ver') or tem_permissao('relatorios') or tem_permissao('financeiro'));
create policy manutencoes_ver on manutencoes for select to authenticated
    using (tem_permissao('manutencoes') or tem_permissao('veiculos_ver') or tem_permissao('financeiro'));

-- Histórico e tentativas: só o chefe lê; ninguém grava direto
create policy logs_ver on logs for select to authenticated using (eh_chefe());
create policy tentativas_ver on login_tentativas for select to authenticated using (eh_chefe());

-- Funções: ninguém de fora chama, exceto as de login
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
revoke execute on function criar_chefe(text, text) from authenticated;
revoke execute on function _modo_rpc() from authenticated;
revoke execute on function registrar_log(text, text, bigint, text) from authenticated;  -- ninguém grava histórico falso
grant execute on function login_bloqueado(text) to anon;
grant execute on function registrar_tentativa_login(text, boolean, text, text) to anon;

grant select on vw_locacoes, vw_situacao_frota, vw_faturamento_mensal, vw_alertas to authenticated;


-- =====================================================================
-- 9. FOTOS DOS VEÍCULOS (Supabase Storage, bucket "veiculos")
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('veiculos', 'veiculos', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 2097152,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists veiculos_fotos_ver on storage.objects;
drop policy if exists veiculos_fotos_enviar on storage.objects;
drop policy if exists veiculos_fotos_trocar on storage.objects;
drop policy if exists veiculos_fotos_apagar on storage.objects;

create policy veiculos_fotos_ver on storage.objects for select
    using (bucket_id = 'veiculos');
create policy veiculos_fotos_enviar on storage.objects for insert to authenticated
    with check (bucket_id = 'veiculos' and public.tem_permissao('veiculos_gerenciar'));
create policy veiculos_fotos_trocar on storage.objects for update to authenticated
    using (bucket_id = 'veiculos' and public.tem_permissao('veiculos_gerenciar'));
create policy veiculos_fotos_apagar on storage.objects for delete to authenticated
    using (bucket_id = 'veiculos' and public.tem_permissao('veiculos_gerenciar'));


-- =====================================================================
-- 10. DADOS DE EXEMPLO (datas relativas a hoje)
--     Usuários NÃO entram aqui: crie pelo painel do chefe (Edge Function)
--     ou em Authentication → Users + select criar_chefe(...).
-- =====================================================================

insert into clientes (id, nome, cpf, cnh, cnh_validade, email, telefone, arquivado, arquivado_em, criado_em) values
(1, 'João da Silva',     '10433218100', '96001338941', current_date + 900,  'joao@gmail.com',            '19999999999', false, null, now() - interval '230 days'),
(2, 'Evaldo José',       '08386379499', '02654235141', current_date + 600,  'evaldo@gmail.com',          '1940028922',  false, null, now() - interval '225 days'),
(3, 'Caio Andrade',      '16155940789', '81618495903', current_date + 1200, 'andrade@gmail.com',         '19989568439', false, null, now() - interval '220 days'),
(4, 'Ana Beatriz Souza', '31034131656', '47525534144', current_date + 1500, 'ana.souza@gmail.com',       '11987654321', false, null, now() - interval '150 days'),
(5, 'Marcos Oliveira',   '92832764851', '35030564106', current_date + 400,  'marcos.oli@hotmail.com',    '21998765432', false, null, now() - interval '120 days'),
(6, 'Fernanda Lima',     '39537672409', '23884969629', current_date + 800,  'fernanda.lima@gmail.com',   '19991234567', false, null, now() - interval '90 days'),
(7, 'Rafael Mendes',     '53287101269', '26916697875', current_date + 20,   'rafael.mendes@outlook.com', '19993456789', false, null, now() - interval '60 days'),
(8, 'Juliana Rocha',     '48018451427', '62704828170', current_date - 15,   'juliana.rocha@gmail.com',   '11976543210', true,  now() - interval '10 days', now() - interval '200 days');

insert into veiculos (id, marca, modelo, ano, placa, chassi, valor_diaria, status, arquivado, arquivado_em, criado_em) values
(1,  'Toyota',        'Corolla',            2025, 'FEG1A33', '9BRBDWHE5S0123451', 350,  'Disponível',    true,  now() - interval '100 days', now() - interval '240 days'),
(2,  'BMW',           '320i',               2024, 'DEF2E34', 'WBA5R1C08RFS23456', 500,  'Disponível',    true,  now() - interval '90 days',  now() - interval '240 days'),
(3,  'BMW',           'M3',                 2026, 'ABC1D23', 'WBS43AY05TFR12345', 500,  'Disponível',    false, null, now() - interval '240 days'),
(4,  'Audi',          'A5 Sportback',       2024, 'AUD5E67', 'WAUZZZF54RA012345', 700,  'Disponível',    false, null, now() - interval '235 days'),
(7,  'Volkswagen',    'Jetta GLI',          2023, 'GTR3R35', '3VW5T7BU2PM012345', 450,  'Disponível',    false, null, now() - interval '230 days'),
(10, 'Porsche',       '911 Carrera',        2024, 'POR9A25', 'WP0AA2A93RS201234', 1800, 'Disponível',    false, null, now() - interval '225 days'),
(11, 'Mercedes-Benz', 'C63 AMG',            2026, 'MER6B24', 'W1KAF8HB4TR012345', 2500, 'Alugado',       false, null, now() - interval '220 days'),
(12, 'Toyota',        'Hilux SRX',          2023, 'HLX4521', '8AJBA3CD1P1654321', 380,  'Disponível',    false, null, now() - interval '180 days'),
(13, 'Jeep',          'Compass Limited',    2024, 'JPC2F19', '988675139RKA12345', 320,  'Em manutenção', false, null, now() - interval '170 days'),
(14, 'Honda',         'Civic Touring',      2022, 'CVC8834', '93HFC2630NZ123456', 280,  'Alugado',       false, null, now() - interval '160 days'),
(15, 'Land Rover',    'Range Rover Evoque', 2025, 'RRE7H40', 'SALZA2BX5SH123456', 1200, 'Alugado',       false, null, now() - interval '150 days');

insert into locacoes (id, cliente_id, veiculo_id, data_retirada, data_prevista, data_devolucao, valor_diaria, dias_previstos,
                      valor_previsto, dias_atraso, valor_atraso, valor_total, status, observacoes, finalizado_em, criado_em) values
(1,  1, 3,  current_date - 200, current_date - 197, current_date - 197, 500,  3, 1500,  0, 0,    1500,  'Finalizada',   null, now() - interval '197 days', now() - interval '200 days'),
(2,  3, 7,  current_date - 170, current_date - 164, current_date - 164, 450,  6, 2700,  0, 0,    2700,  'Finalizada',   null, now() - interval '164 days', now() - interval '170 days'),
(3,  2, 10, current_date - 150, current_date - 147, current_date - 145, 1800, 3, 5400,  2, 3600, 9000,  'Finalizada',   'Devolvido com 2 dias de atraso.', now() - interval '145 days', now() - interval '150 days'),
(4,  4, 4,  current_date - 120, current_date - 115, current_date - 115, 700,  5, 3500,  0, 0,    3500,  'Finalizada',   null, now() - interval '115 days', now() - interval '120 days'),
(5,  5, 12, current_date - 95,  current_date - 88,  current_date - 88,  380,  7, 2660,  0, 0,    2660,  'Finalizada',   null, now() - interval '88 days',  now() - interval '95 days'),
(6,  6, 3,  current_date - 70,  current_date - 66,  current_date - 66,  500,  4, 2000,  0, 0,    2000,  'Finalizada',   null, now() - interval '66 days',  now() - interval '70 days'),
(7,  1, 15, current_date - 50,  current_date - 47,  current_date - 47,  1200, 3, 3600,  0, 0,    3600,  'Finalizada',   null, now() - interval '47 days',  now() - interval '50 days'),
(8,  7, 7,  current_date - 35,  current_date - 30,  current_date - 30,  450,  5, 2250,  0, 0,    2250,  'Finalizada',   null, now() - interval '30 days',  now() - interval '35 days'),
(9,  3, 13, current_date - 25,  current_date - 20,  current_date - 20,  320,  5, 1600,  0, 0,    1600,  'Finalizada',   'Cliente relatou barulho na suspensão.', now() - interval '20 days', now() - interval '25 days'),
(10, 4, 10, current_date - 15,  current_date - 13,  current_date - 13,  1800, 2, 3600,  0, 0,    3600,  'Finalizada',   null, now() - interval '13 days',  now() - interval '15 days'),
(11, 5, 4,  current_date - 10,  current_date - 8,   null,               700,  2, 1400,  0, 0,    0,     'Cancelada',    'Cancelado: cliente desistiu antes da retirada.', now() - interval '10 days', now() - interval '10 days'),
(12, 7, 12, current_date - 4,   current_date - 1,   current_date - 1,   380,  3, 1140,  0, 0,    1140,  'Finalizada',   null, now() - interval '1 day',    now() - interval '4 days'),
(13, 2, 11, current_date - 3,   current_date + 5,   null,               2500, 8, 20000, 0, 0,    20000, 'Em andamento', null, null, now() - interval '3 days'),
(14, 6, 14, current_date - 9,   current_date - 2,   null,               280,  7, 1960,  0, 0,    1960,  'Em andamento', null, null, now() - interval '9 days'),
(15, 1, 15, current_date - 2,   current_date + 1,   null,               1200, 3, 3600,  0, 0,    3600,  'Em andamento', null, null, now() - interval '2 days');

insert into manutencoes (id, veiculo_id, locacao_id, defeito, oficina, data_entrada, previsao_liberacao, data_liberacao,
                         servico_realizado, custo, status, criado_em) values
(1, 3,  null, 'Pastilhas de freio no limite de desgaste.', 'Auto Center Campinas', current_date - 60, current_date - 57, current_date - 57,
    'Troca de pastilhas e discos de freio dianteiros.', 850, 'Concluída', now() - interval '60 days'),
(2, 12, null, 'Volante puxando para a direita.', 'Pneus & Cia', current_date - 40, current_date - 38, current_date - 38,
    'Alinhamento, balanceamento e rodízio de pneus.', 420, 'Concluída', now() - interval '40 days'),
(3, 10, null, 'Revisão programada de 30.000 km.', 'Concessionária Porsche Center', current_date - 12, current_date - 10, current_date - 10,
    'Troca de óleo, filtros e velas.', 2300, 'Concluída', now() - interval '12 days'),
(4, 13, 9,    'Ruído na suspensão dianteira relatado pelo cliente na devolução.', 'Auto Center Campinas', current_date - 20, current_date - 2, null,
    null, null, 'Em andamento', now() - interval '20 days');

-- Contadores continuam depois dos IDs de exemplo
select setval(pg_get_serial_sequence('clientes', 'id'), 8);
select setval(pg_get_serial_sequence('veiculos', 'id'), 15);
select setval(pg_get_serial_sequence('locacoes', 'id'), 15);
select setval(pg_get_serial_sequence('manutencoes', 'id'), 4);

-- Os inserts de exemplo geraram linhas no histórico sem usuário; limpamos
delete from logs;
