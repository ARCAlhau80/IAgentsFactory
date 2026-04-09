const fs = require("fs");
const http = require("http");
const path = require("path");
const { spawn } = require("child_process");

const projectRoot = path.resolve(__dirname, "..", "..");
const publicDir = path.join(__dirname, "public");
const configPath = process.env.IAGENTSFACTORY_DASHBOARD_CONFIG_PATH || process.env.ISGT_FACTORY_DASHBOARD_CONFIG_PATH || path.join(projectRoot, "config", "dashboard-config.json");
const factoryDbPath = process.env.IAGENTSFACTORY_DB_PATH || process.env.ISGT_FACTORY_DB_PATH || path.join(process.env.USERPROFILE || process.env.HOME || ".", ".iagents-factory", "knowledge.db");
const mcpGraphPath = process.env.IAGENTSFACTORY_MCP_GRAPH_PATH || process.env.ISGT_FACTORY_MCP_GRAPH_PATH || "C:/Users/AR CALHAU/source/repos/mcp-graph-workflow";
const betterSqlite3Path = path.join(mcpGraphPath, "node_modules", "better-sqlite3");
const Database = require(betterSqlite3Path);

const config = JSON.parse(fs.readFileSync(configPath, "utf8").replace(/^\uFEFF/, ""));
const port = Number(process.env.IAGENTSFACTORY_DASHBOARD_PORT || process.env.ISGT_FACTORY_DASHBOARD_PORT || config.dashboard.port || 3010);
const newProjectScriptPath = path.join(projectRoot, "new-project.ps1");

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    request.on("data", (chunk) => {
      chunks.push(chunk);
      const totalSize = chunks.reduce((sum, current) => sum + current.length, 0);
      if (totalSize > 1024 * 1024) {
        reject(new Error("Payload muito grande."));
        request.destroy();
      }
    });
    request.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf8").trim();
        resolve(raw ? JSON.parse(raw) : {});
      } catch (error) {
        reject(new Error("JSON invalido no corpo da requisicao."));
      }
    });
    request.on("error", reject);
  });
}

function normalizeBootstrapField(value, fallback = "") {
  if (value === null || value === undefined) {
    return fallback;
  }

  return String(value).trim() || fallback;
}

function runBootstrapProject(payload) {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(newProjectScriptPath)) {
      reject(new Error(`Wizard nao encontrado em ${newProjectScriptPath}`));
      return;
    }

    const mode = normalizeBootstrapField(payload.projectMode, "new").toLowerCase() === "existing" ? "existing" : "new";
    const args = [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      newProjectScriptPath,
      "-Auto",
      "-ProjectMode",
      mode,
      "-ProjectName",
      normalizeBootstrapField(payload.projectName, "NewProject"),
      "-ProjectPath",
      normalizeBootstrapField(payload.projectPath, path.join(path.dirname(projectRoot), normalizeBootstrapField(payload.projectName, "NewProject"))),
      "-ProjectType",
      normalizeBootstrapField(payload.projectType, "microservice-api"),
      "-ProblemStatement",
      normalizeBootstrapField(payload.problemStatement, "Projeto bootstrapado a partir do dashboard da factory."),
      "-InputDescription",
      normalizeBootstrapField(payload.inputDescription, "JSON com parametros de entrada."),
      "-OutputDescription",
      normalizeBootstrapField(payload.outputDescription, "Resposta JSON com o resultado da operacao."),
      "-Constraints",
      normalizeBootstrapField(payload.constraints, "Simplicidade, observabilidade e reuso multiprojeto."),
      "-StackPreference",
      normalizeBootstrapField(payload.stackPreference, "aberto a sugestao"),
    ];

    if (payload.selectedStack) {
      args.push("-SelectedStack", normalizeBootstrapField(payload.selectedStack));
    }
    if (payload.autoSuggest !== false) {
      args.push("-AutoSuggest");
    }

    const child = spawn("powershell", args, {
      cwd: projectRoot,
      windowsHide: true,
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });

    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error((stderr || stdout || `Falha ao executar bootstrap. Exit code ${code}.`).trim()));
        return;
      }

      resolve({
        ok: true,
        code,
        stdout: stdout.trim(),
        stderr: stderr.trim(),
        projectPath: normalizeBootstrapField(payload.projectPath, path.join(path.dirname(projectRoot), normalizeBootstrapField(payload.projectName, "NewProject"))),
        projectName: normalizeBootstrapField(payload.projectName, "NewProject"),
      });
    });
  });
}

function openDatabase() {
  const database = new Database(factoryDbPath, { readonly: true });
  database.pragma("journal_mode = WAL");
  database.pragma("busy_timeout = 5000");
  return database;
}

function oneValue(database, query) {
  const row = database.prepare(query).get();
  if (!row) {
    return 0;
  }

  const firstKey = Object.keys(row)[0];
  return row[firstKey] ?? 0;
}

function many(database, query) {
  return database.prepare(query).all();
}

