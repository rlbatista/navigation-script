#!/usr/bin/env bash

##########################################################################################################
## Checagem de versão do Bash. O script usa recursos que exigem Bash >= 4.4
## (mapfile/readarray, expansão ${var,,}, complete -o nosort), necessários
## tanto no Linux quanto no macOS (cujo Bash padrão é o 3.2).
##########################################################################################################
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
  echo "goto.sh requer Bash >= 4.4 (versão atual: $BASH_VERSION)" >&2
  return 1 2>/dev/null || exit 1
fi

##########################################################################################################
## Lista de flags reconhecidas por goto(), como pares <curta> <longa>. É a fonte única usada pelo
## autocomplete (__goto_completion) para sugerir as opções disponíveis. O case dentro de goto() continua
## sendo a implementação de cada flag; ao adicionar uma flag nova lá, adicione o par correspondente aqui
## também.
##########################################################################################################
__GOTO_FLAGS=(
  -h --help
  -e --edit
  -s --show-destinies
  -g --get
  -c --check-destinies
  -p --purge-destinies
  -a --add
  -d --delete
  -u --update
  -r --rename
  -q --question
  -m --map-file
  -b --backup
)

##########################################################################################################
## Função...: goto
## Descrição: Função principal do script, onde a principal atividade é navegar para diretório mapeados em
##            em um arquivo (destinos.map).
## Dependencias: Este script depende do eza, batcat e vi
##########################################################################################################
function goto() {
  [[ $# == 0 ]] && {
    __goto_choose_destiny
    return $?
  }

  [[ $1 == '-h' || $1 == '--help' ]] && {
    __goto_manual
    return "$(__goto_exit_code OK)"
  }

  local mapFile
  mapFile="$(__goto_get_destiny_file)"

  case "$1" in
    -e | --edit)
      vi "$mapFile"
      return "$(__goto_exit_code OK)"
      ;;

    -s | --show-destinies)
      __goto_show_destinies
      return "$(__goto_exit_code OK)"
      ;;

    -g | --get)
      __goto_get_destiny "$2"
      return $?
      ;;

    -c | --check-destinies)
      __goto_check_destinies
      return $?
      ;;

    -p | --purge-destinies)
      __goto_purge_destinies
      return $?
      ;;

    -a | --add)
      __goto_copy_destiny_file
      __goto_add_destiny "$2" "$3"
      return $?
      ;;

    -d | --delete)
      __goto_copy_destiny_file
      __goto_remove_destiny "$2"
      return $?
      ;;

    -u | --update)
      __goto_copy_destiny_file
      __goto_update_destiny "$2" "$3"
      return $?
      ;;

    -r | --rename)
      __goto_copy_destiny_file
      __goto_rename_destiny "$2" "$3"
      return $?
      ;;

    -q | --question)
      __goto_question_folder "$2"
      return $?
      ;;

    -m | --map-file)
      __goto_get_destiny_file
      return $?
      ;;

    -b | --backup)
      __goto_backup_destiny_file "$2" "$3"
      return $?
      ;;
  esac

  local destino
  destino=$(__goto_get_destiny "$1" 2> /dev/null)

  [[ -z $destino ]] && {
    [[ ! -d $1 ]] && {
      echo "Destino [$1] não encontrado" >&2
      return "$(__goto_exit_code ERR_DESTINY_NOT_FOUND)"
    }

    destino="$1"
  }
  
  destino=${destino/\~/$HOME}

  shift
  while [[ $# -gt 0 ]]; do
    destino="$destino/$1"
    shift
  done

  [[ ! -d $destino ]] && {
    echo "Diretório [$destino] não encontrado" >&2
    return "$(__goto_exit_code ERR_DIRECTORY_NOT_FOUND)"
  }

  cd "$destino" 2>/dev/null || {
    local cdErrorCode=$?
    echo -e "Erro ao acessar o diretório $destino"
    echo -e "Verifique as permissões e tente novamente"
    echo -e "Código de erro do comando 'cd': $cdErrorCode"
    return "$(__goto_exit_code ERR_DIRECTORY_ACCESS_DENIED)"
  }

  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_generate_return_code
## Parametros: $1 -> texto que representa o código que deve ser gerado para retorno
## Descrição.: retorna um códgo baseado no texto informado em $1. A ideia da função é dar mais semantica
##             para o retorno das funções melhorando a legibilidade. Essa função gera um código de retorno
##             que não deve ser retornada diretamente mas sim, após chamar essa função, deve ser retornado
##             o valor de $?:
##             Exemplo:
##               function fazAlgo() {
##                 // faz alguma coisa que gera um erro por exemplo
##                 __goto_generate_return_code ERROR_CODE_GENERICO # essa linha apenas gera o código
##                 return $?  # Essa linha de fato retorna o código gerado
##               }
##             Na prática, prefira o atalho "return $(__goto_exit_code X)" (ver __goto_exit_code logo
##             abaixo), que funciona em uma linha só e em qualquer ponto da função, inclusive dentro de
##             blocos de guarda.
##########################################################################################################
function __goto_generate_return_code() {
  case "${1:-}" in
    OK) return 0;;

    ERR_DESTINY_NOT_FOUND) return 10;;

    ERR_ALIAS_MISSING_ON_COMMAND) return 20;;
    ERR_ALIAS_NOT_FOUND) return 21;;
    ERR_ALIAS_ALREADY_EXISTS) return 22;;
    
    ERR_DIRECTORY_NOT_MAPPED) return 30;;
    ERR_DIRECTORY_ACCESS_DENIED) return 31;;
    ERR_DIRECTORY_NOT_FOUND) return 32;;
    ERR_DIRECTORY_MISSING_ON_COMMAND) return 33;;
    ERR_DIRECTORY_CANT_CREATE) return 34;;
    
    ERR_FILE_ALREADY_EXISTS) return 40;;
    ERR_FILE_ACCESS_DENIED) return 41;;
    ERR_FILE_NOT_VALID) return 42;;
    ERR_FILE_CANT_COPY) return 43;;
    *) return 1;;
  esac
}

