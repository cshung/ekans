// Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
// Licensed under the MIT License. See the LICENSE file in the project root for details.

#pragma once

#include <ekans.h>

// This file expose the implementation details to unit tests, and also allow
// the runtime implementation to write functions in any order

typedef enum {
  number,
  boolean,
  environment,
  closure,
  nil,
  cons,
} ekans_type;

typedef struct ekans_environment {
  int                 binding_count;
  ekans_value**       bindings;
  struct ekans_value* parent;
} ekans_environment;

typedef struct ekans_closure {
  ekans_value*   closure;
  ekans_function function;
} ekans_closure;

typedef struct ekans_cons {
  ekans_value* head;
  ekans_value* tail;
} ekans_cons;

struct ekans_value {
  ekans_type type;
  union {
    int               n;
    bool              b;
    ekans_environment e;
    ekans_closure     c;
    ekans_cons        l;
  } value;
  struct ekans_value* prev;
  struct ekans_value* next;
};

extern ekans_value head;
extern ekans_value tail;

ekans_value* plus(ekans_value* environment);

typedef struct stack_slot {
  ekans_value**      slot;
  struct stack_slot* next;
} stack_slot;

extern stack_slot* g_stack_slots;

void print_ekans_value_helper(ekans_value* v);

void append(ekans_value* new_value);

void mark();

bool marked(ekans_value* obj);

void mark_recursively(ekans_value* obj);

void mark_this(ekans_value* obj);

void sweep();

void reset_this(ekans_value* obj);

bool is(ekans_value* obj, ekans_type type);

void* brutal_malloc(size_t size);

void* brutal_calloc(size_t count, size_t size);

void brutal_free(void* ptr);
