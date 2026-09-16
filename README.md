# goto

Script Bash que adiciona o comando `goto`, um navegador rápido de diretórios
por apelido (alias). Em vez de digitar `cd /caminho/longo/do/projeto`, você
mapeia esse caminho para um apelido curto (ex.: `proj`) e navega com
`goto proj`.

## Dependências

- `bash` (usa `mapfile`, `select`, `[[ ]]`)
- `eza` — usado no autocomplete para listar subdiretórios
- `vi` — usado por `goto -e` para editar o arquivo de mapeamentos
- utilitários padrão: `awk`, `grep`, `sed`, `sort`, `realpath`, `mktemp`

## Instalação

Adicione ao seu `.bashrc` (ou equivalente):

```bash
source /caminho/para/goto.sh
```

Isso registra a função `goto` e o autocomplete (`complete -F __goto_completion goto`).

## Arquivo de mapeamentos

Os mapeamentos ficam em um arquivo texto simples, uma entrada por linha, no
formato:

```
apelido=/caminho/absoluto/do/diretorio
```

- Local padrão: `$HOME/.goto-destinies`
- Pode ser customizado com a variável de ambiente `GOTO_DESTINY_FILE`
- O arquivo é criado automaticamente na primeira vez que for necessário

Toda operação que **altera** o arquivo (`-a`, `-d`, `-u`, `-r`, `-p`) faz
antes um backup em `<arquivo>~` (mantém apenas uma cópia, sobrescrita a cada
nova alteração).

## Uso

### Navegar

```bash
goto                    # menu interativo para escolher um destino
goto <apelido>          # navega para o diretório mapeado
goto <apelido> <sub>    # navega para um subdiretório dentro do mapeado
goto <diretorio>        # se <apelido> não existir mas for um caminho válido, navega direto
```

O autocomplete (`<TAB>`) sugere apelidos cadastrados, opções (`-a`, `-d`, ...)
e, ao completar um subdiretório, lista o conteúdo real da pasta mapeada.

### Gerenciar mapeamentos

| Comando | Descrição |
|---|---|
| `goto -h`, `--help` | Exibe o manual completo |
| `goto -s`, `--show-destinies` | Lista todos os mapeamentos formatados |
| `goto -g`, `--get <apelido>` | Imprime o diretório associado a um apelido |
| `goto -a`, `--add <diretorio> <apelido>` | Adiciona um novo mapeamento |
| `goto -u`, `--update <apelido> <diretorio>` | Atualiza o diretório de um apelido existente |
| `goto -d`, `--delete <apelido>` | Remove um mapeamento |
| `goto -r`, `--rename <antigo> <novo>` | Renomeia o apelido de um mapeamento |
| `goto -c`, `--check-destinies` | Verifica se todos os diretórios mapeados ainda existem |
| `goto -p`, `--purge-destinies` | Remove mapeamentos cujo diretório não existe mais |
| `goto -q`, `--question [diretorio]` | Verifica se um diretório (ou o atual, se omitido) já está mapeado |
| `goto -e`, `--edit` | Abre o arquivo de mapeamentos no `vi` |
| `goto -m`, `--map-file` | Mostra o caminho do arquivo de mapeamentos em uso |

### Exemplos

```bash
goto -a ~/projetos/meu-app app      # mapeia ~/projetos/meu-app como "app"
goto app                            # navega para ~/projetos/meu-app
goto app src                        # navega para ~/projetos/meu-app/src
goto -r app app2                    # renomeia o apelido "app" para "app2"
goto -u app2 ~/projetos/outro-app   # atualiza o destino do apelido "app2"
goto -c                             # checa se todos os diretórios mapeados existem
goto -p                             # remove os mapeamentos quebrados
```

## Códigos de retorno

Todas as funções retornam códigos semânticos centralizados em
`__goto_generate_return_code`:

