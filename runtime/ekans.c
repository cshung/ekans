// Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
// Licensed under the MIT License. See the LICENSE file in the project root for details.

#include <assert.h>
#include <ekans-internals.h>
#include <ekans.h>
#include <stdio.h>
#include <stdlib.h>

//
// error handling principle:
//
// The ekans language does not support handling error - so all we need to do
// when an error happen is to print it out and quit the process with a non-zero exit code
//
// This avoids propagating the error for nothing.
//

#define EKANS_MARK_BITS 65536

// global variables

stack_slot* g_stack_slots = NULL;

ekans_value head;
ekans_value tail;

// runtime initialization/finalization

void initialize_ekans() {
  head.prev = NULL;
  head.next = &tail;
  tail.prev = &head;
  tail.next = NULL;
}

void finalize_ekans() {
  collect();
}

// value creation routines

ekans_value* create_number_value(int v) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = number;
  result->value.n     = v;
  append(result);
  return result;
}

ekans_value* create_boolean_value(bool v) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = boolean;
  result->value.b     = v;
  append(result);
  return result;
}

ekans_value* create_environment(ekans_value* parent, const int size) {
  assert(parent == NULL || is(parent, environment));
  ekans_value* result           = brutal_malloc(sizeof(ekans_value));
  result->type                  = environment;
  result->value.e.bindings      = (ekans_value**)brutal_calloc(size, sizeof(ekans_value*));
  result->value.e.binding_count = size;
  result->value.e.parent        = parent;
  append(result);
  return result;
}

ekans_value* create_closure(ekans_value* env, ekans_function function) {
  assert(is(env, environment));
  ekans_value* result      = brutal_malloc(sizeof(ekans_value));
  result->type             = closure;
  result->value.c.closure  = env;
  result->value.c.function = function;
  append(result);
  return result;
}

ekans_value* create_nil_value() {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = nil;
  append(result);
  return result;
}

ekans_value* create_cons_cell(ekans_value* head, ekans_value* tail) {
  ekans_value* result  = brutal_malloc(sizeof(ekans_value));
  result->type         = cons;
  result->value.l.head = head;
  result->value.l.tail = tail;
  append(result);
  return result;
}

// Garbage collection routines

void push_stack_slot(ekans_value** slot) {
  stack_slot* top = brutal_malloc(sizeof(stack_slot));
  top->slot       = slot;
  top->next       = g_stack_slots;
  g_stack_slots   = top;
}

void pop_stack_slot(int count) {
  for (int i = 0; i < count; i++) {
    stack_slot* top = g_stack_slots;
    g_stack_slots   = top->next;
    brutal_free(top);
  }
}

void collect() {
  mark();
  sweep();
}

void mark() {
  stack_slot* cur = g_stack_slots;
  while (cur != NULL) {
    ekans_value* obj = *(cur->slot);
    if (obj) {
      mark_recursively(obj);
    }
    cur = cur->next;
  }
}

void sweep() {
  ekans_value* cur = head.next;
  // int freed = 0;
  // int reset = 0;
  while (cur != &tail) {
    ekans_value* next = cur->next;
    if (marked(cur)) {
      // reset += 1;
      reset_this(cur);
    } else {
      if (is(cur, environment)) {
        brutal_free(cur->value.e.bindings);
      }
      // freed += 1;
      cur->prev->next = cur->next;
      cur->next->prev = cur->prev;
      brutal_free(cur);
    }
    cur = next;
  }
  // no printf("[log] GC completed, freed = %d, reset = %d\n", freed, reset);
}

void append(ekans_value* new_value) {
  new_value->prev       = tail.prev;
  new_value->next       = &tail;
  new_value->prev->next = new_value;
  new_value->next->prev = new_value;
}

