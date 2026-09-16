#!/usr/bin/env bash
# Funções compartilhadas pelos arquivos .bats de teste do goto.sh

GOTO_SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/goto.sh"

# Cria um binário fake em $TEST_BIN_DIR/<nome> com o corpo de script informado.
# Usado para interceptar chamadas a comandos externos (vi, eza) sem executá-los
# de verdade.
stub_bin() {
  local name="$1"
  local body="$2"
  cat > "$TEST_BIN_DIR/$name" <<STUB
#!/usr/bin/env bash
$body
STUB
  chmod +x "$TEST_BIN_DIR/$name"
}

# Prepara um ambiente isolado por teste: PATH com diretório de stubs na
# frente, arquivo de destinos temporário (GOTO_DESTINY_FILE) e dois
# diretórios de exemplo (DIR_A / DIR_B). Deve ser chamada no setup() de cada
# arquivo .bats. O goto.sh é sourceado por último, já enxergando esse ambiente.
goto_test_setup() {
  TEST_BIN_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_BIN_DIR"
  PATH="$TEST_BIN_DIR:$PATH"

  export GOTO_DESTINY_FILE="$BATS_TEST_TMPDIR/destinies.map"
  : > "$GOTO_DESTINY_FILE"

  DIR_A="$BATS_TEST_TMPDIR/dir_a"
  DIR_B="$BATS_TEST_TMPDIR/dir_b"
  mkdir -p "$DIR_A" "$DIR_B"

  # shellcheck disable=SC1090
  source "$GOTO_SCRIPT_PATH"
}
