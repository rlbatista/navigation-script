 #!/bin/bash
function goto() {
  [[ $# == 0 ]] && {
    __goto_manual
    return 1
  }

  [[ $1 == '-h' || $1 == '--help' ]] && {
    __goto_manual
    return 0
  }

  local mapfile="$(__get_destiny_file)"

  [[ $1 == '-e' || $1 == '--edit' ]] && {
    vi $mapfile
    return 0
  }

  [[ $1 == '-s' || $1 == '--show-destinies' ]] && {
    bat $mapfile
    return 0 
  }

  [[ $1 == '-c' || $1 == '--check-destinies' ]] && {
    __check_destinies
    return $?
  }

  [[ -d $1 ]] && {
#   echo "Indo para diretório [$1]"
    cd $1
    return 0 
  }

  [[ $1 == '-a' || $1 == '--add' ]] && {
    __create_bkp
    __add_destiny $2 $3
    return $?
  }

  [[ $1 == '-d' || $1 == '--delete' ]] && {
    __create_bkp
    __remove_destiny $2
    return $?
  }

  [[ $1 == '-u' || $1 == '--update' ]] && {
    __create_bkp
    __update_destiny $2 $3
    return $?
  }

  destino=$(awk -v dest="$1" -F'=' '$1 == dest {print $2}' $mapfile)

  [[ -z $destino ]] && {
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

# echo "Indo para diretório mapeado [$destino]"
  cd $destino
  return 0
}

function __get_destiny_file() {
  echo "$HOME/scripts/destinos.map"
}

function __check_destinies() {
  local mapFile="$(__get_destiny_file)"
  local status=0
  while IFS="=" read -r chave destino; do
    [[ -d $destino ]] || {
      status=1
      echo -e "O destino '$destino' apontado por '$chave' não foi encontrado"
    }
  done < "$mapFile"

  [[ $status == 0 ]] && { 
    echo "Todos os mapeamentos são válidos" 
  }
}

function __create_bkp() {
  local destMap="$(__get_destiny_file)"
  local bkpFile="$(__get_destiny_file)~"

  [[ -f $destMap ]] || {
    touch $destMap
  }

  cp $destMap $bkpFile
}

function __add_destiny() {
  local destMap="$(__get_destiny_file)"
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
  __sort_destiny_file

  echo "Destino [$destAlias] adicionado"
}

function __remove_destiny() {
  local destMap="$(__get_destiny_file)"
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
}

function __update_destiny() {
  local destMap="$(__get_destiny_file)"
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
  
  __remove_destiny $destAlias 2>&1 > /dev/null
  __add_destiny $dir $destAlias 2>&1 > /dev/null

  echo "Destino [$destAlias] atualizado"
}

function __sort_destiny_file() {
  local destMap="$(__get_destiny_file)"
  local tmpFile=$(mktemp)

  sort $destMap > $tmpFile
  mv $tmpFile $destMap
}

function __goto_completion()
{
  local destFile="$(__get_destiny_file)"
  [[ -f $destFile ]] || {
    touch $destFile
  }

  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}
  local registeredDestinies="$(awk -F'=' '{print $1}' $destFile)"
  local registeredDestiniesAsArray=($registeredDestinies)
  local options="-h --help --e --edit -s --show-destinies -c --check-destinies -a --add -d --delete"

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
}

function __goto_manual_use() {
  echo -e "\nUso:"
}

function __goto_manual_browse_directory() {
  echo -e "\nNavega para um diretório mapeado:"
  echo -e "\tgoto <apelido> [subdiretório]"
  echo -e "\t\t<apelido> - apelido do diretório mapeado (use <TAB> para completar)"
  echo -e "\t\t[subdiretório] - subdiretório do diretório mapeado (use <TAB> para completar)"
}

function __goto_manual_show_directories() {
  echo -e "\nMostra os diretórios mapeados:"
  echo -e "\tgoto -s|--show-destinies"
}

function __goto_manual_check_destinies() {
  echo -e "\nCheca se todos os diretórios mapeados ainda existem:"
  echo -e "\tgoto -c|--check-destinies"
}

function __goto_manual_edit_destinies() {
  echo -e "\nAbre o arquivo de mapeamento para edição (com o VI):"
  echo -e "\tgoto -e|--edit"
}

function __goto_manual_add_destiny() {
  echo -e "\nAdiciona um novo destino:"
  echo -e "\tgoto -a|--add <diretório> <apelido>"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido já existir, é exibida uma mensagem de erro"
}

function __goto_manual_delete_destiny() {
  echo -e "\nRemove um destino:"
  echo -e "\tgoto -d|--delete <apelido>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
}

function __goto_manual_update_destiny() {
  echo -e "\nAtualiza um destino:"
  echo -e "\tgoto -u|--update <apelido> <diretório>"
  echo -e "\t\t<apelido> - apelido do diretório mapeado"
  echo -e "\t\t<diretório> - diretório a ser mapeado (use <TAB> para completar)"
  echo -e "\t* Se o apelido não existir, é exibida uma mensagem de erro"
}

function __goto_manual_show_manual() {
  echo -e "\nExibe o manual:"
  echo -e "\tgoto -h|--help"
}

function __goto_manual() {
  __goto_manual_header
  __goto_manual_use
  __goto_manual_browse_directory
  __goto_manual_show_directories
  __goto_manual_check_destinies
  __goto_manual_edit_destinies
  __goto_manual_add_destiny
  __goto_manual_delete_destiny
  __goto_manual_update_destiny
  __goto_manual_show_manual
}
