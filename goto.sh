 #!/bin/bash

##########################################################################################################
## Função...: goto
## Descrição: Função principal do script, onde a principal atividade é navegar para diretório mapeados em
##            em um arquivo (destinos.map).
## Dependencias: Este script depende do eza, batcat e vi
##########################################################################################################
function goto() {
  [[ $# == 0 ]] && {
    __goto_manual
    return 1
  }

  [[ $1 == '-h' || $1 == '--help' ]] && {
    __goto_manual
    return 0
  }

  local mapfile="$(__goto_get_destiny_file)"

  [[ $1 == '-e' || $1 == '--edit' ]] && {
    vi $mapfile
    return 0
  }

  [[ $1 == '-s' || $1 == '--show-destinies' ]] && {
    bat $mapfile
    return 0 
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
    __goto_add_destiny $2 $3
    return $?
  }

  [[ $1 == '-d' || $1 == '--delete' ]] && {
    __goto_create_bkp
    __goto_remove_destiny $2
    return $?
  }

  [[ $1 == '-u' || $1 == '--update' ]] && {
    __goto_create_bkp
    __goto_update_destiny $2 $3
    return $?
  }

  destino=$(awk -v dest="$1" -F'=' '$1 == dest {print $2}' $mapfile)

  [[ -z $destino ]] && {
    [[ -d $1 ]] && {
      cd $1
      return 0 
    }

    echo "Destino [$1] não encontrado" >&2
    return 2
  }
  
  destino=${destino/\~/$HOME}

  [[ -n $2 ]] && {
    destino="$destino/$2"
  }

  [[ ! -d $destino ]] && {
    echo "Diretório [$destino] não encontrado" >&2
    return 4
  }

  cd $destino
  return 0
}

##########################################################################################################
## Função....: __goto_get_destiny_file
## Parametros: nenhum
## Descrição.: Função interna que visa centralizar a localização do arquivo utilizado para o mapeamendo
##            dos diretórios. Caso queira mudar o local do arquivo, altere nesta função.
##########################################################################################################
function __goto_get_destiny_file() {
  echo "$HOME/scripts/destinos.map"
  return 0
}

##########################################################################################################
## Função....: __goto_check_destinies
## Parametros: nenhum
## Descrição.: Função interna que provê a funcionalidade de validação dos mapeamentos realizados. Mostra
##            na tela quais mapeamentos não existem ou, se tudo estiver ok, exibe uma mensagem informando
##            que está tudo correto.
##########################################################################################################
function __goto_check_destinies() {
  local returnValue=0
  local mapFile="$(__goto_get_destiny_file)"
  local status="ok"
  while IFS="=" read -r chave destino || [[ -n $chave || -n $destino ]]; do
    [[ -d $destino ]] || {
      status="invalid"
      returnValue=1
      echo -e "O destino '$destino' apontado por '$chave' não foi encontrado"
    }
  done < "$mapFile"

  [[ $status == "ok" ]] && { 
    echo "Todos os mapeamentos são válidos" 
  }

  return $returnValue
}

##########################################################################################################
## Função....: __goto_purge_destinies
## Parametros: nenhum
## Descrição.: Remove todos os mapeamentos inválidos
##########################################################################################################
function __goto_purge_destinies() {
  local mapFile="$(__goto_get_destiny_file)"
  local fileWasPurged="no"
  local createBkp="yes"
  while IFS="=" read -r chave destino || [[ -n $chave || -n $destino ]]; do
    [[ -d $destino ]] || {
      fileWasPurged="yes"
      [[ $createBkp == "yes" ]] && {
        __goto_create_bkp
        createBkp="no-more"
      }
      __goto_remove_destiny $chave
    }
  done < "$mapFile"

  [[ $fileWasPurged == 'yes' ]] && { 
    __goto_sort_destiny_file
    echo -e "Arquivo de destinos expurgado com sucesso!"
  } || echo -e "Sem nada a expurgar"

  return 0
}

##########################################################################################################
## Função....: __goto_create_bkp
## Parametros: nenhum
## Descrição.: Provê a funcionalidade de backup do arquivo de destino. Toda operação do script que altera
##            de alguma forma o conteúdo do arquivo, é feita uma cópia antes. O script mantém apenas uma
##            cópia.
##########################################################################################################
function __goto_create_bkp() {
  local destMap="$(__goto_get_destiny_file)"
  local bkpFile="$(__goto_get_destiny_file)~"

  [[ -f $destMap ]] || {
    touch $destMap
  }

  cp $destMap $bkpFile
  return 0
}

##########################################################################################################
## Função....: __goto_add_destiny
## Parametros: 
##   $1 -> diretório de destino a ser mapeado
##   $2 -> chave (apelido) usado no mapeamento
## Descrição.: Adiciona uma entrada no arquivo de mapeamento.
##########################################################################################################
function __goto_add_destiny() {
  local destMap="$(__goto_get_destiny_file)"
  local dest=$1
  local destAlias=$2

  [[ -z $dest ]] && {
    echo 'Informe o diretório de destino' >&2
    __goto_manual_use
    __goto_manual_add_destiny
    return 4
  }

  [[ -d $dest ]] || {
    echo "Diretório [$dest] não encontrado" >&2
    __goto_manual_use
    __goto_manual_add_destiny
    return 8
  }

  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_add_destiny
    return 16
  }

  [[ -f $destMap ]] || {
    touch $destMap
  }

  grep -q "^$destAlias=" $destMap && {
    echo "Destino [$destAlias] já existe" >&2
    echo "Use -u --update para atualizar o destino" >&2
    __goto_manual_use
    __goto_manual_add_destiny    
    return 32
  }

  echo "$destAlias=$(realpath $dest)" >> $destMap
  __goto_sort_destiny_file

  echo "Destino [$destAlias] adicionado"
  return 0
}

