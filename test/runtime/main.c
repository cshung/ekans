#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <ekans-internals.h>
#include <ekans.h>

void test_initialize_ekans() {
  initialize_ekans();
  {
    assert(head.next == &tail);
    assert(tail.prev == &head);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_create_number_value() {
  initialize_ekans();
  {
    ekans_value* v = NULL;
    create_number_value(20250312, &v);
    assert(is(v, number));
    assert(v->value.n == 20250312);
    assert(head.next == v);
    assert(v->prev == &head);
    assert(v->next == &tail);
    assert(tail.prev == v);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_create_boolean_value() {
  initialize_ekans();
  {
    ekans_value* v = NULL;
    create_boolean_value(true, &v);
    assert(is(v, boolean));
    assert(v->value.b == true);
    assert(head.next == v);
    assert(v->prev == &head);
    assert(v->next == &tail);
    assert(tail.prev == v);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_create_nil_value() {
  initialize_ekans();
  {
    ekans_value* v = NULL;
    create_nil_value(&v);
    assert(is(v, nil));
    assert(head.next == v);
    assert(v->prev == &head);
    assert(v->next == &tail);
    assert(tail.prev == v);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_create_cons_value() {
  initialize_ekans();
  {
    ekans_value* a = NULL;
    ekans_value* b = NULL;
    ekans_value* c = NULL;
    // Intentionally not push_stack_slot for a and b to test marking
    push_stack_slot(&c);
    create_number_value(1, &a);
    create_nil_value(&b);
    create_cons_cell(a, b, &c);
    collect();
    pop_stack_slot(1);
    assert(is(a, number));
    assert(is(b, nil));
    assert(is(c, cons));
    assert(c->value.l.head == a);
    assert(c->value.l.tail == b);
    assert(head.next == a);
    assert(a->next == b);
    assert(b->next == c);
    assert(c->next == &tail);
    assert(tail.prev == c);
    assert(c->prev == b);
    assert(b->prev == a);
    assert(a->prev == &head);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_addition(void) {
  initialize_ekans();

  ekans_value* global_environment = NULL;
  ekans_value* plus_closure       = NULL;
  ekans_value* local_environment  = NULL;
  ekans_value* plus_function      = NULL;
  ekans_value* result             = NULL;
  ekans_value* p                  = NULL;
  ekans_value* q                  = NULL;

  push_stack_slot(&global_environment);
  push_stack_slot(&plus_closure);
  push_stack_slot(&local_environment);
  push_stack_slot(&plus_function);
  push_stack_slot(&result);
  push_stack_slot(&p);
  push_stack_slot(&q);

  create_environment(NULL, 1, &global_environment);
  create_closure(global_environment, plus, &plus_closure);
  set_environment(global_environment, 0, plus_closure);

  create_environment(global_environment, 2, &local_environment);
  assert(local_environment);

  create_number_value(1, &p);
  create_number_value(2, &q);
  set_environment(local_environment, 0, p);
  set_environment(local_environment, 1, q);
  get_environment(global_environment, 0, 0, &plus_function);
  assert(plus_function);

  function_of(plus_closure)(local_environment, &result);
  collect(); // we should be able to put the collect call between every line, and it should still be correct
  assert(result->value.n == 3);

  pop_stack_slot(7);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

int main() {
  printf("=====================\n");
  test_initialize_ekans();
  test_create_number_value();
  test_create_boolean_value();
  test_create_nil_value();
  test_create_cons_value();
  test_addition();
  printf("=====================\n");
  printf("All tests passed!\n");
  return 0;
}
