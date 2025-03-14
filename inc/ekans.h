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

typedef ekans_value* (*ekans_function)(ekans_value*);

// value creation routines

ekans_value* create_number_value(int v);

ekans_value* create_boolean_value(bool v);

ekans_value* create_environment(ekans_value* parent, const int size);

ekans_value* create_closure(ekans_value* closure, ekans_function function);

ekans_value* create_nil_value();

ekans_value* create_cons_cell(ekans_value* head, ekans_value* tail);

// accessors

ekans_value* get_environment(ekans_value* env, int levels_up, int index);

void set_environment(ekans_value* env, int index, ekans_value* value);

ekans_value* closure_of(ekans_value* val);

ekans_function function_of(ekans_value* val);

// primitive functions

void print_ekans_value(ekans_value* v);

// garbage collection

void push_stack_slot(ekans_value** slot);

void pop_stack_slot(int count);

void collect();

// life cycle management

void initialize_ekans();

void finalize_ekans();
