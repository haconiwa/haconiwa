#include "mruby.h"
#include "mruby/string.h"
#include "mruby/hash.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

struct mrbgem_revision {
  char* gemname;
  char* revision;
};

static mrb_value mrb_haconiwa_mrgbem_versions(mrb_state *mrb, mrb_value self)
{
  struct mrbgem_revision gems[] = {
    #include "REVISIONS.defs"
    {NULL, NULL},
  };
  mrb_value ha = mrb_hash_new(mrb);

  for (int i = 0; gems[i].gemname != NULL; ++i) {
    mrb_hash_set(mrb, ha, mrb_str_new_cstr(mrb, gems[i].gemname), mrb_str_new_cstr(mrb, gems[i].revision));
  }

  return ha;
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
