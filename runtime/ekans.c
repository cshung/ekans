// Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
// Licensed under the MIT License. See the LICENSE file in the project root for details.

#include <assert.h>
#include <ekans-internals.h>
#include <ekans.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

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

void create_number_value(int v, ekans_value** pReturn) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = number;
  result->value.n     = v;
  *pReturn            = result;
  append(result);
}

void create_boolean_value(bool v, ekans_value** pReturn) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = boolean;
  result->value.b     = v;
  *pReturn            = result;
  append(result);
}

void create_char_value(char v, ekans_value** pReturn) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = character;
  result->value.a     = v;
  *pReturn            = result;
  append(result);
}

void create_string_value(char* s, ekans_value** pReturn) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = string;
  result->value.s     = brutal_malloc(strlen(s) + 1);
  strncpy(result->value.s, s, strlen(s) + 1);
  result->value.s[strlen(s)] = '\0';
  *pReturn                   = result;
  append(result);
}

void create_symbol_value(char* s, ekans_value** pReturn) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = symbol;
  result->value.s     = brutal_malloc(strlen(s) + 1);
  strncpy(result->value.s, s, strlen(s) + 1);
  result->value.s[strlen(s)] = '\0';
  *pReturn                   = result;
  append(result);
}

void create_environment(ekans_value* parent, const int size, ekans_value** pReturn) {
  assert(parent == NULL || is(parent, environment));
  ekans_value* result           = brutal_malloc(sizeof(ekans_value));
  result->type                  = environment;
  result->value.e.bindings      = (ekans_value**)brutal_calloc(size, sizeof(ekans_value*));
  result->value.e.binding_count = size;
  result->value.e.parent        = parent;
  *pReturn                      = result;
  append(result);
}

void create_closure(ekans_value* env, ekans_function function, ekans_value** pReturn) {
  assert(is(env, environment));
  ekans_value* result      = brutal_malloc(sizeof(ekans_value));
  result->type             = closure;
  result->value.c.closure  = env;
  result->value.c.function = function;
  *pReturn                 = result;
  append(result);
}

void create_nil_value(ekans_value** pReturn) {
  ekans_value* result = brutal_malloc(sizeof(ekans_value));
  result->type        = nil;
  *pReturn            = result;
  append(result);
}

