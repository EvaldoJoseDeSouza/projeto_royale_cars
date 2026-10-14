import 'package:flutter/material.dart';
import 'package:royale_cars_location/widgets/animated_golden_title.dart';
import 'package:royale_cars_location/widgets/royale_footer.dart';

class SobreNosPage extends StatelessWidget {
  const SobreNosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> desenvolvedores = [
      {
        "nome": "Evaldo Jose de Souza",
        "função": "Desenvolvedor do Projeto / Mobile",
      },
      {
        "nome": "Caio Andrade Campos",
        "função": "Desenvolvedor do Projeto / Desktop",
      },
      {
        "nome": "Gabriel dos Santos",
        "função": "Desenvolvedor do Projeto / Web",
      },
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 247, 245),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 34, 48, 78),
        centerTitle: true,
        title: const AnimatedGoldenTitle("Sobre Nós", fontSize: 22),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          children: [
            // --- TÍTULO DA EQUIPE ---
            const Text(
              "Desenvolvedores do Sistema Royale Cars!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 34, 48, 78),
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 15),
            // --- BLOCO DE IMAGENS DOS DESENVOLVEDORES ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProjectImage('assets/images/evaldo.png'),
                const SizedBox(width: 12),
                _buildProjectImage('assets/images/caio.png'),
                const SizedBox(width: 12),
                _buildProjectImage('assets/images/gabriel.png'),
              ],
            ),
            const SizedBox(height: 25),

            // --- LISTA DE INTEGRANTES ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: desenvolvedores.length,
                itemBuilder: (context, index) {
                  final dev = desenvolvedores[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color.fromARGB(255, 34, 48, 78),
                        child: Text(
                          dev['nome']![0],
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        dev['nome']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        dev['função']!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      trailing: const Icon(Icons.code, color: Colors.amber),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // --- DESCRIÇÃO TÉCNICA DO PROJETO (NOVO BLOCO) ---
            _buildSectionTitle("O Projeto Royale Cars"),
            _buildInfoCard(
              "O Royale Cars surge para resolver um problema crônico na mobilidade urbana: a subutilização de veículos particulares de nicho (luxo, antigos e pequenas frotas) que passam a maior parte do tempo parados em garagens gerando apenas custos fixos.\n\n"
              "Nossa plataforma atua no modelo Peer-to-Peer (P2P), funcionando como o 'Airbnb dos Automóveis'. Conectamos proprietários de veículos exclusivos a locatários que buscam uma experiência única. "
              "O sistema automatiza o controle de contratos, o cálculo dinâmico de diárias e a emissão de laudos de manutenção estruturados, garantindo total segurança, rentabilidade e sustentabilidade para ativos que antes estavam ociosos.",
            ),

            _buildSectionTitle("Especificações e Tecnologia"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildTechChip(
                    "Arquitetura Híbrida (Web/Mobile/Desktop)",
                    Icons.devices,
                  ),
                  _buildTechChip("Metodologia Ágil (Scrum)", Icons.loop),
                  _buildTechChip(
                    "Stack: Flutter, Electron, HTML, CSS, PHP & MySQL",
                    Icons.settings_suggest,
                  ),
                  _buildTechChip("Interface Intuitiva", Icons.auto_awesome),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- MANIFESTO / TEXTO DE IMPACTO ---
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.rocket_launch,
                    color: Colors.amber,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Somos uma equipe de entusiastas em Tecnologia e Desenvolvimento de Sistemas pelo Colégio Técnico de Limeira (COTIL-UNICAMP). Mais do que estudantes, somos mentes inquietas que acreditam no poder da engenharia de software para transformar mercados.\n\n"
                    "A Royale Cars nasceu em nossos laboratórios não apenas como um projeto acadêmico, mas como o embrião de uma futura startup unicórnio. Unindo o rigor técnico da nossa formação à visão de futuro que o mercado exige, estamos em constante evolução — preparando o terreno para nossa jornada no ensino superior e para a construção de soluções que impactem a vida de milhares de pessoas. Nosso combustível é a inovação; nosso destino é o topo.",
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Colors.blueGrey[800],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            // --- RODAPÉ INSTITUCIONAL ---
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                "PROJETO INTEGRADOR  - COTIL - UNICAMP 2026",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }

  // Widget para Títulos de Seção
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  // Widget para Cards de Informação Curta
  Widget _buildInfoCard(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 34, 48, 78).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }

  // Widget para as Tecnologias (Chips)
  Widget _buildTechChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 34, 48, 78),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectImage(String path) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amberAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.grey, size: 35),
        ),
      ),
    );
  }
}
