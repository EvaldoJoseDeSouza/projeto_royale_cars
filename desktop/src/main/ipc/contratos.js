// =====================================================================
//  IPC do contrato de locação (ver, imprimir e salvar em PDF)
// ---------------------------------------------------------------------
//  A assinatura do cliente é colhida SÓ no celular, na retirada
//  (decisão 6 do grupo). Ela fica guardada como imagem PNG no bucket
//  PRIVADO "contratos" do Supabase. A web e o desktop só mostram.
//
//  Por que baixar a imagem aqui no processo principal, e não deixar a
//  tela carregar um link? Porque o bucket é privado: só abre com o login
//  de quem tem a permissão "locacoes_ver". Baixando aqui, a imagem vai
//  para a tela já pronta (como texto "data:image/png;base64,...") e
//  também sai no PDF e na impressão, sem depender de link que expira.
// =====================================================================

const { ipcMain, BrowserWindow, dialog, shell } = require("electron");
const fs = require("fs/promises");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");

// "deps" vem do index.js
function registrarIpcContratos(deps) {
  const { mostrarAviso } = deps;

  // A janela que pediu (a do contrato). Os avisos aparecem em cima dela.
  const janelaDe = (event) => BrowserWindow.fromWebContents(event.sender);

  // ----------------------------------------------------- BUSCAR
  // Devolve { locacao, assinatura } ou { erro: "mensagem" }
  ipcMain.handle("buscar-contrato", async (event, locacaoId) => {
    if (!temPermissao("locacoes_ver")) {
      return { erro: "Você não tem permissão para ver os aluguéis." };
    }

    // A visão vw_locacoes já traz o cliente, o carro e quem registrou.
    // Assim o contrato sai certo até para cliente ou carro arquivado.
    const { data: locacao, error } = await supabase
      .from("vw_locacoes")
      .select("*")
      .eq("id", Number(locacaoId))
      .maybeSingle();

    if (error) {
      console.error("Erro ao buscar o contrato:", error.message);
      return { erro: "Não foi possível carregar o contrato. Verifique a internet." };
    }
    if (!locacao) return { erro: "Aluguel não encontrado." };

    // Sem assinatura (aluguel feito na web ou no desktop): o contrato sai
    // com a linha em branco, para o cliente assinar no papel.
    let assinatura = null;
    if (locacao.assinatura_path) {
      const { data: arquivo, error: erroArquivo } = await supabase.storage
        .from("contratos")
        .download(locacao.assinatura_path);

      if (erroArquivo) {
        console.error("Não foi possível baixar a assinatura:", erroArquivo.message);
      } else {
        // O arquivo chega como "Blob". Viramos em texto base64 para a tela.
        const bytes = Buffer.from(await arquivo.arrayBuffer());
        assinatura = `data:image/png;base64,${bytes.toString("base64")}`;
      }
    }

    return { locacao, assinatura };
  });

  // --------------------------------------------------- IMPRIMIR
  // Abre a janela de impressão do Windows (dá para escolher a impressora
  // ou "Microsoft Print to PDF").
  ipcMain.handle("imprimir-contrato", (event) => {
    return new Promise((resolver) => {
      event.sender.print({ printBackground: true }, (deuCerto, motivo) => {
        // Cancelar a impressão não é erro: só não faz nada
        if (!deuCerto && motivo && motivo !== "cancelled") {
          console.error("Falha ao imprimir:", motivo);
        }
        resolver({ sucesso: deuCerto });
      });
    });
  });

  // ------------------------------------------------- SALVAR PDF
  ipcMain.handle("salvar-contrato-pdf", async (event, locacaoId) => {
    const janela = janelaDe(event);

    // 1) Pergunta onde salvar (já sugere um nome)
    const escolha = await dialog.showSaveDialog(janela, {
      title: "Salvar contrato em PDF",
      defaultPath: `contrato-${locacaoId}.pdf`,
      filters: [{ name: "PDF", extensions: ["pdf"] }],
    });
    if (escolha.canceled || !escolha.filePath) return { sucesso: false };

    // 2) "Imprime" a própria janela num arquivo PDF, no tamanho A4.
    //    O CSS de impressão (@media print) esconde os botões.
    try {
      const pdf = await event.sender.printToPDF({ pageSize: "A4", printBackground: true });
      await fs.writeFile(escolha.filePath, pdf);
    } catch (erro) {
      console.error("Erro ao salvar o PDF:", erro);
      await mostrarAviso(janela, {
        tipo: "erro",
        titulo: "PDF não salvo",
        mensagem: "Não foi possível salvar o arquivo. Ele pode estar aberto em outro programa.",
      });
      return { sucesso: false };
    }

    // 3) Mostra o arquivo na pasta, para a pessoa achar fácil
    shell.showItemInFolder(escolha.filePath);
    return { sucesso: true, caminho: escolha.filePath };
  });
}

module.exports = { registrarIpcContratos };
