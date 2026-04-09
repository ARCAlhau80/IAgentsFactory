const currencyFormatter = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "USD" });
const numberFormatter = new Intl.NumberFormat("pt-BR");
const dashboardState = {
  filters: {
    project: "",
    language: "",
    domain: "",
  },
  bootstrapBusy: false,
};

function serializeForm(form) {
  const formData = new FormData(form);
  return {
    projectMode: formData.get("projectMode") || "new",
    projectType: formData.get("projectType") || "microservice-api",
    projectName: formData.get("projectName") || "",
    projectPath: formData.get("projectPath") || "",
    problemStatement: formData.get("problemStatement") || "",
    inputDescription: formData.get("inputDescription") || "",
    outputDescription: formData.get("outputDescription") || "",
    constraints: formData.get("constraints") || "",
    stackPreference: formData.get("stackPreference") || "aberto a sugestao",
    selectedStack: formData.get("selectedStack") || "",
    autoSuggest: formData.get("autoSuggest") === "on",
  };
}

function setBootstrapBusy(isBusy) {
  dashboardState.bootstrapBusy = isBusy;
  const submitButton = document.getElementById("submit-bootstrap");
  if (submitButton) {
    submitButton.disabled = isBusy;
    submitButton.textContent = isBusy ? "Criando projeto..." : "Criar e Registrar Projeto";
  }
}

function showBootstrapStatus(message, details = "", isError = false) {
  const target = document.getElementById("bootstrap-status");
  const safeMessage = escapeHtml(message);
  const safeDetails = details ? `<pre>${escapeHtml(details)}</pre>` : "";
  target.innerHTML = `
    <article class="bootstrap-status-card">
      <strong>${isError ? "Falha no bootstrap" : "Bootstrap executado"}</strong>
      <div>${safeMessage}</div>
      ${safeDetails}
    </article>
  `;
}

function openBootstrapModal() {
  document.getElementById("bootstrap-modal").classList.remove("hidden");
}

function closeBootstrapModal() {
  document.getElementById("bootstrap-modal").classList.add("hidden");
}

async function submitBootstrapForm(event) {
  event.preventDefault();
  if (dashboardState.bootstrapBusy) {
    return;
  }

  const form = event.currentTarget;
  const payload = serializeForm(form);
  setBootstrapBusy(true);
  showBootstrapStatus("Bootstrap em andamento. A factory esta criando o projeto, aplicando o kit e gerando o SPEC inicial.");

  try {
    const response = await fetch("/api/projects/bootstrap", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify(payload),
    });
    const result = await response.json();
    if (!response.ok) {
      throw new Error(result.error || "Falha ao executar o bootstrap do projeto.");
    }

    showBootstrapStatus(`Projeto ${result.projectName} bootstrapado com sucesso em ${result.projectPath}.`, result.stdout || "");
    closeBootstrapModal();
    await loadDashboard();
  } catch (error) {
    showBootstrapStatus(error.message, "Verifique os campos informados e tente novamente.", true);
  } finally {
    setBootstrapBusy(false);
  }
}

function initializeBootstrapUi() {
  const openButton = document.getElementById("open-bootstrap-modal");
  const closeButton = document.getElementById("close-bootstrap-modal");
  const cancelButton = document.getElementById("cancel-bootstrap");
  const modal = document.getElementById("bootstrap-modal");
  const form = document.getElementById("bootstrap-form");
  const projectNameInput = form.querySelector('input[name="projectName"]');
  const projectPathInput = form.querySelector('input[name="projectPath"]');
  const defaultBasePath = "C:\\Users\\AR CALHAU\\source\\repos\\";

  openButton.addEventListener("click", openBootstrapModal);
  closeButton.addEventListener("click", closeBootstrapModal);
  cancelButton.addEventListener("click", closeBootstrapModal);
  modal.querySelector("[data-close-modal='true']").addEventListener("click", closeBootstrapModal);
  form.addEventListener("submit", submitBootstrapForm);

  projectNameInput.addEventListener("input", () => {
    if (!projectPathInput.dataset.touched) {
      projectPathInput.value = `${defaultBasePath}${projectNameInput.value.trim()}`;
    }
  });

  projectPathInput.addEventListener("input", () => {
    projectPathInput.dataset.touched = "true";
  });
}

