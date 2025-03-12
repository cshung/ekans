// Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
// Licensed under the MIT License. See the LICENSE file in the project root for details.

#pragma once

#include <stdio.h>

typedef enum {
  false,
  true
} bool;

typedef struct ekans_value ekans_value;

ekans_value* create_number_value(int v);

ekans_value* create_boolean_value(bool v);

void print_ekans_value(ekans_value* v);

void push_stack_slot(ekans_value** slot);

void pop_stack_slot(int count);

void collect();

void initialize_ekans();

void finalize_ekans();

extern ekans_value head;
extern ekans_value tail;