##########################################################################################################
## Função....: __goto_remove_destiny
## Parametros:
##   $1 -> nome da chave (apelido) que será removido
## Descrição.: Remove uma entrada do arquivo de mapeamento.
##########################################################################################################
function __goto_remove_destiny() {
  local destMap="$(__goto_get_destiny_file)"
  local destAlias=$1

  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_delete_destiny
    return 64
  }

  grep -q "^$destAlias=" $destMap || {
    echo "Destino [$destAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_delete_destiny
    return 128
  }

  sed -i "/^$destAlias=/d" $destMap
  echo "Destino [$destAlias] removido"
  return 0
}

##########################################################################################################
## Função....: __goto_update_destiny
## Parametros:
##   $1 -> nome da chave (apelido) que será atualizada
##   $2 -> novo diretório que será atribuído a chave
## Descrição.: Atualiza um mapeamento.
##########################################################################################################
function __goto_update_destiny() {
  local destMap="$(__goto_get_destiny_file)"
  local destAlias=$1
  local dir=$2

  [[ -z $dir ]] && {
    echo 'Informe o diretório de destino' >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return 256
  }

  [[ -d $dir ]] || {
    echo "Diretório [$dir] não encontrado" >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return 512
  }
  
  [[ -z $destAlias ]] && {
    echo 'Informe o apelido do destino' >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return 1024
  }

  grep -q "^$destAlias=" $destMap || {
    echo "Destino [$destAlias] não encontrado" >&2
    __goto_manual_use
    __goto_manual_update_destiny
    return 2048
  }
  
  __goto_remove_destiny $destAlias 2>&1 > /dev/null
  __goto_add_destiny $dir $destAlias 2>&1 > /dev/null

  echo "Destino [$destAlias] atualizado"
  return 0
}

##########################################################################################################
## Função....: __goto_sort_destiny_file
## Parametros: nenhum
## Descrição.: Ordena o conteúdo do arquivo de mepamento.
##########################################################################################################
function __goto_sort_destiny_file() {
  local destMap="$(__goto_get_destiny_file)"
  local tmpFile=$(mktemp)

  sort $destMap > $tmpFile
  mv $tmpFile $destMap
  return 0
}

