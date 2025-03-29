// Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
// Licensed under the MIT License. See the LICENSE file in the project root for details.

#pragma once

#include <stdio.h>

// This file should include only declarations that will be used by the generated code
// to avoid accidental dependencies on runtime internal implementation from the generated code

// type definitions

typedef enum {
  false,
  true
} bool;

typedef struct ekans_value ekans_value;

typedef void (*ekans_function)(ekans_value*, ekans_value**);

// value creation routines

void create_number_value(int v, ekans_value** pReturn);

void create_boolean_value(bool v, ekans_value** pReturn);

void create_char_value(char v, ekans_value** pReturn);

void create_string_value(char* s, ekans_value** pReturn);

void create_symbol_value(char* s, ekans_value** pReturn);

void create_environment(ekans_value* parent, const int size, ekans_value** pReturn);

void create_closure(ekans_value* closure, ekans_function function, ekans_value** pReturn);

void create_nil_value(ekans_value** pReturn);

void create_cons_cell(ekans_value* head, ekans_value* tail, ekans_value** pReturn);

void create_nil(ekans_value** pReturn);

// accessors

void get_environment(ekans_value* env, int levels_up, int index, ekans_value** pReturn);

void set_environment(ekans_value* env, int index, ekans_value* value);

void closure_of(ekans_value* val, ekans_value** pReturn);

ekans_function function_of(ekans_value* val);

// builtin functions (exposed as builtin functions, user code can call these)

void plus(ekans_value* environment, ekans_value** pReturn);

void subtract(ekans_value* environment, ekans_value** pReturn);

void multiply(ekans_value* environment, ekans_value** pReturn);

void division(ekans_value* environment, ekans_value** pReturn);

void list_cons(ekans_value* environment, ekans_value** pReturn);

void equals(ekans_value* environment, ekans_value** pReturn);

void char_le(ekans_value* environment, ekans_value** pReturn);

void char_ge(ekans_value* environment, ekans_value** pReturn);

void is_null(ekans_value* environment, ekans_value** pReturn);

void car(ekans_value* environment, ekans_value** pReturn);

void cdr(ekans_value* environment, ekans_value** pReturn);

// primitive functions (called by compiler only)

bool is_true(ekans_value* v);

void print_ekans_value(ekans_value* v);

// garbage collection

void push_stack_slot(ekans_value** slot);

void pop_stack_slot(int count);

void collect();

// life cycle management

void initialize_ekans();

void finalize_ekans();
