#!/usr/bin/env bats
# Testes de __goto_create_bkp: criação, proteção contra sobrescrita e --force.

load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load 'test_helper'

setup() {
  goto_test_setup
}

@test "__goto_create_bkp cria uma cópia idêntica do arquivo de destinos" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null

  run __goto_create_bkp
  assert_success
  assert [ -f "${GOTO_DESTINY_FILE}~" ]
  run diff "$GOTO_DESTINY_FILE" "${GOTO_DESTINY_FILE}~"
  assert_success
}

@test "__goto_create_bkp falha se o arquivo de destino do backup já existir sem --force" {
  local customBkp="$BATS_TEST_TMPDIR/custom.bkp"
  : > "$customBkp"

  run __goto_create_bkp "$customBkp"
  assert_failure 40
  assert_output --partial "já existe"
}

@test "__goto_create_bkp sobrescreve o arquivo de destino quando --force é usado" {
  local customBkp="$BATS_TEST_TMPDIR/custom.bkp"
  echo "conteudo antigo" > "$customBkp"
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null

  run __goto_create_bkp "$customBkp" --force
  assert_success
  run diff "$GOTO_DESTINY_FILE" "$customBkp"
  assert_success
}

@test "__goto_create_bkp sobrescreve o backup padrão em chamadas sucessivas, sem precisar de --force" {
  __goto_create_bkp
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null

  run __goto_create_bkp
  assert_success
  run diff "$GOTO_DESTINY_FILE" "${GOTO_DESTINY_FILE}~"
  assert_success
}