void mark_recursively(ekans_value* obj) {
  if (!marked(obj)) {
    mark_this(obj);
    if (is(obj, closure)) {
      mark_recursively(obj->value.c.closure);
    } else if (is(obj, environment)) {
      mark_recursively(obj->value.e.parent);
      for (int i = 0; i < obj->value.e.binding_count; i++) {
        mark_recursively(obj->value.e.bindings[i]);
      }
    } else if (is(obj, cons)) {
      mark_recursively(obj->value.l.head);
      mark_recursively(obj->value.l.tail);
    }
  }
}

void mark_this(ekans_value* obj) {
  obj->type |= EKANS_MARK_BITS;
}

void reset_this(ekans_value* obj) {
  obj->type &= ~EKANS_MARK_BITS;
}

bool marked(ekans_value* obj) {
  return obj == NULL || (obj->type & EKANS_MARK_BITS) != 0;
}

// Accessors

void set_environment(ekans_value* env, int index, ekans_value* value) {
  assert(is(env, environment));
  assert(index < env->value.e.binding_count);
  env->value.e.bindings[index] = value;
}

ekans_value* get_environment(ekans_value* env, int levels_up, int index) {
  assert(is(env, environment));
  while (levels_up > 0 && env != NULL) {
    env = env->value.e.parent;
    assert(env != NULL);
    assert(is(env, environment));
    levels_up--;
  }

  assert(index < env->value.e.binding_count);
  return env->value.e.bindings[index];
}

ekans_value* closure_of(ekans_value* val) {
  assert(is(val, closure));
  return val->value.c.closure;
}

ekans_function function_of(ekans_value* val) {
  assert(is(val, closure));
  return val->value.c.function;
}

// Primitive runtime functions

bool is(ekans_value* obj, ekans_type type) {
  assert(obj);
  return ((obj->type | EKANS_MARK_BITS) == (type | EKANS_MARK_BITS));
}

void print_ekans_value(ekans_value* v) {
  print_ekans_value_helper(v);
  printf("\n");
}

void print_ekans_value_helper(ekans_value* v) {
  switch (v->type) {
    case number: {
      printf("%d", v->value.n);
    } break;
    case boolean: {
      switch (v->value.b) {
        case true: {
          printf("#t");
        } break;
        case false: {
          printf("#f");
        } break;
        default: {
          assert(!"print_ekans_value: unknown boolean value");
        } break;
      }
    } break;
    case cons: {
      printf("(");
      while (true) {
        print_ekans_value_helper(v->value.l.head);
        v = v->value.l.tail;
        if (v->type == nil) {
          printf(")");
          break;
        } else if (v->type == cons) {
          printf(" ");
        } else {
          printf(" . ");
          print_ekans_value_helper(v);
          printf(")");
          break;
        }
      }
      break;
    }
    case nil: {
      printf("'()");
      break;
    }
    default: {
      assert(!"print_ekans_value: unsupported");
    } break;
  }
}

ekans_value* plus(ekans_value* environment) {
  int sum = 0;
  for (int i = 0; i < environment->value.e.binding_count; i++) {
    assert(environment->value.e.bindings[i] != NULL);
    if (environment->value.e.bindings[i]->type != number) {
      fprintf(stderr, "not a number encountered in +\n");
      exit(1);
    }
    sum += environment->value.e.bindings[i]->value.n;
  }
  return create_number_value(sum);
}

// Allocation helpers - just quit the process whenever an error happens

void* brutal_malloc(size_t size) {
  void* result = malloc(size);
  if (!result) {
    fprintf(stderr, "failed to allocate memory\n");
    exit(1);
  }
  // fprintf(stderr, "malloc %p\n", result);
  return result;
}

void* brutal_calloc(size_t count, size_t size) {
  void* result = calloc(count, size);
  if (!result) {
    fprintf(stderr, "failed to allocate memory\n");
    exit(1);
  }
  // fprintf(stderr, "calloc %p\n", result);
  return result;
}

void brutal_free(void* ptr) {
  // fprintf(stderr, "free %p\n", ptr);
  free(ptr);
}