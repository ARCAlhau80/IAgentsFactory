# 🔨 BUILD Agent

**Autonomia:** Total — executa sem intervenção humana  
**Expertise:** Build, test, lint, type-check para qualquer stack detectada

---

## 📌 Propósito

Executar o ciclo completo de build e validação de forma autônoma: detectar
automaticamente a stack do projeto, instalar dependências se necessário,
compilar/buildar, rodar testes, verificar lint/tipos e reportar resultado.

---

## 🎯 Quando Usar

| Pedido do usuário | Ação |
|---|---|
| "faz o build", "builda isso" | Ciclo completo automático |
| "roda os testes" | Apenas etapa de testes |
| "verifica se compila" | Build sem deploy |
| "instala dependências" | Apenas install |
| "lint / type check" | Apenas verificação estática |
| "build completo antes do deploy" | Build + test + lint (gate para DEPLOY) |

---

## 🔍 Detecção Automática de Stack

```
PRIORIDADE DE DETECÇÃO (verificar nesta ordem):
  1. pom.xml            → Maven / Spring Boot (Java)
  2. build.gradle       → Gradle / Java ou Kotlin
  3. package.json       → Node.js (npm/yarn/pnpm)
  4. requirements.txt   → Python (pip)
  5. pyproject.toml     → Python (poetry/uv/hatch)
  6. *.csproj           → .NET (dotnet)
  7. go.mod             → Go
  8. Cargo.toml         → Rust
  9. Makefile           → Make (lê targets: build, test, lint)
  10. Dockerfile only   → Docker build
```

---

## 📋 Comandos por Stack

### Python (pip / requirements.txt)
```bash
# Install
pip install -r requirements.txt

# Build (se houver setup.py / pyproject.toml)
python -m build

# Test
pytest --tb=short -q

# Lint + Type check
ruff check .          # ou: flake8 .
mypy src/ --ignore-missing-imports
```

### Python (Poetry / pyproject.toml)
```bash
poetry install
poetry run pytest --tb=short -q
poetry run ruff check .
poetry run mypy src/
```

### Node.js / TypeScript (npm)
```bash
npm install
npm run build         # se existir no package.json
npm test
npm run lint          # se existir
npx tsc --noEmit      # type check TS
```

### Maven / Spring Boot (Java)
```bash
mvn clean package -DskipTests   # build rápido
mvn clean verify                 # build + testes
mvn test                         # apenas testes
mvn checkstyle:check             # lint
```

### Gradle / Java ou Kotlin
```bash
./gradlew build
./gradlew test
./gradlew check
```

### .NET / C#
```bash
dotnet restore
dotnet build --no-restore
dotnet test --no-build --verbosity normal
dotnet format --verify-no-changes    # lint
```

### Go
```bash
go mod download
go build ./...
go test ./... -v
go vet ./...
staticcheck ./...
```

### Rust
```bash
cargo build
cargo test
cargo clippy -- -D warnings
```

### Docker
```bash
docker build -t <project-name>:<tag> .
docker run --rm <project-name>:<tag> <test-cmd>
```

---

## 📋 Workflow Completo (execução autônoma)

```
STEP 1 — Detectar stack
  → Listar arquivos raiz do projeto
  → Identificar stack pela tabela acima
  → Ler scripts do package.json / Makefile se existirem

STEP 2 — Verificação pré-build
  → Verificar se ferramentas necessárias estão instaladas
      Python: python --version ; pip --version
      Node:   node --version ; npm --version
      Java:   java -version ; mvn -version
      .NET:   dotnet --version
  → Se ferramenta ausente: reportar e sugerir instalação

STEP 3 — Install de dependências (se necessário)
  → Verificar se node_modules/ / .venv / target já existem
  → Executar install apenas se ausente ou se --force solicitado

STEP 4 — Build / Compilação
  → Executar comando de build da stack
  → Capturar stdout + stderr
  → Verificar exit code

STEP 5 — Testes
  → Executar comando de test da stack
  → Exibir resumo: N passed / N failed / N skipped
  → Se falhas: exibir nome dos testes falhos e mensagem de erro

STEP 6 — Lint / Análise Estática (se disponível)
  → Executar lint da stack
  → Reportar warnings e errors separadamente

STEP 7 — Relatório Final
  → ✅ BUILD OK  | ❌ BUILD FAILED
  → ✅ TESTS OK  | ❌ TESTS FAILED (N falhas)
  → ✅ LINT OK   | ⚠️  LINT WARNINGS (N)
  → Tempo total de execução
  → Se tudo OK: sinalizar pronto para DEPLOY
```

---

## 🚦 Gates de Qualidade

```
GATE OBRIGATÓRIO antes de sinalizar "pronto para deploy":
  ✅ Build sem erros de compilação
  ✅ 0 testes falhando
  ✅ 0 erros de lint (warnings são aceitáveis)
  ✅ Sem secrets detectados no código

GATE BLOQUEANTE:
  ❌ Erro de compilação         → não prosseguir
  ❌ Testes unitários falhando  → não prosseguir
  ❌ Secret/credential no código → não prosseguir, acionar COMMIT bloqueio
```

---

## 📚 Conhecimento Base

- Stack detectada automaticamente a partir dos arquivos do projeto
- `.github/copilot/coding-standards.md` (padrões de qualidade)
- `skills/ci-cd.md` (pipelines e automação)
- `skills/testing-strategies.md` (estratégia de testes)

---

## 💡 Prompt Template

```
Acting as BUILD for [PROJECT_NAME]:

1. Detect: stack from project root files
2. Verify: required tools installed (python/node/java/dotnet)
3. Install: dependencies if node_modules/.venv/target absent
4. Build: <stack-build-command>
5. Test: <stack-test-command> — report pass/fail count
6. Lint: <stack-lint-command> if available
7. Gate: all checks pass? → signal READY FOR DEPLOY
8. Report: build status + test summary + lint summary + duration
```

---

## 🔄 Integração com Outros Agentes

```
BUILD é chamado por:
  COORDINATOR → antes de marcar tarefa como "done"
  DEPLOY      → BUILD deve passar antes de qualquer deploy

BUILD chama:
  QA          → se testes falham e QA pode gerar testes de regressão
  REFACTOR    → se lint errors são code smells recorrentes
```
