#!/usr/bin/env bats
# Testes das funções de CRUD sobre o arquivo de mapeamentos:
# __goto_get_destiny_file, __goto_add_destiny, __goto_get_destiny,
# __goto_remove_destiny, __goto_update_destiny, __goto_rename_destiny e
# __goto_sort_destiny_file.

load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load 'test_helper'

setup() {
  goto_test_setup
}

# --- __goto_get_destiny_file ---

@test "__goto_get_destiny_file cria o arquivo apontado por GOTO_DESTINY_FILE se não existir" {
  rm -f "$GOTO_DESTINY_FILE"
  run __goto_get_destiny_file
  assert_success
  assert_output "$GOTO_DESTINY_FILE"
  assert [ -f "$GOTO_DESTINY_FILE" ]
}

@test "__goto_get_destiny_file usa \$HOME/.goto-destinies quando GOTO_DESTINY_FILE não está definida" {
  unset GOTO_DESTINY_FILE
  export HOME="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$HOME"
  run __goto_get_destiny_file
  assert_success
  assert_output "$HOME/.goto-destinies"
}

# --- __goto_add_destiny ---

@test "__goto_add_destiny adiciona um novo mapeamento com o caminho resolvido" {
  run __goto_add_destiny "$DIR_A" "alias1"
  assert_success
  assert_output --partial "[alias1] adicionado"
  run grep -qx "alias1=$(realpath "$DIR_A")" "$GOTO_DESTINY_FILE"
  assert_success
}

@test "__goto_add_destiny falha quando o diretório não é informado" {
  run __goto_add_destiny "" "alias1"
  assert_failure 33
  assert_output --partial "Informe o diretório de destino"
}

@test "__goto_add_destiny falha quando o diretório não existe" {
  run __goto_add_destiny "$BATS_TEST_TMPDIR/nao-existe" "alias1"
  assert_failure 32
}

@test "__goto_add_destiny falha quando o apelido não é informado" {
  run __goto_add_destiny "$DIR_A" ""
  assert_failure 20
}

@test "__goto_add_destiny falha quando o apelido já existe" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_add_destiny "$DIR_B" "alias1"
  assert_failure 22
  assert_output --partial "já existe"
}

# --- __goto_get_destiny ---

@test "__goto_get_destiny retorna o diretório mapeado" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_get_destiny "alias1"
  assert_success
  assert_output "$(realpath "$DIR_A")"
}

@test "__goto_get_destiny falha quando o apelido não é informado" {
  run __goto_get_destiny ""
  assert_failure 20
}

@test "__goto_get_destiny falha quando o apelido não existe" {
  run __goto_get_destiny "inexistente"
  assert_failure 21
}

# --- __goto_remove_destiny ---

@test "__goto_remove_destiny remove um mapeamento existente" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_remove_destiny "alias1"
  assert_success
  assert_output --partial "removido"
  run grep -q "^alias1=" "$GOTO_DESTINY_FILE"
  assert_failure
}

@test "__goto_remove_destiny falha quando o apelido não é informado" {
  run __goto_remove_destiny ""
  assert_failure 20
}

@test "__goto_remove_destiny falha quando o apelido não existe" {
  run __goto_remove_destiny "inexistente"
  assert_failure 21
}

# --- __goto_update_destiny ---

@test "__goto_update_destiny atualiza o diretório de um apelido existente" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_update_destiny "alias1" "$DIR_B"
  assert_success
  assert_output --partial "atualizado"
  run __goto_get_destiny "alias1"
  assert_output "$(realpath "$DIR_B")"
}

@test "__goto_update_destiny falha quando o novo diretório não é informado" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_update_destiny "alias1" ""
  assert_failure 33
}

@test "__goto_update_destiny falha quando o novo diretório não existe" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_update_destiny "alias1" "$BATS_TEST_TMPDIR/nao-existe"
  assert_failure 32
}

@test "__goto_update_destiny falha quando o apelido não é informado" {
  run __goto_update_destiny "" "$DIR_B"
  assert_failure 20
}

@test "__goto_update_destiny falha quando o apelido não existe" {
  run __goto_update_destiny "inexistente" "$DIR_B"
  assert_failure 21
}

# --- __goto_rename_destiny ---

@test "__goto_rename_destiny renomeia o apelido mantendo o mesmo destino" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_rename_destiny "alias1" "alias2"
  assert_success
  assert_output --partial "renomeado"
  run __goto_get_destiny "alias2"
  assert_output "$(realpath "$DIR_A")"
  run __goto_get_destiny "alias1"
  assert_failure 21
}

@test "__goto_rename_destiny falha quando o apelido antigo não é informado" {
  run __goto_rename_destiny "" "alias2"
  assert_failure 20
}

@test "__goto_rename_destiny falha quando o novo apelido não é informado" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run __goto_rename_destiny "alias1" ""
  assert_failure 20
}

@test "__goto_rename_destiny falha quando o apelido antigo não existe" {
  run __goto_rename_destiny "inexistente" "alias2"
  assert_failure 21
}

# --- __goto_sort_destiny_file ---

@test "__goto_sort_destiny_file ordena o arquivo de mapeamentos alfabeticamente" {
  printf 'zebra=%s\n' "$(realpath "$DIR_B")" >> "$GOTO_DESTINY_FILE"
  printf 'abacate=%s\n' "$(realpath "$DIR_A")" >> "$GOTO_DESTINY_FILE"

  run __goto_sort_destiny_file
  assert_success

  run head -n1 "$GOTO_DESTINY_FILE"
  assert_output "abacate=$(realpath "$DIR_A")"
}
