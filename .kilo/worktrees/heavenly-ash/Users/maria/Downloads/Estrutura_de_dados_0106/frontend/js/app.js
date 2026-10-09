// ==================== CONFIGURACAO ====================
const API_URL = 'http://localhost:8080/api';

// ==================== NAVEGACAO ====================
document.addEventListener('DOMContentLoaded', () => {
    // Navegacao sidebar
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const page = item.dataset.page;
            navigateTo(page);
        });
    });

    // Menu toggle mobile
    document.getElementById('menuToggle').addEventListener('click', () => {
        document.getElementById('sidebar').classList.toggle('open');
    });

    // Fechar sidebar ao clicar fora (mobile)
    document.querySelector('.main-content').addEventListener('click', () => {
        document.getElementById('sidebar').classList.remove('open');
    });

    // Carregar dashboard inicial
    carregarDashboard();
});

function navigateTo(page) {
    // Atualizar nav items
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    document.querySelector(`[data-page="${page}"]`).classList.add('active');

    // Atualizar paginas
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.getElementById(`page-${page}`).classList.add('active');

    // Atualizar titulo
    const titles = {
        dashboard: 'Dashboard',
        chamados: 'Chamados',
        fila: 'Fila de Atendimento',
        historico: 'Historico de Operacoes',
        usuarios: 'Usuarios',
        equipamentos: 'Equipamentos',
        busca: 'Busca de Chamados',
        ordenacao: 'Ordenacao e Busca Binaria',
        estruturas: 'Estruturas de Dados'
    };
    document.getElementById('pageTitle').textContent = titles[page] || page;

    // Carregar dados da pagina
    switch (page) {
        case 'dashboard': carregarDashboard(); break;
        case 'chamados': carregarChamados(); break;
        case 'fila': carregarFila(); break;
        case 'historico': carregarHistorico(); break;
        case 'usuarios': carregarUsuarios(); break;
        case 'equipamentos': carregarEquipamentos(); break;
    }

    // Fechar sidebar mobile
    document.getElementById('sidebar').classList.remove('open');
}

// ==================== API HELPER ====================
async function apiRequest(endpoint, method = 'GET', body = null) {
    try {
        const options = {
            method,
            headers: { 'Content-Type': 'application/json' }
        };
        if (body) options.body = JSON.stringify(body);

        const response = await fetch(`${API_URL}${endpoint}`, options);
        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.erro || 'Erro na requisicao');
        }
        return data;
    } catch (error) {
        if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
            showToast('Erro: API nao esta rodando. Execute o backend Java primeiro!', 'error');
        } else {
            showToast('Erro: ' + error.message, 'error');
        }
        throw error;
    }
}

