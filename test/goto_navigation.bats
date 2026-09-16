#!/usr/bin/env bats
# Testes da função principal `goto`: navegação, flags de linha de comando,
# e os pontos "impuros" (menu interativo via `select` e chamada ao `vi`).

load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load 'test_helper'

setup() {
  goto_test_setup
}

# --- navegação ---

@test "goto navega para o diretório mapeado por um apelido" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  goto alias1
  assert [ "$PWD" -ef "$DIR_A" ]
}

@test "goto navega para um subdiretório do apelido mapeado" {
  mkdir -p "$DIR_A/sub"
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  goto alias1 sub
  assert [ "$PWD" -ef "$DIR_A/sub" ]
}

@test "goto navega para um caminho literal quando não há apelido correspondente" {
  # __goto_get_destiny retorna código de erro (comportamento esperado, pois o
  # apelido não existe) antes de o script cair no fallback do caminho
  # literal; desarma o errexit do bats só para não abortar nesse meio-termo.
  set +e
  goto "$DIR_B"
  set -e
  assert [ "$PWD" -ef "$DIR_B" ]
}

@test "goto falha quando o apelido não existe e não é um caminho válido" {
  run goto "inexistente-xyz"
  assert_failure 10
  assert_output --partial "não encontrado"
}

@test "goto falha quando o subdiretório informado não existe" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run goto alias1 subdir-inexistente
  assert_failure 32
  assert_output --partial "não encontrado"
}

# --- flags ---

@test "goto -h exibe o manual" {
  run goto -h
  assert_success
  assert_output --partial "goto -h|--help"
}

@test "goto --help exibe o manual" {
  run goto --help
  assert_success
}

@test "goto -m mostra o caminho do arquivo de mapeamentos" {
  run goto -m
  assert_success
  assert_output "$GOTO_DESTINY_FILE"
}

@test "goto -s lista os destinos cadastrados" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run goto -s
  assert_success
  assert_output --partial "alias1"
  assert_output --partial "$(realpath "$DIR_A")"
}

@test "goto -g obtém o diretório de um apelido" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run goto -g alias1
  assert_success
  assert_output "$(realpath "$DIR_A")"
}

@test "goto -a adiciona um destino via linha de comando" {
  run goto -a "$DIR_A" alias1
  assert_success
  run __goto_get_destiny "alias1"
  assert_output "$(realpath "$DIR_A")"
}

@test "goto -d remove um destino via linha de comando" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run goto -d alias1
  assert_success
  run __goto_get_destiny "alias1"
  assert_failure 21
}

@test "goto -c reporta mapeamentos válidos" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  run goto -c
  assert_success
  assert_output --partial "válidos"
}

@test "goto -q verifica se o diretório atual está mapeado" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null
  cd "$DIR_A"
  run goto -q
  assert_success
  assert_output --partial "está mapeado"
}

# --- ponto impuro: chamada a um comando externo (vi) ---

@test "goto -e abre o arquivo de mapeamentos no editor configurado (vi)" {
  local callLog="$BATS_TEST_TMPDIR/vi-called-with"
  stub_bin "vi" "printf '%s' \"\$@\" > '$callLog'"

  run goto -e
  assert_success
  assert_equal "$(cat "$callLog")" "$GOTO_DESTINY_FILE"
}

# --- ponto impuro: menu interativo (select lendo do stdin) ---

@test "goto sem argumentos permite sair do menu sem navegar" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null

  # 'select' espera o NÚMERO da opção, não o texto; opção 1 = "Sair".
  # Usamos '<<<' (redirecionamento), não '|' (pipe): um pipe forçaria 'goto'
  # a rodar como último estágio de um pipeline, e bash executa esse estágio
  # numa subshell — o que faria o 'cd' interno não valer para o processo pai.
  run bash -c "source '$GOTO_SCRIPT_PATH'; goto <<< '1'"
  assert_success
  assert_output --partial "Saindo"
}

@test "goto sem argumentos navega para o destino escolhido no menu" {
  __goto_add_destiny "$DIR_A" "alias1" > /dev/null

  # opção 1 = "Sair", opção 2 = primeira (e única) linha do arquivo de mapeamentos.
  # 'select' escreve o menu e o prompt (PS3) em stderr, então redirecionamos
  # tanto stdout quanto stderr da chamada para isolar só a saída do 'pwd'.
  run bash -c "source '$GOTO_SCRIPT_PATH'; goto <<< '2' > /dev/null 2>&1; pwd"
  assert_success
  assert_output "$(realpath "$DIR_A")"
}
