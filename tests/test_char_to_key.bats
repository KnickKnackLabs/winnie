#!/usr/bin/env bats

# Unit tests for char_to_key() — maps characters to QEMU sendkey names.

load test_helper

setup() {
  source "$MISE_CONFIG_ROOT/lib/common.sh"
}

# --- lowercase letters ---

@test "char_to_key: a → a" {
  run char_to_key "a"
  [ "$status" -eq 0 ]
  [ "$output" = "a" ]
}

@test "char_to_key: z → z" {
  run char_to_key "z"
  [ "$status" -eq 0 ]
  [ "$output" = "z" ]
}

# --- uppercase letters ---

@test "char_to_key: A → shift-a" {
  run char_to_key "A"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-a" ]
}

@test "char_to_key: Z → shift-z" {
  run char_to_key "Z"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-z" ]
}

# --- digits ---

@test "char_to_key: 0 → 0" {
  run char_to_key "0"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "char_to_key: 9 → 9" {
  run char_to_key "9"
  [ "$status" -eq 0 ]
  [ "$output" = "9" ]
}

# --- unshifted symbols ---

@test "char_to_key: space → spc" {
  run char_to_key " "
  [ "$status" -eq 0 ]
  [ "$output" = "spc" ]
}

@test "char_to_key: - → minus" {
  run char_to_key "-"
  [ "$status" -eq 0 ]
  [ "$output" = "minus" ]
}

@test "char_to_key: = → equal" {
  run char_to_key "="
  [ "$status" -eq 0 ]
  [ "$output" = "equal" ]
}

@test "char_to_key: . → dot" {
  run char_to_key "."
  [ "$status" -eq 0 ]
  [ "$output" = "dot" ]
}

@test "char_to_key: , → comma" {
  run char_to_key ","
  [ "$status" -eq 0 ]
  [ "$output" = "comma" ]
}

@test "char_to_key: / → slash" {
  run char_to_key "/"
  [ "$status" -eq 0 ]
  [ "$output" = "slash" ]
}

@test "char_to_key: ; → semicolon" {
  run char_to_key ";"
  [ "$status" -eq 0 ]
  [ "$output" = "semicolon" ]
}

@test "char_to_key: [ → bracket_left" {
  run char_to_key "["
  [ "$status" -eq 0 ]
  [ "$output" = "bracket_left" ]
}

@test "char_to_key: ] → bracket_right" {
  run char_to_key "]"
  [ "$status" -eq 0 ]
  [ "$output" = "bracket_right" ]
}

# --- shifted symbols ---

@test "char_to_key: ! → shift-1" {
  run char_to_key "!"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-1" ]
}

@test "char_to_key: @ → shift-2" {
  run char_to_key "@"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-2" ]
}

@test "char_to_key: _ → shift-minus" {
  run char_to_key "_"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-minus" ]
}

@test "char_to_key: : → shift-semicolon" {
  run char_to_key ":"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-semicolon" ]
}

@test "char_to_key: ? → shift-slash" {
  run char_to_key "?"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-slash" ]
}

@test "char_to_key: ~ → shift-grave_accent" {
  run char_to_key "~"
  [ "$status" -eq 0 ]
  [ "$output" = "shift-grave_accent" ]
}

# --- special keys ---

@test "char_to_key: tab → tab" {
  run char_to_key $'\t'
  [ "$status" -eq 0 ]
  [ "$output" = "tab" ]
}

@test "char_to_key: newline → ret" {
  run char_to_key $'\n'
  [ "$status" -eq 0 ]
  [ "$output" = "ret" ]
}

# --- unmapped ---

@test "char_to_key: unmapped character returns 1" {
  run char_to_key "€"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unmapped"* ]]
}
