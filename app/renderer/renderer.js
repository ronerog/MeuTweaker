// MeuTweaker - logica da interface (renderer). Chama o processo principal
// via window.mt (exposto pelo preload.js), que por sua vez chama o
// bridge.ps1. Nenhuma logica de tweak mora aqui - so apresentacao e estado
// da UI.

const state = {
  catalog: null,       // { isAdmin, tweaks: [...], perfis: [...] }
  switches: {},         // id -> boolean (estado atual do toggle na tela)
  loaded: { debloat: false, drivers: false, desempenho: false },
  perfTimer: null,
};

// ---------------- helpers de UI ----------------

function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text !== undefined) n.textContent = text;
  return n;
}

function showOverlay(texto) {
  document.getElementById('overlay-text').textContent = texto;
  document.getElementById('overlay').hidden = false;
}
function hideOverlay() {
  document.getElementById('overlay').hidden = true;
}

let toastTimer = null;
function toast(texto, tipo) {
  const t = document.getElementById('toast');
  t.textContent = texto;
  t.className = 'toast' + (tipo ? ` ${tipo}` : '');
  t.hidden = false;
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, 6000);
}

function resumoResultado(r, verboAplicado, verboRevertido) {
  const partes = [];
  const feitos = r.aplicados || r.revertidos || [];
  if (feitos.length) partes.push(`${verboAplicado || verboRevertido}: ${feitos.length}.`);
  if (r.pulados && r.pulados.length) {
    partes.push(`Precisam de administrador (nao aplicados):\n - ${r.pulados.join('\n - ')}`);
  }
  if (r.erros && r.erros.length) {
    partes.push(`Falharam:\n - ${r.erros.map((e) => `${e.nome}: ${e.detail}`).join('\n - ')}`);
  }
  return partes.join('\n\n') || 'Nada a fazer.';
}

// ---------------- navegacao ----------------

function irParaView(nome) {
  document.querySelectorAll('.nav-item').forEach((b) => b.classList.toggle('active', b.dataset.view === nome));
  document.querySelectorAll('.view').forEach((v) => v.classList.toggle('active', v.id === `view-${nome}`));

  if (nome === 'debloat' && !state.loaded.debloat) carregarDebloat();
  if (nome === 'drivers' && !state.loaded.drivers) carregarDrivers();

  if (nome === 'desempenho') {
    if (!state.loaded.desempenho) carregarPerfEstatico();
    iniciarPerfLive();
  } else {
    pararPerfLive();
  }
}

document.querySelectorAll('.nav-item').forEach((b) => {
  b.addEventListener('click', () => irParaView(b.dataset.view));
});

// ---------------- topo / admin ----------------

function aplicarStatusAdmin(isAdmin) {
  const badge = document.getElementById('admin-status');
  badge.textContent = isAdmin ? 'administrador' : 'sem privilegios de administrador';
  badge.className = 'admin-status ' + (isAdmin ? 'is-admin' : 'not-admin');
  document.getElementById('btn-admin').hidden = !!isAdmin;
}

// ---------------- Ajustes ----------------

function renderPerfis(perfis) {
  const row = document.getElementById('perfis-row');
  row.innerHTML = '';
  for (const p of perfis) {
    const card = el('div', 'perfil-card');
    card.innerHTML = `<div class="perfil-nome"><span>${p.icone || ''}</span><span>${p.nome}</span></div><div class="perfil-desc">${p.desc}</div>`;
    card.addEventListener('click', () => aplicarPerfil(p));
    row.appendChild(card);
  }
}

function renderTweaks(tweaks) {
  const lista = document.getElementById('tweaks-list');
  lista.innerHTML = '';
  state.switches = {};

  const categorias = [];
  for (const t of tweaks) if (!categorias.includes(t.categoria)) categorias.push(t.categoria);

  for (const cat of categorias) {
    lista.appendChild(el('div', 'categoria-titulo', cat));
    for (const t of tweaks.filter((x) => x.categoria === cat)) {
      if (t.unico) {
        lista.appendChild(renderTweakUnico(t));
      } else {
        lista.appendChild(renderTweakSwitch(t));
      }
    }
  }
}

