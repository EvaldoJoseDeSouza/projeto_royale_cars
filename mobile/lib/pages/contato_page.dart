import 'package:flutter/material.dart';
import 'package:royale_cars_location/widgets/animated_golden_title.dart';
import 'package:royale_cars_location/widgets/royale_footer.dart';
import 'package:royale_cars_location/widgets/royale_button.dart';

class ContatoPage extends StatefulWidget {
  const ContatoPage({super.key});

  @override
  State<ContatoPage> createState() => _ContatoPageState();
}

class _ContatoPageState extends State<ContatoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _mensagemController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _mensagemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 247, 245),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 34, 48, 78),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const AnimatedGoldenTitle("Contato", fontSize: 24),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SEÇÃO 1: CANAIS DE ATENDIMENTO ---
            const Text(
              "Canais de Atendimento",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 34, 48, 78),
              ),
            ),
            const SizedBox(height: 12),

            _buildCardContato(
              icon: Icons.phone_in_talk_rounded,
              iconColor: Colors.green,
              title: "Telefone / WhatsApp",
              subtitle:
                  "(19) 2025-2026\nSuporte 24h para locatários em viagem.",
            ),
            _buildCardContato(
              icon: Icons.email_rounded,
              iconColor: Colors.blue,
              title: "E-mail Corporativo",
              subtitle:
                  "contato@royalecars.com.br\nRespostas em até 2 dias úteis.",
            ),
            _buildCardContato(
              icon: Icons.location_on_rounded,
              iconColor: Colors.redAccent,
              title: "Sede Central",
              subtitle:
                  "Av. Desenvolvimento de Sistemas, 2026 - Jardim Cotil\nUnicamp - SP, CEP 00000-001",
            ),
            _buildCardContato(
              icon: Icons.access_time_filled_rounded,
              iconColor: Colors.amber.shade800,
              title: "Horário de Retirada e Devolução",
              subtitle:
                  "Segunda a Sexta: 08:00 às 20:00\nSábados e Feriados: 08:00 às 14:00",
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // --- SEÇÃO 2: FORMULÁRIO DE SUPORTE ---
            const Text(
              "Envie uma Mensagem",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 34, 48, 78),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Dúvidas, elogios ou problemas com o sistema? Fale com a administração.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: "Seu Nome",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.amber,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Por favor, insira seu nome.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mensagemController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Mensagem ou Sugestão",
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Por favor, descreva sua mensagem.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  RoyaleButton(
                    label: "Enviar Mensagem",
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Simulação de envio com feedback visual de sucesso
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color.fromARGB(
                              255,
                              34,
                              48,
                              78,
                            ),
                            content: Text(
                              "Obrigado, ${_nomeController.text}! Mensagem enviada com sucesso.",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );

                        // Limpa os campos após o envio
                        _nomeController.clear();
                        _mensagemController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }

  // Helper Widget para construir os cards de contato de forma limpa
  Widget _buildCardContato({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.black87, height: 1.3),
          ),
        ),
      ),
    );
  }
}