##########################################################################################################
## Função....: __goto_exit_code
## Parametros: $1 -> texto que representa o código que deve ser gerado para retorno (ver
##             __goto_generate_return_code)
## Descrição.: Imprime (echo) o código numérico correspondente ao nome semântico informado, para ser usado
##             como "return $(__goto_exit_code X)" em qualquer ponto de uma função, inclusive dentro de
##             blocos de guarda ([[ ... ]] && { ... }). Isso não daria certo com uma função auxiliar que
##             ela mesma desse "return X" internamente: o return de uma função chamada só encerra a
##             própria função chamada, nunca quem a chamou.
##             Exemplo:
##               function fazAlgo() {
##                 [[ -z $1 ]] && {
##                   echo "parametro obrigatorio" >&2
##                   return "$(__goto_exit_code ERROR_CODE_GENERICO)"
##                 }
##               }
##########################################################################################################
function __goto_exit_code() {
  __goto_generate_return_code "$1"
  echo $?
}

##########################################################################################################
## Função....: __goto_choose_destiny
## Parametros: nenhum
## Descrição.: Função interna responsável por exibir os itens cadatrados no arquivo de destino em forma de
##             menu
##########################################################################################################
function __goto_choose_destiny() {
  local mapFile
  mapFile="$(__goto_get_destiny_file)"

  # Exibe as opções de mapeamentos
  mapfile -t opcoes < "$mapFile"
  # Exibe o menu interativo com as opções
  PS3="Escolha um diretório para ir: "
  select opt in "Sair" "${opcoes[@]}"; do
    case $opt in
      "Sair")
        echo "Saindo..."
        return "$(__goto_exit_code OK)"
        ;;
      *)
        # Extrai o diretório da opção selecionada
        diretorio=$(echo "$opt" | cut -d '=' -f 2)
        # Verifica se o diretório existe
        if [ -d "$diretorio" ]; then
          echo "Navegando para $diretorio..."
          cd "$diretorio" || {
            echo "Não foi possível navegar para o diretório selecionado" >&2
            return "$(__goto_exit_code ERR_DIRECTORY_ACCESS_DENIED)"
          }
          break
        else
          echo "O diretório '$diretorio' não existe!" >&2
          return "$(__goto_exit_code ERR_DIRECTORY_NOT_FOUND)"
        fi
        ;;
    esac
  done
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_show_destinies
## Parametros: nenhum
## Descrição.: Função interna responsável por exibir os itens cadatrados no arquivo de destino
##########################################################################################################
function __goto_show_destinies() {
  local mapFile
  mapFile="$(__goto_get_destiny_file)"
  awk -F'=' '
    BEGIN {
      _keywidth = 0
      _valuewidth = 0
      _idx=0
      BG_GRAY="\033[48;5;238m"
      BG_DEFAULT="\033[49m"
      RESET="\033[0m"
    }

    {
      _keys[_idx] = $1
      _values[_idx] = $2
      _currentKeyWidth = length($1)
      _currentValueWidth = length($2)
      _keywidth = _currentKeyWidth > _keywidth ? _currentKeyWidth : _keywidth
      _valuewidth = _currentValueWidth > _valuewidth ? _currentValueWidth : _valuewidth
      _idx++
    }

    END {
      for (i=0; i<_idx; i++) {
        bg = i % 2 == 0 ? BG_DEFAULT : BG_GRAY
        printf " %s%" _keywidth "s     %-"_valuewidth"s%s \n", bg, _keys[i],_values[i], RESET
      }
    }' "$mapFile"
    return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_get_destiny
## Parametros: nome da chave (apelido) do destino a ser obtido
## Descrição.: Função interna responsável por obter o destino correspondente a uma chave
##########################################################################################################
function __goto_get_destiny() {
  local mapFile
  mapFile="$(__goto_get_destiny_file)"
  local destAlias=$1
  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_get_destiny
    return "$(__goto_exit_code ERR_ALIAS_MISSING_ON_COMMAND)"
  }
  local destino
  destino=$(awk -v dest="$destAlias" -F'=' '$1 == dest {print $2}' "$mapFile")
  [[ -z "$destino" ]] && {
    echo "" >&2 # Se o destino não for encontrado, é exibida uma mensagem em branco e retornado um código de erro
    return "$(__goto_exit_code ERR_ALIAS_NOT_FOUND)"
  }
  
  echo "$destino"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_get_destiny_file
## Parametros: nenhum
## Descrição.: Função interna que visa garantir a existencia do arquivo de mapeamento. A função busca o
##            arquivo apontado pela variável de ambiente GOTO_DESTINY_FILE e caso ela não exista, o padrão
##            $HOME/.goto-cfg/goto-destinies é utilizado.
##########################################################################################################
function __goto_get_destiny_file() {
  local mapFile="${GOTO_DESTINY_FILE:-$HOME/.goto-cfg/goto-destinies}"
  [[ -f "$mapFile" ]] || {
    if ! mkdir -p "$(dirname "$mapFile")"; then
      echo -e "Não foi possível criar o arquivo de mapeamento" >&2
      return "$(__goto_exit_code ERR_DIRECTORY_CANT_CREATE)"
    fi
    touch "$mapFile"
  }
  echo "$mapFile"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_check_destinies
## Parametros: nenhum
## Descrição.: Função interna que provê a funcionalidade de validação dos mapeamentos realizados. Mostra
##            na tela quais mapeamentos não existem ou, se tudo estiver ok, exibe uma mensagem informando
##            que está tudo correto.
##########################################################################################################
function __goto_check_destinies() {
  local returnValue=OK
  local mapFile
  mapFile="$(__goto_get_destiny_file)"
  local status="ok"
  while IFS="=" read -r chave destino || [[ -n $chave || -n $destino ]]; do
    [[ -d $destino ]] || {
      status="invalid"
      returnValue=ERR_DIRECTORY_NOT_FOUND
      echo -e "O destino '$destino' apontado por '$chave' não foi encontrado" >&2
    }
  done < "$mapFile"

  [[ $status == "ok" ]] && { 
    echo "Todos os mapeamentos são válidos" 
  }

  return "$(__goto_exit_code $returnValue)"
}

##########################################################################################################
## Função....: __goto_purge_destinies
## Parametros: nenhum
## Descrição.: Remove todos os mapeamentos inválidos
##########################################################################################################
function __goto_purge_destinies() {
  local mapFile
  mapFile="$(__goto_get_destiny_file)"
  local fileWasPurged="no"
  local createBkp="yes"
  while IFS="=" read -r chave destino || [[ -n $chave || -n "$destino" ]]; do
    [[ -d $destino ]] || {
      fileWasPurged="yes"
      [[ $createBkp == "yes" ]] && {
        __goto_copy_destiny_file
        createBkp="no-more"
      }
      __goto_remove_destiny "$chave"
    }
  done < "$mapFile"

  [[ $fileWasPurged == 'yes' ]] && { 
    __goto_sort_destiny_file
    echo -e "Arquivo de destinos expurgado com sucesso!"
  } || echo -e "Sem nada a expurgar"

    return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_copy_destiny_file
## Parametros: $1 -> (opcional) - Nome do arquivo de destino da cópia. Se omitido, usa o backup automático
##             padrão ($mapFile~), sobrescrevendo a cópia anterior.
##             $2 -> (opcional) - recebe -f ou --force para permitir a sobrescrita do arquivo de destino.
## Descrição.: Copia o arquivo de mapeamento para o destino informado, criando o diretório de destino se
##             necessário. É o mecanismo usado tanto pelo backup automático (antes de qualquer operação
##             que altera o arquivo, como -a/-d/-u/-r/-p) quanto por pedidos futuros de backup manual com
##             nome de arquivo próprio. Se o arquivo destino já existir, é exibida uma mensagem de erro e
##             a cópia é cancelada, a menos que --force seja usado.
##########################################################################################################
function __goto_copy_destiny_file() {
  local bkpSourceFile
  bkpSourceFile="$(__goto_get_destiny_file)"
  local bkpDestinyFile="${1:-$(__goto_get_destiny_file)~}"
  local overwrite="no"
  [[ ${2,,} == '-f' || ${2,,} == '--force' || "$bkpSourceFile~" == "$bkpDestinyFile" ]] && {
    overwrite="yes"
  }

  [[ -e "$bkpDestinyFile" ]] && {
    [[ $overwrite == 'no' ]] && {
      echo -e "Não foi possível criar o backup. Arquivo $bkpDestinyFile já existe no destino"
      return "$(__goto_exit_code ERR_FILE_ALREADY_EXISTS)"
    }

    [[ ! -f "$bkpDestinyFile" ]] && {
      echo -e "Não foi possível criar o backup. $bkpDestinyFile não é um arquivo válido"
      return "$(__goto_exit_code ERR_FILE_NOT_VALID)"
    }

    [[ ! -w "$bkpDestinyFile" ]] && {
    echo -e "Não foi possível criar o backup. Acesso negado em $bkpDestinyFile"
    return "$(__goto_exit_code ERR_FILE_ACCESS_DENIED)"
    }
  }

  [[ ! -e "$bkpDestinyFile" ]] && {
    local bkpDestinyDir
    bkpDestinyDir="$(dirname "$bkpDestinyFile")"

    [[ ! -d "$bkpDestinyDir" ]] && {
      if ! mkdir -p "$bkpDestinyDir"; then
        echo -e "Não foi possível criar o backup. Não foi possível criar o diretório $bkpDestinyDir"
        return "$(__goto_exit_code ERR_DIRECTORY_CANT_CREATE)"
      fi
    }

    [[ ! -w "$bkpDestinyDir" || ! -x "$bkpDestinyDir" ]] && {
      echo -e "Não foi possível criar o backup. Acesso negado em $bkpDestinyFile"
      return "$(__goto_exit_code ERR_FILE_ACCESS_DENIED)"
    }
  }

  if ! \cp "$bkpSourceFile" "$bkpDestinyFile"; then
    echo -e "Não foi possível criar o backup.\nErro desconhecido durante a copia de $bkpSourceFile para $bkpDestinyFile"
    return "$(__goto_exit_code ERR_FILE_CANT_COPY)"
  fi

  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_add_destiny
## Parametros: 
##   $1 -> diretório de destino a ser mapeado
##   $2 -> chave (apelido) usado no mapeamento
## Descrição.: Adiciona uma entrada no arquivo de mapeamento.
##########################################################################################################
function __goto_add_destiny() {
  local destMap
  destMap="$(__goto_get_destiny_file)"
  local dest=$1
  local destAlias=$2

  [[ -z $dest ]] && {
    echo 'Informe o diretório de destino' >&2
    __goto_manual_use
    __goto_manual_add_destiny
    return "$(__goto_exit_code ERR_DIRECTORY_MISSING_ON_COMMAND)"
  }

  [[ -d $dest ]] || {
    echo "Diretório [$dest] não encontrado" >&2
    __goto_manual_use
    __goto_manual_add_destiny
    return "$(__goto_exit_code ERR_DIRECTORY_NOT_FOUND)"
  }

  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_add_destiny
    return "$(__goto_exit_code ERR_ALIAS_MISSING_ON_COMMAND)"
  }

  grep -q "^$destAlias=" "$destMap" && {
    echo "Destino [$destAlias] já existe" >&2
    echo "Use -u --update para atualizar o destino" >&2
    __goto_manual_use
    __goto_manual_add_destiny
    return "$(__goto_exit_code ERR_ALIAS_ALREADY_EXISTS)"
  }

  echo "$destAlias=$(realpath "$dest")" >> "$destMap"
  __goto_sort_destiny_file

  echo "Destino [$destAlias] adicionado"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_remove_destiny
## Parametros:
##   $1 -> nome da chave (apelido) que será removido
## Descrição.: Remove uma entrada do arquivo de mapeamento.
##########################################################################################################
function __goto_remove_destiny() {
  local destMap
  destMap="$(__goto_get_destiny_file)"
  local destAlias=$1

  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_delete_destiny
    return "$(__goto_exit_code ERR_ALIAS_MISSING_ON_COMMAND)"
  }

  grep -q "^$destAlias=" "$destMap" || {
    echo "Destino [$destAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_delete_destiny
    return "$(__goto_exit_code ERR_ALIAS_NOT_FOUND)"
  }

  local tmpFile
  tmpFile=$(mktemp "${TMPDIR:-/tmp}/goto-destinies.XXXXXX")
  grep -v "^$destAlias=" "$destMap" > "$tmpFile"
  mv "$tmpFile" "$destMap"

  echo "Destino [$destAlias] removido"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_update_destiny
## Parametros:
##   $1 -> nome da chave (apelido) que será atualizada
##   $2 -> novo diretório que será atribuído a chave
## Descrição.: Atualiza um mapeamento.
##########################################################################################################
function __goto_update_destiny() {
  local destMap
  destMap="$(__goto_get_destiny_file)"
  local destAlias=$1
  local dir=$2

  [[ -z $dir ]] && {
    echo 'Informe o diretório de destino' >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return "$(__goto_exit_code ERR_DIRECTORY_MISSING_ON_COMMAND)"
  }

  [[ -d $dir ]] || {
    echo "Diretório [$dir] não encontrado" >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return "$(__goto_exit_code ERR_DIRECTORY_NOT_FOUND)"
  }
  
  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return "$(__goto_exit_code ERR_ALIAS_MISSING_ON_COMMAND)"
  }

  grep -q "^$destAlias=" "$destMap" || {
    echo "Destino [$destAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return "$(__goto_exit_code ERR_ALIAS_NOT_FOUND)"
  }

  local oldDir
  oldDir=$(__goto_get_destiny "$destAlias" 2> /dev/null)

  __goto_remove_destiny "$destAlias" > /dev/null 2>&1
  __goto_add_destiny "$dir" "$destAlias" > /dev/null 2>&1 || {
    __goto_add_destiny "$oldDir" "$destAlias" > /dev/null 2>&1
    echo "Não foi possível atualizar [$destAlias]. Mapeamento original restaurado." >&2
    return "$(__goto_exit_code ERR_DIRECTORY_NOT_FOUND)"
  }

  echo "Destino [$destAlias] atualizado"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_rename_destiny
## Parametros:
##   $1 -> nome da chave (apelido) que será renomeada
##   $2 -> nova chave (apelido) que será utlizada no mapeamento
## Descrição.: Renomeia a chave (apelido) de mapeamento.
##########################################################################################################
function __goto_rename_destiny() {
  local destMap
  destMap="$(__goto_get_destiny_file)"
  local oldAlias="$1"
  local newAlias="$2"

  [[ -z "$oldAlias" ]] && {
    echo "Necessário informar qual alias será renomeado"
    __goto_manual_use
    __goto_manual_rename_destiny
    return "$(__goto_exit_code ERR_ALIAS_MISSING_ON_COMMAND)"
  }

  [[ -z "$newAlias" ]] && {
    echo "Necessário informar o novo alias"
    __goto_manual_use
    __goto_manual_rename_destiny
    return "$(__goto_exit_code ERR_ALIAS_MISSING_ON_COMMAND)"
  }

  grep -q "^$oldAlias=" "$destMap" || {
    echo "Destino [$oldAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_rename_destiny
    return "$(__goto_exit_code ERR_ALIAS_NOT_FOUND)"
  }

  grep -q "^$newAlias=" "$destMap" && {
    echo "Destino [$newAlias] já existe" >&2
    __goto_manual_use
    __goto_manual_rename_destiny
    return "$(__goto_exit_code ERR_ALIAS_ALREADY_EXISTS)"
  }

  local destAlias
  destAlias=$(__goto_get_destiny "$oldAlias")
  [[ -z $destAlias ]] && {
    echo "Não foi possível renomear [$destAlias]. Destino não existe"
    return "$(__goto_exit_code ERR_ALIAS_ALREADY_EXISTS)"
  }

  __goto_remove_destiny "$oldAlias" > /dev/null 2>&1
  __goto_add_destiny "$destAlias" "$newAlias" > /dev/null 2>&1 || {
    __goto_add_destiny "$destAlias" "$oldAlias" > /dev/null 2>&1
    echo "Não foi possível renomear [$oldAlias] para [$newAlias]. Mapeamento original restaurado." >&2
    return "$(__goto_exit_code ERR_ALIAS_ALREADY_EXISTS)"
  }

  echo "Destino [$oldAlias] renomeado para [$newAlias]"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_question_folder
## Parametros: (opcional) diretório que se deseja verificar
## Descrição.: Verifica se o diretório informado está mapeado.
##             Se não for informado um parametro, o diretório atual é utilizado.
##########################################################################################################
function __goto_question_folder() {
  local destMap
  destMap="$(__goto_get_destiny_file)"
  local amIInMapping="$1"

  if [[ -z $amIInMapping ]]; then
    amIInMapping="$(pwd)"
  else
    amIInMapping="$(realpath "$amIInMapping")"
  fi

  local mapping
  mapping="$(grep "^.*=$amIInMapping$" "$destMap")"
  if [[ -n "$mapping" ]]; then
    # o mesmo diretório pode estar mapeado sob mais de um apelido (o -a/--add
    # só valida apelido duplicado, não diretório duplicado); junta todas as
    # chaves encontradas em vez de mostrar só a primeira linha do grep
    local chaves=""
    local linha
    while IFS= read -r linha; do
      local chave="${linha%%=*}"
      chaves="${chaves:+$chaves, }$chave"
    done <<< "$mapping"

    if [[ $mapping == *$'\n'* ]]; then
      echo "$amIInMapping está mapeado nas chaves $chaves"
    else
      echo "$amIInMapping está mapeado na chave $chaves"
    fi
    return "$(__goto_exit_code OK)"
  else
    echo "$amIInMapping não está mapeado"
    return "$(__goto_exit_code ERR_DIRECTORY_NOT_MAPPED)"
  fi
}

##########################################################################################################
## Função....: __goto_sort_destiny_file
## Parametros: nenhum
## Descrição.: Ordena o conteúdo do arquivo de mepamento.
##########################################################################################################
function __goto_sort_destiny_file() {
  local destMap
  destMap="$(__goto_get_destiny_file)"
  local tmpFile
  tmpFile=$(mktemp "${TMPDIR:-/tmp}/goto-destinies.XXXXXX")

  sort "$destMap" > "$tmpFile"
  mv "$tmpFile" "$destMap"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função....: __goto_generate_backup_name
## Parametros: nenhum
## Descrição.: Gera um nome de arquivo disponível no diretório padrão de backup do script (o diretório
##             "backup" ao lado do arquivo de mapeamento), garantindo unicidade e criação atômica via
##             mktemp em vez de um laço manual de tentativa e erro baseado em timestamp.
##########################################################################################################
function __goto_generate_backup_name() {
  local bkpPath
  bkpPath="$(dirname "$(__goto_get_destiny_file)")/backup"

  mkdir -p "$bkpPath" || {
    echo "Não foi possível criar o diretório de backup $bkpPath" >&2
    return "$(__goto_exit_code ERR_DIRECTORY_CANT_CREATE)"
  }
  local isoDate="$(date +%FT%R:%S%z)"
  # sem echo/return explícitos de propósito: por ser a última instrução da
  # função, tanto o stdout (o caminho gerado) quanto o status de saída do
  # mktemp atravessam para quem chamou esta função, igual a qualquer comando
  # Unix bem comportado (echo do resultado + exit code de sucesso/falha).
  # Tornar isso explícito exigiria capturar o resultado antes de checar o
  # status, sob risco de mascarar uma falha do mktemp (ex.: sem permissão)
  # como sucesso.
  mktemp "$bkpPath/goto-destinies-bkp-$isoDate-XXXXXX"
}

##########################################################################################################
## Função....: __goto_backup_destiny_file
## Parametros: $1 (opcional) -> Nome do arquivo de destino do backup. Se omitido, um nome é calculado por
##             __goto_generate_backup_name.
##             $2 (opcional) -> recebe -f ou --force para permitir a sobrescrita do arquivo de destino.
## Descrição.: Cria um backup deliberado do arquivo de mapeamento (goto -b/--backup), em um destino que
##             não é sobrescrito pelo backup automático das operações de edição (-a/-d/-u/-r/-p).
##########################################################################################################
function __goto_backup_destiny_file() {
  local bkpDestiny="$1"
  local force="$2"

  [[ -z $bkpDestiny ]] && {
    bkpDestiny="$(__goto_generate_backup_name)" || return $?
    # mktemp já criou o arquivo vazio pra reservar o nome com segurança; forçar
    # aqui é seguro, pois não existe conteúdo de usuário sendo sobrescrito
    force="--force"
  }

  __goto_copy_destiny_file "$bkpDestiny" "$force" || return $?

  echo "Backup criado com sucesso em: $bkpDestiny"
  return "$(__goto_exit_code OK)"
}

##########################################################################################################
## Função...: __goto_completion
## Descrição: Provê a funciolidade "completar" para o script ao pressionar a tecla <TAB>.
##########################################################################################################
function __goto_completion() {
  local destFile
  destFile="$(__goto_get_destiny_file)"
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}
  local registeredDestinies
  registeredDestinies="$(awk -F'=' '{print $1}' "$destFile")"
  local options="${__GOTO_FLAGS[*]}"
  COMPREPLY=( )

  case "$prev" in
    goto)
      if [[ ! "$cur" =~ ^- ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$registeredDestinies" -- "$cur")
        mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <(compgen -d -- "$cur")
      else
        mapfile -t COMPREPLY < <(compgen -W "$options" -- "$cur")
      fi
      ;;
    -d|--delete|-u|--update|-r|--rename|-g|--get)
      mapfile -t COMPREPLY < <(compgen -W "$registeredDestinies" -- "$cur")
      ;;
    -a|--add|-q|--question|-b|--backup)
      mapfile -t COMPREPLY < <(compgen -d -- "$cur")
      ;;
    *)
      local mappedItem=${COMP_WORDS[1]}
      local folder
      folder=$(awk -F'=' -v alias="$mappedItem" '$1 == alias {print $2}' "$destFile")
      [[ -z "$folder" ]] && folder="$mappedItem"
      if [[ -d $folder ]]; then
        for ((i=2; i < COMP_CWORD; i++)); do
          folder="$folder/${COMP_WORDS[i]}"
        done

        if [[ -d $folder ]]; then
          local destinies
          destinies=$(eza -D "$folder" | xargs -n1 basename 2>/dev/null)
          [[ -n $destinies ]] && mapfile -t COMPREPLY < <(compgen -W "$destinies" -- "$cur")
        fi
      fi
      ;;
  esac

  return "$(__goto_exit_code OK)"
}

complete -o nosort -F __goto_completion goto


##########################################################################################################
## Funções de ajuda
##########################################################################################################
function __goto_manual_header() {
  echo -e "A principal função do script é permitir a navegação rápida entre"
  echo -e "diretórios mapeados no arquivo 'destinos.map'"
  echo -e "Cada linha no arquivo representa um mapeamento entre um apelido e"
  echo -e "um diretório no formato 'apelido=diretório'"
  echo -e "O script também permite a edição do arquivo de mapeamento, adição,"
  echo -e "remoção e atualização de destinos"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_use() {
  echo -e "\nUso:"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_browse_directory() {
  echo -e "\nNavega para um diretório mapeado:"
  echo -e "\tgoto <apelido> [subdiretório]"
  echo -e "\t\t<apelido> - apelido do diretório mapeado (use <TAB> para completar)"
  echo -e "\t\t[subdiretório] - subdiretório do diretório mapeado (use <TAB> para completar)"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_show_directories() {
  echo -e "\nMostra os diretórios mapeados:"
  echo -e "\tgoto -s|--show-destinies"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_get_destiny() {
  echo -e "\nObtém o diretório mapeado correspondente a um apelido:"
  echo -e "\tgoto -g|--get <apelido>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado (use <TAB> para completar)"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_check_destinies() {
  echo -e "\nCheca se todos os diretórios mapeados ainda existem:"
  echo -e "\tgoto -c|--check-destinies"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_purge_destinies() {
  echo -e "\nRemove todos os mapeamentos que no qual o diretório destino não existe"
  echo -e "\tgoto -p|--purge-destinies"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_edit_destinies() {
  echo -e "\nAbre o arquivo de mapeamento para edição (com o VI):"
  echo -e "\tgoto -e|--edit"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_add_destiny() {
  echo -e "\nAdiciona um novo destino:"
  echo -e "\tgoto -a|--add <diretório> <apelido>"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido já existir, é exibida uma mensagem de erro"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_delete_destiny() {
  echo -e "\nRemove um destino:"
  echo -e "\tgoto -d|--delete <apelido>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_update_destiny() {
  echo -e "\nAtualiza um destino:"
  echo -e "\tgoto -u|--update <apelido> <diretório>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_rename_destiny() {
  echo -e "\nRenomeia um destino:"
  echo -e "\tgoto -r|--rename <antigo> <novo>"
  echo -e "\t\t<antigo> - antigo apelido cadastrado"
  echo -e "\t\t<novo> - novo apelido que substituirá o <antigo>"
  echo -e "\t* Se o apelido antigo não existir, é exibida uma mensagem de erro"
  echo -e "\t* Se o apelido novo já existir, é exibida uma mensagem de erro"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_question_folder() {
  echo -e "\nVerifica se existe um mapeamento definido para o diretório atual"
  echo -e "\tgoto -q|--question [diretório]"
  echo -e "\t\t[diretorio] - (opcional) diretório que se deseja verificar."
  echo -e "\t* Se nenhum diretório for informado, será utilizado o diretório atual"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_show_map_file() {
  echo -e "\nExibe o local do arquivo de destinos:"
  echo -e "\tgoto -m|--map-file"
  echo -e "\t* O arquivo é definido pela variável de ambiente: GOTO_DESTINY_FILE"
  echo -e "\t  e caso esta não exista, utiliza o arquivo padrão: \$HOME/.goto-destinies"
  echo -e "\t* Cria o arquivo se não existir"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_backup_destiny_file() {
  echo -e "\nCria um backup avulso do arquivo de mapeamento, que não é sobrescrito pelo"
  echo -e "backup automático feito antes de -a/-d/-u/-r/-p:"
  echo -e "\tgoto -b|--backup [arquivo] [-f|--force]"
  echo -e "\t\t[arquivo] - (opcional) caminho de destino do backup"
  echo -e "\t\t            se omitido, um nome é gerado automaticamente no diretório de backup"
  echo -e "\t\t[-f|--force] - (opcional) sobrescreve o arquivo de destino se ele já existir"
  echo -e "\t* Se o arquivo de destino já existir e --force não for usado, é exibida uma mensagem de erro"
  return "$(__goto_exit_code OK)"
}

function __goto_manual_show_manual() {
  echo -e "\nExibe o manual:"
  echo -e "\tgoto -h|--help"
  return "$(__goto_exit_code OK)"
}

function __goto_manual() {
  __goto_manual_header
  __goto_manual_use
  __goto_manual_browse_directory
  __goto_manual_show_directories
  __goto_manual_get_destiny
  __goto_manual_check_destinies
  __goto_manual_purge_destinies
  __goto_manual_edit_destinies
  __goto_manual_add_destiny
  __goto_manual_delete_destiny
  __goto_manual_update_destiny
  __goto_manual_rename_destiny
  __goto_manual_question_folder
  __goto_manual_show_map_file
  __goto_manual_backup_destiny_file
  __goto_manual_show_manual
  return "$(__goto_exit_code OK)"
}