function sqlLiteral(value) {
  return String(value || "").replace(/'/g, "''");
}

function sqlEqualsIgnoreCase(columnName, value) {
  return `LOWER(TRIM(COALESCE(${columnName}, ''))) = LOWER(TRIM('${sqlLiteral(value)}'))`;
}

function normalizeFilter(value) {
  const normalized = normalizeText(value);
  return normalized || "";
}

function canonicalLanguage(value) {
  const normalized = normalizeText(value).toLowerCase();
  if (!normalized) {
    return "";
  }

  const map = {
    python: "Python",
    java: "Java",
    javascript: "JavaScript",
    typescript: "TypeScript",
    csharp: "C#",
    "c#": "C#",
  };

  return map[normalized] || normalizeText(value);
}

function buildLearnedSolutionsWhere(filters, includeDeprecated = false) {
  const clauses = [];
  if (!includeDeprecated) {
    clauses.push("is_deprecated = 0");
  }
  if (filters.project) {
    clauses.push(sqlEqualsIgnoreCase("source_project", filters.project));
  }
  if (filters.language) {
    clauses.push(sqlEqualsIgnoreCase("language", filters.language));
  }
  if (filters.domain) {
    clauses.push(sqlEqualsIgnoreCase("domain", filters.domain));
  }
  return clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : "";
}

function buildProjectsWhere(filters) {
  const clauses = ["is_active = 1"];
  if (filters.project) {
    clauses.push(sqlEqualsIgnoreCase("name", filters.project));
  }
  if (filters.language) {
    clauses.push(sqlEqualsIgnoreCase("language", filters.language));
  }
  return `WHERE ${clauses.join(" AND ")}`;
}

function listOptions(database, query, fieldName = "label", normalizeOption = (value) => normalizeText(value)) {
  return many(database, query)
    .map((row) => normalizeOption(row[fieldName]))
    .filter((value, index, array) => value && array.findIndex((candidate) => candidate.toLowerCase() === value.toLowerCase()) === index)
    .sort((left, right) => left.localeCompare(right, "pt-BR"));
}

function normalizeText(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value).replace(/\r?\n/g, " ").trim();
}

