# Plano de unificação `main` + `feat/mac` em um único script

## Contexto

Hoje existem dois branches do `goto.sh`:

- **`main`** — mantido no Linux, é a versão mais completa e mais recente
  (backup automático, `purge`/`check`/`rename`/`question`, códigos de retorno
  semânticos, menu com `select`, listagem zebrada, autocomplete recursivo via
  `case`, suíte de testes com bats-core).
- **`feat/mac`** — mantido na máquina de trabalho (Mac), com um subconjunto
  menor de funcionalidades, mas contendo ajustes pontuais para rodar em
  macOS que **não existem no `main`**.

Este documento parte do `main` como fonte principal (mais completa) e mapeia
exatamente o que falta nela para funcionar em macOS, o que pode ser
descartado do `feat/mac` por já estar superado, e os passos para chegar a um
único branch/script compatível com as duas máquinas.

Este é um documento de **planejamento**, mas as decisões abaixo já foram
tomadas e a Fase 1 (correções de portabilidade no `main`) já foi executada
— ver "Status da execução" logo depois das perguntas em aberto.

## Decisões registradas

- **`eza`**: já está instalado na máquina de trabalho (Mac). Mantido como
  dependência única para as duas máquinas — nenhuma mudança no
  `__goto_completion`.
- **Checagem de versão do Bash**: implementada (ver "Requisito de
  ambiente").
- **`feat/mac`**: mantido como está, sem alterações. Além disso foi criado
  o branch **`feat/linux`**, apontando para o estado do `main` logo antes
  desta rodada de correções de portabilidade — ou seja, as duas máquinas
  passam a ter um branch histórico próprio (`feat/linux` e `feat/mac`)
  registrando como cada uma rodava o script antes da unificação.
- **`sed -i`**: resolvido com a alternativa baseada em `grep -v` (Apêndice
  B), não com `sed -i.bak`.

## Metodologia

- `git log --oneline feat/mac` para entender a história e a motivação de
  cada commit específico de Mac.
- `git show <commit>` nos commits que mencionam ajustes de macOS, para ler o
  diff exato de cada correção.
- `diff -u` entre `goto.sh` dos dois branches, para confirmar quais partes
  do `feat/mac` ainda são relevantes hoje ou já foram superadas pela
  evolução do `main`.

Ponto de bifurcação dos branches: commit `36673c2` (bem anterior a toda a
evolução recente do `main`, incluindo `refactor`, `refac` e a suíte de
testes).

## Diagnóstico: o que realmente incompatibiliza o `main` com macOS

Comparando os commits de ajuste do `feat/mac` com o estado atual do
`goto.sh` no `main`, sobram **3 pontos concretos** de incompatibilidade —
o resto das diferenças entre os branches é apenas funcionalidade nova do
`main` que nunca existiu no `feat/mac` (e que não usa nada específico de
Linux).

### 1. `sed -i` sem argumento de sufixo — crítico

[goto.sh:486](../goto.sh#L486):

```bash
sed -i "/^$destAlias=/d" "$destMap"
```

GNU `sed` (Linux) aceita `-i` sozinho. O BSD `sed` do macOS **exige** um
argumento logo depois de `-i` (mesmo que vazio) para o sufixo de backup —
sem ele, o `sed` do Mac interpreta a própria expressão como esse sufixo e
falha (ou, pior, cria um arquivo de backup com o nome da regex).

Foi exatamente isso que o commit `57783cd` (`ajusta o sed para
funcionamento no mac`) corrigiu no `feat/mac`, trocando para:

```bash
sed -i '' "/^$destAlias=/d" "$destMap"
```

**Impacto no `main` de hoje:** `__goto_remove_destiny` é chamada por
`-d/--delete`, `-u/--update` (via remove+add) e `-r/--rename` (idem), e
também por `__goto_purge_destinies`. Ou seja, **quatro comandos inteiros
quebram no Mac** com o `sed` atual.

**Status: corrigido.** Optamos pela alternativa do Apêndice B em vez de
`sed -i.bak`, eliminando a dependência do `sed` para essa operação e o
arquivo de backup intermediário. `__goto_remove_destiny`
([goto.sh:496-499](../goto.sh#L496-L499)) agora é:

```bash
local tmpFile
tmpFile=$(mktemp "${TMPDIR:-/tmp}/goto-destinies.XXXXXX")
grep -v "^$destAlias=" "$destMap" > "$tmpFile"
mv "$tmpFile" "$destMap"
```

Idêntico em GNU e BSD `grep`, sem flag de edição in-place e sem arquivo de
backup para limpar depois.

### 2. Dependência do `eza` no autocomplete — degradação silenciosa

[goto.sh:684](../goto.sh#L684):

```bash
destinies=$(eza -D "$folder" | xargs -n1 basename 2>/dev/null)
```

`eza` não é um comando de sistema — precisa ser instalado nas duas
máquinas. No commit `e8e50f4`, na época, ele não estava disponível no Mac
de trabalho, e foi substituído por:

```bash
destinies=$(ls -d "$folder"/*/ 2>/dev/null | xargs -n1 basename 2>/dev/null)
```

**Impacto:** diferente do `sed`, essa parte falha "silenciosamente" — o
`2>/dev/null` e o `[[ -n $destinies ]] || COMPREPLY=()` fazem o Mac
simplesmente não sugerir nada ao pressionar `<TAB>` dentro de um diretório
mapeado, sem erro visível. É um problema de funcionalidade reduzida, não
de comando quebrado.

**Status: sem ação necessária.** `eza` já está instalado no Mac de
trabalho — mantido como está, sem trocar para a forma baseada em `ls`.

### 3. `mktemp` sem template — risco a validar

[goto.sh:635](../goto.sh#L635):

```bash
tmpFile=$(mktemp)
```

GNU `mktemp` aceita ser chamado sem argumentos. O `mktemp` BSD (padrão do
macOS) tradicionalmente **exige** um template (`mktemp /tmp/goto.XXXXXX`)
ou a flag `-t`, e pode falhar com "usage: mktemp ..." quando chamado sem
nada. Isso não apareceu nos commits do `feat/mac` porque
`__goto_sort_destiny_file` é relativamente nova e não existia quando os
ajustes de Mac foram feitos.

Não tinha como confirmar isso de dentro de um Linux, mas como a correção é
trivial e funciona igual nos dois SOs, foi **aplicada preventivamente**
(ainda vale validar de fato numa sessão real do Mac, mas sem risco de
regressão no Linux — os testes continuam passando):

```bash
tmpFile=$(mktemp "${TMPDIR:-/tmp}/goto-destinies.XXXXXX")
```

**Status: corrigido** em [goto.sh:649](../goto.sh#L649)
(`__goto_sort_destiny_file`) e reaproveitado também na correção do `sed`
acima (`__goto_remove_destiny`).

## O que NÃO precisa de ação (já resolvido ou superado pelo `main`)

- **Shebang (`#!/bin/bash` vs `#!/opt/local/bin/bash`)** — irrelevante.
  `goto.sh` é sempre usado via `source`, então o shebang nunca é
  interpretado; quem manda é o shell que já está rodando na sessão do
  usuário.
- **Localização do arquivo de mapeamento hardcoded** — o `feat/mac` também
  resolveu isso de forma independente (commit `fc1047a`), mas o `main` já
  tem a mesma ideia, de forma mais madura: variável de ambiente
  `GOTO_DESTINY_FILE` com fallback para `$HOME/.goto-destinies` e criação
  automática do arquivo ([goto.sh:280-288](../goto.sh#L280-L288)). Nada a
  portar aqui — **atenção**, porém, ao nome de arquivo diferente entre os
  branches: ver "Migração de dados" abaixo.
- **`__goto_check_in_array`** (commit `e8e50f4`) — função criada porque a
  checagem `"(${array[@]})" == *" $prev "*` não funcionava igual no Mac.
  O `main` reestruturou o autocomplete inteiro com `case "$prev" in ...`
  ([goto.sh:657-689](../goto.sh#L657-L689)), que não usa mais esse padrão
  de matching — o problema não existe mais na base de código atual, não
  há nada para portar.
- **`-g/--get`, `-m/--map-file`** (commits `f082054`, `72f1e39`) — já
  existem no `main`, implementados de forma mais completa (usando
  `__goto_generate_return_code` em vez de `return 1`/`return 2` fixos).
- **Menu numerado, listagem zebrada, autocomplete recursivo** (commits
  `264c6ad`, `43e4279`, `ab1a1d4`) — já presentes e mais evoluídos no
  `main`.

## Requisito de ambiente (não é bug, é pré-requisito)

O script usa `mapfile`/`readarray`, expansão `${var,,}` e
`complete -o nosort`, que exigem **Bash ≥ 4.4**. O Mac já foi atualizado
para Bash 5 — mas isso só resolve o problema se a sessão que dá `source` no
script for de fato essa Bash 5 (o Bash 3.2 que vem por padrão no macOS
continua instalado e pode ser o que abre em um terminal novo, dependendo de
como o shell padrão do usuário foi configurado). Vale documentar
explicitamente essa exigência no `README.md` e adicionar uma checagem
defensiva no topo do `goto.sh`.

**Status: corrigido.** Guard adicionado em
[goto.sh:3-11](../goto.sh#L3-L11), logo após o shebang:

```bash
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
  echo "goto.sh requer Bash >= 4.4 (versão atual: $BASH_VERSION)" >&2
  return 1 2>/dev/null || exit 1
fi
```

O `return 1 2>/dev/null || exit 1` cobre os dois modos de uso do script:
quando é dado `source` (caso normal), `return` interrompe só a leitura do
arquivo, sem derrubar o shell do usuário; se alguém tentar executá-lo
diretamente (`./goto.sh`), `return` fora de uma função/arquivo sourceado
falha, e cai no `exit 1`.

Ainda falta atualizar o `README.md` para deixar essa exigência explícita
na seção "Dependências".

## Migração de dados (não é código)

O `feat/mac`, na sua última iteração antes de adotar a variável de
ambiente, usava por padrão `$HOME/.goto-destinos` (nome com erro de
digitação, sem o "i"), enquanto o `main` usa `$HOME/.goto-destinies`. Se a
máquina de trabalho tiver mapeamentos salvos nesse arquivo antigo, a
migração para o `main` precisa ou:

- renomear o arquivo: `mv ~/.goto-destinos ~/.goto-destinies`; ou
- apontar explicitamente via `export GOTO_DESTINY_FILE=~/.goto-destinos`
  no `.zshrc`/`.bashrc` do Mac.

Isso deve ser conferido manualmente antes de trocar o Mac para o `main` —
não é algo que o código consiga detectar sozinho com segurança.

## Item trivial: `.gitignore`

O `feat/mac` ignora `.vscode/settings.json` (commit `8dd5720`), o `main`
não. Vale só somar essa linha ao `.gitignore` do `main` na hora da
unificação — não tem relação com compatibilidade, é só uma sobra de
configuração de editor específica da máquina de trabalho.

**Status: corrigido**, entrada somada ao `.gitignore`.

## Plano de execução

1. ~~**Corrigir os pontos de portabilidade no `main`**~~ **— feito.**
   - ~~`sed -i` → alternativa com `grep -v` (Apêndice B).~~
   - ~~`eza`: decisão tomada, mantido sem mudança de código.~~
   - ~~`mktemp` → `mktemp "${TMPDIR:-/tmp}/goto-destinies.XXXXXX"`.~~
   - ~~Checagem de versão do Bash no topo do script.~~
   - ~~Atualizar a seção "Dependências" do `README.md` com o requisito de
     Bash >= 4.4.~~ **— feito** (também removida a menção a `sed`, que
     não é mais usado pelo script).
2. **Cobrir com teste antes de mexer** — feito antes das mudanças: a
   suíte bats já cobria `__goto_remove_destiny` e
   `__goto_sort_destiny_file`; os 59 testes continuam passando após as
   correções desta rodada, sem precisar adicionar casos novos.
3. **Validar manualmente no Mac** — ainda pendente. Rodar `npm test` lá
   (bats-core é Bash puro, roda igual nas duas plataformas) e testar o
   uso real (`goto -a`, `-d`, `-u`, `-r`, `-p`, `<TAB>`), incluindo o
   ponto do `mktemp` que não pôde ser validado a partir do Linux.
4. ~~**Ajustar o `.gitignore`**~~ **— feito.**
5. **Migrar os dados** do Mac (`~/.goto-destinos` → `~/.goto-destinies`
   ou `GOTO_DESTINY_FILE`) — passo manual na máquina de trabalho, a
   cargo do usuário; considerado resolvido para efeito deste plano.
6. ~~**Aposentar o `feat/mac`**~~ — **decisão alterada**: o branch é
   mantido como registro histórico (junto com o novo `feat/linux`), não
   apagado. Ver "Decisões registradas".

## Apêndice A — commits do `feat/mac` e seu destino na unificação

| Commit | Descrição | Destino |
|---|---|---|
| `e8e50f4` | shebang, arquivo hardcoded, `__goto_check_in_array`, `eza`→`ls` | shebang e arquivo hardcoded: obsoletos; `__goto_check_in_array`: obsoleto (completion foi reescrita); `eza`→`ls`: decisão em aberto (ver acima) |
| `57783cd` | `sed -i` → `sed -i ''` | **portar o fix** (adaptado para forma cross-OS, ver ponto 1) |
| `264c6ad`, `43e4279`, `ab1a1d4`, `668d304` | menu numerado, zebra, completion recursivo, legibilidade | já superados por versões mais completas no `main` |
| `8dd5720` | `.vscode/settings.json` no `.gitignore` | portar (trivial) |
| `fc1047a` | variável de ambiente para arquivo de destino | já resolvido de forma equivalente (e mais madura) no `main`; atenção à migração de dados |
| `72f1e39` | `-m/--map-file` | já existe no `main` |
| `f082054` | `-g/--get` | já existe no `main` |

## Apêndice B — alternativa ao `sed -i` sem depender de flag de backup

Caso prefira não depender de nenhuma particularidade do `sed -i` (a forma
com `.bak` já é portável, mas cria e apaga um arquivo temporário a cada
chamada), a remoção de uma linha por chave pode ser feita sem `sed`:

```bash
grep -v "^$destAlias=" "$destMap" > "$destMap.tmp" && mv "$destMap.tmp" "$destMap"
```

Isso é idêntico em GNU e BSD `grep`, não precisa de flag de edição
in-place e evita o tema todo do `sed -i`.
