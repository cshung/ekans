#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ekans-internals.h>
#include <ekans.h>

void test_initialize_ekans() {
  initialize_ekans(0, NULL);
  {
    assert(head.next == &tail);
    assert(tail.prev == &head);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_create_number_value() {
  initialize_ekans(0, NULL);
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
  initialize_ekans(0, NULL);
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
  initialize_ekans(0, NULL);
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
  initialize_ekans(0, NULL);
  {
    ekans_value* a = NULL;
    ekans_value* b = NULL;
    ekans_value* c = NULL;
    // Intentionally not push_stack_slot for a and b to test marking
    push_stack_slot(&c);
    create_number_value(1, &a);
    create_nil_value(&b);
    create_cons_cell(a, b, &c);
    collect(true);
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

void test_create_char_value() {
  initialize_ekans(0, NULL);
  {
    ekans_value* v = NULL;
    create_char_value('c', &v);
    assert(is(v, character));
    assert(v->value.a == 'c');
    assert(head.next == v);
    assert(v->prev == &head);
    assert(v->next == &tail);
    assert(tail.prev == v);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_create_newline_value() {
  initialize_ekans(0, NULL);
  {
    ekans_value* v = NULL;
    create_char_value('\n', &v);
    assert(is(v, character));
    assert(v->value.a == '\n');
    assert(head.next == v);
    assert(v->prev == &head);
    assert(v->next == &tail);
    assert(tail.prev == v);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_create_string_value() {
  initialize_ekans(0, NULL);
  {
    ekans_value* v = NULL;
    create_string_value("Cecilia", &v);
    assert(is(v, string));
    assert(strcmp(v->value.s, "Cecilia") == 0);
    assert(head.next == v);
    assert(v->prev == &head);
    assert(v->next == &tail);
    assert(tail.prev == v);
  }
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_addition(void) {
  initialize_ekans(0, NULL);

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
  collect(true); // we should be able to put the collect call between every line, and it should still be correct
  assert(result->value.n == 3);

  pop_stack_slot(7);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_list_to_string() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);

  // Create the list: '(123456 "gapry" #t)
  create_number_value(123456, &node1);
  create_string_value("gapry", &node2);
  create_boolean_value(true, &node3);

  ekans_value* xs = NULL;
  create_nil_value(&xs);
  create_cons_cell(node3, xs, &xs);
  create_cons_cell(node2, xs, &xs);
  create_cons_cell(node1, xs, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  list_to_string(environment, &result);

  // printf("%s\n", result->value.s);

  assert(is(result, string));
  assert(strcmp(result->value.s, "123456gapry#t") == 0);

  pop_stack_slot(5);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_string_append() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* str1        = NULL;
  ekans_value* str2        = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&str1);
  push_stack_slot(&str2);

  create_environment(NULL, 2, &environment);

  create_string_value("Hello", &str1);
  create_string_value("World", &str2);
  set_environment(environment, 0, str1);
  set_environment(environment, 1, str2);

  string_append(environment, &result);

  // printf("%s\n", result->value.s);

  assert(is(result, string));
  assert(strcmp(result->value.s, "HelloWorld") == 0);

  pop_stack_slot(4);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_format_string() {
  initialize_ekans(0, NULL);

  ekans_value* environment   = NULL;
  ekans_value* result        = NULL;
  ekans_value* format_string = NULL;
  ekans_value* arg1          = NULL;
  ekans_value* arg2          = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&format_string);
  push_stack_slot(&arg1);
  push_stack_slot(&arg2);

  create_environment(NULL, 3, &environment);

  create_string_value("Hello ~a and ~a!", &format_string);
  set_environment(environment, 0, format_string);

  create_string_value("Alice", &arg1);
  create_string_value("Bob", &arg2);
  set_environment(environment, 1, arg1);
  set_environment(environment, 2, arg2);

  format(environment, &result);

  // printf("[log] %s\n", result->value.s);

  assert(is(result, string));
  assert(strcmp(result->value.s, "Hello Alice and Bob!") == 0);

  pop_stack_slot(5);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// cadr = car(cdr(list))
void test_cadr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);

  // Create the list: '(1 2 3)
  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);

  create_nil_value(&list);
  create_cons_cell(node3, list, &list);
  create_cons_cell(node2, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  cadr(environment, &result);

  // printf("%d\n", result->value.n);

  assert(is(result, number));
  assert(result->value.n == 2);

  pop_stack_slot(6);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// caddr = car(cdr(cdr(list))) = cadr(cdr(list))
void test_caddr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);

  // Create the list: '(1 2 3)
  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);

  create_nil_value(&list);
  create_cons_cell(node3, list, &list);
  create_cons_cell(node2, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  caddr(environment, &result);
  // printf("%d\n", result->value.n);

  assert(is(result, number));
  assert(result->value.n == 3);

  pop_stack_slot(6);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// cddr = cdr(cdr(list))
void test_cddr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);

  // Create the list: '(1 2 3)
  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);

  create_nil_value(&list);
  create_cons_cell(node3, list, &list);
  create_cons_cell(node2, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  cddr(environment, &result);
  // printf("%d\n", result->value.l.head->value.n);

  assert(is(result, cons));
  assert(result->value.l.head == node3);

  pop_stack_slot(6);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// cddadr = cdr(cdr(car(cdr(list)))) = cdr(cdr(cadr(list)))
// > (cddadr '(1 (2 3 4)))
// '(4)
void test_cddadr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* sublist     = NULL;
  ekans_value* list        = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;
  ekans_value* node4       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);
  push_stack_slot(&node4);

  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);
  create_number_value(4, &node4);

  create_nil_value(&sublist);
  create_cons_cell(node4, sublist, &sublist);
  create_cons_cell(node3, sublist, &sublist);
  create_cons_cell(node2, sublist, &sublist);

  create_nil_value(&list);
  create_cons_cell(sublist, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  cddadr(environment, &result);
  // printf("%d\n", result->value.l.head->value.n);

  assert(is(result, cons));
  assert(result->value.l.head->value.n == 4);
  assert(result->value.l.head == node4);

  pop_stack_slot(7);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// cdadr = cdr(car(cdr(list))) = cdr(cadr(list))
// > (cdadr '(1 (2 3 4)))
// '(3 4)
void test_cdadr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* sublist     = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;
  ekans_value* node4       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);
  push_stack_slot(&node4);

  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);
  create_number_value(4, &node4);

  create_nil_value(&sublist);
  create_cons_cell(node4, sublist, &sublist);
  create_cons_cell(node3, sublist, &sublist);
  create_cons_cell(node2, sublist, &sublist);

  create_nil_value(&list);
  create_cons_cell(sublist, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  cdadr(environment, &result);
  // printf("%d\n", result->value.l.head->value.n);
  // printf("%d\n", result->value.l.head->next->value.n);

  assert(is(result, cons));
  assert(result->value.l.head->value.n == 3);
  assert(result->value.l.head->next->value.n == 4);

  pop_stack_slot(7);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// caadr = car(cdr(car(list))) = car(cadr(list))
//
// > (caadr '(1 (2 3 4)))
// 2
// > (car (cadr '(1 (2 3 4))))
// 2
void test_caadr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* sublist     = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;
  ekans_value* node4       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);
  push_stack_slot(&node4);

  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);
  create_number_value(4, &node4);

  create_nil_value(&sublist);
  create_cons_cell(node4, sublist, &sublist);
  create_cons_cell(node3, sublist, &sublist);
  create_cons_cell(node2, sublist, &sublist);

  create_nil_value(&list);
  create_cons_cell(sublist, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  caadr(environment, &result);
  // printf("%d\n", result->value.n);

  assert(is(result, number));
  assert(result->value.n == 2);

  pop_stack_slot(7);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// caar
//
// > (caar '((2 3) 4))
// 2
// > (car (car '((2 3) 4)))
// 2
void test_caar() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* sublist     = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&sublist);
  push_stack_slot(&node1);
  push_stack_slot(&node2);

  create_number_value(2, &node1);
  create_number_value(3, &node2);

  create_nil_value(&sublist);
  create_cons_cell(node2, sublist, &sublist);
  create_cons_cell(node1, sublist, &sublist);

  create_nil_value(&list);
  create_cons_cell(sublist, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  caar(environment, &result);
  // printf("%d\n", result->value.n);

  assert(is(result, number));
  assert(result->value.n == 2);

  pop_stack_slot(6);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// cdar = cdr(car(list))
//
// > (cdar '((2 3) 4))
// '(3)
// > (cdr (car '((2 3) 4)))
// '(3)
void test_cdar() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* sublist     = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&sublist);
  push_stack_slot(&node1);
  push_stack_slot(&node2);

  create_number_value(2, &node1);
  create_number_value(3, &node2);

  create_nil_value(&sublist);
  create_cons_cell(node2, sublist, &sublist);
  create_cons_cell(node1, sublist, &sublist);

  create_nil_value(&list);
  create_cons_cell(sublist, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  cdar(environment, &result);
  // printf("%d\n", result->value.l.head->value.n);

  assert(is(result, cons));
  assert(result->value.l.head->value.n == 3);

  pop_stack_slot(6);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// cdddr = cdr(cdr(cdr(list)))
//
// > (cdddr '(1 2 3 4))
// '(4)
// > (cdr (cdr (cdr '(1 2 3 4))))
// '(4)
void test_cdddr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;
  ekans_value* node4       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);
  push_stack_slot(&node4);

  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);
  create_number_value(4, &node4);

  create_nil_value(&list);
  create_cons_cell(node4, list, &list);
  create_cons_cell(node3, list, &list);
  create_cons_cell(node2, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  cdddr(environment, &result);
  // printf("%d\n", result->value.l.head->value.n);

  assert(is(result, cons));
  assert(result->value.l.head->value.n == 4);

  pop_stack_slot(7);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

// cadddr = car(cdddr(list))
//
// > (cadddr '(1 2 3 4))
// 4
// > (car (cdddr '(1 2 3 4)))
// 4
// >
void test_cadddr() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* list        = NULL;
  ekans_value* node1       = NULL;
  ekans_value* node2       = NULL;
  ekans_value* node3       = NULL;
  ekans_value* node4       = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&list);
  push_stack_slot(&node1);
  push_stack_slot(&node2);
  push_stack_slot(&node3);
  push_stack_slot(&node4);

  create_number_value(1, &node1);
  create_number_value(2, &node2);
  create_number_value(3, &node3);
  create_number_value(4, &node4);

  create_nil_value(&list);
  create_cons_cell(node4, list, &list);
  create_cons_cell(node3, list, &list);
  create_cons_cell(node2, list, &list);
  create_cons_cell(node1, list, &list);

  create_environment(NULL, 1, &environment);
  set_environment(environment, 0, list);

  cadddr(environment, &result);
  // printf("%d\n", result->value.n);

  assert(is(result, number));
  assert(result->value.n == 4);

  pop_stack_slot(7);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_write_file() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* filename    = NULL;
  ekans_value* content     = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&filename);
  push_stack_slot(&content);

  create_environment(NULL, 2, &environment);

  create_string_value("build/test_write_file.txt", &filename);
  create_string_value("Hello, World!", &content);
  set_environment(environment, 0, filename);
  set_environment(environment, 1, content);

  write_file(environment, &result);

  assert(is(result, nil));

  pop_stack_slot(4);
  finalize_ekans();
  printf("[%s] passed\n", __FUNCTION__);
}

void test_read_file() {
  initialize_ekans(0, NULL);

  ekans_value* environment = NULL;
  ekans_value* result      = NULL;
  ekans_value* filename    = NULL;

  push_stack_slot(&environment);
  push_stack_slot(&result);
  push_stack_slot(&filename);

  create_environment(NULL, 1, &environment);

  create_string_value("build/test_write_file.txt", &filename);
  set_environment(environment, 0, filename);

  read_file(environment, &result);

  assert(is(result, string));
  assert(strcmp(result->value.s, "Hello, World!") == 0);

  pop_stack_slot(3);
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
  test_create_char_value();
  test_create_newline_value();
  test_create_string_value();
  test_addition();
  {
    // Issue: change the order will cause stack-use-after-return
    test_cadr();
    test_caddr();
    test_cddr();
    test_cddadr();
    test_cdadr();
    test_caadr();
    test_caar();
    test_cdar();
    test_cdddr();
    test_cadddr();
    test_write_file();
    test_read_file();
    test_format_string();
    test_string_append();
    test_list_to_string();
  }
  printf("=====================\n");
  printf("All tests passed!\n");
  return 0;
}
