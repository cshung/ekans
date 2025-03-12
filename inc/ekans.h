#pragma once

#include <stdio.h>

typedef enum { false, true } bool;

typedef struct ekans_value ekans_value;

ekans_value *create_number_value(int v);

ekans_value *create_boolean_value(bool v);

void print_ekans_value(ekans_value *v);

void initialize_ekans();

void finalize_ekans();