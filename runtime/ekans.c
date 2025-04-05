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

int    g_argc;
char** g_argv;

// runtime initialization/finalization

void initialize_ekans(int argc, char** argv) {
  g_argc    = argc;
  g_argv    = argv;
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

void ekans_value_to_string(ekans_value* v, buffer* b) {
  switch (v->type) {
    case number: {
      append_int(b, v->value.n);
    } break;
    case boolean: {
      append_bool(b, v->value.b);
    } break;
    case character: {
      append_char(b, v->value.a);
    } break;
    case symbol: {
      append_string(b, v->value.s);
    } break;
    case string: {
      append_string(b, v->value.s);
    } break;
    case cons: {
      append_string(b, "(");
      while (true) {
        ekans_value_to_string(v->value.l.head, b);
        v = v->value.l.tail;
        if (v->type == nil) {
          append_string(b, ")");
          break;
        } else if (v->type == cons) {
          append_string(b, " ");
        } else {
          append_string(b, " . ");
          ekans_value_to_string(v, b);
          append_string(b, ")");
          break;
        }
      }
      break;
    }
    case nil: {
      append_string(b, "()");
      break;
    }
    default: {
      assert(!"[ekans_value_to_string][error]: unsupported type");
    } break;
  }
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

void less(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "Error: < requires exactly two arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  assert(environment->value.e.bindings[1] != NULL);
  if (environment->value.e.bindings[0]->type != number) {
    fprintf(stderr, "Error: < requires its 1st argument to be number\n");
    exit(1);
  }
  if (environment->value.e.bindings[1]->type != number) {
    fprintf(stderr, "Error: < requires its 2nd argument to be number\n");
    exit(1);
  }
  create_boolean_value(environment->value.e.bindings[0]->value.n < environment->value.e.bindings[1]->value.n, pReturn);
}

void greater(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "Error: > requires exactly two arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  assert(environment->value.e.bindings[1] != NULL);
  if (environment->value.e.bindings[0]->type != number) {
    fprintf(stderr, "Error: > requires its 1st argument to be number\n");
    exit(1);
  }
  if (environment->value.e.bindings[1]->type != number) {
    fprintf(stderr, "Error: > requires its 2nd argument to be number\n");
    exit(1);
  }
  create_boolean_value(environment->value.e.bindings[0]->value.n > environment->value.e.bindings[1]->value.n, pReturn);
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

void string_to_list(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: string_to_list requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  if (environment->value.e.bindings[0]->type != string) {
    fprintf(stderr, "Error: string_to_list requires its 1st argument to be string\n");
    exit(1);
  }
  ekans_value* result = NULL;
  create_nil_value(&result);
  int len = strlen(environment->value.e.bindings[0]->value.s);
  for (int i = 0; i < len; i++) {
    ekans_value* c;
    create_char_value(environment->value.e.bindings[0]->value.s[len - i - 1], &c);
    ekans_value* temp = NULL;
    create_cons_cell(c, result, &temp);
    result = temp;
  }
  *pReturn = result;
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
  ekans_value* v1     = environment->value.e.bindings[0];
  ekans_value* v2     = environment->value.e.bindings[1];
  bool         result = false;
  if (v1->type != v2->type) {
    result = false;
  } else if (is(v1, number)) {
    result = v1->value.n == v2->value.n;
  } else if (is(v1, character)) {
    result = v1->value.a == v2->value.a;
  } else if (is(v1, symbol)) {
    result = (strcmp(v1->value.s, v2->value.s) == 0);
  } else if (is(v1, string)) {
    result = (strcmp(v1->value.s, v2->value.s) == 0);
  } else {
    fprintf(stderr, "Error: unsupported type encountered in equals\n");
    exit(1);
  }
  create_boolean_value(result, pReturn);
}

void args(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 0) {
    fprintf(stderr, "Error: args requires exactly zero arguments\n");
    exit(1);
  }
  ekans_value* result = NULL;
  create_nil_value(&result);
  for (int i = 1; i < g_argc; i++) {
    ekans_value* c;
    create_string_value(g_argv[g_argc - i], &c);
    ekans_value* temp = NULL;
    create_cons_cell(c, result, &temp);
    result = temp;
  }
  *pReturn = result;
}

void println(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: displayln requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  if (environment->value.e.bindings[0]->type != string) {
    fprintf(stderr, "Error: displayln requires its 1st argument to be a string\n");
    exit(1);
  }
  printf("%s\n", environment->value.e.bindings[0]->value.s);
  create_nil_value(pReturn);
}

void failfast(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: error requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  print_ekans_value(environment->value.e.bindings[0]);
  exit(1);
}

void is_pair(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "Error: is_pair requires exactly one arguments\n");
    exit(1);
  }
  assert(environment->value.e.bindings[0] != NULL);
  create_boolean_value(environment->value.e.bindings[0]->type == cons, pReturn);
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

// Begin TODO

void list_to_string(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "[%s] error: requires exactly one arguments\n", __PRETTY_FUNCTION__);
    exit(1);
  }

  assert(environment->value.e.bindings[0] != NULL);

  if (environment->value.e.bindings[0]->type != cons) {
    fprintf(stderr, "[%s] error: requires 1st argument to be a pair\n", __PRETTY_FUNCTION__);
    exit(1);
  }

  buffer buff;
  allocate_buffer(&buff);
  ekans_value* list = environment->value.e.bindings[0];
  while (list->type == cons) {
    ekans_value_to_string(list->value.l.head, &buff);
    list = list->value.l.tail;
    if (list->type == nil) {
      break;
    } else if (list->type != cons) {
      fprintf(stderr, "[%s][error]: the list must end with a nil type\n", __PRETTY_FUNCTION__);
      exit(1);
    }
  }
  create_string_value(buff.begin, pReturn);
  deallocate_buffer(&buff);
}