// ==================== DASHBOARD ====================
async function carregarDashboard() {
    try {
        const stats = await apiRequest('/estatisticas');

        document.getElementById('statTotal').textContent = stats.totalChamados;
        document.getElementById('statFila').textContent = stats.naFila;
        document.getElementById('statAtendimento').textContent = stats.emAtendimento;
        document.getElementById('statFinalizados').textContent = stats.finalizados;
        document.getElementById('statSla').textContent = stats.slaEstourados || 0;
        document.getElementById('statArvore').textContent = stats.alturaArvore || 0;

        // Barras de prioridade
        const total = stats.totalChamados || 1;
        const priorityBars = document.getElementById('priorityBars');
        priorityBars.innerHTML = `
            <div class="priority-bar-item">
                <span class="priority-bar-label">Critica</span>
                <div class="priority-bar-track">
                    <div class="priority-bar-fill priority-critica" style="width: ${(stats.critica / total) * 100}%">${stats.critica}</div>
                </div>
            </div>
            <div class="priority-bar-item">
                <span class="priority-bar-label">Alta</span>
                <div class="priority-bar-track">
                    <div class="priority-bar-fill priority-alta" style="width: ${(stats.alta / total) * 100}%">${stats.alta}</div>
                </div>
            </div>
            <div class="priority-bar-item">
                <span class="priority-bar-label">Media</span>
                <div class="priority-bar-track">
                    <div class="priority-bar-fill priority-media" style="width: ${(stats.media / total) * 100}%">${stats.media}</div>
                </div>
            </div>
            <div class="priority-bar-item">
                <span class="priority-bar-label">Baixa</span>
                <div class="priority-bar-track">
                    <div class="priority-bar-fill priority-baixa" style="width: ${(stats.baixa / total) * 100}%">${stats.baixa}</div>
                </div>
            </div>
        `;

        // Ultimas operacoes (historico - pilha)
        try {
            const historico = await apiRequest('/historico');
            const timeline = document.getElementById('dashTimeline');
            if (historico.registros && historico.registros.length > 0) {
                const ultimos = historico.registros.slice(0, 5);
                timeline.innerHTML = ultimos.map(r => renderTimelineItem(r)).join('');
            } else {
                timeline.innerHTML = '<p class="text-muted">Nenhuma operacao registrada</p>';
            }
        } catch (e) { /* ignore */ }

        // Proximo na fila
        try {
            const fila = await apiRequest('/fila');
            const container = document.getElementById('dashProximoFila');
            if (fila.chamados && fila.chamados.length > 0) {
                const c = fila.chamados[0];
                container.innerHTML = `
                    <div class="fila-item" style="border-left-color: var(--success);">
                        <div class="fila-position" style="background: var(--success);">1</div>
                        <div class="fila-info">
                            <h4>#${c.id} - ${c.titulo}</h4>
                            <p>${c.nomeUsuario} | ${c.setor} | ${c.prioridadeTexto}</p>
                        </div>
                        <button class="btn btn-success btn-sm" onclick="iniciarAtendimento(${c.id})">
                            <i class="fas fa-play"></i> Atender
                        </button>
                    </div>
                `;
            } else {
                container.innerHTML = '<p class="text-muted">Nenhum chamado na fila de atendimento</p>';
            }
        } catch (e) { /* ignore */ }

    } catch (error) {
        console.error('Erro ao carregar dashboard:', error);
    }
}

// ==================== CHAMADOS ====================
async function carregarChamados() {
    try {
        const chamados = await apiRequest('/chamados');
        const filtro = document.getElementById('filtroStatus').value;
        const tbody = document.getElementById('tabelaChamados');

        const filtrados = filtro ? chamados.filter(c => c.status === filtro) : chamados;

        if (filtrados.length === 0) {
            tbody.innerHTML = `
                <tr><td colspan="8">
                    <div class="empty-state">
                        <i class="fas fa-ticket-alt"></i>
                        <h4>Nenhum chamado encontrado</h4>
                        <p>Crie um novo chamado para comecar</p>
                    </div>
                </td></tr>
            `;
            return;
        }

        tbody.innerHTML = filtrados.map(c => `
            <tr class="${c.slaEstourado ? 'sla-estourado' : ''}">
                <td><strong>#${c.id}</strong></td>
                <td>${c.titulo}</td>
                <td>${c.nomeUsuario}</td>
                <td>${c.setor}</td>
                <td><span class="badge badge-prioridade-${c.prioridade}">${c.prioridadeTexto}</span></td>
                <td><span class="badge badge-status-${c.status}">${formatStatus(c.status)}</span></td>
                <td>
                    ${c.dataAbertura}
                    ${c.slaEstourado ? '<br><span class="badge badge-sla-estourado"><i class="fas fa-exclamation-triangle"></i> SLA</span>' : 
                      (c.status !== 'FINALIZADO' ? '<br><span class="badge badge-sla-ok">SLA: ' + c.slaTexto + '</span>' : '')}
                </td>
                <td>
                    <div style="display:flex;gap:4px;">
                        <button class="btn btn-primary btn-icon" onclick="verDetalhes(${c.id})" title="Detalhes">
                            <i class="fas fa-eye"></i>
                        </button>
                        ${c.status === 'EM_ATENDIMENTO' ? `
                            <button class="btn btn-success btn-icon" onclick="abrirModalFinalizar(${c.id})" title="Finalizar">
                                <i class="fas fa-check"></i>
                            </button>
                        ` : ''}
                    </div>
                </td>
            </tr>
        `).join('');
    } catch (error) {
        console.error('Erro ao carregar chamados:', error);
    }
}

