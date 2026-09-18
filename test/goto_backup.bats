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

@test "__goto_create_bkp cria o diretório de destino quando ele não existe" {
  local bkpFile="$BATS_TEST_TMPDIR/novo-diretorio/backup"
  assert [ ! -d "$BATS_TEST_TMPDIR/novo-diretorio" ]

  run __goto_create_bkp "$bkpFile"
  assert_success
  assert [ -d "$BATS_TEST_TMPDIR/novo-diretorio" ]
  assert [ -f "$bkpFile" ]
}

@test "__goto_create_bkp cria diretórios aninhados quando nenhum deles existe ainda" {
  local bkpFile="$BATS_TEST_TMPDIR/a/b/c/backup"

  run __goto_create_bkp "$bkpFile"
  assert_success
  assert [ -f "$bkpFile" ]
}

@test "__goto_create_bkp falha quando não consegue criar o diretório de destino" {
  # um arquivo comum no lugar de um componente do caminho faz o 'mkdir -p'
  # falhar de verdade (ENOTDIR), funciona em qualquer SO e independente de
  # rodar como root ou não
  local blockingFile="$BATS_TEST_TMPDIR/nao-e-diretorio"
  : > "$blockingFile"

  run __goto_create_bkp "$blockingFile/backup"
  assert_failure 34
}

@test "__goto_create_bkp continua reportando acesso negado quando o diretório já existe mas não é gravável" {
  [[ $EUID -eq 0 ]] && skip "root ignora permissões de diretório"

  local blockedDir="$BATS_TEST_TMPDIR/sem-permissao"
  mkdir -p "$blockedDir"
  chmod 000 "$blockedDir"

  run __goto_create_bkp "$blockedDir/backup"
  chmod 755 "$blockedDir"

  assert_failure 41
  assert_output --partial "Acesso negado"
}