void string_append(ekans_value* environment, ekans_value** pReturn) {
  buffer buff;
  allocate_buffer(&buff);
  for (int i = 0; i < environment->value.e.binding_count; i++) {
    assert(environment->value.e.bindings[i] != NULL);
    if (environment->value.e.bindings[i]->type != string) {
      fprintf(stderr, "[%s] string_append: requires argument to be a string\n", __PRETTY_FUNCTION__);
      exit(1);
    }
    append_string(&buff, environment->value.e.bindings[i]->value.s);
  }
  create_string_value(buff.begin, pReturn);
  deallocate_buffer(&buff);
}

void format(ekans_value* environment, ekans_value** pReturn) {
  buffer buff;
  allocate_buffer(&buff);
  {
    // Example:
    // fmt_str = "Hello ~a and ~a"
    // environment->value.e.binding_count = 3
    // environment->value.e.bindings[0]->value.s = "Hello ~a and ~a"
    // environment->value.e.bindings[1]->value.s = "Alice"
    // environment->value.e.bindings[2]->value.s = "Bob"
    // Result: "Hello Alice and Bob"
    const char* fmt_str = environment->value.e.bindings[0]->value.s;
    int         arg_idx = 1; // start with the first argument after the format string

    for (const char* c = fmt_str; c != NULL && *c != '\0'; ++c) {
      if (*c == '~' && *(c + 1) == 'a') {
        if (arg_idx >= environment->value.e.binding_count) {
          fprintf(stderr, "[%s] arguments index error !!! \n", __PRETTY_FUNCTION__);
          exit(1);
        }
        ekans_value* arg = environment->value.e.bindings[arg_idx++];
        ekans_value_to_string(arg, &buff);
        ++c; // skip 'a', e.g. fmt_str = "Hello ~a and ~a"
      } else {
        append_char(&buff, *c);
      }
    }
    create_string_value(buff.begin, pReturn);
  }
  deallocate_buffer(&buff);
}

// cadr = car(cdr(list))
void cadr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cdr_result = NULL;
  cdr(environment, &cdr_result);

  ekans_value* cadr_env = NULL;
  create_environment(NULL, 1, &cadr_env);
  set_environment(cadr_env, 0, cdr_result);

  car(cadr_env, pReturn);
}

// caddr = car(cdr(cdr(list))) = cadr(cdr(list))
void caddr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cdr_result = NULL;
  cdr(environment, &cdr_result);

  ekans_value* cdr_env = NULL;
  create_environment(NULL, 1, &cdr_env);
  set_environment(cdr_env, 0, cdr_result);

  cadr(cdr_env, pReturn);
}

// cddr = cdr(cdr(list))
void cddr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cdr_result = NULL;
  cdr(environment, &cdr_result);

  ekans_value* cdr_env = NULL;
  create_environment(NULL, 1, &cdr_env);
  set_environment(cdr_env, 0, cdr_result);

  cdr(cdr_env, pReturn);
}

