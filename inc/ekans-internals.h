#pragma once

#include <ekans.h>

const int mark_bit = 65536;

typedef enum { number, boolean } ekans_type;

struct ekans_value {
  ekans_type type;
  union {
    int n;
    bool b;
  } value;
  struct ekans_value *prev;
  struct ekans_value *next;
};

typedef struct stack_slot {
  ekans_value **slot;
  struct stack_slot *next;
} stack_slot;

stack_slot *g_stack_slots = NULL;

void append(ekans_value *new_value);

void mark();

bool marked(ekans_value *obj);

void mark_recursively(ekans_value *obj);

void mark_this(ekans_value *obj);

void sweep();

void reset_this(ekans_value *obj);
