#pragma once

#include <ekans.h>

typedef enum { number, boolean } ekans_type;

typedef struct ekans_value {
  ekans_type type;
  union {
    int n;
    bool b;
  } value;
  struct ekans_value *prev;
  struct ekans_value *next;
} ekans_value;

void append(ekans_value *new_value);