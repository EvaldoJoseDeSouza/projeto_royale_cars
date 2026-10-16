/* =====================================================================
   ROYALE CARS - JavaScript da interface
   ---------------------------------------------------------------------
   Aqui ficam as máscaras e as validações que avisam o usuário na hora.
   As mesmas regras são conferidas de novo no PHP (includes/validacoes.php)
   e no banco, porque o JavaScript pode ser desligado pelo usuário.
   ===================================================================== */

(function () {
    'use strict';

    var apenasDigitos = function (texto) {
        return String(texto || '').replace(/\D/g, '');
    };


    /* ----------------------------------------------------------------
       VALIDADORES (mesma lógica do PHP)
       ---------------------------------------------------------------- */

    function validarCPF(valor) {
        var cpf = apenasDigitos(valor);

        if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) {
            return false;
        }

        for (var posicao = 9; posicao < 11; posicao++) {
            var soma = 0;

            for (var i = 0; i < posicao; i++) {
                soma += Number(cpf[i]) * ((posicao + 1) - i);
            }

            var digito = (soma * 10) % 11;

            if (digito === 10) {
                digito = 0;
            }

            if (Number(cpf[posicao]) !== digito) {
                return false;
            }
        }

        return true;
    }

    function validarCNH(valor) {
        var cnh = apenasDigitos(valor);

        if (cnh.length !== 11 || /^(\d)\1{10}$/.test(cnh)) {
            return false;
        }

        var d = cnh.split('').map(Number);
        var soma, i, resto, dv1, dv2;

        // Versão 1
        soma = 0;
        for (i = 0; i < 9; i++) {
            soma += d[i] * (9 - i);
        }

        var desconto = 0;
        dv1 = soma % 11;

        if (dv1 >= 10) {
            dv1 = 0;
            desconto = 2;
        }

        soma = 0;
        for (i = 0; i < 9; i++) {
            soma += d[i] * (i + 1);
        }

        resto = soma % 11;
        dv2 = resto >= 10 ? 0 : resto - desconto;

        if (dv1 === d[9] && dv2 === d[10]) {
            return true;
        }

        // Versão 2 (Detran-PR)
        soma = 0;
        for (i = 0; i < 9; i++) {
            soma += d[i] * (i + 2);
        }

        resto = soma % 11;
        dv1 = resto <= 1 ? 0 : 11 - resto;

        var numeros = [dv1].concat(d.slice(0, 9));
        soma = 0;
        for (i = 0; i < numeros.length; i++) {
            soma += numeros[i] * (i + 2);
        }

        resto = soma % 11;
        dv2 = resto <= 1 ? 0 : 11 - resto;

        return dv1 === d[9] && dv2 === d[10];
    }

    var DDDS = [
        11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 24, 27, 28,
        31, 32, 33, 34, 35, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49,
        51, 53, 54, 55, 61, 62, 63, 64, 65, 66, 67, 68, 69,
        71, 73, 74, 75, 77, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89,
        91, 92, 93, 94, 95, 96, 97, 98, 99
    ];

    function validarTelefone(valor) {
        var t = apenasDigitos(valor);

        if (t.length !== 10 && t.length !== 11) {
            return false;
        }

        if (DDDS.indexOf(Number(t.substring(0, 2))) === -1) {
            return false;
        }

        return t.length === 11 ? t[2] === '9' : '2345'.indexOf(t[2]) !== -1;
    }

    function validarPlaca(valor) {
        var placa = String(valor || '').toUpperCase().replace(/[\s-]/g, '');

        return /^[A-Z]{3}\d{4}$/.test(placa) || /^[A-Z]{3}\d[A-Z]\d{2}$/.test(placa);
    }

    function validarChassi(valor) {
        var chassi = String(valor || '').toUpperCase().replace(/\s/g, '');

        return /^[A-HJ-NPR-Z0-9]{17}$/.test(chassi) && !/^(.)\1{16}$/.test(chassi);
    }

    function validarNome(valor) {
        var nome = String(valor || '').trim().replace(/\s+/g, ' ');

        return nome.length >= 5 && /^[A-Za-zÀ-ÖØ-öø-ÿ'.-]+( [A-Za-zÀ-ÖØ-öø-ÿ'.-]+)+$/.test(nome);
    }

    function validarEmail(valor) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(valor || '').trim());
    }

    function validarSenha(valor) {
        return valor.length >= 8 && /[A-Za-z]/.test(valor) && /\d/.test(valor);
    }

    var validadores = {
        cpf:      { testar: validarCPF,      erro: 'CPF inválido. Confira os números digitados.' },
        cnh:      { testar: validarCNH,      erro: 'Número de CNH inválido.' },
        telefone: { testar: validarTelefone, erro: 'Telefone inválido. Use DDD + número, ex.: (19) 99999-9999.' },
        placa:    { testar: validarPlaca,    erro: 'Placa inválida. Use ABC-1234 (antiga) ou ABC1D23 (Mercosul).' },
        chassi:   { testar: validarChassi,   erro: 'O chassi deve ter 17 letras/números (sem I, O e Q).' },
        nome:     { testar: validarNome,     erro: 'Informe nome e sobrenome.' },
        email:    { testar: validarEmail,    erro: 'E-mail inválido.' },
        senha:    { testar: validarSenha,    erro: 'Mínimo de 8 caracteres, com letras e números.' }
    };


    /* ----------------------------------------------------------------
       MÁSCARAS
       ---------------------------------------------------------------- */

    var mascaras = {
        cpf: function (v) {
            v = apenasDigitos(v).slice(0, 11);
            return v
                .replace(/^(\d{3})(\d)/, '$1.$2')
                .replace(/^(\d{3})\.(\d{3})(\d)/, '$1.$2.$3')
                .replace(/\.(\d{3})(\d)/, '.$1-$2');
        },
        cnh: function (v) {
            return apenasDigitos(v).slice(0, 11);
        },
        telefone: function (v) {
            v = apenasDigitos(v).slice(0, 11);

            if (v.length <= 2) {
                return v.length ? '(' + v : v;
            }

            if (v.length <= 10) {
                return v.replace(/^(\d{2})(\d{0,4})(\d{0,4}).*/, function (_, a, b, c) {
                    return '(' + a + ') ' + b + (c ? '-' + c : '');
                });
            }

            return v.replace(/^(\d{2})(\d{5})(\d{4})$/, '($1) $2-$3');
        },
        placa: function (v) {
            return String(v).toUpperCase().replace(/[^A-Z0-9-]/g, '').slice(0, 8);
        },
        chassi: function (v) {
            return String(v).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 17);
        }
    };

    document.querySelectorAll('[data-mascara]').forEach(function (campo) {
        var mascara = mascaras[campo.dataset.mascara];

        if (!mascara) {
            return;
        }

        campo.value = mascara(campo.value);

        campo.addEventListener('input', function () {
            campo.value = mascara(campo.value);
        });
    });


    /* ----------------------------------------------------------------
       VALIDAÇÃO NA HORA (mostra o erro embaixo do campo)
       ---------------------------------------------------------------- */

    function mostrarErro(campo, mensagem) {
        var aviso = campo.parentNode.querySelector('.campo-erro-js');

        if (!aviso) {
            aviso = document.createElement('small');
            aviso.className = 'campo-erro campo-erro-js';
            campo.parentNode.appendChild(aviso);
        }

        aviso.textContent = mensagem;
        aviso.hidden = !mensagem;
        campo.classList.toggle('invalido', Boolean(mensagem));
        campo.setCustomValidity(mensagem);
    }

    function conferirCampo(campo) {
        var regra = validadores[campo.dataset.validar];
        var valor = campo.value.trim();

        if (!regra) {
            return;
        }

        if (valor === '' && !campo.required) {
            mostrarErro(campo, '');
            return;
        }

        mostrarErro(campo, valor === '' || regra.testar(valor) ? '' : regra.erro);
    }

    document.querySelectorAll('[data-validar]').forEach(function (campo) {
        campo.addEventListener('blur', function () {
            conferirCampo(campo);
        });

        campo.addEventListener('input', function () {
            if (campo.classList.contains('invalido')) {
                conferirCampo(campo);
            }
        });
    });

    // Confirmação de senha
    document.querySelectorAll('[data-confirma]').forEach(function (campo) {
        var original = document.getElementById(campo.dataset.confirma);

        var conferir = function () {
            mostrarErro(campo, campo.value && campo.value !== original.value ? 'As senhas não são iguais.' : '');
        };

        campo.addEventListener('input', conferir);
        original.addEventListener('input', conferir);
    });

    document.querySelectorAll('form').forEach(function (form) {
        form.addEventListener('submit', function (evento) {
            form.querySelectorAll('[data-validar]').forEach(conferirCampo);

            if (!form.checkValidity()) {
                evento.preventDefault();
                form.reportValidity();
                return;
            }

            if (form.dataset.confirmar && !window.confirm(form.dataset.confirmar)) {
                evento.preventDefault();
            }
        });
    });


    /* ----------------------------------------------------------------
       MENU NO CELULAR
       ---------------------------------------------------------------- */

    var botaoMenu = document.querySelector('[data-abrir-menu]');
    var sidebar = document.getElementById('sidebar');

    if (botaoMenu && sidebar) {
        botaoMenu.addEventListener('click', function (evento) {
            evento.stopPropagation();
            sidebar.classList.toggle('aberta');
        });

        document.addEventListener('click', function (evento) {
            if (!sidebar.contains(evento.target)) {
                sidebar.classList.remove('aberta');
            }
        });
    }


    /* ----------------------------------------------------------------
       PRÉVIA DA IMAGEM DO VEÍCULO
       ---------------------------------------------------------------- */

    document.querySelectorAll('input[type="file"][data-preview]').forEach(function (input) {
        var imagem = document.getElementById(input.dataset.preview);

        input.addEventListener('change', function () {
            var arquivo = input.files[0];

            if (!arquivo) {
                return;
            }

            if (arquivo.size > 2 * 1024 * 1024) {
                mostrarErro(input, 'A imagem deve ter no máximo 2 MB.');
                return;
            }

            mostrarErro(input, '');
            imagem.src = URL.createObjectURL(arquivo);
            imagem.hidden = false;
        });
    });


    /* ----------------------------------------------------------------
       PERMISSÕES: sugestão por cargo e dependências
       ---------------------------------------------------------------- */

    var areaPermissoes = document.querySelector('[data-permissoes]');

    if (areaPermissoes) {
        var padroes = JSON.parse(areaPermissoes.dataset.padroes || '{}');
        var dependencias = JSON.parse(areaPermissoes.dataset.dependencias || '{}');
        var caixas = areaPermissoes.querySelectorAll('input[name="permissoes[]"]');

        var marcar = function (chave) {
            caixas.forEach(function (caixa) {
                if (caixa.value === chave) {
                    caixa.checked = true;
                }
            });
        };

        caixas.forEach(function (caixa) {
            caixa.addEventListener('change', function () {
                if (caixa.checked) {
                    (dependencias[caixa.value] || []).forEach(marcar);
                }
            });
        });

        document.querySelectorAll('[data-aplicar-cargo]').forEach(function (botao) {
            botao.addEventListener('click', function () {
                var cargo = document.getElementById('cargo').value;
                var lista = padroes[cargo] || [];

                caixas.forEach(function (caixa) {
                    caixa.checked = lista.indexOf(caixa.value) !== -1;
                });
            });
        });
    }


    /* ----------------------------------------------------------------
       CÁLCULO DO ALUGUEL NA TELA
       ---------------------------------------------------------------- */

    var moeda = function (valor) {
        return valor.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
    };

    var diasEntre = function (inicio, fim) {
        var a = new Date(inicio + 'T12:00:00');
        var b = new Date(fim + 'T12:00:00');

        return Math.round((b - a) / 86400000);
    };

    var formLocacao = document.querySelector('[data-calculo-locacao]');

    if (formLocacao) {
        var selectVeiculo = formLocacao.querySelector('#veiculo_id');
        var campoRetirada = formLocacao.querySelector('#data_retirada');
        var campoPrevista = formLocacao.querySelector('#data_prevista');

        var atualizarLocacao = function () {
            var opcao = selectVeiculo.options[selectVeiculo.selectedIndex];
            var diaria = opcao ? Number(opcao.dataset.diaria || 0) : 0;
            var dias = 0;

            if (campoRetirada.value && campoPrevista.value) {
                dias = Math.max(1, diasEntre(campoRetirada.value, campoPrevista.value));
                campoPrevista.setCustomValidity(
                    campoPrevista.value < campoRetirada.value ? 'A devolução não pode ser antes da retirada.' : ''
                );
            }

            document.getElementById('prev-diaria').textContent = diaria ? moeda(diaria) : '—';
            document.getElementById('prev-dias').textContent = dias ? dias + (dias === 1 ? ' diária' : ' diárias') : '—';
            document.getElementById('prev-total').textContent = diaria && dias ? moeda(diaria * dias) : '—';
        };

        [selectVeiculo, campoRetirada, campoPrevista].forEach(function (campo) {
            campo.addEventListener('change', atualizarLocacao);
            campo.addEventListener('input', atualizarLocacao);
        });

        atualizarLocacao();

        // Quilometragem de saída: ao escolher o carro, vem a km dele.
        // Só troca se a pessoa ainda não digitou outra coisa no campo.
        var campoKm = formLocacao.querySelector('#km_saida');

        if (campoKm) {
            var kmAutomatica = '';

            var preencherKm = function () {
                var opcao = selectVeiculo.options[selectVeiculo.selectedIndex];
                var km = opcao && opcao.dataset.km ? opcao.dataset.km : '';

                if (campoKm.value === '' || campoKm.value === kmAutomatica) {
                    campoKm.value = km;
                    kmAutomatica = km;
                }

                campoKm.min = km || 0;
            };

            selectVeiculo.addEventListener('change', preencherKm);
            preencherKm();
        }
    }

    var formDevolucao = document.querySelector('[data-calculo-devolucao]');

    if (formDevolucao) {
        var campoDevolucao = formDevolucao.querySelector('#data_devolucao');
        var diaria = Number(formDevolucao.dataset.diaria);
        var retirada = formDevolucao.dataset.retirada;
        var prevista = formDevolucao.dataset.prevista;

        var campoTaxas = formDevolucao.querySelector('#taxas_extras');
        var campoKmRetorno = formDevolucao.querySelector('#km_retorno');
        var kmSaida = Number(formDevolucao.dataset.kmSaida || 0);

        // A mesma conta que o banco faz (é só uma prévia: quem grava é o banco)
        var atualizarDevolucao = function () {
            if (!campoDevolucao.value) {
                return;
            }

            var dias = Math.max(1, diasEntre(retirada, campoDevolucao.value));
            var atraso = Math.max(0, diasEntre(prevista, campoDevolucao.value));
            var taxas = campoTaxas ? Math.max(0, Number(String(campoTaxas.value).replace(',', '.')) || 0) : 0;
            var kmRetorno = campoKmRetorno ? Number(campoKmRetorno.value) : 0;

            document.getElementById('dev-dias').textContent = dias + (dias === 1 ? ' diária' : ' diárias');
            document.getElementById('dev-atraso').textContent = atraso ? atraso + ' dia(s) (já somados)' : 'Sem atraso';
            document.getElementById('dev-total').textContent = moeda(dias * diaria + taxas);

            if (document.getElementById('dev-taxas')) {
                document.getElementById('dev-taxas').textContent = taxas ? moeda(taxas) : '—';
            }

            if (document.getElementById('dev-km')) {
                document.getElementById('dev-km').textContent = kmRetorno >= kmSaida && campoKmRetorno.value !== ''
                    ? (kmRetorno - kmSaida).toLocaleString('pt-BR') + ' km'
                    : '—';
            }
        };

        [campoDevolucao, campoTaxas, campoKmRetorno].forEach(function (campo) {
            if (campo) {
                campo.addEventListener('input', atualizarDevolucao);
                campo.addEventListener('change', atualizarDevolucao);
            }
        });
        atualizarDevolucao();

        var caixaManutencao = formDevolucao.querySelector('#enviar_manutencao');
        var areaManutencao = document.getElementById('area-manutencao');

        if (caixaManutencao && areaManutencao) {
            var alternar = function () {
                areaManutencao.hidden = !caixaManutencao.checked;
                areaManutencao.querySelector('textarea').required = caixaManutencao.checked;
            };

            caixaManutencao.addEventListener('change', alternar);
            alternar();
        }
    }
})();
