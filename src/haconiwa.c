#include "mruby.h"
#include "mruby/error.h"
#include "mruby/string.h"
#include "mruby/hash.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

struct mrbgem_revision {
  const char* gemname;
  const char* revision;
};

const struct mrbgem_revision GEMS[] = {
  #include "REVISIONS.defs"
  {NULL, NULL},
};

static mrb_value mrb_haconiwa_mrgbem_revisions(mrb_state *mrb, mrb_value self)
{
  mrb_value ha = mrb_hash_new(mrb);

  for (int i = 0; GEMS[i].gemname != NULL; ++i) {
    mrb_hash_set(mrb, ha, mrb_str_new_cstr(mrb, GEMS[i].gemname), mrb_str_new_cstr(mrb, GEMS[i].revision));
  }

  return ha;
}

#define TRY_REOPEN(fp, newfile, mode, oldfp) \
  fp = freopen("/dev/null", "w", stdout);    \
  if(fp == NULL) mrb_sys_fail(mrb, "freopen failed")

static mrb_value mrb_haconiwa_daemon_fd_reopen(mrb_state *mrb, mrb_value self)
{
  /* TODO reopen to log file */
  FILE *fp;
  TRY_REOPEN(fp, "/dev/null", "r", stdin);
  TRY_REOPEN(fp, "/dev/null", "w", stdout);
  TRY_REOPEN(fp, "/dev/null", "w", stderr);

  return mrb_true_value();
}

void mrb_haconiwa_gem_init(mrb_state *mrb)
{
  struct RClass *haconiwa;
  haconiwa = mrb_define_module(mrb, "Haconiwa");
  mrb_define_class_method(mrb, haconiwa, "mrbgem_revisions", mrb_haconiwa_mrgbem_revisions, MRB_ARGS_NONE());
  mrb_define_class_method(mrb, haconiwa, "daemon_fd_reopen", mrb_haconiwa_daemon_fd_reopen, MRB_ARGS_NONE());

  DONE;
}

void mrb_haconiwa_gem_final(mrb_state *mrb)
{
}