function buildHeroChips(payload) {
  const chips = [];
  const appliedFilters = payload.appliedFilters || dashboardState.filters;

  if (appliedFilters.project) {
    chips.push(`Projeto: ${escapeHtml(appliedFilters.project)}`);
  }
  if (appliedFilters.language) {
    chips.push(`Linguagem: ${escapeHtml(appliedFilters.language)}`);
  }
  if (appliedFilters.domain) {
    chips.push(`Dominio: ${escapeHtml(appliedFilters.domain)}`);
  }
  if (chips.length === 0) {
    chips.push("Portfolio completo");
    chips.push("Acervo compartilhado");
    chips.push("Leitura local-first");
  }

  document.getElementById("hero-chips").innerHTML = chips
    .map((chip) => `<span class="hero-chip">${chip}</span>`)
    .join("");
}

function renderSnapshotRail(payload) {
  const target = document.getElementById("snapshot-rail");
  const summary = payload.summary || {};
  const dominantDomain = payload.domains?.[0]?.label || "Sem dominio dominante";
  const dominantAgent = payload.agents?.[0]?.label || "Sem agente dominante";
  const latestMonth = payload.timeline?.[0]?.label || "Sem historico";
  const activeProject = payload.appliedFilters?.project || (payload.projects?.[0]?.name ?? "Portfolio completo");

  const items = [
    {
      label: "Foco operacional",
      value: activeProject,
      detail: summary.projects > 1 ? `${numberFormatter.format(summary.projects)} projetos ativos na carteira da factory.` : "Projeto em destaque no recorte atual."
    },
    {
      label: "Dominio mais forte",
      value: dominantDomain,
      detail: "Area onde o acervo tem maior densidade de conhecimento reutilizavel."
    },
    {
      label: "Canal de captura",
      value: dominantAgent,
      detail: "Origem predominante do conhecimento consolidado na base."
    },
    {
      label: "Pulso recente",
      value: latestMonth,
      detail: `${numberFormatter.format(summary.solutions || 0)} solucoes acumuladas com qualidade media ${Number(summary.avgQuality || 0).toFixed(2)}.`
    }
  ];

  target.innerHTML = items.map((item) => `
    <article class="snapshot-card">
      <span class="snapshot-label">${item.label}</span>
      <strong class="snapshot-value">${escapeHtml(item.value)}</strong>
      <p class="snapshot-detail">${escapeHtml(item.detail)}</p>
    </article>
  `).join("");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function metricValue(key, value) {
  if (key === "costSaved") {
    return currencyFormatter.format(Number(value || 0));
  }
  if (key === "avgQuality") {
    return Number(value || 0).toFixed(2);
  }
  return numberFormatter.format(Number(value || 0));
}

function renderKpis(summary) {
  const entries = [
    ["solutions", "Solucoes armazenadas"],
    ["projects", "Projetos ativos"],
    ["reuses", "Reusos totais"],
    ["tokensUsed", "Tokens consumidos"],
    ["tokensSaved", "Tokens economizados"],
    ["costSaved", "Custo evitado"],
    ["avgQuality", "Qualidade media"],
  ];

  document.getElementById("kpis").innerHTML = entries.map(([key, label]) => `
    <article class="kpi-card">
      <p class="kpi-title">${label}</p>
      <div class="kpi-value">${metricValue(key, summary[key])}</div>
    </article>
  `).join("");
}

function renderBars(targetId, rows, valueKey = "value") {
  const target = document.getElementById(targetId);
  if (!rows || rows.length === 0) {
    target.innerHTML = '<div class="empty-state">Sem dados suficientes ainda.</div>';
    return;
  }

  const maxValue = Math.max(...rows.map((row) => Number(row[valueKey] || row.value || 0)), 1);
  target.innerHTML = rows.map((row) => {
    const numericValue = Number(row[valueKey] || row.value || 0);
    const width = Math.max(8, (numericValue / maxValue) * 100);
    return `
      <div class="bar-row">
        <span class="bar-label">${row.label}</span>
        <div class="bar-track"><div class="bar-fill" style="width:${width}%"></div></div>
        <span class="bar-value">${numberFormatter.format(numericValue)}</span>
      </div>
    `;
  }).join("");
}

function createTable(headers, rows, mapper) {
  if (!rows || rows.length === 0) {
    return '<div class="empty-state">Sem registros para exibir.</div>';
  }

  const thead = `<tr>${headers.map((header) => `<th>${header}</th>`).join("")}</tr>`;
  const tbody = rows.map((row) => `<tr>${mapper(row).map((cell) => `<td>${cell}</td>`).join("")}</tr>`).join("");
  return `<table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>`;
}

function renderAlerts(alerts) {
  const target = document.getElementById("alerts");
  if (!alerts || alerts.length === 0) {
    target.innerHTML = "";
    return;
  }

  target.innerHTML = alerts.map((alert) => `
    <div class="alert">
      <strong>Alerta ${alert.id}</strong>
      <div>${alert.message}</div>
    </div>
  `).join("");
}

function renderTables(payload) {
  document.getElementById("top-solutions").innerHTML = createTable(
    ["Projeto", "Dominio", "Pattern", "Lang", "Usos", "Qualidade", "Resumo"],
    payload.topSolutions,
    (row) => [row.sourceProject || "-", row.domain, row.pattern, row.language || "-", numberFormatter.format(row.usageCount), row.qualityScore.toFixed(2), row.summary || "-"]
  );

  document.getElementById("recent-captures").innerHTML = createTable(
    ["Projeto", "Dominio", "Pattern", "Lang", "Agente", "Qualidade", "Data", "Resumo"],
    payload.recentCaptures,
    (row) => [row.sourceProject || "-", row.domain, row.pattern, row.language || "-", row.agent || "-", row.qualityScore.toFixed(2), row.createdAt || "-", row.summary || "-"]
  );

  document.getElementById("projects").innerHTML = createTable(
    ["Projeto", "Lang", "Framework", "Solucoes usadas", "Tokens salvos", "Ultimo uso"],
    payload.projects,
    (row) => [row.name, row.language || "-", row.framework || "-", numberFormatter.format(row.totalSolutionsUsed), numberFormatter.format(row.totalTokensSaved), row.lastActiveAt || "-"]
  );
}

function createOptions(options, selectedValue) {
  return ['<option value="">Todos</option>'].concat(
    (options || []).map((option) => {
      const selected = option === selectedValue ? ' selected' : '';
      return `<option value="${escapeHtml(option)}"${selected}>${escapeHtml(option)}</option>`;
    })
  ).join("");
}

function renderFilters(payload) {
  const target = document.getElementById("filters");
  const filters = payload.appliedFilters || dashboardState.filters;
  dashboardState.filters = { ...dashboardState.filters, ...filters };

  target.innerHTML = `
    <div class="filters-head">
      <div>
        <p class="eyebrow">Recorte</p>
        <h2>Filtros do acervo</h2>
      </div>
      <button id="clear-filters" class="ghost-button" type="button">Limpar filtros</button>
    </div>
    <div class="filter-grid">
      <label class="filter-field">
        <span>Projeto</span>
        <select id="filter-project">${createOptions(payload.filterOptions?.projects, filters.project)}</select>
      </label>
      <label class="filter-field">
        <span>Linguagem</span>
        <select id="filter-language">${createOptions(payload.filterOptions?.languages, filters.language)}</select>
      </label>
      <label class="filter-field">
        <span>Dominio</span>
        <select id="filter-domain">${createOptions(payload.filterOptions?.domains, filters.domain)}</select>
      </label>
    </div>
  `;

  document.getElementById("filter-project").addEventListener("change", onFilterChange);
  document.getElementById("filter-language").addEventListener("change", onFilterChange);
  document.getElementById("filter-domain").addEventListener("change", onFilterChange);
  document.getElementById("clear-filters").addEventListener("click", () => {
    dashboardState.filters = { project: "", language: "", domain: "" };
    loadDashboard().catch((error) => console.error(error));
  });
}

function onFilterChange() {
  dashboardState.filters = {
    project: document.getElementById("filter-project").value,
    language: document.getElementById("filter-language").value,
    domain: document.getElementById("filter-domain").value,
  };
  loadDashboard().catch((error) => console.error(error));
}

async function loadDashboard() {
  const params = new URLSearchParams();
  Object.entries(dashboardState.filters).forEach(([key, value]) => {
    if (value) {
      params.set(key, value);
    }
  });

  const query = params.toString();
  const response = await fetch(`/api/dashboard${query ? `?${query}` : ""}`, { cache: "no-store" });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.error || "Falha ao carregar dashboard");
  }

  document.getElementById("generated-at").textContent = new Date(payload.generatedAt).toLocaleString("pt-BR");
  document.getElementById("refresh-interval").textContent = `${Math.round(payload.refreshInterval / 1000)} s`;

  buildHeroChips(payload);
  renderSnapshotRail(payload);
  renderFilters(payload);
  renderAlerts(payload.alerts);
  renderKpis(payload.summary);
  renderBars("domains", payload.domains);
  renderBars("agents", payload.agents);
  renderBars("quality", payload.quality);
  renderBars("timeline", payload.timeline, "captures");
  renderTables(payload);

  return payload.refreshInterval;
}

async function main() {
  try {
    initializeBootstrapUi();
    const refreshInterval = await loadDashboard();
    window.setInterval(() => {
      loadDashboard().catch((error) => console.error(error));
    }, refreshInterval);
  } catch (error) {
    document.getElementById("kpis").innerHTML = `<div class="empty-state">${error.message}</div>`;
  }
}

main();