async function criarChamado(event) {
    event.preventDefault();
    try {
        const chamado = {
            titulo: document.getElementById('chamadoTitulo').value,
            descricao: document.getElementById('chamadoDescricao').value,
            prioridade: parseInt(document.getElementById('chamadoPrioridade').value),
            nomeUsuario: document.getElementById('chamadoUsuario').value,
            setor: document.getElementById('chamadoSetor').value,
            equipamento: document.getElementById('chamadoEquipamento').value
        };

        await apiRequest('/chamados', 'POST', chamado);
        showToast('Chamado criado com sucesso!', 'success');
        fecharModal('modalNovoChamado');
        document.getElementById('formNovoChamado').reset();

        // Recarregar pagina atual
        const activePage = document.querySelector('.nav-item.active').dataset.page;
        navigateTo(activePage);
    } catch (error) {
        console.error('Erro ao criar chamado:', error);
    }
}

async function verDetalhes(id) {
    try {
        const c = await apiRequest(`/chamados/${id}`);
        const container = document.getElementById('detalhesConteudo');
        container.innerHTML = `
            <div class="detail-grid">
                <div class="detail-item">
                    <label>ID</label>
                    <span>#${c.id}</span>
                </div>
                <div class="detail-item">
                    <label>Status</label>
                    <span class="badge badge-status-${c.status}">${formatStatus(c.status)}</span>
                </div>
                <div class="detail-item detail-full">
                    <label>Titulo</label>
                    <span>${c.titulo}</span>
                </div>
                <div class="detail-item detail-full">
                    <label>Descricao</label>
                    <span>${c.descricao}</span>
                </div>
                <div class="detail-item">
                    <label>Prioridade</label>
                    <span class="badge badge-prioridade-${c.prioridade}">${c.prioridadeTexto}</span>
                </div>
                <div class="detail-item">
                    <label>Setor</label>
                    <span>${c.setor}</span>
                </div>
                <div class="detail-item">
                    <label>Usuario</label>
                    <span>${c.nomeUsuario}</span>
                </div>
                <div class="detail-item">
                    <label>Equipamento</label>
                    <span>${c.equipamento || '-'}</span>
                </div>
                <div class="detail-item">
                    <label>Data Abertura</label>
                    <span>${c.dataAbertura}</span>
                </div>
                <div class="detail-item">
                    <label>Data Finalizacao</label>
                    <span>${c.dataFinalizacao || '-'}</span>
                </div>
                ${c.tecnicoResponsavel ? `
                <div class="detail-item">
                    <label>Tecnico Responsavel</label>
                    <span>${c.tecnicoResponsavel}</span>
                </div>` : ''}
                ${c.solucao ? `
                <div class="detail-item detail-full">
                    <label>Solucao Aplicada</label>
                    <span>${c.solucao}</span>
                </div>` : ''}
            </div>
        `;
        abrirModal('modalDetalhes');
    } catch (error) {
        console.error('Erro ao ver detalhes:', error);
    }
}

