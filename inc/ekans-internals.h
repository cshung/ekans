// Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
// Licensed under the MIT License. See the LICENSE file in the project root for details.

#pragma once

#include <ekans.h>

extern const int mark_bit;

typedef enum {
  number,
  boolean
} ekans_type;

struct ekans_value {
  ekans_type type;
  union {
    int  n;
    bool b;
  } value;
  struct ekans_value* prev;
  struct ekans_value* next;
};

typedef struct stack_slot {
  ekans_value**      slot;
  struct stack_slot* next;
} stack_slot;

extern stack_slot* g_stack_slots;

void append(ekans_value* new_value);

void mark();

bool marked(ekans_value* obj);

void mark_recursively(ekans_value* obj);

void mark_this(ekans_value* obj);

void sweep();

void reset_this(ekans_value* obj);
