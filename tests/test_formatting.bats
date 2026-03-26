#!/usr/bin/env bats

# Tests for vm:stats helpers: human_bytes, human_uptime

load test_helper

setup() {
  source "$MISE_CONFIG_ROOT/lib/common.sh"
}

# --- human_bytes ---

@test "human_bytes: 0 → 0 B" {
  run human_bytes 0
  [ "$output" = "0 B" ]
}

@test "human_bytes: 512 → 512 B" {
  run human_bytes 512
  [ "$output" = "512 B" ]
}

@test "human_bytes: 1024 → 1.0 KB" {
  run human_bytes 1024
  [ "$output" = "1.0 KB" ]
}

@test "human_bytes: 1536 → 1.5 KB" {
  run human_bytes 1536
  [ "$output" = "1.5 KB" ]
}

@test "human_bytes: 1048576 → 1.0 MB" {
  run human_bytes 1048576
  [ "$output" = "1.0 MB" ]
}

@test "human_bytes: 13400064 → 12.8 MB" {
  run human_bytes 13400064
  [ "$output" = "12.8 MB" ]
}

@test "human_bytes: 1073741824 → 1.0 GB" {
  run human_bytes 1073741824
  [ "$output" = "1.0 GB" ]
}

@test "human_bytes: 1925949440 → 1.8 GB" {
  run human_bytes 1925949440
  [ "$output" = "1.8 GB" ]
}

# --- human_uptime ---

@test "human_uptime: seconds only → Ns" {
  run human_uptime "45"
  [ "$output" = "45s" ]
}

@test "human_uptime: zero seconds → 0s" {
  run human_uptime "00"
  [ "$output" = "0s" ]
}

@test "human_uptime: MM:SS → Nm" {
  run human_uptime "03:22"
  [ "$output" = "3m" ]
}

@test "human_uptime: HH:MM:SS → Nh Nm" {
  run human_uptime "02:15:30"
  [ "$output" = "2h 15m" ]
}

@test "human_uptime: DD-HH:MM:SS → Nd Nh Nm" {
  run human_uptime "01-13:49:45"
  [ "$output" = "1d 13h 49m" ]
}

@test "human_uptime: large days" {
  run human_uptime "14-00:05:12"
  [ "$output" = "14d 5m" ]
}

@test "human_uptime: exactly 1 hour" {
  run human_uptime "01:00:00"
  [ "$output" = "1h" ]
}

@test "human_uptime: 1 minute 0 seconds" {
  run human_uptime "01:00"
  [ "$output" = "1m" ]
}

@test "human_uptime: leading whitespace stripped" {
  run human_uptime "   05:30"
  [ "$output" = "5m" ]
}