void create_cons_cell(ekans_value* head, ekans_value* tail, ekans_value** pReturn) {
  ekans_value* result  = brutal_malloc(sizeof(ekans_value));
  result->type         = cons;
  result->value.l.head = head;
  result->value.l.tail = tail;
  *pReturn             = result;
  append(result);
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
      if (is(cur, string) || is(cur, symbol)) {
        brutal_free(cur->value.s);
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

void get_environment(ekans_value* env, int levels_up, int index, ekans_value** pReturn) {
  assert(is(env, environment));
  while (levels_up > 0 && env != NULL) {
    env = env->value.e.parent;
    assert(env != NULL);
    assert(is(env, environment));
    levels_up--;
  }

  assert(index < env->value.e.binding_count);
  if (env->value.e.bindings[index] == NULL) {
    fprintf(stderr, "Error: accessing a definition before evaluation\n");
    exit(1);
  }
  *pReturn = env->value.e.bindings[index];
}

void closure_of(ekans_value* val, ekans_value** pReturn) {
  if (!is(val, closure)) {
    fprintf(stderr, "Error: not a function encountered in a call\n");
    exit(1);
  }
  *pReturn = val->value.c.closure;
}

ekans_function function_of(ekans_value* val) {
  if (!is(val, closure)) {
    fprintf(stderr, "Error: not a function encountered in a call\n");
    exit(1);
  }
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
    case character: {
      printf("#\\%c", v->value.a);
    } break;
    case symbol: {
      printf("'%s", v->value.s);
    } break;
    case string: {
      printf("\"%s\"", v->value.s);
    } break;
    case cons: {
      printf("'(");
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
      assert(!"Error: print_ekans_value: unsupported");
    } break;
  }
}

void plus(ekans_value* environment, ekans_value** pReturn) {
  int sum = 0;
  for (int i = 0; i < environment->value.e.binding_count; i++) {
    assert(environment->value.e.bindings[i] != NULL);
    if (environment->value.e.bindings[i]->type != number) {
      fprintf(stderr, "Error: not a number encountered in +\n");
      exit(1);
    }
    sum += environment->value.e.bindings[i]->value.n;
  }
  create_number_value(sum, pReturn);
}

void subtract(ekans_value* environment, ekans_value** pReturn) {
  int diff = environment->value.e.bindings[0]->value.n;
  for (int i = 1; i < environment->value.e.binding_count; i++) {
    assert(environment->value.e.bindings[i] != NULL);
    if (environment->value.e.bindings[i]->type != number) {
      fprintf(stderr, "Error: not a number encountered in -\n");
      exit(1);
    }
    diff -= environment->value.e.bindings[i]->value.n;
  }
  create_number_value(diff, pReturn);
}

void multiply(ekans_value* environment, ekans_value** pReturn) {
  int product = 1;
  for (int i = 0; i < environment->value.e.binding_count; i++) {
    assert(environment->value.e.bindings[i] != NULL);

    if (environment->value.e.bindings[i]->type != number) {
      fprintf(stderr, "Error: not a number encountered in *\n");
      exit(1);
    }

    const int t = environment->value.e.bindings[i]->value.n;
    if (t != 0) {
      if (product > INT_MAX / t || product < INT_MIN / t) {
        fprintf(stderr, "Error: failed to integer overflow in the function: [%s]\n", __PRETTY_FUNCTION__);
        exit(1);
      }
    }
    product *= t;
  }
  create_number_value(product, pReturn);
}

void division(ekans_value* environment, ekans_value** pReturn) {
  int quotient = environment->value.e.bindings[0]->value.n;
  for (int i = 1; i < environment->value.e.binding_count; i++) {
    assert(environment->value.e.bindings[i] != NULL);

    if (environment->value.e.bindings[i]->type != number) {
      fprintf(stderr, "Error: not a number encountered in /\n");
      exit(1);
    }

    const int t = environment->value.e.bindings[i]->value.n;
    if (t == 0) {
      fprintf(stderr, "Error: failed to division by zero in the function: [%s]\n", __PRETTY_FUNCTION__);
      exit(1);
    }
    quotient /= t;
  }
  create_number_value(quotient, pReturn);
}

void not(ekans_value * environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: not requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  if (environment->value.e.bindings[0]->type != boolean) {
    fprintf(stderr, "Error: not requires its 1st argument to be boolean\n");
    exit(1);
  }
  create_boolean_value(!environment->value.e.bindings[0]->value.b, pReturn);
}

void char_le(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "Error: char_le requires exactly two arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  assert(environment->value.e.bindings[1] != NULL);
  if (environment->value.e.bindings[0]->type != character) {
    fprintf(stderr, "Error: char_le requires its 1st argument to be character\n");
    exit(1);
  }
  if (environment->value.e.bindings[1]->type != character) {
    fprintf(stderr, "Error: char_le requires its 2nd argument to be character\n");
    exit(1);
  }
  create_boolean_value(environment->value.e.bindings[0]->value.a <= environment->value.e.bindings[1]->value.a, pReturn);
}

void char_ge(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "Error: char_ge requires exactly two arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  assert(environment->value.e.bindings[1] != NULL);
  if (environment->value.e.bindings[0]->type != character) {
    fprintf(stderr, "Error: char_ge requires its 1st argument to be character\n");
    exit(1);
  }
  if (environment->value.e.bindings[1]->type != character) {
    fprintf(stderr, "Error: char_ge requires its 2nd argument to be character\n");
    exit(1);
  }
  create_boolean_value(environment->value.e.bindings[0]->value.a >= environment->value.e.bindings[1]->value.a, pReturn);
}

void char_to_int(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: char_to_int requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  if (environment->value.e.bindings[0]->type != character) {
    fprintf(stderr, "Error: char_to_int requires its 1st argument to be character\n");
    exit(1);
  }
  create_number_value((int)environment->value.e.bindings[0]->value.a, pReturn);
}

void list_cons(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "Error: cons requires exactly two arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  assert(environment->value.e.bindings[1] != NULL);
  create_cons_cell(environment->value.e.bindings[0], environment->value.e.bindings[1], pReturn);
}

void list_constructor(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count == 0) {
    create_nil_value(pReturn);
    return;
  }

  ekans_value* result = NULL;
  create_nil_value(&result);

  for (int i = environment->value.e.binding_count - 1; i >= 0; --i) {
    ekans_value* temp = NULL;
    create_cons_cell(environment->value.e.bindings[i], result, &temp);
    result = temp;
  }
  *pReturn = result;
}

