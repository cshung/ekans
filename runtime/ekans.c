#include <assert.h>
#include <ekans-internals.h>
#include <ekans.h>
#include <stdio.h>
#include <stdlib.h>

ekans_value head;
ekans_value tail;

void initialize_ekans() {
  head.prev = NULL;
  head.next = &tail;
  tail.prev = &head;
  tail.next = NULL;
}

ekans_value *create_number_value(int v) {
  ekans_value *result = malloc(sizeof(ekans_value));
  append(result);
  result->type = number;
  result->value.n = v;
  return result;
}

ekans_value *create_boolean_value(bool v) {
  ekans_value *result = malloc(sizeof(ekans_value));
  append(result);
  result->type = boolean;
  result->value.b = v;
  return result;
}

void print_ekans_value(ekans_value *v) {
  switch (v->type) {
  case number:
    printf("%d\n", v->value.n);
    break;
  case boolean:
    switch (v->value.b) {
    case true:
      printf("#t\n");
      break;
    case false:
      printf("#f\n");
      break;
    default:
      assert(!"print_ekans_value: unknown boolean value");
    }
    break;
  default:
    assert(!"print_ekans_value: unknown type");
  }
}

void finalize_ekans() {
  ekans_value *cur = head.next;
  while (cur != &tail) {
    cur = cur->next;
    free(cur->prev);
  }
}

void append(ekans_value *new_value) {
  new_value->prev = tail.prev;
  new_value->next = &tail;
  new_value->prev->next = new_value;
  new_value->next->prev = new_value;
}