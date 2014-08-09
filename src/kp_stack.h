//
//  kp_stack.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 10/08/14.
//
//

#ifndef kingpin_kp_stack_h
#define kingpin_kp_stack_h

typedef struct {
    void **storage;
    void **top;
} kp_stack_t;

static inline kp_stack_t kp_stack_create(size_t capacity) {
    kp_stack_t stack;

    stack.storage = malloc(capacity * sizeof(void *));
    stack.top = stack.storage;

    return stack;
}

static inline void kp_stack_push(kp_stack_t *stack, void *el) {
    *(stack->top++) = el;
}

static inline void *kp_stack_pop(kp_stack_t *stack) {
    return *(--stack->top);
}

#endif
