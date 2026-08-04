# Digimon iOS — Mod Menu com liga/desliga (sem jailbreak, sem JIT)

Menu ImGui que **liga e desliga em runtime** os cinco cheats que hoje são patch
estático no IPA. Baseado no template
[VenerableCode/iOS-Theos-ModMenuTemp-NoJB](https://github.com/VenerableCode/iOS-Theos-ModMenuTemp-NoJB),
que usa [Titanox](https://github.com/Ragekill3377/Titanox) — **não** Dobby.

> **Status: NÃO TESTADO em device.** O objetivo desta primeira versão é provar
> uma coisa só: se a escrita em memória de código funciona em app sideloaded.
> Ver "O que exatamente estamos testando".

---

## Por que não precisa de JIT

O que exige JIT/jailbreak é reescrever código **em runtime** com Dobby. O
Titanox não faz isso: é `fishhook` (símbolos, em `__DATA`), swizzling de ObjC
(tabelas de dados) e `mach_vm_protect` + escrita de memória.

A própria documentação do Titanox confirma o limite, e é o dado mais útil dela:

> *Static Inline Hook: **Drawback: need to manually replace binary***

Ou seja: até o Titanox, para endereço arbitrário, precisa do binário **patchado
offline** — que é exatamente o que `patch_ios_digimon.py` já faz. Este projeto
não substitui o patch estático; ele **alterna** entre os bytes do patch e os
bytes originais.

---

## Arquitetura

```
IPA já patchado (5 cheats ativos)        <- patch_ios_digimon.py, offline
        +
DigimonMenu.dylib injetado (Sideloadly)
        |
        +-- MenuLoad/UserMenu.mm      menu ImGui, 6 checkboxes
        +-- Source/DigimonPatches.mm  escreve stub (ligar) ou original (desligar)
        +-- Titanox                   mach_vm_protect + read/write de memória
        +-- swizzle de drawInMTKView: desenha o menu (sem JIT)
```

Cada alvo guarda **os dois conjuntos de bytes**:

| Estado | Bytes escritos |
|---|---|
| Ligado | o stub (ex.: `fmul d0,d0,d1` do dano ×1000) |
| Desligado | o prólogo original da função |

---

## A decisão de desenho que protege contra o pior caso

O IPA é distribuído **já patchado**. Consequência: se a escrita em runtime for
recusada pelo iOS, o estado permanece o de hoje — **cheats ligados e
funcionando**. A falha degrada para o comportamento atual, nunca para "jogo
quebrado" ou "cheats mortos sem explicação".

Foi lição aprendida no lado Android deste projeto (regra 6.17-c: falhar fechado,
e nunca deixar falha silenciosa sem mensagem).

---

## Proteções implementadas

1. **Validação de bytes na inicialização.** Para cada alvo, lê a memória e exige
   que os bytes casem com o stub **ou** com o original. Qualquer outra coisa
   significa versão diferente do jogo → o alvo é marcado inválido e **nunca é
   escrito**. Na UI aparece desabilitado com `(nao validado)`.
2. **Releitura após escrever.** Não confia no retorno do write: relê e compara.
   Se não bateu, o estado interno não muda e o checkbox volta ao valor real —
   um checkbox não pode mentir sobre o estado.
3. **Restaura a proteção** da página para R-X depois de escrever.
4. **Log de tudo** em `Documents/TITANOX_LOGS.txt` (base, kr do vm_protect,
   resultado de cada toggle).
5. **Aba DIAGNÓSTICO** no menu, mostrando base, alvos válidos e se a escrita
   funcionou.

---

## Alvos (do `OFFSETS_DIGIMON_IOS.md`)

| # | Feature | RVA | Bytes |
|---|---|---|---|
| 0 | Dano ×1000 + Modo Deus | `0x3127250` | 44 |
| 1 | Cadência de ataque 0.1s | `0x2CDCCDC` | 24 |
| 2 | Nunca errar | `0x313B66C` | 8 |
| 3 | Velocidade 5x (estado X1) | `0x32AE148` | 4 |
| 4 | Velocidade 5x (estado X2) | `0x32AE150` | 4 |
| 5 | Pular vídeo de anúncio | `0x2E5D7E4` | 8 |

Válidos **somente** para `UnityFramework` de 162.117.056 bytes (v1.1.1 build 42).

### Validação obrigatória antes de compilar

```
python ferramentas_dump/valida_tweak_ios.py
```

Confere três coisas que, se divergirem, produzem um toggle que **corrompe
código**:

1. stub do tweak == bytes que o patcher grava
2. original do tweak == bytes do IPA limpo
3. stub do tweak == bytes do IPA patchado

Resultado atual: **18 de 18 conferem**.

---

## Compilar

Não precisa de Mac. O workflow `.github/workflows/build-ios-digimon.yml` compila
no runner macOS do GitHub:

```powershell
$env:Path = "C:\Program Files\GitHub CLI;C:\Program Files\Git\cmd;" + $env:Path
git add -A; git commit -m "mod menu ios digimon"; git push
gh workflow run "build-ios-digimon.yml" --ref main
gh run list  --workflow "build-ios-digimon.yml" --limit 3
gh run view <ID> --log-failed          # se falhar
gh run download <ID> --dir build_out   # baixa DigimonMenu.dylib
```

O workflow clona o template (ImGui + Titanox), sobrepõe **nossos** arquivos sem
sobrescrevê-los, compila e sobe o `.dylib` como artefato. Por isso ImGui e
Titanox **não** são versionados aqui.

---

## Instalar

1. Sideloadly → arrastar o **IPA já patchado**
   (`...-Decrypted-MOD.ipa`).
2. **Advanced options → inject dylib** → `DigimonMenu.dylib`.
3. Instalar e abrir. O template mostra um **ícone flutuante** ~3s após abrir;
   tocar nele abre/fecha o menu.

---

## O que exatamente estamos testando

Nesta primeira rodada, **uma única pergunta**: `mach_vm_protect` consegue tornar
escrevível uma página de código do `UnityFramework` num app sideloaded?

- **Se sim** → os toggles funcionam, a aba DIAGNÓSTICO mostra
  `escrita em runtime: FUNCIONA`, e o projeto está resolvido.
- **Se não** → aparece `escrita recusada: cheats ficam como estao`, e o log
  traz o `kr` do `vm_protect`. Nesse caso os cheats continuam ligados (o IPA
  está patchado) e a conclusão é que liga/desliga por escrita de memória não é
  possível nesse setup — restaria a rota de flags em `__DATA` com stubs
  condicionais.

O menu abrir **não** é prova de sucesso: o menu é ObjC/Metal e sobe de qualquer
forma. A prova é o toggle mudar o comportamento em jogo.

### Roteiro de teste sugerido

1. Abrir o menu, ir em DIAGNÓSTICO, conferir que `alvos` mostra **6/6**.
2. Desligar **Dano x1000 + Modo Deus** e entrar em combate: o dano deve voltar
   ao normal e o inimigo deve machucar.
3. Religar e conferir que volta a matar em um golpe.
4. Repetir com **Velocidade** (o efeito é imediato, sem precisar de combate).
5. Se algo não mudar, puxar `Documents/TITANOX_LOGS.txt`.

### Correção de crash (jul/2026)

Sintoma: o ícone aparecia, mas tocar nele para abrir o menu fechava o jogo.

Causa: o wrapper `+[TitanoxHook log:]` do template repassa um `va_list` como se
fosse o primeiro argumento variádico de `THLog(NSString*, ...)`. Com `%s`/`%@`
isso dereferencia um ponteiro inválido e dá SIGSEGV. Nosso `inicializar` usava
esse wrapper com `%s` logo na primeira linha, então o crash acontecia no primeiro
desenho do menu. O código interno do Titanox nunca usa esse wrapper — chama a
função C `THLog(...)` direto.

Correção: `DigimonPatches.mm` agora chama `THLog(...)` direto (varargs corretos),
o `inicializar` roda uma única vez e está protegido por `@try/@catch`, e o
`DrawMenu` chama `ImGui::End()` sempre (pareado com `Begin`, senão com `-DNDEBUG`
a pilha de janelas corrompe).
