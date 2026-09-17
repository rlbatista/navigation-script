# Backlog de refactor do `goto.sh`

Lista organizada por prioridade e por tipo de commit (semântico), pensada
para virar commits atômicos e fáceis de reverter individualmente caso algo
dê errado. Nada foi implementado ainda — é um backlog para decidir o
momento de cada item.

Regra geral: todo item aqui foi avaliado quanto à compatibilidade com
macOS (ver [docs/unificacao-linux-mac.md](unificacao-linux-mac.md) para o
histórico completo de portabilidade). Nenhum dos itens abaixo toca em
comandos sensíveis a GNU/BSD (`sed`, `mktemp`, `eza`, `realpath`) — é tudo
sintaxe de Bash ou `awk` simples, que já se comporta igual nas duas
plataformas.

## 0. Shebang portátil (`chore`) — fora da ordem de prioridade das demais — feito

```diff
-#!/bin/bash
+#!/usr/bin/env bash
```

`env bash` resolve o interpretador pelo `$PATH` de quem executa, em vez de
um caminho fixo (`/bin/bash` no Linux, `/opt/local/bin/bash` no MacPorts,
mas também poderia ser `/opt/homebrew/bin/bash` ou `/usr/local/bin/bash`
num Mac com Homebrew). Isso resolve automaticamente para o Bash certo em
qualquer uma dessas combinações — inclusive a que já foi ajustada na
máquina de trabalho.

Duas notas importantes:

- Como o script é sempre usado via `source`, o shebang continua sem efeito
  prático hoje — só passa a importar se o arquivo for executado
  diretamente (ex.: `./goto.sh`, ou uma ferramenta como o `shellcheck`).
- Mesmo corrigido, `./goto.sh <apelido>` nunca vai conseguir navegar de
  verdade: um `cd` dentro de um processo filho não muda o diretório do
  shell pai que o chamou — é uma limitação de processos do Unix, não do
  script. Os subcomandos que só imprimem informação (`-s`, `-g`, `-c`,
  `-h` etc.) até funcionariam via execução direta, mas isso exigiria
  detectar "fui sourceado ou executado" no fim do arquivo — fora do escopo
  deste item, é só uma observação para o caso de considerar isso no
  futuro.

## 1. `fix`: declarar `destino` como `local` em `goto()` — feito

[goto.sh:95](../goto.sh#L95):

```bash
destino=$(__goto_get_destiny "$1" 2> /dev/null)
```

Sem `local`, essa variável vaza para o escopo global do shell do usuário
depois que `goto` retorna — pode colidir com uma variável `$destino` que o
usuário já tenha em uso. Correção: `local destino` antes da atribuição
(mesmo padrão já usado em outras funções do arquivo, ex.
`__goto_get_destiny`, linha 270).

**Prioridade:** alta. **Risco:** nenhum — escopo de variável em Bash,
comportamento idêntico em qualquer plataforma.

## 2. `fix`: propagar falha de `__goto_add_destiny` em update/rename — feito

`__goto_update_destiny` e `__goto_rename_destiny` implementam a operação
como remove + add, mas descartam a saída e o código de retorno do `add`:

```bash
__goto_remove_destiny "$oldAlias" > /dev/null 2>&1
__goto_add_destiny "$destAlias" "$newAlias" > /dev/null 2>&1
echo "Destino [$oldAlias] renomeado para [$newAlias]"
__goto_generate_return_code OK
return $?
```

Caso concreto e fácil de reproduzir hoje: `goto -r foo bar`, sendo `bar`
um apelido que **já existe**. O `remove` de `foo` roda normalmente; o
`add` de `bar` falha (apelido duplicado), mas como a saída vai para
`/dev/null` e o `$?` nunca é checado, a função ainda imprime "renomeado"
e retorna sucesso. Resultado: `foo` some do mapeamento, `bar` continua
apontando pro destino antigo, e nada avisa o usuário que a operação
falhou.

Em `__goto_update_destiny` a janela de falha é mais estreita (o diretório
já foi validado antes de chamar remove+add), mas o padrão de ignorar o
retorno é o mesmo — cabe corrigir as duas funções num commit só, checando
o `$?` do `__goto_add_destiny` e reportando erro (e, idealmente,
recolocando o mapeamento antigo) se ele falhar.

**Prioridade:** alta. **Risco:** nenhum — lógica pura de Bash, sem
comando de SO envolvido.

## 3. `fix`: variáveis de cor trocadas no awk de `__goto_show_destinies`

[goto.sh:230-246](../goto.sh#L230-L246):

```awk
BD_DEFAULT="\033[49m"
...
bg = i % 2 == 0 ? BG_DEFAULT : BG_GRAY
```

`BD_DEFAULT` é definida mas nunca usada; `BG_DEFAULT` é usada mas nunca
definida (typo entre "BD" e "BG"). Efeito prático: o zebrado só colore as
linhas ímpares — as pares saem sempre sem cor de fundo, provavelmente não
é o efeito pretendido.

**Prioridade:** média. **Risco:** nenhum — `awk` puro (sem gawk/bsd-awk
específico), comportamento idêntico nas duas plataformas.

## 4. `refactor`: `case` no dispatcher de `goto()`

Hoje `goto()` despacha as ~13 flags com blocos repetidos:

```bash
[[ $1 == '-x' || $1 == '--xyz' ]] && {
  ...
  return $?
}
```

Trocar por um único `case "$1" in ... esac`, no mesmo estilo que
`__goto_completion` já usa (`case "$prev" in ...`). Reduz repetição e
deixa as duas funções consistentes entre si.

**Prioridade:** média. **Risco:** baixo — a suíte de testes já cobre
todas as flags, então dá pra validar a refatoração sem medo de regressão
silenciosa. `case`/`[[` são Bash puro.

## 5. `refactor`: helper `__goto_return`

```bash
function __goto_return() {
  __goto_generate_return_code "$1"
  return $?
}
```

Colapsa o par `__goto_generate_return_code CODE; return $?`, que se
repete umas 40 vezes no arquivo, para uma linha só em cada ponto de
retorno.

**Prioridade:** baixa. **Risco:** nenhum — mudança mecânica, sem lógica
nova.

## 6. `refactor`: fonte única para a lista de flags

A string de opções usada no autocomplete
(`__goto_completion`, variável `options`) é mantida à mão, separada da
lista real de flags aceitas por `goto()`. Quem adicionar uma flag nova em
um lugar pode esquecer do outro. Proposta: uma constante única (array)
referenciada nos dois pontos.

**Prioridade:** baixa. **Risco:** baixo — só Bash, sem dependência de SO.

## 7. `refactor`: renomear `local mapfile` para `mapFile`

[goto.sh:31](../goto.sh#L31):

```bash
local mapfile
mapfile="$(__goto_get_destiny_file)"
```

Essa variável local sombreia o builtin `mapfile` usado em outras funções
do mesmo arquivo (`__goto_choose_destiny`, `__goto_completion`). Não
quebra nada hoje (é local à função, e `goto()` não chama o builtin), mas é
um nome confuso — alinhar com a convenção `mapFile`/`destMap` já usada no
resto do arquivo.

**Prioridade:** baixa. **Risco:** nenhum — puramente cosmético.
