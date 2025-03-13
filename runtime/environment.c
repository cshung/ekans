// Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
// Licensed under the MIT License. See the LICENSE file in the project root for details.

#include <environment.h>
#include <stdio.h>

ekans_environment* create_environment(ekans_environment* parent, const int size) {
  ekans_environment* const environment = (ekans_environment*)malloc(sizeof(ekans_environment));
  if (environment == NULL) {
    fprintf(stderr, "Error: Failed to allocate memory for ekans_environment.\n");
    return NULL;
  }

  environment->bindings = (ekans_value**)calloc(size, sizeof(ekans_value*));
  if (environment->bindings == NULL) {
    fprintf(stderr, "Error: Failed to allocate memory for ekans environment bindings (size: %d).\n", size);
    free(environment);
    return NULL;
  }

  environment->binding_count = size;
  environment->parent        = parent;
  return environment;
}

int plus(ekans_environment* environment, ekans_value** result) {
  int sum = 0;
  for (int i = 0; i < environment->binding_count; i++) {
    if (environment->bindings[i] == NULL || environment->bindings[i]->type != number) {
      return 1;
    }
    sum += environment->bindings[i]->value.n;
  }
  *result = create_number_value(sum);
  return 0;
}

void set_environment(ekans_environment* env, int index, ekans_value* value) {
  if (index >= 0 && index < env->binding_count) {
    env->bindings[index] = value;
  }
}

ekans_value* get_environment(ekans_environment* env, int levels_up, int index) {
  while (levels_up > 0 && env != NULL) {
    env = env->parent;
    levels_up--;
  }

  if (env != NULL && index >= 0 && index < env->binding_count) {
    return env->bindings[index];
  }
  return NULL;
}

ekans_environment* closure_of(ekans_value* val) {
  return ((ekans_closure*)val)->closure;
}

ekans_value* function_of(ekans_value* val) {
  return val;
}
