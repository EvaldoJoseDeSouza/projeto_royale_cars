-- ============================================================
-- migracao_supabase.sql
-- Rode isto UMA VEZ no SQL Editor do Supabase (o mesmo projeto
-- que o desktop do Caio já usa: rhdmiqcfksekmrtgnjgo.supabase.co).
--
-- Todas as mudanças aqui são ADITIVAS (novas colunas com valor
-- padrão, e uma tabela nova) — nada é removido ou renomeado, então
-- o app desktop continua funcionando exatamente como está.
-- ============================================================

-- 🌟 Quilometragem do veículo (odômetro atual) — pedido da banca
ALTER TABLE veiculos
  ADD COLUMN IF NOT EXISTS quilometragem integer NOT NULL DEFAULT 0;

-- 🌟 Quilometragem de saída/retorno de cada locação, + assinatura
-- digital do cliente (contrato) — outro ponto pedido pela banca
ALTER TABLE locacoes
  ADD COLUMN IF NOT EXISTS km_saida integer,
  ADD COLUMN IF NOT EXISTS km_retorno integer,
  ADD COLUMN IF NOT EXISTS assinatura_base64 text,
  ADD COLUMN IF NOT EXISTS contrato_gerado_em timestamptz;

-- 🌟 Tabela nova de laudos de manutenção (checklist do veículo).
-- Isso é só usado pelo app Flutter — não conflita com o desktop,
-- que só usa o campo veiculos.status = 'Em Manutenção'.
CREATE TABLE IF NOT EXISTS laudos_manutencao (
  id bigint generated always as identity primary key,
  id_empresa bigint NOT NULL,
  id_veiculo bigint NOT NULL,
  placa text NOT NULL,
  motor_ok boolean NOT NULL DEFAULT true,
  freios_ok boolean NOT NULL DEFAULT true,
  pneus_ok boolean NOT NULL DEFAULT true,
  oleo_ok boolean NOT NULL DEFAULT true,
  observacoes text,
  data_registro timestamptz NOT NULL DEFAULT now()
);
