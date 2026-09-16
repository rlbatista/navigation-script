#!/usr/bin/env bats
# Testes de validação e manutenção do arquivo de mapeamentos:
# __goto_check_destinies, __goto_purge_destinies e __goto_question_folder.

load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load 'test_helper'

setup() {
  goto_test_setup
}

# --- __goto_check_destinies ---

@test "__goto_check_destinies reporta sucesso quando todos os diretórios existem" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  __goto_add_destiny "$DIR_B" "alias2" > /dev/null

  run __goto_check_destinies
  assert_success
  assert_output --partial "Todos os mapeamentos são válidos"
}

@test "__goto_check_destinies reporta diretórios que não existem mais" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  rmdir "$DIR_A"

  run __goto_check_destinies
  assert_failure 32
  assert_output --partial "não foi encontrado"
}

# --- __goto_purge_destinies ---

@test "__goto_purge_destinies remove apenas os mapeamentos inválidos" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  __goto_add_destiny "$DIR_B" "alias2" > /dev/null
  rmdir "$DIR_A"

  run __goto_purge_destinies
  assert_success
  assert_output --partial "expurgado com sucesso"

  run grep -q "^alias1=" "$GOTO_DESTINY_FILE"
  assert_failure
  run grep -q "^alias2=" "$GOTO_DESTINY_FILE"
  assert_success
}

@test "__goto_purge_destinies informa quando não há nada a expurgar" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null

  run __goto_purge_destinies
  assert_success
  assert_output --partial "Sem nada a expurgar"
}

@test "__goto_purge_destinies cria backup antes de expurgar" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  rmdir "$DIR_A"

  run __goto_purge_destinies
  assert_success
  assert [ -f "${GOTO_DESTINY_FILE}~" ]
}

# --- __goto_question_folder ---

@test "__goto_question_folder identifica um diretório mapeado" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null

  run __goto_question_folder "$DIR_A"
  assert_success
  assert_output --partial "está mapeado"
}

@test "__goto_question_folder identifica um diretório não mapeado" {
  run __goto_question_folder "$DIR_B"
  assert_failure 30
  assert_output --partial "não está mapeado"
}

@test "__goto_question_folder usa o diretório atual quando nenhum é informado" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  cd "$DIR_A"

  run __goto_question_folder
  assert_success
  assert_output --partial "está mapeado"
}