// cddadr = cdr(cdr(car(cdr(list)))) = cdr(cdr(cadr(list)))
//
// > (cddadr '(1 (2 3 4)))
// '(4)
void cddadr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cadr_result = NULL;
  ekans_value* cdr_env1    = NULL;
  ekans_value* cdr_result  = NULL;
  ekans_value* cdr_env2    = NULL;

  cadr(environment, &cadr_result);

  create_environment(NULL, 1, &cdr_env1);
  set_environment(cdr_env1, 0, cadr_result);

  cdr(cdr_env1, &cdr_result);

  create_environment(NULL, 1, &cdr_env2);
  set_environment(cdr_env2, 0, cdr_result);

  cdr(cdr_env2, pReturn);
}

// cdadr = cdr(car(cdr(list))) = cdr(cadr(list))
// > (cdadr '(1 (2 3 4)))
// '(3 4)
void cdadr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cadr_result = NULL;
  ekans_value* cadr_env    = NULL;
  create_environment(NULL, 1, &cadr_env);
  set_environment(cadr_env, 0, environment->value.e.bindings[0]);

  cadr(cadr_env, &cadr_result);

  ekans_value* cdr_env = NULL;
  create_environment(NULL, 1, &cdr_env);
  set_environment(cdr_env, 0, cadr_result);

  cdr(cdr_env, pReturn);
}

// caadr = car(cdr(car(list))) = car(cadr(list))
//
// > (caadr '(1 (2 3 4)))
// 2
// > (car (cadr '(1 (2 3 4))))
// 2
void caadr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cadr_result = NULL;
  ekans_value* cdr_env     = NULL;
  create_environment(NULL, 1, &cdr_env);
  set_environment(cdr_env, 0, environment->value.e.bindings[0]);

  cadr(cdr_env, &cadr_result);

  ekans_value* car_env = NULL;
  create_environment(NULL, 1, &car_env);
  set_environment(car_env, 0, cadr_result);

  car(car_env, pReturn);
}

// caar
//
// > (caar '((2 3) 4))
// 2
// > (car (car '((2 3) 4)))
// 2
void caar(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* car_result = NULL;
  ekans_value* car_env    = NULL;
  ekans_value* car_env2   = NULL;

  create_environment(NULL, 1, &car_env);
  set_environment(car_env, 0, environment->value.e.bindings[0]);

  car(car_env, &car_result);

  create_environment(NULL, 1, &car_env2);
  set_environment(car_env2, 0, car_result);

  car(car_env2, pReturn);
}

// cdar = cdr(car(list))
//
// > (cdar '((2 3) 4))
// '(3)
// > (cdr (car '((2 3) 4)))
// '(3)
void cdar(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* car_result = NULL;
  ekans_value* car_env    = NULL;
  ekans_value* cdr_env    = NULL;

  create_environment(NULL, 1, &car_env);
  set_environment(car_env, 0, environment->value.e.bindings[0]);

  car(car_env, &car_result);

  create_environment(NULL, 1, &cdr_env);
  set_environment(cdr_env, 0, car_result);

  cdr(cdr_env, pReturn);
}

// cdddr = cdr(cdr(cdr(list)))
//
// > (cdddr '(1 2 3 4))
// '(4)
// > (cdr (cdr (cdr '(1 2 3 4))))
// '(4)
void cdddr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cdr_env1    = NULL;
  ekans_value* cdr_env2    = NULL;
  ekans_value* cdr_env3    = NULL;
  ekans_value* cdr_result1 = NULL;
  ekans_value* cdr_result2 = NULL;

  create_environment(NULL, 1, &cdr_env1);
  set_environment(cdr_env1, 0, environment->value.e.bindings[0]);
  cdr(cdr_env1, &cdr_result1);

  create_environment(NULL, 1, &cdr_env2);
  set_environment(cdr_env2, 0, cdr_result1);
  cdr(cdr_env2, &cdr_result2);

  create_environment(NULL, 1, &cdr_env3);
  set_environment(cdr_env3, 0, cdr_result2);
  cdr(cdr_env3, pReturn);
}

