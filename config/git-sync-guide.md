# IAgentsFactory — Team Knowledge Sync via Git
#
# Estratégia: exportar knowledge como JSON shareable via Git,
# sem expor o banco SQLite binário.
#
# WORKFLOW:
#   1. Dev A: .\iagents-factory.ps1 export             → cria JSON
#   2. Dev A: git add .iagents-factory/exports/ && git commit && git push
#   3. Dev B: git pull
#   4. Dev B: .\iagents-factory.ps1 import .iagents-factory/exports/knowledge-export-*.json
#   5. Dedup automático via content_hash
#
# AUTOMAÇÃO: 
#   Adicione hooks ao .git/hooks/post-merge ou use Git Actions

# ===============================================================
# Git Hook: post-merge (auto-import após pull)
# ===============================================================
# Salve como: .git/hooks/post-merge (chmod +x)
# ---------------------------------------------------------------
# #!/bin/sh
# echo "[IAgentsFactory] Verificando knowledge exports..."
# EXPORTS=$(git diff --name-only ORIG_HEAD..HEAD -- '.iagents-factory/exports/*.json')
# if [ -n "$EXPORTS" ]; then
#   echo "[IAgentsFactory] Novos exports encontrados, importando..."
#   for f in $EXPORTS; do
#     powershell -NoProfile -File iagents-factory.ps1 import "$f"
#   done
# fi
# ---------------------------------------------------------------

# ===============================================================
# Git Hook: pre-push (auto-export antes de push)
# ===============================================================
# Salve como: .git/hooks/pre-push (chmod +x)
# ---------------------------------------------------------------
# #!/bin/sh
# echo "[IAgentsFactory] Exportando knowledge antes do push..."
# powershell -NoProfile -File iagents-factory.ps1 export
# git add .iagents-factory/exports/ 2>/dev/null
# STAGED=$(git diff --cached --name-only -- '.iagents-factory/exports/')
# if [ -n "$STAGED" ]; then
#   git commit -m "chore: auto-export IAgentsFactory knowledge" --no-verify
# fi
# ---------------------------------------------------------------

