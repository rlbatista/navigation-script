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
    __goto_generate_return_code OK
    return $?
  }

  local mapfile
  mapfile="$(__goto_get_destiny_file)"

  [[ $1 == '-e' || $1 == '--edit' ]] && {
    vi "$mapfile"
    __goto_generate_return_code OK
    return $?
  }

  [[ $1 == '-s' || $1 == '--show-destinies' ]] && {
    __goto_show_destinies
    __goto_generate_return_code OK
    return $?
  }

  [[ $1 == '-g' || $1 == '--get' ]] && {
    __goto_get_destiny "$2"
    return $?
  }

  [[ $1 == '-c' || $1 == '--check-destinies' ]] && {
    __goto_check_destinies
    return $?
  }

  [[ $1 == '-p' || $1 == '--purge-destinies' ]] && {
    __goto_purge_destinies
    return $?
  }

  [[ $1 == '-a' || $1 == '--add' ]] && {
    __goto_create_bkp
    __goto_add_destiny "$2" "$3"
    return $?
  }

  [[ $1 == '-d' || $1 == '--delete' ]] && {
    __goto_create_bkp
    __goto_remove_destiny "$2"
    return $?
  }

  [[ $1 == '-u' || $1 == '--update' ]] && {
    __goto_create_bkp
    __goto_update_destiny "$2" "$3"
    return $?
  }

  [[ $1 == '-r' || $1 == '--rename' ]] && {
    __goto_create_bkp
    __goto_rename_destiny "$2" "$3"
    return $?
  }

  [[ $1 == '-q' || $1 == '--question' ]] && {
    __goto_question_folder "$2"
    return $?
  }

  [[ $1 == '-m' || $1 == '--map-file' ]] && {
    __goto_get_destiny_file
    return $?
  }

  local destino
  destino=$(__goto_get_destiny "$1" 2> /dev/null)

  [[ -z $destino ]] && {
    [[ ! -d $1 ]] && {
      echo "Destino [$1] não encontrado" >&2
      __goto_generate_return_code ERR_DESTINY_NOT_FOUND
      return $?
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
    __goto_generate_return_code ERR_DIRECTORY_NOT_FOUND
    return $?
  }

  cd "$destino" 2>/dev/null || {
    local cdErrorCode=$?
    echo -e "Erro ao acessar o diretório $destino"
    echo -e "Verifique as permissões e tente novamente"
    echo -e "Código de erro do comando 'cd': $cdErrorCode"
    __goto_generate_return_code ERR_DIRECTORY_ACCESS_DENIED
    return $?
  }

  __goto_generate_return_code OK
  return $?
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
    
    ERR_FILE_ALREADY_EXISTS) return 40;;
    ERR_FILE_ACCESS_DENIED) return 41;;
    ERR_FILE_NOT_VALID) return 42;;
    ERR_FILE_CANT_COPY) return 43;;
    *) return 1;;
  esac
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
        __goto_generate_return_code OK
        return $?
        ;;
      *)
        # Extrai o diretório da opção selecionada
        diretorio=$(echo "$opt" | cut -d '=' -f 2)
        # Verifica se o diretório existe
        if [ -d "$diretorio" ]; then
          echo "Navegando para $diretorio..."
          cd "$diretorio" || {
            echo "Não foi possível navegar para o diretório selecionado" >&2
            __goto_generate_return_code ERR_DIRECTORY_ACCESS_DENIED
            return $?
          }
          break
        else
          echo "O diretório '$diretorio' não existe!" >&2
          __goto_generate_return_code ERR_DIRECTORY_NOT_FOUND
          return $?
        fi
        ;;
    esac
  done
  __goto_generate_return_code OK
  return $?
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
      BD_DEFAULT="\033[49m"
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
    __goto_generate_return_code OK
    return $?
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
    __goto_generate_return_code ERR_ALIAS_MISSING_ON_COMMAND
    return $?
  }
  local destino
  destino=$(awk -v dest="$destAlias" -F'=' '$1 == dest {print $2}' "$mapFile")
  [[ -z "$destino" ]] && {
    echo "" >&2 # Se o destino não for encontrado, é exibida uma mensagem em branco e retornado um código de erro
    __goto_generate_return_code ERR_ALIAS_NOT_FOUND
    return $?
  }
  
  echo "$destino"
  __goto_generate_return_code OK
  return $?
}

##########################################################################################################
## Função....: __goto_get_destiny_file
## Parametros: nenhum
## Descrição.: Função interna que visa garantir a existencia do arquivo de mapeamento. A função busca o
##            arquivo apontado pela variável de ambiente GOTO_DESTINY_FILE e caso ela não exista, o padrão
##            $HOME/.goto-destinies é utilizado.
##########################################################################################################
function __goto_get_destiny_file() {
  local mapFile="${GOTO_DESTINY_FILE:-$HOME/.goto-destinies}"
  [[ -f "$mapFile" ]] || {
    touch "$mapFile"
  }
  echo "$mapFile"
  __goto_generate_return_code OK
  return $?
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

  __goto_generate_return_code $returnValue
  return $?
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
        __goto_create_bkp
        createBkp="no-more"
      }
      __goto_remove_destiny "$chave"
    }
  done < "$mapFile"

  [[ $fileWasPurged == 'yes' ]] && { 
    __goto_sort_destiny_file
    echo -e "Arquivo de destinos expurgado com sucesso!"
  } || echo -e "Sem nada a expurgar"

    __goto_generate_return_code OK
    return $?
}

