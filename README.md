# Repositório dos projetos para TCC do MBA em Engenharia de Software 2026
Este repositório contém os dois projetos criados para usar como base para as análises do meu TCC no MBA em Engenharia de Software da USP/ESALQ.
Ambos os projetos são apps simples que apresentam uma lista de tarefas, onde é possível listar, cadastrar, concluir e excluir tarefas. A diferença é que cada um foi feito em um arquitetura diferente, sendo:
- UIKit e MVC, representando arquitetura imperativa;
- SwiftUI, Combine e MVVM, representando arquitetura reativa.

Os apps e as análises foram feitos/testados usando iOS e Xcode 26.4 em um simulador do iPhone 17.

Abaixo há uma explicação e tutorial de como ativar cada cenário de erro implementado para a análise.  

# Cenários de erro — Como ativar e reproduzir

---

## E1 — Inconsistência de estado

**UIKit:**
```swift
// TaskViewController.swift
static var enableE1_StateInconsistency: Bool = true
```
**Gatilho:** deslizar uma tarefa e tocar em Excluir
**Sintoma:** crash com `NSInternalInconsistencyException`

**SwiftUI:**
```swift
// TaskViewModel.swift
static var enableE1_BackgroundMutation: Bool = true
```
**Gatilho:** deslizar uma tarefa e tocar em Excluir
**Sintoma:** runtime warning no console (iOS 17+) — sem crash

---

## E2 — Gerenciamento incorreto de ciclo de vida assíncrono

### Conceito
O mesmo bug conceitual nas duas arquiteturas: uma operação assíncrona
perde sua referência antes de completar. No UIKit, o objeto de serviço
é dealocado. No Combine, o AnyCancellable não é armazenado.
Resultado em ambos: loading infinito, sem crash, sem log automático.

**UIKit:**
```swift
// TaskViewController.swift
static var enableE2_EphemeralService: Bool = true
```
**Gatilho:** abrir o app ou fazer pull-to-refresh
**Sintoma:** ActivityIndicator gira indefinidamente — lista nunca carrega

**SwiftUI:**
```swift
// TaskViewModel.swift
static var enableE2_UnretainedCancellable: Bool = true
```
**Gatilho:** abrir o app ou fazer pull-to-refresh
**Sintoma:** ProgressView gira indefinidamente — lista nunca carrega

### Diferença arquitetural chave
- UIKit: o objeto de serviço precisa existir enquanto a operação está viva
  — isso é explícito e visível no código (variável local vs propriedade)
- Combine: a ausência de `.store(in: &cancellables)` é uma omissão silenciosa
  — o compilador não avisa, não há nada errado sintaticamente

---

## E3 — Force unwrap em estado inválido

**UIKit:**
```swift
// TaskViewController.swift
static var enableE3_ForceUnwrap: Bool = true
```

**SwiftUI:**
```swift
// TaskViewModel.swift
static var enableE3_ForceUnwrap: Bool = true
```

**Gatilho:** tocar em qualquer tarefa e aguardar 2 segundos
**Sintoma:** crash com `EXC_BAD_INSTRUCTION` em ambos

---

## E4 — Operação assíncrona que nunca completa

**UIKit:**
```swift
// TaskService.swift
static var enableE4_NeverCompletes: Bool = true
```

**SwiftUI:**
```swift
// TaskViewModel.swift — ReactiveTaskService
static var enableE4_NeverEmits: Bool = true
```

**Gatilho:** abrir o app
**Sintoma:** loading infinito em ambos — sem crash, sem log

---

## Regras gerais

- Nunca ative duas flags ao mesmo tempo
- Limpe o console (Cmd+K) antes de cada sessão
- Reinicie o app entre iterações (Cmd+. → Cmd+R)
- Para E1 e E3: aguarde 1–2 min após o crash para o Crashlytics processar
- Tire screenshot do Crashlytics (E1, E3) e do console (E2, E4) como evidência