function renderTweakSwitch(t) {
  state.switches[t.id] = !!t.aplicado;

  const row = el('div', 'tweak-row');

  const label = document.createElement('label');
  label.className = 'switch';
  const input = document.createElement('input');
  input.type = 'checkbox';
  input.checked = !!t.aplicado;
  input.addEventListener('change', () => { state.switches[t.id] = input.checked; });
  const track = el('span', 'track');
  const thumb = el('span', 'thumb');
  label.appendChild(input);
  label.appendChild(track);
  label.appendChild(thumb);

  const info = el('div', 'tweak-info');
  const nome = el('div', 'tweak-nome', t.nome);
  if (t.admin) nome.appendChild(el('span', 'tag-admin', '[admin]'));
  info.appendChild(nome);
  info.appendChild(el('div', 'tweak-desc', t.desc));

  row.appendChild(label);
  row.appendChild(info);
  return row;
}

function renderTweakUnico(t) {
  const row = el('div', 'tweak-row');
  const info = el('div', 'tweak-info');
  info.appendChild(el('div', 'tweak-nome', t.nome));
  info.appendChild(el('div', 'tweak-desc', t.desc));

  const btn = el('button', 'unico-btn', 'Executar agora');
  btn.addEventListener('click', async () => {
    showOverlay(`Executando: ${t.nome}...`);
    const r = await window.mt.applyTweaks([t.id]);
    hideOverlay();
    toast(resumoResultado(r, 'Executado'), r.erros && r.erros.length ? 'error' : 'success');
  });

  row.appendChild(btn);
  row.appendChild(info);
  return row;
}

async function carregarCatalogo() {
  const r = await window.mt.getCatalog();
  if (!r.ok) { toast(r.detail || 'Falha ao carregar catalogo.', 'error'); return; }
  state.catalog = r;
  aplicarStatusAdmin(r.isAdmin);
  renderPerfis(r.perfis);
  renderTweaks(r.tweaks);
}

function idsMarcados() {
  return Object.keys(state.switches).filter((id) => state.switches[id]);
}
function idsDesmarcados() {
  return Object.keys(state.switches).filter((id) => !state.switches[id]);
}

async function aplicarIds(ids, overlayTexto) {
  showOverlay(overlayTexto || 'Aplicando ajustes...');
  const r = await window.mt.applyTweaks(ids);
  hideOverlay();
  if (!r.ok) { toast(r.detail || 'Falha ao aplicar.', 'error'); return; }
  toast(resumoResultado(r, 'Aplicados'), r.erros && r.erros.length ? 'error' : 'success');
  await carregarCatalogo();
}

async function aplicarPerfil(perfil) {
  showOverlay(`Aplicando perfil: ${perfil.nome}...`);
  const r = await window.mt.applyPerfil(perfil.id);
  hideOverlay();
  if (!r.ok) { toast(r.detail || 'Falha ao aplicar perfil.', 'error'); return; }
  const texto = perfil.revertAll
    ? resumoResultado({ revertidos: r.revertidos, erros: r.erros }, null, 'Revertidos')
    : resumoResultado(r, 'Aplicados');
  toast(texto, r.erros && r.erros.length ? 'error' : 'success');
  await carregarCatalogo();
}

document.getElementById('btn-boost').addEventListener('click', async () => {
  if (!state.catalog) return;
  for (const t of state.catalog.tweaks) {
    if (t.recomendado && !t.unico) state.switches[t.id] = true;
  }
  renderTweaks(state.catalog.tweaks.map((t) => ({ ...t, aplicado: state.switches[t.id] ?? t.aplicado })));
  await aplicarIds(idsMarcados(), 'Aplicando ajustes recomendados...');
});

document.getElementById('btn-apply').addEventListener('click', () => aplicarIds(idsMarcados()));

