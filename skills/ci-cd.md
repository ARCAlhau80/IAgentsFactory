# 🐳 SKILL: CI/CD & Containerization

**Propósito:** Automatizar build, test, deploy com qualidade  
**Aplicabilidade:** Qualquer projeto que vai para produção  
**Esforço:** 1-3 dias para pipeline básico

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Configurando pipeline de CI/CD
- Dockerizando aplicação
- Automatizando testes no merge
- Configurando deploy automático

---

## 🎯 Pipeline Mínimo

```
┌─────────┐    ┌──────────┐    ┌─────────┐    ┌──────────┐
│  COMMIT  │───▶│  BUILD   │───▶│  TEST   │───▶│  DEPLOY  │
└─────────┘    └──────────┘    └─────────┘    └──────────┘
    │              │               │               │
    │          Compila          Unit tests      Staging/
    │          Lint             Integration     Production
    │          Security scan   Coverage check
    │
  Push/PR trigger
```

---

## 📐 GitHub Actions (Template)

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      # ─── Setup (adaptar para sua stack) ─────
      
      # Java:
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
      
      # Node.js:
      # - uses: actions/setup-node@v4
      #   with:
      #     node-version: '20'
      
      # Python:
      # - uses: actions/setup-python@v5
      #   with:
      #     python-version: '3.12'
      
      # ─── Build ──────────────────────────────
      
      - name: Build
        run: [BUILD_CMD]      # ./mvnw clean compile | npm ci | pip install -r requirements.txt
      
      # ─── Test ───────────────────────────────
      
      - name: Run Tests
        run: [TEST_CMD]       # ./mvnw test | npm test | pytest
      
      # ─── Coverage ──────────────────────────
      
      - name: Check Coverage
        run: [COVERAGE_CMD]   # ./mvnw jacoco:report | npx jest --coverage | pytest --cov
      
      # ─── Lint ───────────────────────────────
      
      - name: Lint
        run: [LINT_CMD]       # ./mvnw checkstyle:check | npm run lint | flake8
```

---

## 🐳 Dockerfile (Template Multi-Stage)

### Java

```dockerfile
# Build stage
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY pom.xml mvnw ./
COPY .mvn .mvn
RUN ./mvnw dependency:resolve
COPY src src
RUN ./mvnw package -DskipTests

# Run stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Node.js

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

### Python

```dockerfile
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

FROM python:3.12-slim
WORKDIR /app
COPY --from=build /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=build /app .
RUN adduser --system app
USER app
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 🔒 Docker Security

```
✅ OBRIGATÓRIO:
- Usar imagem slim/alpine (menor superfície de ataque)
- Multi-stage build (não deixar build tools na imagem final)
- Non-root user (USER app, nunca rodar como root)
- .dockerignore (não copiar .git, node_modules, .env)
- Imagens com tag específica (não usar :latest em produção)

❌ NUNCA:
- Rodar como root
- Copiar .env / secrets para a imagem
- Usar :latest (não é reproduzível)
- Instalar ferramentas desnecessárias na imagem final
```

---

## 📄 .dockerignore (Template)

```
.git
.github
.env
.env.*
node_modules
target
__pycache__
*.pyc
.pytest_cache
coverage
.idea
.vscode
*.md
!README.md
docker-compose*.yml
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| Build sem cache | CI demora 15min+ | Cache de dependências (actions/cache) |
| Testes instáveis (flaky) | Pipeline falha aleatoriamente | Isoler testes, usar TestContainers |
| Sem multi-stage | Imagem Docker de 1GB+ | Multi-stage: build + runtime separados |
| Secrets no Dockerfile | Credenciais expostas | Usar build args ou runtime env vars |
| Deploy sem tag | "Qual versão está em produção?" | Tag com git SHA ou semver |
