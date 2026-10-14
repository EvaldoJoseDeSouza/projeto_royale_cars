// =====================================================================
//  IPC do painel: Dashboard (resumo do dia) e Financeiro
// ---------------------------------------------------------------------
//  Antes, o desktop baixava TODAS as locações e fazia as contas aqui,
//  no JavaScript. Agora quem soma é o banco, pelas "visões" (views), que
//  são consultas prontas guardadas no banco — as mesmas que a web e o
//  celular usam, então os números batem nas 3 plataformas:
//
//    vw_situacao_frota     → quantos carros disponíveis, alugados, na oficina
//    vw_alertas            → atrasos, devoluções próximas, CNH vencendo...
//    vw_faturamento_mensal → faturamento e gasto com manutenção, mês a mês
//
//  As visões respeitam as permissões de quem está logado (RLS): quem não
//  pode ver o financeiro recebe a lista vazia, mesmo se pedir.
// =====================================================================

const { ipcMain } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");

const soma = (lista, campo) => (lista || []).reduce((total, linha) => total + Number(linha[campo] || 0), 0);

// "AAAA-MM-DD" de hoje no horário do computador (ver formatos.js)
function hojeTexto() {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 10);
}

function registrarIpcPainel() {
  // --------------------------------------------------------- RESUMO
  // Os quadros do topo do Dashboard e a lista de alertas
  ipcMain.handle("buscar-resumo-painel", async () => {
    // Promise.all: faz as 3 perguntas ao banco AO MESMO TEMPO,
    // em vez de esperar uma terminar para começar a outra.
    const [frota, alertas, meses] = await Promise.all([
      supabase.from("vw_situacao_frota").select("*").maybeSingle(),
      supabase.from("vw_alertas").select("tipo, referencia_id, titulo, detalhe, data").order("data", { ascending: true }).limit(30),
      temPermissao("financeiro")
        ? supabase.from("vw_faturamento_mensal").select("mes, faturamento, alugueis").order("mes", { ascending: false }).limit(2)
        : Promise.resolve({ data: null }),
    ]);

    [frota, alertas, meses].forEach((r) => r.error && console.error("Erro no resumo do painel:", r.error.message));

    // meses vem do mais novo para o mais velho: [este mês, mês passado]
    const [esteMes, mesPassado] = meses.data || [];
    return {
      frota: frota.data || null,
      alertas: alertas.data || [],
      faturamento: esteMes
        ? { mes: Number(esteMes.faturamento), anterior: Number(mesPassado ? mesPassado.faturamento : 0) }
        : null,
    };
  });

  // ------------------------------------------------------ FINANCEIRO
  // periodo: { inicio: "AAAA-MM-DD", fim: "AAAA-MM-DD" }
  ipcMain.handle("buscar-financeiro", async (event, periodo = {}) => {
    if (!temPermissao("financeiro")) return { sucesso: false };

    const hoje = hojeTexto();
    const inicio = periodo.inicio || `${hoje.slice(0, 7)}-01`; // padrão: do dia 1 deste mês
    const fim = periodo.fim || hoje;                            // até hoje

    const [entradas, manutencoes, emAndamento, meses] = await Promise.all([
      // Aluguéis finalizados no período. Lemos a tabela "locacoes" (e não a
      // visão vw_locacoes) com cliente e veículo "pendurados": quem só tem a
      // permissão Financeiro não pode ver clientes, e nesse caso o nome vem
      // vazio, mas o valor continua aparecendo.
      supabase
        .from("locacoes")
        .select("id, data_devolucao, valor_total, taxas_extras, dias_atraso, clientes(nome), veiculos(marca, modelo, placa)")
        .eq("status", "Finalizada")
        .gte("data_devolucao", inicio)
        .lte("data_devolucao", fim)
        .order("data_devolucao", { ascending: false }),
      // Manutenções concluídas (pagas) no período
      supabase
        .from("manutencoes")
        .select("custo")
        .eq("status", "Concluída")
        .gte("data_liberacao", inicio)
        .lte("data_liberacao", fim),
      // O que ainda vai entrar: aluguéis que estão na rua agora
      supabase.from("locacoes").select("valor_previsto").eq("status", "Em andamento"),
      // Os últimos 12 meses para o gráfico
      supabase.from("vw_faturamento_mensal").select("mes, faturamento, alugueis, manutencao").order("mes", { ascending: true }),
    ]);

    const erro = [entradas, manutencoes, emAndamento, meses].find((r) => r.error);
    if (erro) {
      console.error("Erro ao buscar o financeiro:", erro.error.message);
      return { sucesso: false };
    }

    const faturamento = soma(entradas.data, "valor_total");
    const gastoManutencao = soma(manutencoes.data, "custo");
    const alugueis = entradas.data.length;

    return {
      sucesso: true,
      periodo: { inicio, fim },
      indicadores: {
        faturamento,
        alugueis,
        ticketMedio: alugueis > 0 ? faturamento / alugueis : 0,
        gastoManutencao,
        resultado: faturamento - gastoManutencao,
        aReceber: soma(emAndamento.data, "valor_previsto"),
      },
      entradas: entradas.data,
      meses: meses.data.map((m) => ({
        mes: m.mes,
        faturamento: Number(m.faturamento),
        manutencao: Number(m.manutencao),
        alugueis: Number(m.alugueis),
      })),
    };
  });
}

module.exports = { registrarIpcPainel };