##########################################################################################################
## Função....: __goto_create_bkp
## Parametros: $1 -> (opcional) - Nome do arquivo que será utilizado como destino do backup.
##             $2 -> (opcional) - recebe -f ou --force para permitir a sobrescrita do arquivo de destino.
## Descrição.: Provê a funcionalidade de backup do arquivo de destino. Toda operação do script que altera
##            de alguma forma o conteúdo do arquivo, é feita uma cópia antes. O script mantém apenas uma
##            cópia. Se o arquivo destino já existir, é exibida uma mensagem de erro o backup é cancelado.
##########################################################################################################
function __goto_create_bkp() {
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
      __goto_generate_return_code ERR_FILE_ALREADY_EXISTS
      return $?
    }

    [[ ! -f "$bkpDestinyFile" ]] && {
      echo -e "Não foi possível criar o backup. $bkpDestinyFile não é um arquivo válido"
      __goto_generate_return_code ERR_FILE_NOT_VALID
      return $?
    }

    [[ ! -w "$bkpDestinyFile" ]] && {
    echo -e "Não foi possível criar o backup. Acesso negado em $bkpDestinyFile"
    __goto_generate_return_code ERR_FILE_ACCESS_DENIED
    return $?
    }
  }

  [[ ! -e "$bkpDestinyFile" ]] && {
    local bkpDestinyDir
    bkpDestinyDir="$(dirname "$bkpDestinyFile")"
    [[ ! -w "$bkpDestinyDir" || ! -x "$bkpDestinyDir" ]] && {
      echo -e "Não foi possível criar o backup. Acesso negado em $bkpDestinyFile"
      __goto_generate_return_code ERR_FILE_ACCESS_DENIED
      return $?
    }
  }

  if ! \cp "$bkpSourceFile" "$bkpDestinyFile"; then
    echo -e "Não foi possível criar o backup.\nErro desconhecido durante a copia de $bkpSourceFile para $bkpDestinyFile"
    __goto_generate_return_code ERR_FILE_CANT_COPY
    return $?
  fi

  __goto_generate_return_code OK
  return $?
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
    __goto_generate_return_code ERR_DIRECTORY_MISSING_ON_COMMAND
    return $?
  }

  [[ -d $dest ]] || {
    echo "Diretório [$dest] não encontrado" >&2
    __goto_manual_use
    __goto_manual_add_destiny
    __goto_generate_return_code ERR_DIRECTORY_NOT_FOUND
    return $?
  }

  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_add_destiny
    __goto_generate_return_code ERR_ALIAS_MISSING_ON_COMMAND
    return $?
  }

  grep -q "^$destAlias=" "$destMap" && {
    echo "Destino [$destAlias] já existe" >&2
    echo "Use -u --update para atualizar o destino" >&2
    __goto_manual_use
    __goto_manual_add_destiny
    __goto_generate_return_code ERR_ALIAS_ALREADY_EXISTS
    return $?
  }

  echo "$destAlias=$(realpath "$dest")" >> "$destMap"
  __goto_sort_destiny_file

  echo "Destino [$destAlias] adicionado"
  __goto_generate_return_code OK
  return $?
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
    __goto_generate_return_code ERR_ALIAS_MISSING_ON_COMMAND
    return $?
  }

  grep -q "^$destAlias=" "$destMap" || {
    echo "Destino [$destAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_delete_destiny
    __goto_generate_return_code ERR_ALIAS_NOT_FOUND
    return $?
  }

  local tmpFile
  tmpFile=$(mktemp "${TMPDIR:-/tmp}/goto-destinies.XXXXXX")
  grep -v "^$destAlias=" "$destMap" > "$tmpFile"
  mv "$tmpFile" "$destMap"

  echo "Destino [$destAlias] removido"
  __goto_generate_return_code OK
  return $?
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
    __goto_generate_return_code ERR_DIRECTORY_MISSING_ON_COMMAND
    return $?
  }

  [[ -d $dir ]] || {
    echo "Diretório [$dir] não encontrado" >&2
    __goto_manual_use
    __goto_manual_update_destiny
    __goto_generate_return_code ERR_DIRECTORY_NOT_FOUND
    return $?
  }
  
  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_update_destiny
    __goto_generate_return_code ERR_ALIAS_MISSING_ON_COMMAND
    return $?
  }

  grep -q "^$destAlias=" "$destMap" || {
    echo "Destino [$destAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_update_destiny
    __goto_generate_return_code ERR_ALIAS_NOT_FOUND
    return $?
  }
  
  __goto_remove_destiny "$destAlias"  > /dev/null 2>&1
  __goto_add_destiny "$dir" "$destAlias" > /dev/null 2>&1

  echo "Destino [$destAlias] atualizado"
  __goto_generate_return_code OK
  return $?
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
    __goto_generate_return_code ERR_ALIAS_MISSING_ON_COMMAND
    return $?
  }

  [[ -z "$newAlias" ]] && {
    echo "Necessário informar o novo alias"
    __goto_manual_use
    __goto_manual_rename_destiny
    __goto_generate_return_code ERR_ALIAS_MISSING_ON_COMMAND
    return $?
  }

  grep -q "^$oldAlias=" "$destMap" || {
    echo "Destino [$oldAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_rename_destiny
    __goto_generate_return_code ERR_ALIAS_NOT_FOUND
    return $?
  }

  local destAlias
  destAlias=$(__goto_get_destiny "$oldAlias")
  [[ -z $destAlias ]] && {
    echo "Não foi possível renomear [$destAlias]. Destino não existe"
    __goto_generate_return_code ERR_ALIAS_ALREADY_EXISTS
    return $?
  }

  __goto_remove_destiny "$oldAlias" > /dev/null 2>&1
  __goto_add_destiny "$destAlias" "$newAlias" > /dev/null 2>&1
  echo "Destino [$oldAlias] renomeado para [$newAlias]"
  __goto_generate_return_code OK
  return $?
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

  if grep -q "^.*=$amIInMapping$" "$destMap"; then
    echo "$amIInMapping está mapeado"
    __goto_generate_return_code OK
    return $?
  else
    echo "$amIInMapping não está mapeado"
    __goto_generate_return_code ERR_DIRECTORY_NOT_MAPPED
    return $?
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
  __goto_generate_return_code OK
  return $?
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
  local options="-h --help --e --edit -s --show-destinies -g --get -c --check-destinies -p --purge-destinies -a --add -d --delete -u --update -r --rename -q --question -m --map-file"
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
    -a|--add|-q|--question)
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

  __goto_generate_return_code OK
  return $?
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
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_use() {
  echo -e "\nUso:"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_browse_directory() {
  echo -e "\nNavega para um diretório mapeado:"
  echo -e "\tgoto <apelido> [subdiretório]"
  echo -e "\t\t<apelido> - apelido do diretório mapeado (use <TAB> para completar)"
  echo -e "\t\t[subdiretório] - subdiretório do diretório mapeado (use <TAB> para completar)"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_show_directories() {
  echo -e "\nMostra os diretórios mapeados:"
  echo -e "\tgoto -s|--show-destinies"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_get_destiny() {
  echo -e "\nObtém o diretório mapeado correspondente a um apelido:"
  echo -e "\tgoto -g|--get <apelido>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado (use <TAB> para completar)"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_check_destinies() {
  echo -e "\nCheca se todos os diretórios mapeados ainda existem:"
  echo -e "\tgoto -c|--check-destinies"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_purge_destinies() {
  echo -e "\nRemove todos os mapeamentos que no qual o diretório destino não existe"
  echo -e "\tgoto -p|--purge-destinies"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_edit_destinies() {
  echo -e "\nAbre o arquivo de mapeamento para edição (com o VI):"
  echo -e "\tgoto -e|--edit"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_add_destiny() {
  echo -e "\nAdiciona um novo destino:"
  echo -e "\tgoto -a|--add <diretório> <apelido>"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido já existir, é exibida uma mensagem de erro"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_delete_destiny() {
  echo -e "\nRemove um destino:"
  echo -e "\tgoto -d|--delete <apelido>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_update_destiny() {
  echo -e "\nAtualiza um destino:"
  echo -e "\tgoto -u|--update <apelido> <diretório>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_rename_destiny() {
  echo -e "\nRenomeia um destino:"
  echo -e "\tgoto -r|--rename <antigo> <novo>"
  echo -e "\t\t<antigo> - antigo apelido cadastrado"
  echo -e "\t\t<novo> - novo apelido que substituirá o <antigo>"
  echo -e "\t* Se o apelido antigo não existir, é exibida uma mensagem de erro"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_question_folder() {
  echo -e "\nVerifica se existe um mapeamento definido para o diretório atual"
  echo -e "\tgoto -q|--question [diretório]"
  echo -e "\t\t[diretorio] - (opcional) diretório que se deseja verificar."
  echo -e "\t* Se nenhum diretório for informado, será utilizado o diretório atual"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_show_map_file() {
  echo -e "\nExibe o local do arquivo de destinos:"
  echo -e "\tgoto -m|--map-file"
  echo -e "\t* O arquivo é definido pela variável de ambiente: GOTO_DESTINY_FILE"
  echo -e "\t  e caso esta não exista, utiliza o arquivo padrão: \$HOME/.goto-destinies"
  echo -e "\t* Cria o arquivo se não existir"
  __goto_generate_return_code OK
  return $?
}

function __goto_manual_show_manual() {
  echo -e "\nExibe o manual:"
  echo -e "\tgoto -h|--help"
  __goto_generate_return_code OK
  return $?
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
  __goto_manual_show_manual
  __goto_generate_return_code OK
  return $?
}
