#!/usr/bin/env bats
# Testa o mapeamento nome semântico -> código numérico feito por
# __goto_generate_return_code.

load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load 'test_helper'

setup() {
  goto_test_setup
}

@test "__goto_generate_return_code mapeia cada nome para o código esperado" {
  local nome codigo
  while read -r nome codigo; do
    # 'run' isola cada chamada do errexit do bats: a maioria dos códigos aqui
    # é intencionalmente diferente de zero, o que abortaria o teste se
    # chamado diretamente.
    run __goto_generate_return_code "$nome"
    assert_equal "$status" "$codigo"
  done <<'CASOS'
OK 0
ERR_DESTINY_NOT_FOUND 10
ERR_ALIAS_MISSING_ON_COMMAND 20
ERR_ALIAS_NOT_FOUND 21
ERR_ALIAS_ALREADY_EXISTS 22
ERR_DIRECTORY_NOT_MAPPED 30
ERR_DIRECTORY_ACCESS_DENIED 31
ERR_DIRECTORY_NOT_FOUND 32
ERR_DIRECTORY_MISSING_ON_COMMAND 33
ERR_FILE_ALREADY_EXISTS 40
ERR_FILE_ACCESS_DENIED 41
ERR_FILE_NOT_VALID 42
ERR_FILE_CANT_COPY 43
CODIGO_DESCONHECIDO 1
CASOS
}
