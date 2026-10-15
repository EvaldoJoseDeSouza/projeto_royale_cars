-- =====================================================================
--  ROYALE CARS - Correção: histórico ao trocar a foto do veículo
--  Rodar UMA vez no SQL Editor do Supabase (depois do 01 ao 04).
--  Pode rodar de novo sem problema: só substitui a função.
--
--  O problema: ao trocar ou tirar a foto de um veículo, o banco recusava
--  a alteração com o erro "malformed array literal". A linha que anota
--  "trocou a foto" no histórico juntava um texto sem tipo definido a uma
--  lista de textos, e o PostgreSQL tentava ler o texto como lista.
--  A correção diz o tipo com "::text" (e anota "removeu a foto" quando a
--  foto é tirada). A mesma correção já está no 02_complemento.sql.
-- =====================================================================

set search_path = public;

create or replace function tg_veiculos_depois()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    mudancas text[] := '{}';
    nome text := new.marca || ' ' || new.modelo || ' (' || fmt_placa(new.placa) || ')';
begin
    if tg_op = 'INSERT' then
        perform registrar_log('veiculos', 'cadastrar', new.id,
            format('Cadastrou o veículo %s, diária de %s, %s km.', nome, fmt_moeda(new.valor_diaria), new.quilometragem));
        return null;
    end if;

    if new.arquivado and not old.arquivado then
        perform registrar_log('veiculos', 'arquivar', new.id, format('Arquivou o veículo %s.', nome));
    elsif old.arquivado and not new.arquivado then
        perform registrar_log('veiculos', 'reativar', new.id, format('Reativou o veículo %s.', nome));
    end if;

    -- Mudanças feitas pelas funções (aluguel, devolução) já têm o próprio registro
    if _em_modo_rpc() then
        return null;
    end if;

    if new.marca is distinct from old.marca then mudancas := mudancas || format('marca: %s → %s', old.marca, new.marca); end if;
    if new.modelo is distinct from old.modelo then mudancas := mudancas || format('modelo: %s → %s', old.modelo, new.modelo); end if;
    if new.ano is distinct from old.ano then mudancas := mudancas || format('ano: %s → %s', old.ano, new.ano); end if;
    if new.placa is distinct from old.placa then mudancas := mudancas || format('placa: %s → %s', fmt_placa(old.placa), fmt_placa(new.placa)); end if;
    if new.chassi is distinct from old.chassi then mudancas := mudancas || format('chassi: %s → %s', old.chassi, new.chassi); end if;
    if new.valor_diaria is distinct from old.valor_diaria then
        mudancas := mudancas || format('diária de %s para %s', fmt_moeda(old.valor_diaria), fmt_moeda(new.valor_diaria));
    end if;
    if new.quilometragem is distinct from old.quilometragem then
        mudancas := mudancas || format('quilometragem: %s → %s km', old.quilometragem, new.quilometragem);
    end if;
    -- "::text" diz ao banco que é UM texto (sem isso ele tenta ler como lista inteira e dá erro)
    if new.imagem is distinct from old.imagem then
        mudancas := mudancas || (case when new.imagem is null then 'removeu a foto' else 'trocou a foto' end)::text;
    end if;

    if array_length(mudancas, 1) > 0 then
        perform registrar_log('veiculos', 'editar', new.id, format('Editou o %s: %s.', nome, array_to_string(mudancas, '; ')));
    end if;

    return null;
end $$;