##########################################################################################################
## Função...: __goto_completion
## Descrição: Provê a funciolidade "completar" para o script ao pressionar a tecla <TAB>.
##########################################################################################################
function __goto_completion()
{
  local destFile="$(__goto_get_destiny_file)"
  [[ -f $destFile ]] || {
    touch $destFile
  }

  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}
  local registeredDestinies="$(awk -F'=' '{print $1}' $destFile)"
  local registeredDestiniesAsArray=($registeredDestinies)
  local options="-h --help --e --edit -s --show-destinies -c --check-destinies -p --purge-destinies -a --add -d --delete"

  if [[ $prev == 'goto' && ! $cur =~ ^- ]] ; then
    COMPREPLY=( $(compgen -W "$registeredDestinies" -- $cur) )
    COMPREPLY+=( $(compgen -d -- $cur) )

  elif [[ $prev == 'goto' && $cur =~ ^- ]] ; then
    COMPREPLY=( $(compgen -W "$options" -- $cur) )

  elif [[ $prev == '-d' || $prev == '--delete' ]] ; then
    COMPREPLY=( $(compgen -W "$registeredDestinies" -- $cur) )

  elif [[ $prev == '-a' || $prev == '--add' ]] ; then
    COMPREPLY=( $(compgen -d -- $cur) )

  elif [[ $prev == '-u' || $prev == '--update' ]] ; then
    COMPREPLY=( $(compgen -W "$registeredDestinies" -- $cur) )
  
  elif [[ "(${registeredDestiniesAsArray[@]})" == *" ${prev} "* ]] ; then
    local folder=$(awk -F'=' -v alias="$prev" '$1 == alias {print $2}' $destFile)
    if [[ -d $folder ]]; then
      local destinies=$(eza -D $folder | xargs -n1 basename 2>/dev/null)
      [[ -n $destinies ]] && COMPREPLY=( $(compgen -W "$destinies" --  $cur) ) || COMPREPLY=( )
    fi

  else 
    COMPREPLY=( )
  fi

  return 0
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
  return 0
}

function __goto_manual_use() {
  echo -e "\nUso:"
  return 0
}

function __goto_manual_browse_directory() {
  echo -e "\nNavega para um diretório mapeado:"
  echo -e "\tgoto <apelido> [subdiretório]"
  echo -e "\t\t<apelido> - apelido do diretório mapeado (use <TAB> para completar)"
  echo -e "\t\t[subdiretório] - subdiretório do diretório mapeado (use <TAB> para completar)"
  return 0
}

function __goto_manual_show_directories() {
  echo -e "\nMostra os diretórios mapeados:"
  echo -e "\tgoto -s|--show-destinies"
  return 0
}

function __goto_manual_check_destinies() {
  echo -e "\nCheca se todos os diretórios mapeados ainda existem:"
  echo -e "\tgoto -c|--check-destinies"
  return 0
}

function __goto_manual_purge_destinies() {
  echo -e "\nRemove todos os mapeamentos que no qual o diretório destino não existe"
  echo -e "\tgoto -p|--purge-destinies"
  return 0
}

function __goto_manual_edit_destinies() {
  echo -e "\nAbre o arquivo de mapeamento para edição (com o VI):"
  echo -e "\tgoto -e|--edit"
  return 0
}

function __goto_manual_add_destiny() {
  echo -e "\nAdiciona um novo destino:"
  echo -e "\tgoto -a|--add <diretório> <apelido>"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido já existir, é exibida uma mensagem de erro"
  return 0
}

function __goto_manual_delete_destiny() {
  echo -e "\nRemove um destino:"
  echo -e "\tgoto -d|--delete <apelido>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
  return 0
}

function __goto_manual_update_destiny() {
  echo -e "\nAtualiza um destino:"
  echo -e "\tgoto -u|--update <apelido> <diretório>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
  return 0
}

function __goto_manual_show_manual() {
  echo -e "\nExibe o manual:"
  echo -e "\tgoto -h|--help"
  return 0
}

function __goto_manual() {
  __goto_manual_header
  __goto_manual_use
  __goto_manual_browse_directory
  __goto_manual_show_directories
  __goto_manual_check_destinies
  __goto_manual_purge_destinies
  __goto_manual_edit_destinies
  __goto_manual_add_destiny
  __goto_manual_delete_destiny
  __goto_manual_update_destiny
  __goto_manual_show_manual
  return 0
}
