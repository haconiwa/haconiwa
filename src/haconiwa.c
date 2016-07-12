#include "mruby.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

static mrb_value mrb_haconiwa_mrgbem_versions(mrb_state *mrb, mrb_value self)
{
  return mrb_fixnum_value(0);
}

void mrb_haconiwa_gem_init(mrb_state *mrb)
{
  struct RClass *haconiwa;
  haconiwa = mrb_define_module(mrb, "Haconiwa");
  mrb_define_class_method(mrb, haconiwa, "mrbgem_versions", mrb_haconiwa_mrgbem_versions, MRB_ARGS_NONE());

  DONE;
}

void mrb_haconiwa_gem_final(mrb_state *mrb)
{
}