// ==================== FILA ====================
async function carregarFila() {
    try {
        const fila = await apiRequest('/fila');
        const container = document.getElementById('filaContainer');
        document.getElementById('filaCount').textContent = `${fila.tamanho} chamado(s)`;

        if (fila.chamados.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-check-circle"></i>
                    <h4>Fila vazia</h4>
                    <p>Nenhum chamado aguardando atendimento</p>
                </div>
            `;
            return;
        }

        container.innerHTML = fila.chamados.map((c, i) => `
            <div class="fila-item">
                <div class="fila-position">${i + 1}</div>
                <div class="fila-info">
                    <h4>#${c.id} - ${c.titulo}</h4>
                    <p>
                        <strong>${c.nomeUsuario}</strong> | ${c.setor} |
                        <span class="badge badge-prioridade-${c.prioridade}">${c.prioridadeTexto}</span>
                        | Aberto: ${c.dataAbertura}
                    </p>
                </div>
                <div class="fila-actions">
                    ${i === 0 ? `
                        <button class="btn btn-success btn-sm" onclick="iniciarAtendimento(${c.id})">
                            <i class="fas fa-play"></i> Atender
                        </button>
                    ` : `
                        <span class="badge badge-secondary">Aguardando</span>
                    `}
                    <button class="btn btn-primary btn-icon btn-sm" onclick="verDetalhes(${c.id})" title="Detalhes">
                        <i class="fas fa-eye"></i>
                    </button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        console.error('Erro ao carregar fila:', error);
    }
}

async function iniciarAtendimento(id) {
    try {
        await apiRequest(`/chamados/atender/${id}`, 'POST');
        showToast(`Atendimento do chamado #${id} iniciado!`, 'success');

        // Recarregar pagina atual
        const activePage = document.querySelector('.nav-item.active').dataset.page;
        navigateTo(activePage);
    } catch (error) {
        console.error('Erro ao iniciar atendimento:', error);
    }
}

// ==================== FINALIZAR CHAMADO ====================
function abrirModalFinalizar(id) {
    document.getElementById('finalizarId').value = id;
    document.getElementById('finalizarTecnico').value = '';
    document.getElementById('finalizarSolucao').value = '';
    abrirModal('modalFinalizar');
}

async function finalizarChamado(event) {
    event.preventDefault();
    try {
        const id = document.getElementById('finalizarId').value;
        const dados = {
            tecnico: document.getElementById('finalizarTecnico').value,
            solucao: document.getElementById('finalizarSolucao').value
        };

        await apiRequest(`/chamados/finalizar/${id}`, 'POST', dados);
        showToast(`Chamado #${id} finalizado com sucesso!`, 'success');
        fecharModal('modalFinalizar');

        const activePage = document.querySelector('.nav-item.active').dataset.page;
        navigateTo(activePage);
    } catch (error) {
        console.error('Erro ao finalizar chamado:', error);
    }
}

// ==================== HISTORICO ====================
async function carregarHistorico() {
    try {
        const historico = await apiRequest('/historico');
        const container = document.getElementById('historicoContainer');
        document.getElementById('historicoCount').textContent = `${historico.tamanho} registro(s)`;

        if (historico.registros.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-history"></i>
                    <h4>Historico vazio</h4>
                    <p>Nenhuma operacao registrada ainda</p>
                </div>
            `;
            return;
        }

        container.innerHTML = historico.registros.map(r => renderTimelineItem(r)).join('');
    } catch (error) {
        console.error('Erro ao carregar historico:', error);
    }
}

function renderTimelineItem(r) {
    let iconClass, icon, tipoLabel;
    if (r.tipo.startsWith('UNDO')) {
        iconClass = 'undo';
        icon = 'fa-undo';
        tipoLabel = 'Desfazer';
    } else if (r.tipo === 'CRIACAO') {
        iconClass = 'criacao';
        icon = 'fa-plus';
        tipoLabel = 'Criacao';
    } else if (r.tipo === 'ATENDIMENTO') {
        iconClass = 'atendimento';
        icon = 'fa-wrench';
        tipoLabel = 'Atendimento';
    } else {
        iconClass = 'finalizacao';
        icon = 'fa-check';
        tipoLabel = 'Finalizacao';
    }

    return `
        <div class="timeline-item">
            <div class="timeline-icon ${iconClass}">
                <i class="fas ${icon}"></i>
            </div>
            <div class="timeline-content">
                <h4>${tipoLabel} - Chamado #${r.chamadoId}</h4>
                <p>${r.descricao}</p>
                <div class="timeline-date">${r.dataHora}</div>
            </div>
        </div>
    `;
}

// ==================== USUARIOS ====================
async function carregarUsuarios() {
    try {
        const usuarios = await apiRequest('/usuarios');
        const tbody = document.getElementById('tabelaUsuarios');

        if (usuarios.length === 0) {
            tbody.innerHTML = `
                <tr><td colspan="6">
                    <div class="empty-state">
                        <i class="fas fa-users"></i>
                        <h4>Nenhum usuario cadastrado</h4>
                    </div>
                </td></tr>
            `;
            return;
        }

        tbody.innerHTML = usuarios.map(u => `
            <tr>
                <td><strong>#${u.id}</strong></td>
                <td>${u.nome}</td>
                <td>${u.email}</td>
                <td>${u.setor}</td>
                <td>${u.cargo}</td>
                <td>
                    <button class="btn btn-danger btn-icon btn-sm" onclick="removerUsuario(${u.id})" title="Remover">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    } catch (error) {
        console.error('Erro ao carregar usuarios:', error);
    }
}

async function criarUsuario(event) {
    event.preventDefault();
    try {
        const usuario = {
            nome: document.getElementById('usuarioNome').value,
            email: document.getElementById('usuarioEmail').value,
            setor: document.getElementById('usuarioSetor').value,
            cargo: document.getElementById('usuarioCargo').value
        };

        await apiRequest('/usuarios', 'POST', usuario);
        showToast('Usuario cadastrado com sucesso!', 'success');
        fecharModal('modalNovoUsuario');
        document.getElementById('formNovoUsuario').reset();
        carregarUsuarios();
    } catch (error) {
        console.error('Erro ao criar usuario:', error);
    }
}

async function removerUsuario(id) {
    if (!confirm('Deseja realmente remover este usuario?')) return;
    try {
        await apiRequest(`/usuarios/${id}`, 'DELETE');
        showToast('Usuario removido!', 'success');
        carregarUsuarios();
    } catch (error) {
        console.error('Erro ao remover usuario:', error);
    }
}

// ==================== EQUIPAMENTOS ====================
async function carregarEquipamentos() {
    try {
        const equipamentos = await apiRequest('/equipamentos');
        const tbody = document.getElementById('tabelaEquipamentos');

        if (equipamentos.length === 0) {
            tbody.innerHTML = `
                <tr><td colspan="6">
                    <div class="empty-state">
                        <i class="fas fa-desktop"></i>
                        <h4>Nenhum equipamento cadastrado</h4>
                    </div>
                </td></tr>
            `;
            return;
        }

        tbody.innerHTML = equipamentos.map(e => `
            <tr>
                <td><strong>#${e.id}</strong></td>
                <td>${e.tipo}</td>
                <td>${e.marca}</td>
                <td>${e.patrimonio}</td>
                <td>${e.setor}</td>
                <td>
                    <button class="btn btn-danger btn-icon btn-sm" onclick="removerEquipamento(${e.id})" title="Remover">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    } catch (error) {
        console.error('Erro ao carregar equipamentos:', error);
    }
}

async function criarEquipamento(event) {
    event.preventDefault();
    try {
        const equipamento = {
            tipo: document.getElementById('equipTipo').value,
            marca: document.getElementById('equipMarca').value,
            patrimonio: document.getElementById('equipPatrimonio').value,
            setor: document.getElementById('equipSetor').value
        };

        await apiRequest('/equipamentos', 'POST', equipamento);
        showToast('Equipamento cadastrado com sucesso!', 'success');
        fecharModal('modalNovoEquipamento');
        document.getElementById('formNovoEquipamento').reset();
        carregarEquipamentos();
    } catch (error) {
        console.error('Erro ao criar equipamento:', error);
    }
}

async function removerEquipamento(id) {
    if (!confirm('Deseja realmente remover este equipamento?')) return;
    try {
        await apiRequest(`/equipamentos/${id}`, 'DELETE');
        showToast('Equipamento removido!', 'success');
        carregarEquipamentos();
    } catch (error) {
        console.error('Erro ao remover equipamento:', error);
    }
}

// ==================== BUSCA ====================
async function buscarPorId() {
    const id = document.getElementById('buscaId').value;
    if (!id) {
        showToast('Digite um ID para buscar', 'error');
        return;
    }

    try {
        const resultado = await apiRequest(`/busca?id=${id}`);
        const container = document.getElementById('resultadoBusca');

        if (resultado.encontrado) {
            const c = resultado.chamado;
            container.innerHTML = `
                <div class="info-box info-green">
                    <i class="fas fa-check-circle"></i>
                    <strong>Chamado encontrado na Arvore Binaria!</strong>
                </div>
                <div class="search-result-item">
                    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                        <strong>#${c.id} - ${c.titulo}</strong>
                        <span class="badge badge-status-${c.status}">${formatStatus(c.status)}</span>
                    </div>
                    <p style="font-size:0.88rem;color:var(--text-secondary);">
                        ${c.descricao}<br>
                        <strong>Usuario:</strong> ${c.nomeUsuario} | <strong>Setor:</strong> ${c.setor} |
                        <strong>Prioridade:</strong> <span class="badge badge-prioridade-${c.prioridade}">${c.prioridadeTexto}</span>
                    </p>
                </div>
            `;
        } else {
            container.innerHTML = `
                <div class="info-box" style="background:#fee2e2;color:#991b1b;border:1px solid #fca5a5;">
                    <i class="fas fa-times-circle"></i>
                    <strong>Chamado #${id} nao encontrado na Arvore Binaria.</strong>
                </div>
            `;
        }
    } catch (error) {
        console.error('Erro na busca:', error);
    }
}

async function buscarPorTermo() {
    const termo = document.getElementById('buscaTermo').value;
    if (!termo) {
        showToast('Digite um termo para buscar', 'error');
        return;
    }

    try {
        const resultado = await apiRequest(`/busca?termo=${encodeURIComponent(termo)}`);
        renderResultadosBusca(resultado, `Busca por "${termo}" na Lista Ligada`);
    } catch (error) {
        console.error('Erro na busca:', error);
    }
}

async function listarEmOrdem() {
    try {
        const resultado = await apiRequest('/busca');
        renderResultadosBusca(resultado, 'Travessia Em Ordem (In-Order) da Arvore Binaria');
    } catch (error) {
        console.error('Erro na listagem:', error);
    }
}

async function listarPorTravessia() {
    const modo = document.getElementById('modoTravessia').value;
    const nomes = {
        emOrdem: 'Em Ordem (Esquerda, Raiz, Direita)',
        preOrdem: 'Pre-Ordem (Raiz, Esquerda, Direita)',
        posOrdem: 'Pos-Ordem (Esquerda, Direita, Raiz)'
    };
    try {
        const resultado = await apiRequest(`/busca?modo=${modo}`);
        renderResultadosBusca(resultado, `Travessia ${nomes[modo]} da Arvore Binaria`);
    } catch (error) {
        console.error('Erro na travessia:', error);
    }
}

// ==================== DESFAZER (UNDO) ====================
async function desfazerUltimaAcao() {
    try {
        const info = await apiRequest('/desfazer');
        if (!info.temUndo) {
            showToast('Nenhuma acao para desfazer', 'info');
            return;
        }
        if (!confirm(`Desfazer: ${info.proximoUndo.descricao}?`)) return;

        const resultado = await apiRequest('/desfazer', 'POST');
        showToast(resultado.mensagem, 'success');

        // Recarregar pagina atual
        const activePage = document.querySelector('.nav-item.active').dataset.page;
        navigateTo(activePage);
    } catch (error) {
        console.error('Erro ao desfazer:', error);
    }
}

// ==================== ORDENACAO (SELECTION SORT) ====================
async function ordenarChamados() {
    const criterio = document.getElementById('criterioOrdenacao').value;
    try {
        const resultado = await apiRequest(`/ordenar?criterio=${criterio}`);
        renderResultadoOrdenacao(resultado);
    } catch (error) {
        console.error('Erro ao ordenar:', error);
    }
}

async function buscaBinaria() {
    const prio = document.getElementById('buscaBinariaPrio').value;
    try {
        const resultado = await apiRequest(`/ordenar?criterio=prioridade&buscaPrioridade=${prio}`);
        renderResultadoOrdenacao(resultado);
    } catch (error) {
        console.error('Erro na busca binaria:', error);
    }
}

function renderResultadoOrdenacao(resultado) {
    const container = document.getElementById('resultadoOrdenacao');
    const nomesCriterio = { prioridade: 'Prioridade', id: 'ID', status: 'Status', setor: 'Setor' };

    if (resultado.total === 0) {
        container.innerHTML = `
            <div class="info-box" style="background:#fee2e2;color:#991b1b;border:1px solid #fca5a5;">
                <i class="fas fa-search"></i>
                <strong>Nenhum chamado para ordenar.</strong>
            </div>
        `;
        return;
    }

    let buscaBinariaHtml = '';
    if (resultado.buscaBinariaResultado && resultado.buscaBinariaResultado !== null) {
        const c = resultado.buscaBinariaResultado;
        buscaBinariaHtml = `
            <div class="info-box info-purple" style="margin-top:12px;">
                <i class="fas fa-bullseye"></i>
                <strong>Busca Binaria encontrou:</strong> #${c.id} - ${c.titulo}
                (Prioridade: ${c.prioridadeTexto}, Status: ${formatStatus(c.status)})
            </div>
        `;
    } else if (resultado.buscaBinariaResultado === null && container.innerHTML.includes('Busca Binaria')) {
        buscaBinariaHtml = `
            <div class="info-box" style="background:#fee2e2;color:#991b1b;border:1px solid #fca5a5;margin-top:12px;">
                <i class="fas fa-times-circle"></i>
                <strong>Busca Binaria: nenhum chamado encontrado com essa prioridade.</strong>
            </div>
        `;
    }

    container.innerHTML = `
        <div class="info-box info-green">
            <i class="fas fa-sort"></i>
            <strong>Selection Sort por ${nomesCriterio[resultado.criterio] || resultado.criterio} - ${resultado.total} chamado(s)</strong>
        </div>
        ${buscaBinariaHtml}
        ${resultado.resultados.map((c, i) => `
            <div class="search-result-item">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                    <strong><span style="color:var(--text-secondary);">[${i+1}]</span> #${c.id} - ${c.titulo}</strong>
                    <div style="display:flex;gap:6px;">
                        <span class="badge badge-prioridade-${c.prioridade}">${c.prioridadeTexto}</span>
                        <span class="badge badge-status-${c.status}">${formatStatus(c.status)}</span>
                        ${c.slaEstourado ? '<span class="badge badge-sla-estourado"><i class="fas fa-exclamation-triangle"></i> SLA</span>' : ''}
                    </div>
                </div>
                <p style="font-size:0.85rem;color:var(--text-secondary);">
                    <strong>Usuario:</strong> ${c.nomeUsuario} | <strong>Setor:</strong> ${c.setor} | <strong>SLA:</strong> ${c.slaTexto}
                </p>
            </div>
        `).join('')}
    `;
}

function renderResultadosBusca(resultado, titulo) {
    const container = document.getElementById('resultadoBusca');

    if (resultado.total === 0) {
        container.innerHTML = `
            <div class="info-box" style="background:#fee2e2;color:#991b1b;border:1px solid #fca5a5;">
                <i class="fas fa-search"></i>
                <strong>Nenhum resultado encontrado.</strong>
            </div>
        `;
        return;
    }

    container.innerHTML = `
        <div class="info-box info-green">
            <i class="fas fa-check-circle"></i>
            <strong>${titulo} - ${resultado.total} resultado(s)</strong>
        </div>
        ${resultado.resultados.map(c => `
            <div class="search-result-item">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                    <strong>#${c.id} - ${c.titulo}</strong>
                    <div style="display:flex;gap:6px;">
                        <span class="badge badge-prioridade-${c.prioridade}">${c.prioridadeTexto}</span>
                        <span class="badge badge-status-${c.status}">${formatStatus(c.status)}</span>
                    </div>
                </div>
                <p style="font-size:0.85rem;color:var(--text-secondary);">
                    ${c.descricao}<br>
                    <strong>Usuario:</strong> ${c.nomeUsuario} | <strong>Setor:</strong> ${c.setor} | <strong>Aberto:</strong> ${c.dataAbertura}
                </p>
            </div>
        `).join('')}
    `;
}

// ==================== MODAIS ====================
function abrirModal(id) {
    document.getElementById(id).classList.add('show');
}

function fecharModal(id) {
    document.getElementById(id).classList.remove('show');
}

function abrirModalNovoChamado() {
    document.getElementById('formNovoChamado').reset();
    abrirModal('modalNovoChamado');
}

function abrirModalNovoUsuario() {
    document.getElementById('formNovoUsuario').reset();
    abrirModal('modalNovoUsuario');
}

function abrirModalNovoEquipamento() {
    document.getElementById('formNovoEquipamento').reset();
    abrirModal('modalNovoEquipamento');
}

// Fechar modal ao clicar no overlay
document.addEventListener('click', (e) => {
    if (e.target.classList.contains('modal-overlay')) {
        e.target.classList.remove('show');
    }
});

// Fechar modal com Escape
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        document.querySelectorAll('.modal-overlay.show').forEach(m => m.classList.remove('show'));
    }
});

// ==================== TOAST ====================
function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const icons = { success: 'fa-check-circle', error: 'fa-exclamation-circle', info: 'fa-info-circle' };
    toast.innerHTML = `<i class="fas ${icons[type] || icons.info}"></i> ${message}`;

    container.appendChild(toast);

    setTimeout(() => {
        toast.classList.add('toast-out');
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}

// ==================== HELPERS ====================
function formatStatus(status) {
    const map = {
        'ABERTO': 'Aberto',
        'EM_ATENDIMENTO': 'Em Atendimento',
        'FINALIZADO': 'Finalizado'
    };
    return map[status] || status;
}
