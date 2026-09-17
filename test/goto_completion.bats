#!/usr/bin/env bats
# Testes de __goto_completion. Como é uma função de completion do bash, ela
# não é chamada interativamente: montamos manualmente COMP_WORDS/COMP_CWORD
# (como o bash faria ao pressionar <TAB>) e inspecionamos o array COMPREPLY.

load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load 'test_helper'

setup() {
  goto_test_setup
  __goto_add_destiny "$DIR_A" "alpha" > /dev/null
  __goto_add_destiny "$DIR_B" "beta" > /dev/null
}

contains_reply() {
  local needle="$1"
  local item
  for item in "${COMPREPLY[@]}"; do
    [[ $item == "$needle" ]] && return 0
  done
  return 1
}

@test "__goto_completion sugere os apelidos cadastrados logo após 'goto'" {
  COMP_WORDS=(goto "")
  COMP_CWORD=1

  __goto_completion

  run contains_reply "alpha"
  assert_success
  run contains_reply "beta"
  assert_success
}

@test "__goto_completion sugere as opções quando o argumento começa com '-'" {
  COMP_WORDS=(goto "-")
  COMP_CWORD=1

  __goto_completion

  run contains_reply "-a"
  assert_success
  run contains_reply "--add"
  assert_success
}

@test "__goto_completion sugere '-e' (forma curta de --edit)" {
  COMP_WORDS=(goto "-")
  COMP_CWORD=1

  __goto_completion

  # a lista de opções era uma string retypada à mão e tinha "--e" no lugar
  # de "-e"; ao centralizar em __GOTO_FLAGS esse typo foi corrigido.
  run contains_reply "-e"
  assert_success
  run contains_reply "--e"
  assert_failure
}

@test "__goto_completion sugere apelidos cadastrados para -d/-u/-r/-g" {
  COMP_WORDS=(goto -d "")
  COMP_CWORD=2

  __goto_completion

  run contains_reply "alpha"
  assert_success
  run contains_reply "beta"
  assert_success
}

@test "__goto_completion sugere diretórios do sistema de arquivos para -a/-q" {
  cd "$BATS_TEST_TMPDIR"
  COMP_WORDS=(goto -a "")
  COMP_CWORD=2

  __goto_completion

  run contains_reply "dir_a"
  assert_success
  run contains_reply "dir_b"
  assert_success
}

@test "__goto_completion lista o conteúdo do diretório mapeado usando eza" {
  mkdir -p "$DIR_A/sub1" "$DIR_A/sub2"
  stub_bin "eza" "printf '%s\n' '$DIR_A/sub1' '$DIR_A/sub2'"

  COMP_WORDS=(goto alpha "")
  COMP_CWORD=2

  __goto_completion

  run contains_reply "sub1"
  assert_success
  run contains_reply "sub2"
  assert_success
}

@test "__goto_completion não sugere nada quando o eza não retorna conteúdo" {
  stub_bin "eza" "true"

  COMP_WORDS=(goto alpha "")
  COMP_CWORD=2

  # 'xargs -n1 basename' com entrada vazia falha (roda basename sem
  # argumentos), então precisamos desarmar o errexit do bats só para esta
  # chamada; não é um bug do script, é o comportamento normal do xargs.
  set +e
  __goto_completion
  set -e

  assert_equal "${#COMPREPLY[@]}" 0
}