void is_null(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: is_null requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  create_boolean_value(environment->value.e.bindings[0]->type == nil, pReturn);
}

void car(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: car requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  if (environment->value.e.bindings[0]->type != cons) {
    fprintf(stderr, "Error: car requires its 1st argument to be a pair\n");
    exit(1);
  }
  *pReturn = environment->value.e.bindings[0]->value.l.head;
}

void cdr(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: cdr requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  if (environment->value.e.bindings[0]->type != cons) {
    fprintf(stderr, "Error: cdr requires its 1st argument to be a pair\n");
    exit(1);
  }
  *pReturn = environment->value.e.bindings[0]->value.l.tail;
}

bool is_true(ekans_value* v) {
  if (v->type != boolean) {
    fprintf(stderr, "Error: not a boolean encountered in is_true\n");
    exit(1);
  }
  return v->value.b;
}

void equals(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "Error: equals requires exactly two arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  assert(environment->value.e.bindings[1] != NULL);
  ekans_value* v1 = environment->value.e.bindings[0];
  ekans_value* v2 = environment->value.e.bindings[1];
  if (v1->type != v2->type) {
    fprintf(stderr, "Error: type mismatch encountered in equals\n");
    exit(1);
  }
  bool result = false;
  if (is(v1, number)) {
    result = v1->value.n == v2->value.n;
  } else if (is(v1, character)) {
    result = v1->value.a == v2->value.a;
  } else {
    fprintf(stderr, "Error: unsupported type encountered in equals\n");
    exit(1);
  }
  create_boolean_value(result, pReturn);
}

void member(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "Error: member requires exactly two arguments\n");
    exit(1);
  }

  // sample
  // user input   : (member 23 '(12 23 34))
  // expect output: '(23 34)
  ekans_value* target = environment->value.e.bindings[0]; // 23
  ekans_value* list   = environment->value.e.bindings[1]; // '(12 23 34)

  while (list->type == cons) {
    ekans_value* head = list->value.l.head; // head = 12 if list = '(12 23 34)

    ekans_value* equals_env = NULL;
    create_environment(NULL, 2, &equals_env);

    set_environment(equals_env, 0, target);
    set_environment(equals_env, 1, head);

    ekans_value* equals_result = NULL;
    equals(equals_env, &equals_result);

    if (is_true(equals_result)) {
      // *pReturn = list;
      //
      // Warning: `return true` is not the definition of member function in Racket
      // please check the original definition in Racket:
      // https://docs.racket-lang.org/reference/pairs.html#%28def._%28%28lib._racket%2Fprivate%2Fbase..rkt%29._member%29%29
      create_boolean_value(true, pReturn);
      return;
    }
    list = list->value.l.tail;
  }

  if (list->type != nil) {
    fprintf(stderr, "[%s][Error]: the list must end with a nil type to be valid\n", __PRETTY_FUNCTION__);
    exit(1);
  }
  create_boolean_value(false, pReturn); // target is not in the list
}

// Allocation helpers - just quit the process whenever an error happens

void* brutal_malloc(size_t size) {
  void* result = malloc(size);
  if (!result) {
    fprintf(stderr, "Error: failed to allocate memory\n");
    exit(1);
  }
  // fprintf(stderr, "malloc %p\n", result);
  return result;
}

void* brutal_calloc(size_t count, size_t size) {
  void* result = calloc(count, size);
  if (!result) {
    fprintf(stderr, "Error: failed to allocate memory\n");
    exit(1);
  }
  // fprintf(stderr, "calloc %p\n", result);
  return result;
}

void brutal_free(void* ptr) {
  // fprintf(stderr, "free %p\n", ptr);
  free(ptr);
}