| Código | Nome | Significado |
|---|---|---|
| 0 | OK | Sucesso |
| 10 | ERR_DESTINY_NOT_FOUND | Apelido/destino não encontrado |
| 20 | ERR_ALIAS_MISSING_ON_COMMAND | Apelido não informado no comando |
| 21 | ERR_ALIAS_NOT_FOUND | Apelido não cadastrado |
| 22 | ERR_ALIAS_ALREADY_EXISTS | Apelido já existe |
| 30 | ERR_DIRECTORY_NOT_MAPPED | Diretório não está mapeado (usado em `-q`) |
| 31 | ERR_DIRECTORY_ACCESS_DENIED | Sem permissão para acessar o diretório |
| 32 | ERR_DIRECTORY_NOT_FOUND | Diretório não existe |
| 33 | ERR_DIRECTORY_MISSING_ON_COMMAND | Diretório não informado no comando |
| 40 | ERR_FILE_ALREADY_EXISTS | Arquivo de backup já existe |
| 41 | ERR_FILE_ACCESS_DENIED | Sem permissão de escrita no arquivo/diretório de backup |
| 42 | ERR_FILE_NOT_VALID | Caminho de backup não é um arquivo válido |
| 43 | ERR_FILE_CANT_COPY | Falha ao copiar o arquivo durante o backup |
| 1 | (genérico) | Qualquer outro erro não mapeado |

## Estrutura interna

Funções prefixadas com `__goto_` são privadas/internas (não devem ser
chamadas diretamente pelo usuário):

- `__goto_get_destiny_file` — resolve e garante a existência do arquivo de mapeamentos
- `__goto_choose_destiny` — menu interativo (`goto` sem argumentos)
- `__goto_show_destinies` — listagem formatada (`-s`)
- `__goto_get_destiny` — resolve um apelido para seu diretório
- `__goto_check_destinies` / `__goto_purge_destinies` — validação e limpeza
- `__goto_create_bkp` — backup do arquivo antes de alterações
- `__goto_add_destiny` / `__goto_remove_destiny` / `__goto_update_destiny` / `__goto_rename_destiny` — CRUD dos mapeamentos
- `__goto_question_folder` — checa se um diretório já está mapeado (`-q`)
- `__goto_sort_destiny_file` — mantém o arquivo ordenado alfabeticamente
- `__goto_completion` — função de autocomplete registrada via `complete`
- `__goto_manual*` — conjunto de funções que compõem o texto de ajuda (`-h`)

## Observação

O comentário de cabeçalho do script cita `batcat` como dependência, mas ele
não é utilizado em nenhum ponto do código atual — apenas `eza` e `vi` são
efetivamente usados.

## Testes

A suíte de testes usa [bats-core](https://github.com/bats-core/bats-core)
(mais os plugins `bats-support`/`bats-assert`), instalados localmente via npm.

```bash
npm install   # instala bats-core e as bibliotecas de asserção
npm test      # roda toda a suíte (test/*.bats)
```

Cada arquivo `.bats` cobre uma área do script:

| Arquivo | Cobertura |
|---|---|
| `test/goto_mapping.bats` | CRUD de mapeamentos: `__goto_add_destiny`, `__goto_get_destiny`, `__goto_remove_destiny`, `__goto_update_destiny`, `__goto_rename_destiny`, `__goto_sort_destiny_file`, `__goto_get_destiny_file` |
| `test/goto_validation.bats` | `__goto_check_destinies`, `__goto_purge_destinies`, `__goto_question_folder` |
| `test/goto_backup.bats` | `__goto_create_bkp` (criação, proteção contra sobrescrita, `--force`) |
| `test/goto_navigation.bats` | Dispatcher principal `goto` (navegação, todas as flags, menu interativo e `-e/--edit`) |
| `test/goto_completion.bats` | Autocomplete (`__goto_completion`) |
| `test/goto_return_codes.bats` | Mapeamento de `__goto_generate_return_code` |

Cada teste roda com `GOTO_DESTINY_FILE` apontando para um arquivo temporário
isolado (veja `test/test_helper.bash`), então nenhum teste toca no arquivo de
mapeamentos real do usuário.

Duas dependências externas do script (`vi` e `eza`) são substituídas por
binários fake (stubs) durante os testes — ver `stub_bin` em
`test/test_helper.bash` — para não exigir um editor de verdade nem o `eza`
instalado só para rodar a suíte.