document.getElementById('btn-revert').addEventListener('click', async () => {
  showOverlay('Revertendo ajustes desmarcados...');
  const r = await window.mt.revertTweaks(idsDesmarcados());
  hideOverlay();
  if (!r.ok) { toast(r.detail || 'Falha ao reverter.', 'error'); return; }
  toast(resumoResultado(r, null, 'Revertidos'), r.erros && r.erros.length ? 'error' : 'success');
  await carregarCatalogo();
});

document.getElementById('btn-restore-point').addEventListener('click', async () => {
  showOverlay('Criando ponto de restauracao...');
  const r = await window.mt.createRestorePoint();
  hideOverlay();
  toast(r.detail || (r.ok ? 'Ponto de restauracao criado.' : 'Falha.'), r.ok ? 'success' : 'error');
});

document.getElementById('btn-admin').addEventListener('click', () => window.mt.restartAsAdmin());

// ---------------- Debloat ----------------

async function carregarDebloat() {
  const lista = document.getElementById('debloat-list');
  lista.innerHTML = '<p class="hint">Lendo apps instalados...</p>';
  const r = await window.mt.getDebloat();
  lista.innerHTML = '';
  if (!r.ok) { toast(r.detail || 'Falha ao listar apps.', 'error'); return; }
  state.loaded.debloat = true;

  for (const app of r.apps) {
    const row = el('div', 'debloat-row' + (app.instalado ? '' : ' disabled'));
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.disabled = !app.instalado;
    input.dataset.match = app.match;
    const label = el('span', 'debloat-label', app.label);
    row.appendChild(input);
    row.appendChild(label);
    if (!app.instalado) row.appendChild(el('span', 'debloat-tag', '(nao instalado)'));
    if (app.aviso) row.appendChild(el('span', 'debloat-aviso', app.aviso));
    lista.appendChild(row);
  }
}

document.getElementById('btn-debloat-refresh').addEventListener('click', carregarDebloat);

document.getElementById('btn-debloat-remove').addEventListener('click', async () => {
  const marcados = Array.from(document.querySelectorAll('#debloat-list input:checked')).map((i) => i.dataset.match);
  if (!marcados.length) return;
  if (!state.catalog || !state.catalog.isAdmin) {
    toast('Remover apps exige executar o MeuTweaker como administrador.', 'error');
    return;
  }
  const ok = await window.mt.confirm('Confirmar', `Remover ${marcados.length} app(s)? Isso nao e reversivel por aqui.`);
  if (!ok) return;
  showOverlay('Removendo apps...');
  const r = await window.mt.removeDebloat(marcados);
  hideOverlay();
  if (!r.ok) { toast(r.detail || 'Falha ao remover.', 'error'); return; }
  toast(r.resultados.map((x) => `${x.label}: ${x.detail}`).join('\n'), 'success');
  carregarDebloat();
});

// ---------------- Drivers ----------------

async function carregarDrivers() {
  showOverlay('Lendo drivers instalados...');
  const r = await window.mt.getDrivers();
  hideOverlay();
  if (!r.ok) { toast(r.detail || 'Falha ao listar drivers.', 'error'); return; }
  state.loaded.drivers = true;

  const corpoDrivers = document.querySelector('#table-drivers tbody');
  corpoDrivers.innerHTML = '';
  for (const d of r.drivers) {
    const tr = document.createElement('tr');
    const nome = d.contagem > 1 ? `${d.nome} (x${d.contagem})` : d.nome;
    for (const v of [d.classe, nome, d.versao, d.data, d.fornecedor]) {
      const td = document.createElement('td');
      td.textContent = v || '';
      tr.appendChild(td);
    }
    corpoDrivers.appendChild(tr);
  }

  const corpoProblemas = document.querySelector('#table-problemas tbody');
  corpoProblemas.innerHTML = '';
  for (const p of r.problemas) {
    const tr = document.createElement('tr');
    for (const v of [p.nome, p.classe, p.status]) {
      const td = document.createElement('td');
      td.textContent = v || '';
      tr.appendChild(td);
    }
    corpoProblemas.appendChild(tr);
  }
  if (!r.problemas.length) {
    const tr = document.createElement('tr');
    const td = document.createElement('td');
    td.colSpan = 3;
    td.textContent = 'Nenhum dispositivo com problema.';
    td.style.color = 'var(--text-dim)';
    tr.appendChild(td);
    corpoProblemas.appendChild(tr);
  }
}

