# 🔍 PATTERN: Visitor Pattern

**Quando usar:** Percorrer estruturas complexas (árvores de arquivos, grafos, ASTs) aplicando operações  
**Componente:** Visitor, Element, FileWalker  
**Aplicabilidade:** Java, TypeScript, Python, C#

---

## 🎯 Conceito

```
O Visitor permite adicionar NOVAS OPERAÇÕES a uma estrutura de objetos
SEM modificar as classes dos objetos.

Estrutura (Element)  ──aceita──▶  Visitor (Opera sobre Element)
    │                                  │
    ├─ File                            ├─ CountVisitor (conta arquivos)
    ├─ Directory                       ├─ SizeVisitor (calcula tamanho)
    └─ SymLink                         └─ SearchVisitor (busca padrão)
    
REGRA: Novos visitors = novas operações SEM alterar File, Directory, etc.
```

---

## 📐 Quando Usar vs Quando NÃO Usar

```
✅ USE quando:
- Estrutura de objetos é ESTÁVEL (poucos tipos novos)
- Precisa adicionar MUITAS operações diferentes
- Operações variam independentemente dos tipos
- File system traversal, AST processing, XML/JSON walking

❌ NÃO use quando:
- Estrutura muda frequentemente (novo tipo = alterar todos visitors)
- Apenas 1-2 operações (overhead desnecessário)
- Objetos simples sem hierarquia
```

---

## 🏗️ Template (Java)

```java
// 1. Element — aceita visitors
public interface FileElement {
    void accept(FileVisitor visitor);
}

public class FileNode implements FileElement {
    private final String name;
    private final long size;
    private final Path path;

    @Override
    public void accept(FileVisitor visitor) {
        visitor.visit(this);
    }
    // getters...
}

public class DirectoryNode implements FileElement {
    private final String name;
    private final List<FileElement> children;

    @Override
    public void accept(FileVisitor visitor) {
        visitor.visitDirectory(this);
        for (FileElement child : children) {
            child.accept(visitor);  // recursive traversal
        }
    }
}

// 2. Visitor — define operações
public interface FileVisitor {
    void visit(FileNode file);
    void visitDirectory(DirectoryNode directory);
}

// 3. Implementações concretas
public class FileSizeVisitor implements FileVisitor {
    private long totalSize = 0;

    @Override
    public void visit(FileNode file) {
        totalSize += file.getSize();
    }

    @Override
    public void visitDirectory(DirectoryNode directory) {
        // directory itself has no size, children are visited recursively
    }

    public long getTotalSize() { return totalSize; }
}

public class FileSearchVisitor implements FileVisitor {
    private final String pattern;
    private final List<FileNode> matches = new ArrayList<>();

    public FileSearchVisitor(String pattern) {
        this.pattern = pattern;
    }

    @Override
    public void visit(FileNode file) {
        if (file.getName().matches(pattern)) {
            matches.add(file);
        }
    }

    @Override
    public void visitDirectory(DirectoryNode directory) { }

    public List<FileNode> getMatches() { return matches; }
}

// 4. Uso
DirectoryNode root = buildTree("/data");
FileSizeVisitor sizeVisitor = new FileSizeVisitor();
root.accept(sizeVisitor);
System.out.println("Total: " + sizeVisitor.getTotalSize() + " bytes");
```

---

## 🏗️ Template (TypeScript)

```typescript
// Element
interface FileElement {
  accept(visitor: FileVisitor): void;
}

class FileNode implements FileElement {
  constructor(public name: string, public size: number) {}
  accept(visitor: FileVisitor) { visitor.visitFile(this); }
}

class DirectoryNode implements FileElement {
  constructor(public name: string, public children: FileElement[]) {}
  accept(visitor: FileVisitor) {
    visitor.visitDirectory(this);
    this.children.forEach(child => child.accept(visitor));
  }
}

// Visitor
interface FileVisitor {
  visitFile(file: FileNode): void;
  visitDirectory(dir: DirectoryNode): void;
}

// Implementation
class FileSizeVisitor implements FileVisitor {
  totalSize = 0;
  visitFile(file: FileNode) { this.totalSize += file.size; }
  visitDirectory(dir: DirectoryNode) { /* children visited recursively */ }
}
```

---

## 🏗️ Template (Python)

```python
from abc import ABC, abstractmethod

# Element
class FileElement(ABC):
    @abstractmethod
    def accept(self, visitor: 'FileVisitor') -> None: ...

class FileNode(FileElement):
    def __init__(self, name: str, size: int):
        self.name = name
        self.size = size

    def accept(self, visitor: 'FileVisitor'):
        visitor.visit_file(self)

class DirectoryNode(FileElement):
    def __init__(self, name: str, children: list[FileElement]):
        self.name = name
        self.children = children

    def accept(self, visitor: 'FileVisitor'):
        visitor.visit_directory(self)
        for child in self.children:
            child.accept(visitor)

# Visitor
class FileVisitor(ABC):
    @abstractmethod
    def visit_file(self, file: FileNode) -> None: ...
    @abstractmethod
    def visit_directory(self, directory: DirectoryNode) -> None: ...

class FileSizeVisitor(FileVisitor):
    def __init__(self):
        self.total_size = 0

    def visit_file(self, file: FileNode):
        self.total_size += file.size

    def visit_directory(self, directory: DirectoryNode):
        pass
```

---

## ⚠️ Armadilhas

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| Novo tipo de Element | Alterar TODOS os visitors | Usar só se hierarquia é estável |
| Visitor acumulando estado | Bugs em reuso | Criar novo visitor por operação |
| Traversal no Element | Lógica espalhada | Centralizar traversal no composite |

---

## ✅ Checklist

```
[ ] Hierarquia de Elements é estável (poucos tipos novos)?
[ ] Precisa múltiplas operações diferentes sobre a mesma estrutura?
[ ] Cada Visitor tem UMA responsabilidade?
[ ] Traversal está no Element (accept) ou em walker dedicado?
[ ] Visitors são stateless ou criam nova instância por uso?
```