// cadddr = car(cdddr(list))
//
// > (cadddr '(1 2 3 4))
// 4
// > (car (cdddr '(1 2 3 4)))
// 4
// >
void cadddr(ekans_value* environment, ekans_value** pReturn) {
  ekans_value* cdddr_result = NULL;
  ekans_value* cdddr_env    = NULL;
  ekans_value* car_env      = NULL;

  create_environment(NULL, 1, &cdddr_env);
  set_environment(cdddr_env, 0, environment->value.e.bindings[0]);
  cdddr(cdddr_env, &cdddr_result);

  create_environment(NULL, 1, &car_env);
  set_environment(car_env, 0, cdddr_result);
  car(car_env, pReturn);
}

void write_file(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 2) {
    fprintf(stderr, "[%s] error: requires exactly two arguments\n", __PRETTY_FUNCTION__);
    exit(1);
  }

  assert(environment->value.e.bindings[0] != NULL);
  assert(environment->value.e.bindings[1] != NULL);

  if (environment->value.e.bindings[0]->type != string) {
    fprintf(stderr, "[%s] error: requires 1st argument to be a string\n", __PRETTY_FUNCTION__);
    exit(1);
  }
  if (environment->value.e.bindings[1]->type != string) {
    fprintf(stderr, "[%s] error: requires 2nd argument to be a string\n", __PRETTY_FUNCTION__);
    exit(1);
  }

  FILE* file = fopen(environment->value.e.bindings[0]->value.s, "w");
  if (file == NULL) {
    fprintf(stderr,
            "[%s] error: failed to open file %s\n",
            __PRETTY_FUNCTION__,
            environment->value.e.bindings[0]->value.s);
    exit(1);
  }
  fprintf(file, "%s", environment->value.e.bindings[1]->value.s);
  fclose(file);

  create_nil_value(pReturn);
}

void read_file(ekans_value* environment, ekans_value** pReturn) {
  if (environment->value.e.binding_count != 1) {
    fprintf(stderr, "[%s] error: requires exactly one argument\n", __PRETTY_FUNCTION__);
    exit(1);
  }

  assert(environment->value.e.bindings[0] != NULL);

  if (environment->value.e.bindings[0]->type != string) {
    fprintf(stderr, "[%s] error: requires 1st argument to be a string\n", __PRETTY_FUNCTION__);
    exit(1);
  }

  FILE* file = fopen(environment->value.e.bindings[0]->value.s, "r");
  if (file == NULL) {
    fprintf(stderr,
            "[%s] error: failed to open file %s\n",
            __PRETTY_FUNCTION__,
            environment->value.e.bindings[0]->value.s);
    exit(1);
  }

  fseek(file, 0, SEEK_END);
  long size = ftell(file);
  fseek(file, 0, SEEK_SET);

  char* str = (char*)brutal_malloc(size + 1);
  fread(str, 1, size, file);
  str[size] = '\0';

  fclose(file);
  create_string_value(str, pReturn);
  brutal_free(str);
}

// End TODO

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

/* buffer */

void allocate_buffer(buffer* buff) {
  buff->begin    = (char*)brutal_malloc(1024);
  buff->end      = buff->begin;
  buff->capacity = 1024;
  buff->begin[0] = '\0';
}

void deallocate_buffer(buffer* buff) {
  brutal_free(buff->begin);
  buff->begin    = NULL;
  buff->end      = NULL;
  buff->capacity = 0;
}

void append_bool(buffer* buff, bool b) {
  if (b) {
    append_string(buff, "#t");
  } else {
    append_string(buff, "#f");
  }
}

void append_int(buffer* buff, int n) {
  char str[32];
  snprintf(str, sizeof(str), "%d", n);
  append_string(buff, str);
}

void append_char(buffer* buff, char c) {
  char str[2];
  str[0] = c;
  str[1] = '\0';
  append_string(buff, str);
}

void append_string(buffer* buff, const char* str) {
  const int len                = strlen(str);
  const int requested_capacity = (buff->end - buff->begin) + len + 1;

  if (requested_capacity > buff->capacity) {
    int new_capacity = buff->capacity * 2;
    while (new_capacity < requested_capacity) {
      new_capacity *= 2;
    }

    const int   offset    = buff->end - buff->begin;
    char* const new_begin = (char*)brutal_malloc(new_capacity);
    {
      memmove(new_begin, buff->begin, offset); //
    }
    brutal_free(buff->begin);

    buff->begin         = new_begin;
    buff->begin[offset] = '\0';
    buff->end           = buff->begin + offset;
    buff->capacity      = new_capacity;
  }
  memcpy(buff->end, str, len);
  buff->end += len;
  *buff->end = '\0';
}