document.getElementById('btn-drivers-refresh').addEventListener('click', carregarDrivers);

document.getElementById('btn-drivers-backup').addEventListener('click', async () => {
  if (!state.catalog || !state.catalog.isAdmin) {
    toast('Backup de drivers exige executar o MeuTweaker como administrador.', 'error');
    return;
  }
  const destino = await window.mt.chooseFolder();
  if (!destino) return;
  showOverlay('Exportando drivers...');
  const r = await window.mt.backupDrivers(destino);
  hideOverlay();
  if (r.ok) {
    toast(`Backup concluido: ${r.quantidade} driver(s) exportado(s) para ${r.destino}.`, 'success');
  } else {
    toast(`Falha no backup: ${r.detail}`, 'error');
  }
});

// ---------------- Desempenho ----------------

async function carregarPerfEstatico() {
  const r = await window.mt.getPerfStatic();
  if (!r.ok) return;
  state.loaded.desempenho = true;
  const e = r.info;
  document.getElementById('perf-static').textContent =
    `CPU: ${e.cpuNome}  (${e.nucleos} nucleos / ${e.logicos} logicos)\n` +
    `GPU: ${e.gpuNome || 'nao detectada'}\n` +
    `RAM: ${e.ramTotalGb} GB ${e.tipoRam || ''}`;
}

function metricaHtml(label, valorTexto, pct) {
  const barra = pct === null
    ? ''
    : `<div class="perf-bar"><div class="perf-bar-fill" style="width:${Math.min(100, Math.max(0, pct))}%"></div></div>`;
  return `<div class="perf-metric"><div class="perf-label">${label}</div><div class="perf-value">${valorTexto}</div>${barra}</div>`;
}

async function atualizarPerfLive() {
  const r = await window.mt.getPerfLive();
  if (!r.ok) return;
  const a = r.amostra;
  const ramGb = (a.ramDisponivelMb / 1024).toFixed(1);
  document.getElementById('perf-live').innerHTML =
    metricaHtml('CPU', `${a.cpuPct}%`, a.cpuPct) +
    metricaHtml('GPU', `${a.gpuPct}%`, a.gpuPct) +
    metricaHtml('Disco', `${a.discoPct}%`, a.discoPct) +
    metricaHtml('RAM livre', `${ramGb} GB`, null) +
    metricaHtml('Rede recebendo', `${a.redeRecebidoKb} KB/s`, null) +
    metricaHtml('Rede enviando', `${a.redeEnviadoKb} KB/s`, null);
}

function iniciarPerfLive() {
  if (state.perfTimer) return;
  atualizarPerfLive();
  state.perfTimer = setInterval(atualizarPerfLive, 1500);
}
function pararPerfLive() {
  if (!state.perfTimer) return;
  clearInterval(state.perfTimer);
  state.perfTimer = null;
}

// ---------------- Diagnostico ----------------

document.getElementById('btn-diagnostico-run').addEventListener('click', async () => {
  showOverlay('Rodando diagnostico...');
  const r = await window.mt.getDiagnostico();
  hideOverlay();
  if (!r.ok) { toast(r.detail || 'Falha no diagnostico.', 'error'); return; }
  const d = r.diagnostico;
  document.getElementById('diagnostico-percentual').textContent = `Potencial de otimizacao: ${d.potencial}%`;
  const lista = document.getElementById('diagnostico-achados');
  lista.innerHTML = '';
  if (d.achados.length) {
    for (const a of d.achados) lista.appendChild(el('li', null, a));
  } else {
    lista.appendChild(el('li', null, 'Nada relevante encontrado - maquina ja bem otimizada.'));
  }
});

// ---------------- boot ----------------

carregarCatalogo();
