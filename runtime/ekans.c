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
  // printf("Malloc %p\n", result);
  append(result);
  result->type = number;
  result->value.n = v;
  return result;
}

ekans_value *create_boolean_value(bool v) {
  ekans_value *result = malloc(sizeof(ekans_value));
  // printf("Malloc %p\n", result);
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

void push_stack_slot(ekans_value **slot) {
  stack_slot *top = malloc(sizeof(stack_slot));
  // printf("malloc %p\n", top);
  top->slot = slot;
  top->next = g_stack_slots;
  g_stack_slots = top;
}

void pop_stack_slot(int count) {
  for (int i = 0; i < count; i++) {
    stack_slot *top = g_stack_slots;
    g_stack_slots = top->next;
    // printf("free %p\n", top);
    free(top);
  }
}

void collect() {
  mark();
  sweep();
}

void mark() {
  stack_slot *cur = g_stack_slots;
  while (cur != NULL) {
    ekans_value *obj = *(cur->slot);
    if (obj) {
      mark_recursively(obj);
    }
    cur = cur->next;
  }
}

void sweep() {
  ekans_value *cur = head.next;
  // int freed = 0;
  // int reset = 0;
  while (cur != &tail) {
    ekans_value *next = cur->next;
    if (marked(cur)) {
      // reset += 1;
      reset_this(cur);
    } else {
      // freed += 1;
      cur->prev->next = cur->next;
      cur->next->prev = cur->prev;
      // printf("Free %p\n", cur);
      free(cur);
    }
    cur = next;
  }
  // printf("[log] Garbage Collection completed, freed = %d, reset = %d\n",
  // freed, reset);
}

void finalize_ekans() { collect(); }

void append(ekans_value *new_value) {
  new_value->prev = tail.prev;
  new_value->next = &tail;
  new_value->prev->next = new_value;
  new_value->next->prev = new_value;
}

void mark_recursively(ekans_value *obj) {
  if (!marked(obj)) {
    mark_this(obj);
    // TODO, recursively mark referenced values when we start producing
    // complex values
  }
}

void mark_this(ekans_value *obj) { obj->type |= mark_bit; }

void reset_this(ekans_value *obj) { obj->type &= ~mark_bit; }

bool marked(ekans_value *obj) { return (obj->type & mark_bit) != 0; }