function getDashboardData(filters) {
  const database = openDatabase();
  try {
    const normalizedFilters = {
      project: normalizeFilter(filters.project),
      language: normalizeFilter(filters.language),
      domain: normalizeFilter(filters.domain),
    };
    const learnedWhere = buildLearnedSolutionsWhere(normalizedFilters);
    const learnedWhereWithDeprecated = buildLearnedSolutionsWhere(normalizedFilters, true);
    const projectsWhere = buildProjectsWhere(normalizedFilters);

    const summary = {
      solutions: Number(oneValue(database, `SELECT COUNT(*) AS value FROM learned_solutions ${learnedWhere}`)),
      projects: Number(oneValue(database, `SELECT COUNT(*) AS value FROM factory_projects ${projectsWhere}`)),
      reuses: Number(oneValue(database, `SELECT COALESCE(SUM(usage_count), 0) AS value FROM learned_solutions ${learnedWhereWithDeprecated}`)),
      tokensUsed: Number(oneValue(database, `SELECT COALESCE(SUM(tokens_input + tokens_output), 0) AS value FROM learned_solutions ${learnedWhereWithDeprecated}`)),
      tokensSaved: Number(oneValue(database, `SELECT COALESCE(SUM(tokens_saved), 0) AS value FROM learned_solutions ${learnedWhereWithDeprecated}`)),
      avgQuality: Number(oneValue(database, `SELECT ROUND(COALESCE(AVG(quality_score), 0), 2) AS value FROM learned_solutions ${learnedWhere}`)),
    };

    summary.costSaved = Number((summary.tokensSaved / 1000000 * 3).toFixed(2));

    const domains = many(database, `SELECT domain AS label, COUNT(*) AS value FROM learned_solutions ${learnedWhere} GROUP BY domain ORDER BY value DESC, label ASC LIMIT 8`);
    const agents = many(database, `SELECT CASE WHEN source_agent = '' THEN 'unknown' ELSE source_agent END AS label, COUNT(*) AS value FROM learned_solutions ${learnedWhere} GROUP BY label ORDER BY value DESC, label ASC LIMIT 8`);
    const quality = many(database, `SELECT printf('%.1f', CAST(quality_score * 10 AS INTEGER) / 10.0) AS label, COUNT(*) AS value FROM learned_solutions ${learnedWhere} GROUP BY label ORDER BY label ASC`);
    const timeline = many(database, `SELECT strftime('%Y-%m', created_at) AS label, COUNT(*) AS captures, COALESCE(SUM(tokens_output), 0) AS tokens FROM learned_solutions ${learnedWhereWithDeprecated} GROUP BY label ORDER BY label DESC LIMIT 12`).reverse();

    const topSolutions = many(database, `SELECT domain, pattern, language, source_project, usage_count, quality_score, solution_summary FROM learned_solutions ${learnedWhere} ORDER BY usage_count DESC, quality_score DESC, created_at DESC LIMIT 10`)
      .map((row) => ({
        domain: normalizeText(row.domain),
        pattern: normalizeText(row.pattern),
        language: canonicalLanguage(row.language),
        sourceProject: normalizeText(row.source_project),
        usageCount: Number(row.usage_count || 0),
        qualityScore: Number(Number(row.quality_score || 0).toFixed(2)),
        summary: normalizeText(row.solution_summary),
      }));

    const recentCaptures = many(database, `SELECT domain, pattern, language, source_project, source_agent, quality_score, created_at, solution_summary FROM learned_solutions ${learnedWhereWithDeprecated} ORDER BY created_at DESC LIMIT 10`)
      .map((row) => ({
        domain: normalizeText(row.domain),
        pattern: normalizeText(row.pattern),
        language: canonicalLanguage(row.language),
        sourceProject: normalizeText(row.source_project),
        agent: normalizeText(row.source_agent) || "unknown",
        qualityScore: Number(Number(row.quality_score || 0).toFixed(2)),
        createdAt: normalizeText(row.created_at),
        summary: normalizeText(row.solution_summary),
      }));

    const projects = many(database, `SELECT name, language, framework, total_solutions_used, total_tokens_saved, last_active_at FROM factory_projects ${projectsWhere} ORDER BY last_active_at DESC, name ASC`)
      .map((row) => ({
        name: normalizeText(row.name),
        language: canonicalLanguage(row.language),
        framework: normalizeText(row.framework),
        totalSolutionsUsed: Number(row.total_solutions_used || 0),
        totalTokensSaved: Number(row.total_tokens_saved || 0),
        lastActiveAt: normalizeText(row.last_active_at),
      }));

    const filterOptions = {
      projects: listOptions(database, "SELECT name AS label FROM factory_projects WHERE is_active = 1 UNION SELECT source_project AS label FROM learned_solutions WHERE source_project != ''"),
      languages: listOptions(database, "SELECT language AS label FROM factory_projects WHERE is_active = 1 AND language != '' UNION SELECT language AS label FROM learned_solutions WHERE language != ''", "label", canonicalLanguage),
      domains: listOptions(database, "SELECT domain AS label FROM learned_solutions WHERE domain != ''", "label", (value) => normalizeText(value).toLowerCase()),
    };

    const alerts = [];
    for (const alert of config.alerts || []) {
      try {
        const value = Number(oneValue(database, alert.condition));
        if (value >= Number(alert.threshold || 0)) {
          alerts.push({
            id: alert.id,
            value,
            threshold: Number(alert.threshold || 0),
            message: String(alert.message || "").replace("{value}", String(value)),
          });
        }
      } catch (error) {
        console.warn(`[WARN] Skipping alert ${alert.id}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    return {
      generatedAt: new Date().toISOString(),
      title: config.dashboard.title,
      refreshInterval: Number(config.dashboard.refreshInterval || 30000),
      appliedFilters: normalizedFilters,
      filterOptions,
      summary,
      domains,
      agents,
      quality,
      timeline,
      topSolutions,
      recentCaptures,
      projects,
      alerts,
    };
  } finally {
    database.close();
  }
}

function contentType(filePath) {
  if (filePath.endsWith(".html")) {
    return "text/html; charset=utf-8";
  }
  if (filePath.endsWith(".css")) {
    return "text/css; charset=utf-8";
  }
  if (filePath.endsWith(".js")) {
    return "application/javascript; charset=utf-8";
  }
  if (filePath.endsWith(".json")) {
    return "application/json; charset=utf-8";
  }
  return "text/plain; charset=utf-8";
}

const server = http.createServer((request, response) => {
  const parsedUrl = new URL(request.url || "/", `http://${request.headers.host || `localhost:${port}`}`);
  const pathname = parsedUrl.pathname || "/";

  if (pathname === "/health") {
    response.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ ok: true, server: "iagentsfactory-dashboard", dbPath: factoryDbPath }));
    return;
  }

  if (pathname === "/api/dashboard") {
    try {
      const payload = getDashboardData(Object.fromEntries(parsedUrl.searchParams.entries()));
      response.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
      response.end(JSON.stringify(payload));
    } catch (error) {
      response.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
      response.end(JSON.stringify({ ok: false, error: error instanceof Error ? error.message : String(error) }));
    }
    return;
  }

  if (pathname === "/api/projects/bootstrap" && request.method === "POST") {
    readJsonBody(request)
      .then((payload) => runBootstrapProject(payload))
      .then((result) => {
        response.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
        response.end(JSON.stringify(result));
      })
      .catch((error) => {
        response.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
        response.end(JSON.stringify({ ok: false, error: error instanceof Error ? error.message : String(error) }));
      });
    return;
  }

  const filePath = pathname === "/"
    ? path.join(publicDir, "index.html")
    : path.join(publicDir, pathname.replace(/^\//, ""));

  if (!filePath.startsWith(publicDir) || !fs.existsSync(filePath)) {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not found");
    return;
  }

  response.writeHead(200, { "Content-Type": contentType(filePath) });
  response.end(fs.readFileSync(filePath));
});

server.listen(port, () => {
  console.log(`[INFO] IAgentsFactory dashboard listening on http://localhost:${port}`);
  console.log(`[INFO] Knowledge DB: ${factoryDbPath}`);
});

